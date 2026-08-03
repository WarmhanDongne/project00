import {getDatabase} from "firebase-admin/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

const REGION = "asia-northeast3";
const ROOM_CODE_PATTERN = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;

type SaveSeatIndexesData = {
  roomCode?: unknown;
  seatIndexesByUid?: unknown;
};

export const saveRealtimePlayerSeatIndexes = onCall<SaveSeatIndexesData>(
  {region: REGION},
  async (request) => {
    const requesterUid = request.auth?.uid;
    if (!requesterUid) {
      throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
    }

    const rawRoomCode = request.data?.roomCode;
    const roomCode = typeof rawRoomCode === "string" ?
      rawRoomCode.trim().toUpperCase() : "";
    if (!ROOM_CODE_PATTERN.test(roomCode)) {
      throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
    }

    const rawSeatIndexes = request.data?.seatIndexesByUid;
    if (typeof rawSeatIndexes !== "object" || rawSeatIndexes === null ||
        Array.isArray(rawSeatIndexes)) {
      throw new HttpsError(
        "invalid-argument",
        "플레이어 자리 정보를 확인할 수 없습니다.",
      );
    }

    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    const roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists()) {
      throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    }

    const room = roomSnapshot.val() as Record<string, unknown>;
    if (room.hostUid !== requesterUid) {
      throw new HttpsError(
        "permission-denied",
        "방장만 플레이어 자리를 저장할 수 있습니다.",
      );
    }

    const players = room.players;
    if (typeof players !== "object" || players === null ||
        Array.isArray(players)) {
      throw new HttpsError("failed-precondition", "참가 플레이어가 없습니다.");
    }

    const playerIds = Object.keys(players);
    const seatEntries = Object.entries(rawSeatIndexes);
    const seatPlayerIds = new Set(seatEntries.map(([uid]) => uid));
    const seats = seatEntries.map(([, seatIndex]) => seatIndex);
    const validPlayers = seatEntries.length === playerIds.length &&
      playerIds.every((uid) => seatPlayerIds.has(uid));
    const validSeats = seats.every(Number.isInteger) &&
      new Set(seats).size === seats.length &&
      seats.every((seat) =>
        typeof seat === "number" && seat >= 0 && seat < playerIds.length,
      );
    if (!validPlayers || !validSeats) {
      throw new HttpsError(
        "invalid-argument",
        "모든 플레이어의 자리는 중복 없이 지정해야 합니다.",
      );
    }

    const updates: Record<string, number> = {};
    for (const [playerId, seatIndex] of seatEntries) {
      updates[`players/${playerId}/seatIndex`] = seatIndex as number;
    }
    await roomRef.update(updates);

    return {success: true, roomCode};
  },
);
