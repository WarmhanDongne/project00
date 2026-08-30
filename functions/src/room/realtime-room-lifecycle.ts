/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {DataSnapshot, getDatabase} from "firebase-admin/database";
import {getFirestore} from "firebase-admin/firestore";
import {logger} from "firebase-functions";
import {onValueWritten} from "firebase-functions/v2/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";
import {onSchedule} from "firebase-functions/v2/scheduler";

import {
  assertControllerSession,
  ControllerSessionRoom,
} from "./controller-session.js";
import {
  applyWaitingGameSelection,
  decideRoomSeating,
} from "./room-seating-policy.js";
import {runPrimedTransaction} from "./room-transaction.js";

const REGION = "asia-northeast3";
const DATABASE_REGION = "asia-southeast1";
const ROOM_CODE = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;
const CONTROLLER_RECONNECT_GRACE_MS = 3 * 60 * 1000;

/**
 * 진행 중인 게임의 방을 태블릿 heartbeat가 끊긴 뒤에도 유지하는 시간입니다.
 *
 * 대기 방(3분)과 **일부러 다른 값**입니다. 대기 방이 사라지면 다시 만들면
 * 되지만, 진행 중인 판이 사라지면 되돌릴 방법이 없습니다. 되돌릴 수 없는
 * 손해가 훨씬 비싸므로 넉넉한 쪽으로 잡습니다.
 *
 * 15분인 근거:
 * - 복구 가치가 있는 최장 태블릿 장애(OS 업데이트 후 재부팅 5~15분)를 덮습니다.
 *   앱 크래시 10~30초, 기기·공유기 재부팅 1~3분, 배터리 방전 후 충전 3~10분은
 *   모두 그 안입니다.
 * - 정리 스케줄이 5분 주기라 실제 삭제는 15~20분입니다. 게임 한 판(15~30분)
 *   안쪽이라, 이 시간을 넘겼으면 그 그룹은 이미 해산했다고 봐도 됩니다.
 * - 길게 잡는 비용이 거의 없습니다. `playing` 방은 신규 참가가 이미 차단이고
 *   (room-join-policy.ts), 태블릿의 명시적 `방 종료`는 status를 보지 않아
 *   언제든 즉시 가능합니다.
 *
 * ⚠️ 이 값은 휴대폰의 **표시** 유예(20초, `controller_presence.dart`)와 아무
 * 관계가 없습니다. 표시는 빠르고 삭제는 느려야 합니다.
 */
const PLAYING_ROOM_RETENTION_MS = 15 * 60 * 1000;

/**
 * 게임이 끝난 방을 보존하는 시간입니다.
 *
 * ⚠️ 이 값은 생각보다 자주 구속하지 않습니다. 정리 스케줄이
 * `controllerPresence/lastSeen <= now - 3분`으로 **먼저** 거르는데
 * (`cleanupStaleRealtimeRooms`), `syncRealtimeRoomGameStatus`는 `retainUntil`만
 * 쓰고 presence는 건드리지 않습니다. 그래서 태블릿이 살아서 heartbeat를 보내는
 * 동안에는 `finished` 방이 조회 대상에 들어가지도 않습니다. 이 값이 의미를
 * 갖는 것은 "게임이 끝나고 태블릿도 3분 이상 사라진" 경우뿐입니다.
 */
const FINISHED_ROOM_RETENTION_MS = 15 * 60 * 1000;

/**
 * 명시적으로 닫은 방을 보존하는 시간입니다.
 *
 * ⚠️ 위와 같은 이유로 이 값은 **결코 구속하지 않습니다.** `closeRoom`이
 * `lastSeen = now`를 쓰므로 조회 대상이 되는 것은 close + 3분부터인데, 그때는
 * `cleanupAt`(close + 60초)이 이미 지나 있습니다. 실제 삭제 시점은 항상
 * 마지막 heartbeat + 3분입니다.
 */
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
  finishedAt?: number;
  updatedAt?: number;
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
        applyWaitingGameSelection(currentRoom, gameId);
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

/** 늦은 게임 이벤트가 대기실·닫힌 방을 되살리지 않도록 최신 게임과 대조합니다. */
export function synchronizeRoomGameStatus(
  room: RealtimeRoom | null,
  status: unknown,
  now: number,
): RealtimeRoom | undefined {
  if (!room || room.status === "closed" ||
      (status !== "playing" && status !== "finished") ||
      room.game?.public?.status !== status) return;
  if (status === "finished") {
    if (room.status === "finished" && typeof room.retainUntil === "number") return;
    room.finishedAt = now;
    room.retainUntil = now + FINISHED_ROOM_RETENTION_MS;
    room.cleanupAt = room.retainUntil;
  } else {
    delete room.finishedAt;
    delete room.retainUntil;
    delete room.cleanupAt;
  }
  room.status = status;
  room.updatedAt = now;
  return room;
}

/** 게임 public status를 방 수명주기 status와 분리된 필드로 미러링합니다. */
export const syncRealtimeRoomGameStatus = onValueWritten(
  {
    ref: "/rooms/{roomCode}/game/public/status",
    region: DATABASE_REGION,
  },
  async (event) => {
    const status = event.data.after.val();
    if (status !== "playing" && status !== "finished") return;
    const roomRef = getDatabase().ref(`rooms/${event.params.roomCode}`);
    await runPrimedTransaction(roomRef, (raw) =>
      synchronizeRoomGameStatus(raw as RealtimeRoom | null, status, Date.now()),
    );
  },
);

export function shouldDeleteRoom(room: RealtimeRoom, now: number): boolean {
  if (room.status === "closed") return (room.cleanupAt ?? 0) <= now;
  const lastSeen = room.controllerPresence?.lastSeen ?? 0;
  if (room.status === "finished") {
    if (typeof room.retainUntil === "number") return room.retainUntil <= now;
    // retainUntil 도입 전에 종료된 방도 무기한 남기지 않습니다. 단, 실제
    // heartbeat 시각이 없는 방은 나이를 증명할 수 없으므로 보수적으로 보존합니다.
    return lastSeen > 0 && lastSeen + FINISHED_ROOM_RETENTION_MS <= now;
  }
  // 진행 중인 판은 대기 방보다 오래 붙잡습니다. 태블릿이 3분 백그라운드에
  // 있었다는 이유로 게임이 통째로 사라지는 것이 '그룹 폭파'의 직접 원인이었습니다.
  const grace = room.status === "playing" ?
    PLAYING_ROOM_RETENTION_MS :
    CONTROLLER_RECONNECT_GRACE_MS;
  return lastSeen + grace <= now;
}

/** 서로 다른 정리 인덱스에서 찾은 후보를 순서를 유지하며 중복 제거합니다. */
export function mergeCleanupCandidateRoomCodes(
  ...candidateGroups: string[][]
): string[] {
  return [...new Set(candidateGroups.flat())];
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
    const roomsRef = database.ref("rooms");
    const [expiredCleanupSnapshot, stalePresenceSnapshot] = await Promise.all([
      roomsRef
        .orderByChild("cleanupAt")
        .startAt(0)
        .endAt(now)
        .limitToFirst(500)
        .get(),
      roomsRef
        .orderByChild("controllerPresence/lastSeen")
        .endAt(staleBefore)
        .limitToFirst(500)
        .get(),
    ]);

    const keys = (snapshot: DataSnapshot): string[] => {
      const result: string[] = [];
      snapshot.forEach((child) => {
        if (child.key) result.push(child.key);
      });
      return result;
    };
    const candidateCodes = mergeCleanupCandidateRoomCodes(
      keys(expiredCleanupSnapshot),
      keys(stalePresenceSnapshot),
    );

    let deletedCount = 0;
    let preservedCount = 0;
    const jobs = candidateCodes.map(async (roomCode) => {
      let deletedRoom: RealtimeRoom | null = null;
      const roomRef = database.ref(`rooms/${roomCode}`);
      // Admin SDK transaction은 서버 스냅샷이 캐시에 오기 전에 update를 null로
      // 먼저 호출할 수 있습니다. 여기서 undefined를 반환하면 실제 방을 읽지 않고
      // committed=false가 되어 모든 후보가 보존된 것처럼 보입니다.
      const result = await runPrimedTransaction(
        roomRef,
        (raw) => {
          if (raw === null) return;
          const room = raw as RealtimeRoom;
          if (!shouldDeleteRoom(room, now)) return;
          deletedRoom = room;
          return null;
        },
      );
      if (!result.committed || result.snapshot.exists()) {
        preservedCount += 1;
        return;
      }
      deletedCount += 1;
      const deleted = deletedRoom as RealtimeRoom | null;
      const controllerUid = deleted?.controllerUid;
      if (!controllerUid) return;
      const mappingRef = database.ref(`controllerRooms/${controllerUid}`);
      const mapping = await mappingRef.get();
      if (mapping.val() === roomCode) await mappingRef.remove();
      if (deleted?.creationOperationId) {
        await database
          .ref(
            `roomCreateRequests/${controllerUid}/${deleted.creationOperationId}`,
          )
          .remove();
      }
    });
    const results = await Promise.allSettled(jobs);
    const failedCount = results.filter(
      (result) => result.status === "rejected",
    ).length;
    logger.info("Realtime room cleanup summary", {
      expiredCleanupCandidateCount: keys(expiredCleanupSnapshot).length,
      stalePresenceCandidateCount: keys(stalePresenceSnapshot).length,
      uniqueCandidateCount: candidateCodes.length,
      deletedCount,
      preservedCount,
      failedCount,
    });
    if (failedCount > 0) {
      throw new Error("Realtime room cleanup had failed candidates");
    }
  },
);
