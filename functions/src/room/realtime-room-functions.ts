/* eslint-disable valid-jsdoc */

import {randomInt} from "node:crypto";

import {
  getDatabase,
  ServerValue,
} from "firebase-admin/database";
import {
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";

const REGION = "asia-northeast3";

const ROOM_CODE_CHARS =
  "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

const ROOM_CODE_LENGTH = 5;

const ROOM_CODE_PATTERN =
  /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;

const DEFAULT_MAX_PLAYERS = 6;
const MAX_ROOM_CODE_ATTEMPTS = 20;

type SaveSeatIndexesData = {
  roomCode?: unknown;
  seatIndexesByUid?: unknown;
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

    const database = getDatabase();

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
            maxPlayers: DEFAULT_MAX_PLAYERS,
            selectedGame: null,
            createdAt: ServerValue.TIMESTAMP,
          };
        },
      );

      if (result.committed) {
        return {
          success: true,
          roomCode,
        };
      }
    }

    throw new HttpsError(
      "resource-exhausted",
      "사용 가능한 방 코드를 생성하지 못했습니다.",
    );
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

      // 신규 방은 controllerUid를 사용합니다.
      // hostUid는 기존 방 호환용입니다.
      const controllerUid =
        room.controllerUid ?? room.hostUid;

      if (controllerUid !== requesterUid) {
        throw new HttpsError(
          "permission-denied",
          "방을 만든 아이패드에서만 자리를 저장할 수 있습니다.",
        );
      }

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
