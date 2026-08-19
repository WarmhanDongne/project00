/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {getDatabase} from "firebase-admin/database";
import {onValueWritten} from "firebase-functions/v2/database";
import {HttpsError, onCall} from "firebase-functions/v2/https";

import {
  excludeFinalCallPlayer,
  finishFinalCallForInsufficientPlayers,
} from "../final-call/exclude-player.js";
import {FinalCallGameState} from "../final-call/types.js";
import {
  excludeLiarsPokerPlayer,
  finishLiarsPokerForInsufficientPlayers,
} from "../liars-poker/exclude-player.js";
import {LiarsPokerGameState} from "../liars-poker/common/types.js";
import {
  completeGameInterruption,
  InterruptibleRoom,
  reconcileGamePlayerConnection,
} from "./state.js";
import {InterruptibleGameState} from "./types.js";
import {assertControllerSession} from "../room/controller-session.js";

const REGION = "asia-northeast3";

// Realtime Database 트리거는 데이터베이스 인스턴스가 있는 리전에만 만들 수 있습니다.
// 이 프로젝트의 기본 인스턴스는 asia-southeast1에 있습니다
// (project0000-ec01e-default-rtdb.asia-southeast1.firebasedatabase.app).
// asia-northeast3로 배포하면 트리거 생성 단계에서 다음 오류로 실패합니다.
//   cannot create a trigger in region asia-northeast3 (not yet revealed)
// callable 함수는 HTTPS라 이 제약이 없으므로 REGION을 그대로 씁니다.
const DATABASE_TRIGGER_REGION = "asia-southeast1";
const ROOM_CODE = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;

type Data = {
  roomCode?: unknown;
  interruptionId?: unknown;
  controllerSessionId?: unknown;
};

const MINIMUM_PLAYER_COUNTS: Record<string, number> = {
  final_call: 4,
  liars_poker: 2,
};

interface GameRoom extends InterruptibleRoom {
  controllerUid?: string;
  controllerSessionId?: string;
  hostUid?: string;
  selectedGame?: string;
  game?: InterruptibleGameState;
}

/** 남은 플레이어가 연결이 끊긴 플레이어를 제외하고 계속 진행하는 데 투표합니다. */
export const game_common_interruption_vote_to_continue = onCall<Data>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const interruptionId = parseInterruptionId(request.data?.interruptionId);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as GameRoom;
      const game = room.game;
      const interruption = game?.public.interruption;
      if (!game || !interruption || interruption.id !== interruptionId) {
        response = {success: true, alreadyResolved: true};
        return room;
      }
      if (!interruption.eligibleVoterUids.includes(uid)) {
        throw new HttpsError("permission-denied", "이 투표에 참여할 수 없습니다.");
      }
      if (Date.now() >= interruption.deadlineAt) {
        throw new HttpsError("deadline-exceeded", "투표 시간이 종료되었습니다.");
      }

      interruption.votes = {...interruption.votes, [uid]: true};
      const voteCount = Object.keys(interruption.votes).length;
      const approved = interruption.canContinue && voteCount >= interruption.requiredVotes;
      const now = Date.now();
      if (approved) {
        completeGameInterruption(game, interruption.id, now);
        delete room.players?.[interruption.playerUid];
        excludePlayer(room, interruption.playerUid, now);
      } else {
        game.public.revision += 1;
        game.public.updatedAt = now;
      }
      response = {success: true, approved, voteCount, requiredVotes: interruption.requiredVotes};
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "투표를 반영하지 못했습니다.");
    }
    return response;
  },
);

/** 태블릿 진행자가 중단된 플레이어를 제외하고 즉시 게임을 계속합니다. */
export const game_common_interruption_exclude_player = onCall<Data>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const interruptionId = parseInterruptionId(request.data?.interruptionId);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as GameRoom;
      assertControllerSession(room, uid, request.data?.controllerSessionId);
      const game = room.game;
      const interruption = game?.public.interruption;
      if (!game || !interruption || interruption.id !== interruptionId) {
        response = {success: true, alreadyResolved: true};
        return room;
      }
      if (!interruption.canContinue) {
        throw new HttpsError("failed-precondition", "남은 인원이 최소 인원보다 적습니다.");
      }

      const now = Date.now();
      completeGameInterruption(game, interruption.id, now);
      delete room.players?.[interruption.playerUid];
      excludePlayer(room, interruption.playerUid, now);
      response = {success: true, continued: true};
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "플레이어를 제외하고 게임을 계속하지 못했습니다.");
    }
    return response;
  },
);

/** 60초 동안 재접속하지 않으면 제외 후 계속하거나 인원 부족으로 종료합니다. */
export const game_common_interruption_expire = onCall<Data>(
  {region: REGION},
  async (request) => {
    const uid = requireUid(request.auth?.uid);
    const roomCode = parseRoomCode(request.data?.roomCode);
    const interruptionId = parseInterruptionId(request.data?.interruptionId);
    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    let response: Record<string, unknown> | null = null;

    const transaction = await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as GameRoom;
      const game = room.game;
      const interruption = game?.public.interruption;
      if (!game || !interruption || interruption.id !== interruptionId) {
        response = {success: true, alreadyResolved: true};
        return room;
      }
      const isParticipant = uid === room.controllerUid || uid === room.hostUid ||
        interruption.eligibleVoterUids.includes(uid);
      if (!isParticipant) {
        throw new HttpsError("permission-denied", "게임 중단을 종료할 권한이 없습니다.");
      }
      if (uid === room.controllerUid || uid === room.hostUid) {
        assertControllerSession(room, uid, request.data?.controllerSessionId);
      }
      const now = Date.now();
      if (now < interruption.deadlineAt) {
        throw new HttpsError("failed-precondition", "아직 투표 시간이 남아 있습니다.");
      }
      const canContinue = interruption.canContinue;
      completeGameInterruption(game, interruption.id, now);
      delete room.players?.[interruption.playerUid];
      if (canContinue) {
        excludePlayer(room, interruption.playerUid, now);
      } else {
        finishForInsufficientPlayers(room, now);
      }
      response = {success: true, expired: true, continued: canContinue};
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "게임 중단 상태를 종료하지 못했습니다.");
    }
    return response;
  },
);

/** RTDB onDisconnect가 바꾼 플레이어 접속 상태를 공용 게임 중단 상태로 승격합니다. */
export const game_common_interruption_on_connection_changed = onValueWritten(
  {
    ref: "/rooms/{roomCode}/players/{uid}/isConnected",
    region: DATABASE_TRIGGER_REGION,
  },
  async (event) => {
    const roomCode = event.params.roomCode;
    const uid = event.params.uid;
    const wasConnected = event.data.before.val() === true;
    const isConnected = event.data.after.val() === true;
    if (wasConnected === isConnected) return;

    const roomRef = getDatabase().ref(`rooms/${roomCode}`);
    await roomRef.transaction((raw) => {
      if (raw === null) return raw;
      const room = raw as GameRoom;
      reconcileGamePlayerConnection(
        room,
        uid,
        wasConnected,
        isConnected,
        Date.now(),
        {minimumPlayerCount: minimumPlayerCount(room.selectedGame)},
      );
      return room;
    });
  },
);

function excludePlayer(room: GameRoom, uid: string, now: number): void {
  if (room.selectedGame === "final_call") {
    excludeFinalCallPlayer(room.game as unknown as FinalCallGameState, uid, now);
    return;
  }
  if (room.selectedGame === "liars_poker") {
    excludeLiarsPokerPlayer(room.game as unknown as LiarsPokerGameState, uid, now);
  }
}

function finishForInsufficientPlayers(room: GameRoom, now: number): void {
  if (room.selectedGame === "final_call") {
    const game = room.game as unknown as FinalCallGameState;
    finishFinalCallForInsufficientPlayers(game, now);
    return;
  }
  if (room.selectedGame === "liars_poker") {
    const game = room.game as unknown as LiarsPokerGameState;
    finishLiarsPokerForInsufficientPlayers(game, now);
  }
}

function minimumPlayerCount(selectedGame: string | undefined): number {
  return selectedGame ? MINIMUM_PLAYER_COUNTS[selectedGame] ?? 2 : 2;
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

function parseInterruptionId(value: unknown): string {
  const id = typeof value === "string" ? value.trim() : "";
  if (!/^[A-Za-z0-9_-]{3,160}$/.test(id)) {
    throw new HttpsError("invalid-argument", "올바른 게임 중단 ID가 아닙니다.");
  }
  return id;
}
