/* eslint-disable valid-jsdoc */

import {randomInt} from "node:crypto";

import {
  CallableRequest,
  HttpsError,
  onCall,
} from "firebase-functions/v2/https";
import {
  FieldValue,
  getFirestore,
} from "firebase-admin/firestore";

const REGION = "asia-northeast3";
const DEFAULT_MAX_MEMBERS = 6;
const ROOM_CODE_LENGTH = 5;
const ROOM_CODE_CHARS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789";

type ResetRoomData = {
  clientType?: unknown;
};

type RoomCodeData = {
  roomCode?: unknown;
};

type ReadyData = RoomCodeData & {
  isReady?: unknown;
};

type SelectGameData = RoomCodeData & {
  gameId?: unknown;
};

/**
 * 인증된 사용자의 UID를 반환합니다.
 * @param request Callable 요청
 * @return 인증된 UID
 */
function requireUid(request: CallableRequest<unknown>): string {
  const uid = request.auth?.uid;
  if (!uid) {
    throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  }
  return uid;
}

/**
 * 방 생성 요청이 아이패드 화면에서 전달됐는지 확인합니다.
 * @param clientType 클라이언트 기기 유형
 */
function requireTabletClient(clientType: unknown): void {
  if (clientType !== "tablet") {
    throw new HttpsError(
      "permission-denied",
      "아이패드에서만 방을 만들 수 있습니다.",
    );
  }
}

/**
 * 방 코드를 정규화하고 유효성을 검사합니다.
 * @param value 검사할 값
 * @return 정규화된 방 코드
 */
function parseRoomCode(value: unknown): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "방 코드를 입력해주세요.");
  }

  const roomCode = value.trim().toUpperCase();
  const validCode = new RegExp(
    `^[${ROOM_CODE_CHARS}]{${ROOM_CODE_LENGTH}}$`,
  );
  if (!validCode.test(roomCode)) {
    throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
  }
  return roomCode;
}

/**
 * 게임 문서 ID를 검증합니다.
 * @param value 검사할 값
 * @return 검증된 게임 ID
 */
function parseGameId(value: unknown): string {
  if (typeof value !== "string") {
    throw new HttpsError("invalid-argument", "게임을 선택해주세요.");
  }

  const gameId = value.trim();
  if (!/^[a-z0-9_-]{1,64}$/.test(gameId)) {
    throw new HttpsError("invalid-argument", "올바른 게임 ID가 아닙니다.");
  }
  return gameId;
}

/**
 * 충돌 가능성이 낮은 5자리 참여 코드를 생성합니다.
 * @return 생성된 참여 코드
 */
function generateRoomCode(): string {
  return Array.from(
    {length: ROOM_CODE_LENGTH},
    () => ROOM_CODE_CHARS[randomInt(ROOM_CODE_CHARS.length)],
  ).join("");
}
export const createRoomCode = onCall(
  {region: REGION},
  async () => {
    return {
      roomCode: generateRoomCode(),
    };
  },
);

/**
 * 인증 토큰에서 공개 가능한 플레이어 정보를 만듭니다.
 * @param request Callable 요청
 * @param uid 플레이어 UID
 * @return Firestore에 저장할 공개 플레이어 정보
 */
function memberData(request: CallableRequest<unknown>, uid: string) {
  const name = request.auth?.token.name;
  const email = request.auth?.token.email;
  const picture = request.auth?.token.picture;
  const emailName = typeof email === "string" ? email.split("@")[0] : null;

  return {
    uid,
    nickname:
      typeof name === "string" && name.trim().length > 0 ?
        name.trim() :
        emailName || "사용자",
    profileImageUrl: typeof picture === "string" ? picture : "",
    isHost: false,
    isReady: false,
    role: "player",
    status: "active",
    joinedAt: FieldValue.serverTimestamp(),
    updatedAt: FieldValue.serverTimestamp(),
  };
}

/**
 * 아이패드 소유자의 기존 방과 참가자 연결을 제거합니다.
 * 클라이언트는 완료 후 새 방을 생성합니다.
 */
export const resetRoom = onCall<ResetRoomData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const db = getFirestore();
    requireTabletClient(request.data?.clientType);

    const userRoomRef = db.collection("userRooms").doc(uid);
    const userRoomSnapshot = await userRoomRef.get();
    const savedRoomCode = userRoomSnapshot.data()?.roomCode;

    if (typeof savedRoomCode !== "string") {
      return {deletedRoomCode: null};
    }

    const roomCode = parseRoomCode(savedRoomCode);
    const roomRef = db.collection("rooms").doc(roomCode);

    await db.runTransaction(async (transaction) => {
      const roomSnapshot = await transaction.get(roomRef);
      if (!roomSnapshot.exists) {
        return;
      }
      if (roomSnapshot.get("hostUid") !== uid) {
        throw new HttpsError(
          "permission-denied",
          "자신이 만든 방만 초기화할 수 있습니다.",
        );
      }

      transaction.update(roomRef, {
        status: "resetting",
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    const memberSnapshot = await roomRef.collection("members").get();
    if (!memberSnapshot.empty) {
      const participantRefs = memberSnapshot.docs.map((member) =>
        db.collection("roomParticipants").doc(member.id),
      );
      const participantSnapshots = await db.getAll(...participantRefs);
      const batch = db.batch();
      let deleteCount = 0;

      for (const participant of participantSnapshots) {
        if (participant.data()?.roomCode === roomCode) {
          batch.delete(participant.ref);
          deleteCount += 1;
        }
      }
      if (deleteCount > 0) {
        await batch.commit();
      }
    }

    await db.recursiveDelete(roomRef);

    await db.runTransaction(async (transaction) => {
      const latestUserRoom = await transaction.get(userRoomRef);
      if (latestUserRoom.data()?.roomCode === roomCode) {
        transaction.delete(userRoomRef);
      }
    });

    return {deletedRoomCode: roomCode};
  },
);

export const joinRoom = onCall<RoomCodeData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const db = getFirestore();
    const roomRef = db.collection("rooms").doc(roomCode);
    const memberRef = roomRef.collection("members").doc(uid);
    const participantRef = db.collection("roomParticipants").doc(uid);

    await db.runTransaction(async (transaction) => {
      const roomSnapshot = await transaction.get(roomRef);
      const memberSnapshot = await transaction.get(memberRef);
      const participantSnapshot = await transaction.get(participantRef);

      if (!roomSnapshot.exists) {
        throw new HttpsError("not-found", "존재하지 않는 방입니다.");
      }
      // if (roomSnapshot.get("hostUid") === uid) {
      //   throw new HttpsError(
      //     "failed-precondition",
      //     "아이패드 계정은 플레이어로 참가할 수 없습니다.",
      //   );
      // }
      if (roomSnapshot.get("status") !== "waiting") {
        throw new HttpsError(
          "failed-precondition",
          "이미 게임이 시작된 방입니다.",
        );
      }

      const previousRoomCode = participantSnapshot.data()?.roomCode;
      if (
        participantSnapshot.exists &&
        previousRoomCode !== roomCode
      ) {
        throw new HttpsError(
          "failed-precondition",
          "이미 다른 방에 참가하고 있습니다.",
        );
      }

      if (!memberSnapshot.exists) {
        const memberCount =
          (roomSnapshot.get("memberCount") as number | undefined) ?? 0;
        const maxMembers =
          (roomSnapshot.get("maxMembers") as number | undefined) ??
          DEFAULT_MAX_MEMBERS;

        if (memberCount >= maxMembers) {
          throw new HttpsError(
            "resource-exhausted",
            "방의 최대 인원을 초과했습니다.",
          );
        }

        transaction.set(memberRef, memberData(request, uid));
        transaction.update(roomRef, {
          memberCount: memberCount + 1,
          updatedAt: FieldValue.serverTimestamp(),
        });
      }

      transaction.set(
        participantRef,
        {
          uid,
          roomCode,
          updatedAt: FieldValue.serverTimestamp(),
        },
        {merge: true},
      );
    });

    return {roomCode};
  },
);

export const setRoomReady = onCall<ReadyData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    if (typeof request.data?.isReady !== "boolean") {
      throw new HttpsError(
        "invalid-argument",
        "준비 상태를 확인할 수 없습니다.",
      );
    }

    const db = getFirestore();
    const roomRef = db.collection("rooms").doc(roomCode);
    const memberRef = roomRef.collection("members").doc(uid);

    await db.runTransaction(async (transaction) => {
      const roomSnapshot = await transaction.get(roomRef);
      const memberSnapshot = await transaction.get(memberRef);

      if (!roomSnapshot.exists || !memberSnapshot.exists) {
        throw new HttpsError("not-found", "참가 중인 방이 아닙니다.");
      }
      if (roomSnapshot.get("status") !== "waiting") {
        throw new HttpsError(
          "failed-precondition",
          "게임 시작 후에는 준비 상태를 바꿀 수 없습니다.",
        );
      }

      transaction.update(memberRef, {
        isReady: request.data.isReady,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {isReady: request.data.isReady};
  },
);

export const leaveRoom = onCall<RoomCodeData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const db = getFirestore();
    const roomRef = db.collection("rooms").doc(roomCode);
    const memberRef = roomRef.collection("members").doc(uid);
    const participantRef = db.collection("roomParticipants").doc(uid);

    await db.runTransaction(async (transaction) => {
      const roomSnapshot = await transaction.get(roomRef);
      const memberSnapshot = await transaction.get(memberRef);
      const participantSnapshot = await transaction.get(participantRef);

      if (!roomSnapshot.exists || !memberSnapshot.exists) {
        if (
          participantSnapshot.exists &&
          participantSnapshot.get("roomCode") === roomCode
        ) {
          transaction.delete(participantRef);
        }
        return;
      }
      if (roomSnapshot.get("status") !== "waiting") {
        throw new HttpsError(
          "failed-precondition",
          "게임 진행 중에는 방에서 나갈 수 없습니다.",
        );
      }

      const memberCount =
        (roomSnapshot.get("memberCount") as number | undefined) ?? 1;
      transaction.delete(memberRef);
      transaction.update(roomRef, {
        memberCount: Math.max(0, memberCount - 1),
        updatedAt: FieldValue.serverTimestamp(),
      });

      if (
        participantSnapshot.exists &&
        participantSnapshot.get("roomCode") === roomCode
      ) {
        transaction.delete(participantRef);
      }
    });

    return {roomCode};
  },
);

export const selectRoomGame = onCall<SelectGameData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const gameId = parseGameId(request.data?.gameId);
    const db = getFirestore();
    const roomRef = db.collection("rooms").doc(roomCode);
    const gameRef = db.collection("games").doc(gameId);

    await db.runTransaction(async (transaction) => {
      const roomSnapshot = await transaction.get(roomRef);
      const gameSnapshot = await transaction.get(gameRef);

      if (!roomSnapshot.exists) {
        throw new HttpsError("not-found", "존재하지 않는 방입니다.");
      }
      if (roomSnapshot.get("hostUid") !== uid) {
        throw new HttpsError(
          "permission-denied",
          "방장만 게임을 선택할 수 있습니다.",
        );
      }
      if (roomSnapshot.get("status") !== "waiting") {
        throw new HttpsError(
          "failed-precondition",
          "게임 진행 중에는 다른 게임을 선택할 수 없습니다.",
        );
      }
      if (!gameSnapshot.exists) {
        throw new HttpsError("not-found", "등록되지 않은 게임입니다.");
      }
      if (gameSnapshot.get("isActive") === false) {
        throw new HttpsError(
          "failed-precondition",
          "현재 이용할 수 없는 게임입니다.",
        );
      }

      transaction.update(roomRef, {
        gameId,
        selectedGameId: gameId,
        updatedAt: FieldValue.serverTimestamp(),
      });
    });

    return {roomCode, gameId};
  },
);
