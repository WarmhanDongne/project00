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
  beginGameInterruption,
  cancelGameInterruption,
  completeGameInterruption,
  InterruptibleRoom,
} from "./state.js";
import {InterruptibleGameState} from "./types.js";

const REGION = "asia-northeast3";
const ROOM_CODE = /^[ABCDEFGHJKLMNPQRSTUVWXYZ23456789]{5}$/;

type Data = {roomCode?: unknown; interruptionId?: unknown};

interface GameRoom extends InterruptibleRoom {
  controllerUid?: string;
  hostUid?: string;
  selectedGame?: string;
  game?: InterruptibleGameState;
}

/** 남은 플레이어가 연결이 끊긴 플레이어를 제외하고 계속 진행하는 데 투표합니다. */
export const voteToContinueInterruptedGame = onCall<Data>(
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

/** 60초 안에 투표가 통과되지 않았을 때 서버가 게임을 종료합니다. */
export const expireInterruptedGame = onCall<Data>(
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
      const now = Date.now();
      if (now < interruption.deadlineAt) {
        throw new HttpsError("failed-precondition", "아직 투표 시간이 남아 있습니다.");
      }
      const canContinue = interruption.canContinue;
      completeGameInterruption(game, interruption.id, now);
      finishForExpiredVote(room, now, canContinue);
      response = {success: true, expired: true};
      return room;
    });

    if (!transaction.committed || !response) {
      throw new HttpsError("aborted", "게임 중단 상태를 종료하지 못했습니다.");
    }
    return response;
  },
);

/** RTDB onDisconnect가 바꾼 플레이어 접속 상태를 공용 게임 중단 상태로 승격합니다. */
export const handleGamePlayerConnectionChanged = onValueWritten(
  {ref: "/rooms/{roomCode}/players/{uid}/isConnected", region: REGION},
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
      const game = room.game;
      if (!game || game.public.status !== "playing") return room;
      const now = Date.now();
      if (isConnected) {
        const interruption = game.public.interruption;
        if (interruption?.playerUid === uid && interruption.reason === "disconnected") {
          cancelGameInterruption(game, interruption.id, now);
        }
      } else if (wasConnected) {
        beginGameInterruption(room, uid, "disconnected", now);
      }
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

function finishForExpiredVote(
  room: GameRoom,
  now: number,
  hadEnoughPlayers: boolean,
): void {
  if (room.selectedGame === "final_call") {
    const game = room.game as unknown as FinalCallGameState;
    finishFinalCallForInsufficientPlayers(game, now);
    game.public.finishReason = hadEnoughPlayers ?
      "interruptionVoteExpired" : "insufficientPlayers";
    return;
  }
  if (room.selectedGame === "liars_poker") {
    const game = room.game as unknown as LiarsPokerGameState;
    finishLiarsPokerForInsufficientPlayers(game, now);
    game.public.finishReason = hadEnoughPlayers ?
      "interruptionVoteExpired" : "insufficientPlayers";
  }
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
