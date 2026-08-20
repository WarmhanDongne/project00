/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {getDatabase} from "firebase-admin/database";
import {onValueWritten} from "firebase-functions/v2/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
  assertControllerSession,
  ControllerSessionRoom,
} from "./controller-session.js";

const REGION = "asia-northeast3";
const DATABASE_REGION = "asia-southeast1";
const ROOM_CODE = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;
const CONTROLLER_RECONNECT_GRACE_MS = 3 * 60 * 1000;
const FINISHED_ROOM_RETENTION_MS = 15 * 60 * 1000;
const CLOSED_ROOM_RETENTION_MS = 60 * 1000;

type RoomData = {
  roomCode?: unknown;
  controllerSessionId?: unknown;
};

type SelectGameData = RoomData & {gameId?: unknown};
type RemovePlayerData = RoomData & {playerUid?: unknown};

interface RealtimeRoom extends ControllerSessionRoom {
  creationOperationId?: string;
  status?: string;
  selectedGame?: string;
  controllerConnected?: boolean;
  controllerPresence?: {
    connected?: boolean;
    lastSeen?: number;
  };
  players?: Record<string, unknown>;
  game?: {public?: {status?: string}};
  retainUntil?: number;
  cleanupAt?: number;
}

function requireUid(uid: string | undefined): string {
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  return uid;
}

function parseRoomCode(value: unknown): string {
  const roomCode = typeof value === "string" ? value.trim().toUpperCase() : "";
  if (!ROOM_CODE.test(roomCode)) {
    throw new HttpsError("invalid-argument", "올바른 방 코드가 아닙니다.");
  }
  return roomCode;
}

function parseGameId(value: unknown): string {
  const gameId = typeof value === "string" ? value.trim() : "";
  if (!/^[a-z0-9_-]{1,64}$/.test(gameId)) {
    throw new HttpsError("invalid-argument", "올바른 게임 ID가 아닙니다.");
  }
  return gameId;
}

async function requireRoom(roomCode: string): Promise<RealtimeRoom> {
  const snapshot = await getDatabase().ref(`rooms/${roomCode}`).get();
  if (!snapshot.exists()) {
    throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
  }
  return snapshot.val() as RealtimeRoom;
}

/** 앱 재시작 후 저장된 세션으로 기존 방과 게임 상태를 다시 연결합니다. */
export const resumeRealtimeControllerRoom = onCall<RoomData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    const now = Date.now();
    let response: Record<string, unknown> | null = null;
    const roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists()) {
      throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    }

    const result = await roomRef.transaction((raw) => {
      if (raw === null) return;
      const room = raw as RealtimeRoom;
      assertControllerSession(room, uid, request.data?.controllerSessionId);
      if (room.status === "closed") {
        throw new HttpsError("failed-precondition", "이미 종료된 방입니다.");
      }
      room.controllerConnected = true;
      room.controllerPresence = {
        connected: true,
        lastSeen: now,
      };
      room.cleanupAt = now + CONTROLLER_RECONNECT_GRACE_MS;
      response = {
        roomCode,
        selectedGame: room.selectedGame ?? null,
        status: room.status ?? "waiting",
      };
      return room;
    });

    if (!result.committed || !response) {
      throw new HttpsError("aborted", "방 연결을 복구하지 못했습니다.");
    }
    return {success: true, ...(response as Record<string, unknown>)};
  },
);

/** controller가 명시적으로 방을 닫습니다. 실제 삭제는 서버 cleanup이 담당합니다. */
export const closeRoom = onCall<RoomData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    const now = Date.now();
    const roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists()) {
      throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    }

    const room = roomSnapshot.val() as RealtimeRoom;
    assertControllerSession(room, uid, request.data?.controllerSessionId);

    await roomRef.update({
      status: "closed",
      controllerConnected: false,
      controllerPresence: {
        connected: false,
        lastSeen: now,
      },
      cleanupAt: now + CLOSED_ROOM_RETENTION_MS,
    });
    const controllerRoomRef = getDatabase().ref(`controllerRooms/${uid}`);
    const mappedRoom = await controllerRoomRef.get();
    if (mappedRoom.val() === roomCode) await controllerRoomRef.remove();
    if (room.creationOperationId) {
      await getDatabase()
        .ref(`roomCreateRequests/${uid}/${room.creationOperationId}`)
        .remove();
    }
    return {success: true, roomCode};
  },
);

/** 대기실의 게임 선택도 controller 세션 검증 뒤 서버에서 변경합니다. */
export const selectRealtimeRoomGame = onCall<SelectGameData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const gameId = parseGameId(request.data?.gameId);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    const roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists()) {
      throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    }

    const room = roomSnapshot.val() as RealtimeRoom;
    assertControllerSession(room, uid, request.data?.controllerSessionId);
    if (
      room.status === "playing" ||
      room.status === "closed" ||
      room.game?.public?.status === "playing"
    ) {
      throw new HttpsError(
        "failed-precondition",
        "현재 게임을 선택할 수 없습니다.",
      );
    }
    // 선택은 덱·턴·승패를 바꾸는 게임 명령이 아닙니다. 서버에서 controller
    // session과 진행 상태를 확인한 뒤 두 필드를 한 번의 update로 기록합니다.
    await roomRef.update({selectedGame: gameId, status: "waiting"});
    return {success: true, gameId};
  },
);

/** 대기실 강퇴는 controller 세션과 게임 상태를 확인한 뒤 처리합니다. */
export const removeRealtimeRoomPlayer = onCall<RemovePlayerData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const playerUid = typeof request.data?.playerUid === "string" ?
      request.data.playerUid.trim() : "";
    if (!playerUid) {
      throw new HttpsError("invalid-argument", "플레이어 정보가 필요합니다.");
    }
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    const roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists()) {
      throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    }
    const result = await roomRef.transaction((raw) => {
      if (raw === null) return;
      const room = raw as RealtimeRoom;
      assertControllerSession(room, uid, request.data?.controllerSessionId);
      if (room.status === "playing" || room.game?.public?.status === "playing") {
        throw new HttpsError("failed-precondition", "게임 중에는 게임 퇴장 절차를 사용해주세요.");
      }
      if (room.players) delete room.players[playerUid];
      return room;
    });
    if (!result.committed) {
      throw new HttpsError("aborted", "플레이어를 내보내지 못했습니다.");
    }
    return {success: true, playerUid};
  },
);

/** 휴대폰의 대기실 퇴장을 서버에서 본인 UID만 제거하도록 처리합니다. */
export const leaveRealtimeRoom = onCall<RoomData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const room = await requireRoom(roomCode);
    if (room.status === "playing" || room.game?.public?.status === "playing") {
      throw new HttpsError("failed-precondition", "게임 중에는 게임별 퇴장 기능을 사용해주세요.");
    }
    await getDatabase().ref(`rooms/${roomCode}/players/${uid}`).remove();
    return {success: true};
  },
);

/** 게임 public status를 방 수명주기 status와 분리된 필드로 미러링합니다. */
export const syncRealtimeRoomGameStatus = onValueWritten(
  {
    ref: "/rooms/{roomCode}/game/public/status",
    region: DATABASE_REGION,
  },
  async (event) => {
    const status = event.data.after.val();
    if (status !== "playing" && status !== "finished") return;
    const now = Date.now();
    const updates: Record<string, unknown> = {
      status,
      updatedAt: now,
    };
    if (status === "finished") {
      updates.finishedAt = now;
      updates.retainUntil = now + FINISHED_ROOM_RETENTION_MS;
      updates.cleanupAt = now + FINISHED_ROOM_RETENTION_MS;
    } else {
      updates.finishedAt = null;
      updates.retainUntil = null;
    }
    await event.data.after.ref.parent?.parent?.parent?.update(updates);
  },
);

export function shouldDeleteRoom(room: RealtimeRoom, now: number): boolean {
  if (room.status === "closed") return (room.cleanupAt ?? 0) <= now;
  if (room.status === "finished") return (room.retainUntil ?? Infinity) <= now;
  const lastSeen = room.controllerPresence?.lastSeen ?? 0;
  return lastSeen + CONTROLLER_RECONNECT_GRACE_MS <= now;
}

/** heartbeat가 사라진 오래된 방을 서버가 최종적으로 정리합니다. */
export const cleanupStaleRealtimeRooms = onSchedule(
  {
    region: REGION,
    schedule: "every 5 minutes",
    timeZone: "Asia/Seoul",
  },
  async () => {
    const database = getDatabase();
    const now = Date.now();
    const staleBefore = now - CONTROLLER_RECONNECT_GRACE_MS;
    const roomsSnapshot = await database
      .ref("rooms")
      .orderByChild("controllerPresence/lastSeen")
      .endAt(staleBefore)
      .limitToFirst(500)
      .get();
    if (!roomsSnapshot.exists()) return;

    const cleanupJobs: Promise<unknown>[] = [];
    roomsSnapshot.forEach((child) => {
      const roomCode = child.key;
      if (!roomCode) return;
      cleanupJobs.push(database.ref(`rooms/${roomCode}`).transaction((raw) => {
        if (raw === null) return;
        const room = raw as RealtimeRoom;
        if (!shouldDeleteRoom(room, now)) return;
        return null;
      }).then(async (result) => {
        if (!result.committed || result.snapshot.exists()) return;
        const deletedRoom = child.val() as RealtimeRoom;
        const controllerUid = deletedRoom.controllerUid;
        if (!controllerUid) return;
        const mappingRef = database.ref(`controllerRooms/${controllerUid}`);
        const mapping = await mappingRef.get();
        if (mapping.val() === roomCode) await mappingRef.remove();
        if (deletedRoom.creationOperationId) {
          await database
            .ref(
              `roomCreateRequests/${controllerUid}/${deletedRoom.creationOperationId}`,
            )
            .remove();
        }
      }));
    });
    await Promise.all(cleanupJobs);
  },
);
