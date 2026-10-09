import {decorateRecoveryCauses} from "../game-interruption/game-adapters.js";
/* eslint-disable valid-jsdoc */

import {randomUUID} from "node:crypto";

import {
  getDatabase,

} from "firebase-admin/database";
import {assertOnboardingComplete} from
  "../auth/require-complete-onboarding.js";
import {
  RecoveryRoom,
  registerRecoveryFailure,
} from "../game-interruption/recovery-state.js";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  assertControllerSession,

} from "./controller-session.js";
import {
  decideRoomJoin,
  GAME_PREPARATION_STARTED_MESSAGE,
  RoomJoinDecision,
} from "./room-join-policy.js";
import {decideSeatSave} from "./room-seating-policy.js";
import {runPrimedTransaction} from "./room-transaction.js";
import {
  allocateRoomConnection, assertRoomTarget, parseSessionId,
  roomOperationResult, SessionRoom,
} from "./session-contract.js";

const REGION = "asia-northeast3";


const ROOM_CODE_PATTERN =
  /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;

// 마피아가 최대 12명이라 방 상한을 12로 올렸습니다. 게임별 인원 제한은 각
// 게임의 start_game이 따로 확인합니다(예: 파이널콜은 4인 또는 6인).
const DEFAULT_MAX_PLAYERS = 12;

// 포커페이스 캐릭터 20종입니다. 예전 동물 id는 이미 배포된 앱이 보낼 수 있어
// 함께 허용하고, 클라이언트가 포커페이스 얼굴로 바꿔 그립니다.
const ROOM_CHARACTER_IDS = new Set([
  "burger", "cone", "popcorn", "bucket", "pot", "parcel", "watermelon",
  "capmask", "hood", "scarf", "astronaut", "welder", "catcher", "goggles",
  "disguise", "bandage", "tissue", "milk", "cupnoodle", "lampshade",
  "bear", "bee", "cat", "crab", "deer", "elephant", "frog", "giraffe",
  "hedgehog", "kindbear", "octopus", "owl", "penguin", "rabbit", "shark",
  "snake", "whale",
]);

type SaveSeatIndexesData = {
  roomInstanceId?: unknown;
  roomCode?: unknown;
  seatIndexesByUid?: unknown;
  controllerSessionId?: unknown;
};

type JoinRealtimeRoomData = {
  roomCode?: unknown;
  nickname?: unknown;
  characterId?: unknown;
  preserveProfile?: unknown;
  roomInstanceId?: unknown;
  membershipId?: unknown;
  expectedConnectionSeq?: unknown;
  operationId?: unknown;
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

export {createRealtimeRoom} from "./create-room.js";

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
    return {success: true, roomCode, roomInstanceId: room.roomInstanceId};
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
    const operationId = parseSessionId(request.data?.operationId, "작업 ID");
    const expectedRoomId = parseSessionId(request.data?.roomInstanceId, "방 세션");
    const connectionId = randomUUID();
    const newMembershipId = randomUUID();
    const now = Date.now();
    const operationPayload = {
      roomInstanceId: expectedRoomId, nickname, characterId, preserveProfile,
      membershipId: request.data?.membershipId,
      expectedConnectionSeq: request.data?.expectedConnectionSeq,
    };

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
    let connectionResult: Record<string, unknown> | null = null;

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
        const sessionRoom = currentRoom as SessionRoom;
        assertRoomTarget(sessionRoom, expectedRoomId);
        const saved = roomOperationResult(
          sessionRoom, uid, operationId, "connect", operationPayload,
        );
        if (saved) {
          connectionResult = saved;
          savedNickname = saved.nickname as string;
          reconnected = saved.reconnected === true;
          return currentRoom;
        }
        const players = currentRoom.players ?? {};

        const existingPlayer = players[uid];
        const decision = decideRoomJoin({
          roomStatus: currentRoom.status,
          gameStatus: currentRoom.game?.public?.status,
          playerExists: existingPlayer !== undefined,
          playerStatus: existingPlayer?.status,
          reconnectOnly: preserveProfile,
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
          };
          delete updatedPlayer.profileImageUrl;
          delete updatedPlayer.accentColor;
          players[uid] = updatedPlayer;
          currentRoom.players = players;
          connectionResult = allocateRoomConnection(sessionRoom, {
            uid, role: "player", operationId, roomInstanceId: expectedRoomId,
            membershipId: parseSessionId(
              request.data?.membershipId, "참가 세션",
            ),
            expectedConnectionSeq:
              request.data?.expectedConnectionSeq as number,
            connectionId, now, operationPayload,
          });
          registerRecoveryFailure(
            currentRoom as RecoveryRoom, uid, "player", now,
            "preparationFailed",
          );
          decorateRecoveryCauses(currentRoom as RecoveryRoom, now);
          Object.assign(connectionResult!, {
            nickname: savedNickname, reconnected,
          });
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
          lastSeen: now,
          membershipId: newMembershipId,
          seatIndex: -1,
          role: "player",
          status: "active",
          penaltyAttemptCount: 0,
          joinedAt: now,
        };
        currentRoom.players = players;
        sessionRoom.membershipRevision =
          (sessionRoom.membershipRevision ?? 0) + 1;
        connectionResult = allocateRoomConnection(sessionRoom, {
          uid, role: "player", operationId, roomInstanceId: expectedRoomId,
          membershipId: newMembershipId, expectedConnectionSeq: 0,
          connectionId, now, operationPayload,
        });
        Object.assign(connectionResult, {nickname, reconnected: false});
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
      ...(connectionResult as Record<string, unknown> | null),
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
        assertRoomTarget(
          room as unknown as SessionRoom, request.data?.roomInstanceId,
        );
        const players = room.players;
        const playerIds = players ? Object.keys(players) : [];
        // 판정은 순수 함수 한곳에 모읍니다. 특히 명단 불일치(roster-changed)와
        // 좌석 번호 오류(invalid-seats)를 나눠서 돌려주는 것이 요점입니다.
        // 두 경우를 한 문구로 묶으면, 자리 배치 중 누가 나가서 생긴 실패까지
        // "중복 없이 지정하라"로 보여 진행자가 무엇을 고쳐야 하는지 알 수
        // 없었습니다(C-13).
        const decision = decideSeatSave({
          roomStatus: room.status,
          playerIds,
          seatEntries,
          minPlayers: 2,
          maxPlayers: DEFAULT_MAX_PLAYERS,
        });
        switch (decision) {
        case "not-seating":
          rejection = new HttpsError(
            "failed-precondition",
            "자리 배치 중에만 플레이어 자리를 저장할 수 있습니다.",
          );
          return;
        case "no-players":
          rejection = new HttpsError(
            "failed-precondition",
            "참가 플레이어가 없습니다.",
          );
          return;
        case "too-few-players":
          rejection = new HttpsError(
            "failed-precondition",
            "게임을 시작하려면 최소 2명이 필요합니다.",
          );
          return;
        case "too-many-players":
          rejection = new HttpsError(
            "failed-precondition",
            `플레이어는 최대 ${DEFAULT_MAX_PLAYERS}명입니다.`,
          );
          return;
        case "roster-changed":
          rejection = new HttpsError(
            "failed-precondition",
            "참가자가 변경되어 자리 배치를 다시 진행해주세요.",
          );
          return;
        case "invalid-seats":
          rejection = new HttpsError(
            "invalid-argument",
            "모든 플레이어의 자리는 중복 없이 지정해야 합니다.",
          );
          return;
        case "save":
          break;
        }
        for (const [playerId, seatIndex] of seatEntries) {
          players![playerId].seatIndex = seatIndex;
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
