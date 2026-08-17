/* eslint-disable valid-jsdoc */

import {randomInt} from "node:crypto";

import {
  getDatabase,
  ServerValue,
} from "firebase-admin/database";
import {getFirestore} from "firebase-admin/firestore";
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

type JoinRealtimeRoomData = {
  roomCode?: unknown;
  nickname?: unknown;
  accentColor?: unknown;
  preserveProfile?: unknown;
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
            // 클라이언트는 방 전체 onDisconnect 삭제를 예약한 뒤에만
            // true로 바꿉니다. 따라서 휴대폰이 예약 없는 방에
            // 입장하는 경우를 막을 수 있습니다.
            controllerConnected: false,
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
    if (nickname.length < 1 || nickname.length > 20) {
      throw new HttpsError(
        "invalid-argument",
        "닉네임은 1~20자로 입력해주세요.",
      );
    }

    const rawAccentColor = request.data?.accentColor;
    const accentColor = typeof rawAccentColor === "string" &&
      /^#[0-9A-F]{6}$/.test(rawAccentColor.toUpperCase()) ?
      rawAccentColor.toUpperCase() : "#6557D2";
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
    const maxPlayers = typeof room.maxPlayers === "number" ?
      room.maxPlayers : DEFAULT_MAX_PLAYERS;
    const playersRef = roomRef.child("players");

    // Google 로그인 직후 Firestore에 동기화한 프로필을 우선 사용합니다.
    // 문서가 없거나 일시적으로 읽지 못하면 인증 토큰의 사진을 사용합니다.
    const tokenProfileImageUrl =
      typeof request.auth?.token.picture === "string" ?
        request.auth.token.picture : "";
    let profileImageUrl = tokenProfileImageUrl;
    try {
      const userSnapshot = await getFirestore()
        .collection("users")
        .doc(uid)
        .get();
      const firestoreProfileImageUrl =
        userSnapshot.data()?.profileImageUrl;
      if (
        typeof firestoreProfileImageUrl === "string" &&
        firestoreProfileImageUrl.trim().length > 0
      ) {
        profileImageUrl = firestoreProfileImageUrl.trim();
      }
    } catch (error) {
      console.warn("joinRealtimeRoom profile lookup failed", error);
    }

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
        const effectiveAccentColor = preserveProfile &&
          existingPlayer && typeof existingPlayer.accentColor === "string" ?
          existingPlayer.accentColor : accentColor;
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

        if (existingPlayer && typeof existingPlayer === "object") {
          reconnected = true;
          savedNickname = effectiveNickname;
          players[uid] = {
            ...existingPlayer,
            nickname: effectiveNickname,
            profileImageUrl: profileImageUrl ||
              (typeof existingPlayer.profileImageUrl === "string" ?
                existingPlayer.profileImageUrl : ""),
            isConnected: true,
            accentColor: effectiveAccentColor,
          };
          return players;
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
          profileImageUrl,
          accentColor,
          isConnected: true,
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
