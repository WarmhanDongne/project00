/* eslint-disable valid-jsdoc */

import {randomInt} from "node:crypto";

import {
  getDatabase,
  ServerValue,
} from "firebase-admin/database";
import {assertOnboardingComplete} from
  "../auth/require-complete-onboarding.js";
import {
  InterruptibleRoom,
  reconcileGamePlayerConnection,
} from "../game-interruption/state.js";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  assertControllerSession,
  createControllerSessionId,
} from "./controller-session.js";

const REGION = "asia-northeast3";

const ROOM_CODE_CHARS =
  "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

const ROOM_CODE_LENGTH = 5;

const ROOM_CODE_PATTERN =
  /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;

// 마피아가 최대 12명이라 방 상한을 12로 올렸습니다. 게임별 인원 제한은 각
// 게임의 start_game이 따로 확인합니다(예: 파이널콜은 4인 고정).
const DEFAULT_MAX_PLAYERS = 12;
const MAX_ROOM_CODE_ATTEMPTS = 20;
const ROOM_CHARACTER_IDS = new Set([
  "bear", "bee", "cat", "crab", "deer", "elephant", "frog", "giraffe",
  "hedgehog", "kindbear", "octopus", "owl", "penguin", "rabbit", "shark",
  "snake", "whale",
]);

type SaveSeatIndexesData = {
  roomCode?: unknown;
  seatIndexesByUid?: unknown;
  controllerSessionId?: unknown;
};

type JoinRealtimeRoomData = {
  roomCode?: unknown;
  nickname?: unknown;
  characterId?: unknown;
  preserveProfile?: unknown;
};

type ValidateRealtimeRoomData = {
  roomCode?: unknown;
};

/**
 * 중복 가능성이 낮은 5자리 방 코드를 생성합니다.
 */
function generateRoomCode(): string {
  return Array.from(
    {length: ROOM_CODE_LENGTH},
    () => {
      const index = randomInt(ROOM_CODE_CHARS.length);
      return ROOM_CODE_CHARS[index];
    },
  ).join("");
}

/**
 * 아이패드 컨트롤러용 RTDB 방 생성 함수입니다.
 *
 * Firebase Admin SDK를 사용하기 때문에 클라이언트의
 * Realtime Database 보안 규칙을 적용받지 않습니다.
 */
export const createRealtimeRoom = onCall(
  {region: REGION},
  async (request) => {
    const controllerUid = request.auth?.uid;

    if (!controllerUid) {
      throw new HttpsError(
        "unauthenticated",
        "방을 만들려면 로그인이 필요합니다.",
      );
    }
    await assertOnboardingComplete(controllerUid);

    const database = getDatabase();
    const controllerSessionId = createControllerSessionId();
    const now = Date.now();

    for (
      let attempt = 0;
      attempt < MAX_ROOM_CODE_ATTEMPTS;
      attempt += 1
    ) {
      const roomCode = generateRoomCode();
      const roomRef = database.ref(
        `rooms/${roomCode}`,
      );

      const result = await roomRef.transaction(
        (currentRoom) => {
          // 같은 코드의 방이 이미 존재하면
          // 이 트랜잭션을 중단하고 다른 코드를 시도합니다.
          if (currentRoom !== null) {
            return;
          }

          return {
            roomCode,
            controllerUid,
            // controllerSessionId는 보안 규칙에서 읽기를 막고 태블릿이
            // 로컬에 보관합니다. 모든 controller 명령은 UID와 세션을 함께
            // 검사하여 오래된 앱 인스턴스의 요청을 차단합니다.
            controllerSessionId,
            controllerConnected: true,
            controllerPresence: {
              connected: true,
              lastSeen: now,
            },
            status: "waiting",
            cleanupAt: now + 3 * 60 * 1000,
            maxPlayers: DEFAULT_MAX_PLAYERS,
            selectedGame: null,
            createdAt: ServerValue.TIMESTAMP,
          };
        },
      );

      if (result.committed) {
        await database.ref(`controllerRooms/${controllerUid}`).set(roomCode);
        return {
          success: true,
          roomCode,
          controllerSessionId,
        };
      }
    }

    throw new HttpsError(
      "resource-exhausted",
      "사용 가능한 방 코드를 생성하지 못했습니다.",
    );
  },
);

/** 플레이어를 생성하지 않고 방 코드와 현재 입장 가능 상태만 검증합니다. */
export const validateRealtimeRoom = onCall<ValidateRealtimeRoomData>(
  {region: REGION},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    await assertOnboardingComplete(uid);

    const rawRoomCode = request.data?.roomCode;
    const roomCode = typeof rawRoomCode === "string" ?
      rawRoomCode.trim().toUpperCase() : "";
    if (!ROOM_CODE_PATTERN.test(roomCode)) {
      throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
    }

    const snapshot = await getDatabase().ref(`rooms/${roomCode}`).get();
    if (!snapshot.exists()) {
      throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    }
    const room = snapshot.val() as Record<string, unknown>;
    if (room.status === "closed") {
      throw new HttpsError("failed-precondition", "종료된 방입니다.");
    }
    const publicGame = room.game as
      {public?: {status?: unknown}} | undefined;
    if (
      room.status === "finished" ||
      publicGame?.public?.status === "playing"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "이미 진행 중인 게임에는 새로 참가할 수 없습니다.",
      );
    }

    const players = room.players !== null &&
      typeof room.players === "object" &&
      !Array.isArray(room.players) ?
      room.players as Record<string, unknown> : {};
    const maxPlayers = typeof room.maxPlayers === "number" ?
      room.maxPlayers : DEFAULT_MAX_PLAYERS;
    if (!(uid in players) && Object.keys(players).length >= maxPlayers) {
      throw new HttpsError("resource-exhausted", "방 인원이 초과되었습니다.");
    }
    return {success: true, roomCode};
  },
);

/**
 * 휴대폰 참가와 재접속을 Admin SDK로 처리합니다.
 * 기존 UID는 좌석과 게임 데이터를 유지하고 연결 상태만 복구합니다.
 */
export const joinRealtimeRoom = onCall<JoinRealtimeRoomData>(
  {region: REGION},
  async (request) => {
    const uid = request.auth?.uid;
    if (!uid) {
      throw new HttpsError(
        "unauthenticated",
        "로그인이 필요합니다.",
      );
    }
    await assertOnboardingComplete(uid);

    const rawRoomCode = request.data?.roomCode;
    const roomCode = typeof rawRoomCode === "string" ?
      rawRoomCode.trim().toUpperCase() : "";
    if (!ROOM_CODE_PATTERN.test(roomCode)) {
      throw new HttpsError(
        "invalid-argument",
        "올바른 방 코드가 아닙니다.",
      );
    }

    const rawNickname = request.data?.nickname;
    const nickname = typeof rawNickname === "string" ?
      rawNickname.trim() : "";
    if (nickname.length < 1 || nickname.length > 12) {
      throw new HttpsError(
        "invalid-argument",
        "닉네임은 1~12자로 입력해주세요.",
      );
    }

    const rawCharacterId = request.data?.characterId;
    const characterId = typeof rawCharacterId === "string" ?
      rawCharacterId.trim() : "";
    if (!ROOM_CHARACTER_IDS.has(characterId)) {
      throw new HttpsError("invalid-argument", "올바른 캐릭터를 선택해주세요.");
    }
    const preserveProfile = request.data?.preserveProfile === true;

    const database = getDatabase();
    const roomRef = database.ref(`rooms/${roomCode}`);
    const roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists()) {
      throw new HttpsError(
        "not-found",
        "방을 찾을 수 없습니다.",
      );
    }

    const room = roomSnapshot.val() as Record<string, unknown>;
    if (room.status === "closed") {
      throw new HttpsError("failed-precondition", "종료된 방입니다.");
    }
    const maxPlayers = typeof room.maxPlayers === "number" ?
      room.maxPlayers : DEFAULT_MAX_PLAYERS;
    const playersRef = roomRef.child("players");

    let rejection: HttpsError | null = null;
    let reconnected = false;
    let savedNickname = nickname;

    const transaction = await playersRef.transaction(
      (currentValue) => {
        rejection = null;
        reconnected = false;
        const players = currentValue !== null &&
          typeof currentValue === "object" &&
          !Array.isArray(currentValue) ?
          currentValue as Record<string, Record<string, unknown>> : {};

        const existingPlayer = players[uid];
        const effectiveNickname = preserveProfile &&
          existingPlayer && typeof existingPlayer.nickname === "string" ?
          existingPlayer.nickname : nickname;
        const effectiveCharacterId = preserveProfile &&
          existingPlayer && typeof existingPlayer.characterId === "string" &&
          ROOM_CHARACTER_IDS.has(existingPlayer.characterId) ?
          existingPlayer.characterId : characterId;
        const duplicatedNickname = Object.entries(players).some(
          ([playerUid, player]) =>
            playerUid !== uid && player?.nickname === effectiveNickname,
        );
        if (duplicatedNickname) {
          rejection = new HttpsError(
            "already-exists",
            "이미 사용 중인 닉네임입니다.",
          );
          return;
        }
        const duplicatedCharacter = Object.entries(players).some(
          ([playerUid, player]) =>
            playerUid !== uid && player?.characterId === effectiveCharacterId,
        );
        if (duplicatedCharacter) {
          rejection = new HttpsError(
            "already-exists",
            "이미 선택된 캐릭터입니다.",
          );
          return;
        }

        if (existingPlayer && typeof existingPlayer === "object") {
          reconnected = true;
          savedNickname = effectiveNickname;
          const updatedPlayer: Record<string, unknown> = {
            ...existingPlayer,
            nickname: effectiveNickname,
            characterId: effectiveCharacterId,
            isConnected: true,
            lastSeen: Date.now(),
          };
          delete updatedPlayer.profileImageUrl;
          delete updatedPlayer.accentColor;
          players[uid] = updatedPlayer;
          return players;
        }

        const publicGame = room.game as
          {public?: {status?: unknown}} | undefined;
        if (
          room.status === "finished" ||
          publicGame?.public?.status === "playing"
        ) {
          rejection = new HttpsError(
            "failed-precondition",
            "이미 진행 중인 게임에는 새로 참가할 수 없습니다.",
          );
          return;
        }

        if (Object.keys(players).length >= maxPlayers) {
          rejection = new HttpsError(
            "resource-exhausted",
            "방 인원이 초과되었습니다.",
          );
          return;
        }

        players[uid] = {
          uid,
          nickname,
          characterId,
          isConnected: true,
          lastSeen: Date.now(),
          seatIndex: -1,
          role: "player",
          status: "active",
          penaltyAttemptCount: 0,
          joinedAt: Date.now(),
        };
        return players;
      },
    );

    if (!transaction.committed) {
      if (rejection) throw rejection;
      throw new HttpsError(
        "aborted",
        "방 참가 요청이 충돌했습니다. 다시 시도해주세요.",
      );
    }

    // =======================게임 중 재접속 확정==============================
    // players 하위 트랜잭션과 연결 이벤트 트리거의 실행 순서가 엇갈려도 현재
    // presence와 게임 중단 해제를 한 방 트랜잭션에서 다시 확정합니다. seat와
    // game/private는 UID 경로를 그대로 유지하므로 절대 새로 만들지 않습니다.
    if (reconnected) {
      await roomRef.transaction((currentValue) => {
        if (currentValue === null || typeof currentValue !== "object") {
          return currentValue;
        }
        const currentRoom = currentValue as Record<string, unknown> & {
          players?: Record<string, Record<string, unknown>>;
        };
        const currentPlayer = currentRoom.players?.[uid];
        if (!currentPlayer) return currentValue;
        currentPlayer.isConnected = true;
        currentPlayer.lastSeen = Date.now();
        reconcileGamePlayerConnection(
          currentRoom as unknown as InterruptibleRoom,
          uid,
          false,
          true,
          Date.now(),
        );
        return currentRoom;
      });
    }

    return {
      success: true,
      roomCode,
      reconnected,
      nickname: savedNickname,
    };
  },
);

/**
 * 아이패드에서 지정한 플레이어 좌석을 RTDB에 저장합니다.
 */
export const saveRealtimePlayerSeatIndexes =
  onCall<SaveSeatIndexesData>(
    {region: REGION},
    async (request) => {
      const requesterUid = request.auth?.uid;

      if (!requesterUid) {
        throw new HttpsError(
          "unauthenticated",
          "로그인이 필요합니다.",
        );
      }

      // 방 코드 확인
      const rawRoomCode = request.data?.roomCode;

      const roomCode =
        typeof rawRoomCode === "string" ?
          rawRoomCode.trim().toUpperCase() :
          "";

      if (!ROOM_CODE_PATTERN.test(roomCode)) {
        throw new HttpsError(
          "invalid-argument",
          "올바른 방 코드가 아닙니다.",
        );
      }

      // 좌석 정보 확인
      const rawSeatIndexes =
        request.data?.seatIndexesByUid;

      if (
        typeof rawSeatIndexes !== "object" ||
        rawSeatIndexes === null ||
        Array.isArray(rawSeatIndexes)
      ) {
        throw new HttpsError(
          "invalid-argument",
          "플레이어 자리 정보를 확인할 수 없습니다.",
        );
      }

      const database = getDatabase();

      const roomRef = database.ref(
        `rooms/${roomCode}`,
      );

      const roomSnapshot = await roomRef.get();

      if (!roomSnapshot.exists()) {
        throw new HttpsError(
          "not-found",
          "방을 찾을 수 없습니다.",
        );
      }

      const room = roomSnapshot.val() as Record<
        string,
        unknown
      >;

      assertControllerSession(
        room,
        requesterUid,
        request.data?.controllerSessionId,
      );

      const players = room.players;

      if (
        typeof players !== "object" ||
        players === null ||
        Array.isArray(players)
      ) {
        throw new HttpsError(
          "failed-precondition",
          "참가 플레이어가 없습니다.",
        );
      }

      const playerIds = Object.keys(players);
      const seatEntries =
        Object.entries(rawSeatIndexes);

      if (playerIds.length < 2) {
        throw new HttpsError(
          "failed-precondition",
          "게임을 시작하려면 최소 2명이 필요합니다.",
        );
      }

      if (playerIds.length > DEFAULT_MAX_PLAYERS) {
        throw new HttpsError(
          "failed-precondition",
          `플레이어는 최대 ${DEFAULT_MAX_PLAYERS}명입니다.`,
        );
      }

      // 전달된 UID가 실제 참가자와 정확히 일치하는지 확인
      const seatPlayerIds = new Set(
        seatEntries.map(([uid]) => uid),
      );

      const validPlayers =
        seatEntries.length === playerIds.length &&
        playerIds.every(
          (uid) => seatPlayerIds.has(uid),
        );

      // 모든 좌석이 정수이고 0~인원수-1 범위이며
      // 중복되지 않았는지 확인
      const seats = seatEntries.map(
        ([, seatIndex]) => seatIndex,
      );

      const validSeats =
        seats.every(Number.isInteger) &&
        new Set(seats).size === seats.length &&
        seats.every(
          (seat) =>
            typeof seat === "number" &&
            seat >= 0 &&
            seat < playerIds.length,
        );

      if (!validPlayers || !validSeats) {
        throw new HttpsError(
          "invalid-argument",
          "모든 플레이어의 자리는 중복 없이 지정해야 합니다.",
        );
      }

      const updates: Record<string, number> = {};

      for (
        const [playerId, seatIndex] of seatEntries
      ) {
        updates[
          `players/${playerId}/seatIndex`
        ] = seatIndex as number;
      }

      await roomRef.update(updates);

      return {
        success: true,
        roomCode,
        seatIndexesByUid: rawSeatIndexes,
      };
    },
  );
