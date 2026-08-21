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
import {
  decideRoomJoin,
  GAME_PREPARATION_STARTED_MESSAGE,
  RoomJoinDecision,
} from "./room-join-policy.js";
import {runPrimedTransaction} from "./room-transaction.js";

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

type CreateRealtimeRoomData = {
  operationId?: unknown;
};

type RoomCreateReservation = {
  roomCode: string;
  controllerSessionId: string;
  createdAt: number;
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

/** 참가 판정 결과를 클라이언트용 callable 오류로 변환합니다. */
function joinDecisionError(decision: RoomJoinDecision): HttpsError | null {
  switch (decision) {
  case "room-closed":
    return new HttpsError("failed-precondition", "종료된 방입니다.");
  case "room-finished":
    return new HttpsError("failed-precondition", "이미 종료된 게임입니다.");
  case "inactive-player":
    return new HttpsError("failed-precondition", "이 방에는 다시 참가할 수 없습니다.");
  case "game-preparing":
    return new HttpsError(
      "failed-precondition",
      GAME_PREPARATION_STARTED_MESSAGE,
    );
  default:
    return null;
  }
}

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

/** 구버전 요청은 null로 두고 새 클라이언트의 방 생성 작업 ID를 검증합니다. */
function parseCreateOperationId(value: unknown): string | null {
  if (value === undefined || value === null) return null;
  const operationId = typeof value === "string" ? value.trim() : "";
  if (!/^[A-Za-z0-9_-]{8,128}$/.test(operationId)) {
    throw new HttpsError("invalid-argument", "올바른 작업 ID가 필요합니다.");
  }
  return operationId;
}

/**
 * 아이패드 컨트롤러용 RTDB 방 생성 함수입니다.
 *
 * Firebase Admin SDK를 사용하기 때문에 클라이언트의
 * Realtime Database 보안 규칙을 적용받지 않습니다.
 */
export const createRealtimeRoom = onCall<CreateRealtimeRoomData>(
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
    const operationId = parseCreateOperationId(request.data?.operationId);
    const now = Date.now();

    for (
      let attempt = 0;
      attempt < MAX_ROOM_CODE_ATTEMPTS;
      attempt += 1
    ) {
      let roomCode = generateRoomCode();
      let controllerSessionId = createControllerSessionId();
      let reservationRef: ReturnType<typeof database.ref> | null = null;
      if (operationId) {
        reservationRef = database.ref(
          `roomCreateRequests/${controllerUid}/${operationId}`,
        );
        const reserved = await reservationRef.transaction((current) => {
          if (current !== null) return current;
          return {roomCode, controllerSessionId, createdAt: now};
        });
        const reservation = reserved.snapshot.val() as
          RoomCreateReservation | null;
        if (!reservation?.roomCode || !reservation.controllerSessionId) {
          throw new HttpsError("internal", "방 생성 요청을 준비하지 못했습니다.");
        }
        roomCode = reservation.roomCode;
        controllerSessionId = reservation.controllerSessionId;
      }
      const roomRef = database.ref(
        `rooms/${roomCode}`,
      );

      const result = await roomRef.transaction(
        (currentRoom) => {
          if (currentRoom !== null) {
            if (
              operationId &&
              currentRoom.controllerUid === controllerUid &&
              currentRoom.creationOperationId === operationId
            ) {
              return currentRoom;
            }
            // 같은 코드의 다른 방이 이미 존재하면 새 코드를 예약합니다.
            return;
          }

          return {
            roomCode,
            controllerUid,
            // controllerSessionId는 보안 규칙에서 읽기를 막고 태블릿이
            // 로컬에 보관합니다. 모든 controller 명령은 UID와 세션을 함께
            // 검사하여 오래된 앱 인스턴스의 요청을 차단합니다.
            controllerSessionId,
            ...(operationId ? {creationOperationId: operationId} : {}),
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
      if (reservationRef) {
        // 극히 드문 방 코드 충돌일 때만 같은 요청의 예약 코드를 다시 뽑습니다.
        await reservationRef.remove();
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
    const publicGame = room.game as
      {public?: {status?: unknown}} | undefined;

    const players = room.players !== null &&
      typeof room.players === "object" &&
      !Array.isArray(room.players) ?
      room.players as Record<string, Record<string, unknown>> : {};
    const existingPlayer = players[uid];
    const decision = decideRoomJoin({
      roomStatus: room.status,
      gameStatus: publicGame?.public?.status,
      playerExists: existingPlayer !== undefined,
      playerStatus: existingPlayer?.status,
    });
    const decisionError = joinDecisionError(decision);
    if (decisionError) throw decisionError;
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

    let rejection: HttpsError | null = null;
    let reconnected = false;
    let savedNickname = nickname;

    const transaction = await runPrimedTransaction(
      roomRef,
      (currentValue) => {
        rejection = null;
        reconnected = false;
        if (currentValue === null || typeof currentValue !== "object") return;
        const currentRoom = currentValue as Record<string, unknown> & {
          players?: Record<string, Record<string, unknown>>;
          game?: {public?: {status?: unknown}};
        };
        const players = currentRoom.players ?? {};

        const existingPlayer = players[uid];
        const decision = decideRoomJoin({
          roomStatus: currentRoom.status,
          gameStatus: currentRoom.game?.public?.status,
          playerExists: existingPlayer !== undefined,
          playerStatus: existingPlayer?.status,
        });
        const decisionError = joinDecisionError(decision);
        if (decisionError) {
          rejection = decisionError;
          return;
        }

        const roomIsWaiting = (currentRoom.status ?? "waiting") === "waiting" &&
          currentRoom.game?.public?.status !== "playing";
        const keepExistingProfile = preserveProfile || !roomIsWaiting;
        const effectiveNickname = keepExistingProfile &&
          existingPlayer && typeof existingPlayer.nickname === "string" ?
          existingPlayer.nickname : nickname;
        const effectiveCharacterId = keepExistingProfile &&
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
          currentRoom.players = players;
          reconcileGamePlayerConnection(
            currentRoom as unknown as InterruptibleRoom,
            uid,
            false,
            true,
            Date.now(),
          );
          return currentRoom;
        }

        const maxPlayers = typeof currentRoom.maxPlayers === "number" ?
          currentRoom.maxPlayers : DEFAULT_MAX_PLAYERS;
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
        currentRoom.players = players;
        return currentRoom;
      },
    );

    if (!transaction.committed) {
      if (rejection) throw rejection;
      throw new HttpsError(
        "aborted",
        "방 참가 요청이 충돌했습니다. 다시 시도해주세요.",
      );
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

      const seatEntries =
        Object.entries(rawSeatIndexes);
      let rejection: HttpsError | null = null;
      const updateSeatIndexes = (currentValue: unknown) => {
        rejection = null;
        if (currentValue === null || typeof currentValue !== "object") return;
        const room = currentValue as Record<string, unknown> & {
          controllerUid?: string;
          hostUid?: string;
          controllerSessionId?: string;
          players?: Record<string, Record<string, unknown>>;
        };
        assertControllerSession(
          room,
          requesterUid,
          request.data?.controllerSessionId,
        );
        if (room.status !== "seating") {
          rejection = new HttpsError(
            "failed-precondition",
            "자리 배치 중에만 플레이어 자리를 저장할 수 있습니다.",
          );
          return;
        }
        const players = room.players;
        if (!players) {
          rejection = new HttpsError(
            "failed-precondition",
            "참가 플레이어가 없습니다.",
          );
          return;
        }
        const playerIds = Object.keys(players);
        if (playerIds.length < 2) {
          rejection = new HttpsError(
            "failed-precondition",
            "게임을 시작하려면 최소 2명이 필요합니다.",
          );
          return;
        }
        if (playerIds.length > DEFAULT_MAX_PLAYERS) {
          rejection = new HttpsError(
            "failed-precondition",
            `플레이어는 최대 ${DEFAULT_MAX_PLAYERS}명입니다.`,
          );
          return;
        }

        const seatPlayerIds = new Set(seatEntries.map(([uid]) => uid));
        const validPlayers = seatEntries.length === playerIds.length &&
          playerIds.every((uid) => seatPlayerIds.has(uid));
        const seats = seatEntries.map(([, seatIndex]) => seatIndex);
        const validSeats = seats.every(Number.isInteger) &&
          new Set(seats).size === seats.length &&
          seats.every((seat) => typeof seat === "number" &&
            seat >= 0 && seat < playerIds.length);
        if (!validPlayers || !validSeats) {
          rejection = new HttpsError(
            "invalid-argument",
            "모든 플레이어의 자리는 중복 없이 지정해야 합니다.",
          );
          return;
        }
        for (const [playerId, seatIndex] of seatEntries) {
          players[playerId].seatIndex = seatIndex;
        }
        room.players = players;
        return room;
      };
      const transaction = await runPrimedTransaction(
        roomRef,
        updateSeatIndexes,
      );
      if (!transaction.committed) {
        if (rejection) throw rejection;
        throw new HttpsError("aborted", "플레이어 자리를 저장하지 못했습니다.");
      }

      return {
        success: true,
        roomCode,
        seatIndexesByUid: rawSeatIndexes,
      };
    },
  );
