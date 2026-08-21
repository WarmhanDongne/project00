/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {DataSnapshot, getDatabase} from "firebase-admin/database";
import {getFirestore} from "firebase-admin/firestore";
import {onValueWritten} from "firebase-functions/v2/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
  assertControllerSession,
  ControllerSessionRoom,
} from "./controller-session.js";
import {decideRoomSeating} from "./room-seating-policy.js";
import {runPrimedTransaction} from "./room-transaction.js";

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

interface RealtimeRoomPlayer {
  role?: string;
  status?: string;
}

function activePlayerCount(room: RealtimeRoom): number {
  return Object.values(room.players ?? {}).filter((rawPlayer) => {
    if (!rawPlayer || typeof rawPlayer !== "object") return false;
    const player = rawPlayer as RealtimeRoomPlayer;
    return (player.role ?? "player") === "player" &&
      (player.status ?? "active") === "active";
  }).length;
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

function parseGameId(value: unknown): string | null {
  if (value === null) return null;
  const gameId = typeof value === "string" ? value.trim() : "";
  if (!/^[a-z0-9_-]{1,64}$/.test(gameId)) {
    throw new HttpsError("invalid-argument", "올바른 게임 ID가 아닙니다.");
  }
  return gameId;
}

function activeGroupUids(room: RealtimeRoom, controllerUid: string): string[] {
  const uids = new Set([controllerUid]);
  for (const [playerUid, rawPlayer] of Object.entries(room.players ?? {})) {
    if (!rawPlayer || typeof rawPlayer !== "object") continue;
    const player = rawPlayer as RealtimeRoomPlayer;
    if ((player.role ?? "player") === "player" &&
        (player.status ?? "active") === "active") {
      uids.add(playerUid);
    }
  }
  return [...uids];
}

async function assertGameAccessible(
  room: RealtimeRoom,
  controllerUid: string,
  gameId: string,
): Promise<void> {
  const firestore = getFirestore();
  const game = await firestore.collection("games").doc(gameId).get();
  if (!game.exists || game.data()?.enabled === false) {
    throw new HttpsError("not-found", "선택할 수 없는 게임입니다.");
  }
  const accessType = game.data()?.accessType;
  if (accessType !== "paid") return;

  const users = await Promise.all(
    activeGroupUids(room, controllerUid).map((groupUid) =>
      firestore.collection("users").doc(groupUid).get()),
  );
  const owned = isGameAccessibleToGroup(
    accessType,
    gameId,
    users.map((user) => user.data()?.ownedGames),
  );
  if (!owned) {
    throw new HttpsError("permission-denied", "그룹이 보유하지 않은 게임입니다.");
  }
}

export function isGameAccessibleToGroup(
  accessType: unknown,
  gameId: string,
  ownedGamesByUser: unknown[],
): boolean {
  if (accessType !== "paid") return true;
  return ownedGamesByUser.some((ownedGames) =>
    Array.isArray(ownedGames) && ownedGames.includes(gameId));
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

    const result = await runPrimedTransaction(roomRef, (raw) => {
      if (raw === null) return;
      const room = raw as RealtimeRoom;
      assertControllerSession(room, uid, request.data?.controllerSessionId);
      if (room.status === "closed") {
        throw new HttpsError("failed-precondition", "이미 종료된 방입니다.");
      }
      // 자리 배치 초안은 태블릿 메모리에만 있으므로 프로세스가 완전히 재시작된
      // 경우에는 선택 게임을 유지한 채 다시 시작할 수 있는 대기 상태로 돌립니다.
      if (room.status === "seating") room.status = "waiting";
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
    // Admin RTDB의 transaction update 함수는 서버 값이 로컬 캐시에 오기 전에
    // null로 먼저 호출될 수 있습니다. 그때 undefined를 반환하면 서버 값을
    // 확인하지 않고 committed=false로 즉시 종료됩니다. value 리스너를 유지해
    // 완전한 서버 스냅샷을 캐시에 올린 뒤 트랜잭션을 시작합니다.
    let roomValueListener!: (snapshot: DataSnapshot) => void;
    const firstRoomValue = new Promise<DataSnapshot>((resolve, reject) => {
      roomValueListener = (snapshot) => resolve(snapshot);
      roomRef.on("value", roomValueListener, reject);
    });

    try {
      const roomSnapshot = await firstRoomValue;
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
      if (gameId !== null) await assertGameAccessible(room, uid, gameId);
      // 접근 권한 확인 뒤에도 게임 시작과 경합할 수 있으므로, 최종 선택 변경은
      // controller session과 진행 상태를 다시 확인하는 트랜잭션으로 처리합니다.
      const result = await roomRef.transaction((raw) => {
        if (raw === null) return;
        const currentRoom = raw as RealtimeRoom;
        assertControllerSession(
          currentRoom,
          uid,
          request.data?.controllerSessionId,
        );
        if (
          currentRoom.status === "playing" ||
          currentRoom.status === "closed" ||
          (currentRoom.status === "seating" && gameId !== null) ||
          currentRoom.game?.public?.status === "playing"
        ) {
          throw new HttpsError(
            "failed-precondition",
            "현재 게임을 선택할 수 없습니다.",
          );
        }
        if (gameId === null) delete currentRoom.selectedGame;
        else currentRoom.selectedGame = gameId;
        currentRoom.status = "waiting";
        return currentRoom;
      });
      if (!result.committed) {
        throw new HttpsError("aborted", "게임 선택을 변경하지 못했습니다.");
      }
      return {success: true, gameId};
    } finally {
      roomRef.off("value", roomValueListener);
    }
  },
);

/** 선택된 게임의 자리 배치를 시작하고 신규 참가자 명단을 잠급니다. */
export const beginRealtimeRoomSeating = onCall<RoomData>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    const roomSnapshot = await roomRef.get();
    if (!roomSnapshot.exists()) {
      throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    }
    const room = roomSnapshot.val() as RealtimeRoom;
    assertControllerSession(room, uid, request.data?.controllerSessionId);
    const selectedGame = room.selectedGame;
    if (!selectedGame) {
      throw new HttpsError("failed-precondition", "선택된 게임이 없습니다.");
    }

    const gameSnapshot = await getFirestore()
      .collection("games")
      .doc(selectedGame)
      .get();
    if (!gameSnapshot.exists || gameSnapshot.data()?.enabled === false) {
      throw new HttpsError("not-found", "선택할 수 없는 게임입니다.");
    }
    const rawMinPlayers = gameSnapshot.data()?.minPlayers;
    const rawMaxPlayers = gameSnapshot.data()?.maxPlayers;
    const minPlayers = typeof rawMinPlayers === "number" && rawMinPlayers > 0 ?
      rawMinPlayers : 2;
    const maxPlayers = typeof rawMaxPlayers === "number" && rawMaxPlayers > 0 ?
      rawMaxPlayers : 12;

    let rejection: HttpsError | null = null;
    const result = await runPrimedTransaction(roomRef, (raw) => {
      rejection = null;
      if (raw === null || typeof raw !== "object") return;
      const currentRoom = raw as RealtimeRoom;
      assertControllerSession(
        currentRoom,
        uid,
        request.data?.controllerSessionId,
      );
      const count = activePlayerCount(currentRoom);
      const decision = decideRoomSeating({
        roomStatus: currentRoom.status,
        gameStatus: currentRoom.game?.public?.status,
        selectedGame: currentRoom.selectedGame,
        expectedGame: selectedGame,
        activePlayerCount: count,
        minPlayers,
        maxPlayers,
      });
      switch (decision) {
      case "already-seating":
        return currentRoom;
      case "invalid-status":
        rejection = new HttpsError(
          "failed-precondition",
          "현재 자리 배치를 시작할 수 없습니다.",
        );
        return;
      case "game-changed":
        rejection = new HttpsError(
          "aborted",
          "선택된 게임이 변경되었습니다. 다시 시도해주세요.",
        );
        return;
      case "invalid-player-count":
        rejection = new HttpsError(
          "failed-precondition",
          `게임 참가 인원은 ${minPlayers}~${maxPlayers}명이어야 합니다.`,
        );
        return;
      case "begin":
        currentRoom.status = "seating";
        return currentRoom;
      }
    });
    if (!result.committed) {
      if (rejection) throw rejection;
      throw new HttpsError("aborted", "자리 배치를 시작하지 못했습니다.");
    }
    const committedRoom = result.snapshot.val() as RealtimeRoom;
    return {
      success: true,
      roomCode,
      status: "seating",
      playerUids: Object.keys(committedRoom.players ?? {}),
    };
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
    // transaction의 최초 로컬 null이 서버 확인 전 취소로 이어지지 않도록
    // value 리스너로 완전한 방 스냅샷을 캐시에 유지합니다.
    let roomValueListener!: (snapshot: DataSnapshot) => void;
    const firstRoomValue = new Promise<DataSnapshot>((resolve, reject) => {
      roomValueListener = (snapshot) => resolve(snapshot);
      roomRef.on("value", roomValueListener, reject);
    });

    try {
      const roomSnapshot = await firstRoomValue;
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
    } finally {
      roomRef.off("value", roomValueListener);
    }
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
