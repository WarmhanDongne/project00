/* eslint-disable max-len */
import {PublicGameInterruption, ServerGameInterruption} from "../game-interruption/types.js";

export type YutGameId = "yut" | "strategy_yut" | "strategy_yut_edition";
export type YutTeam = "blue" | "white" | "east" | "south" | "west" | "north";
export type YutPhase = "rolling" | "selecting" | "moving" | "finished";
export type YutResultName = "backDo" | "do" | "gae" | "geol" | "yut" | "mo";

export interface YutPlayer {
  uid: string;
  nickname: string;
  characterId: string;
  seatIndex: number;
  team: YutTeam;
  status: "alive" | "eliminated";
}

export interface YutPiece {
  id: number;
  /**
   * -1 is the start yard, 0–28 are board nodes and 29 is home.
   * Node 0 is the start corner; see `advancePath` for the network.
   */
  position: number;
  path: number[];
  status: "ready" | "onBoard" | "finished";
}

export interface YutRoll {
  name: YutResultName;
  steps: number;
  /** 둥근 앞면(× 세 개)이 위로 나온 윷 수. 결과는 4 - upCount(평평한 뒷면 수)로 정합니다. */
  upCount: number;
  /** 윷마다 true = 둥근 앞면, false = 평평한 뒷면. 일반판 [0]은 뒷면에 로고가 찍힌 빽도 윷입니다. */
  stickUps: boolean[];
  backDo: boolean;
  createdAt: number;
  actorUid: string | null;
  /** Strategy only: each player's revealed side, `true` is the front. */
  revealedChoices?: Record<string, boolean>;
}

/** One unused throw result waiting to be applied to a piece on the tablet. */
export interface YutPoolEntry {
  name: YutResultName;
  steps: number;
}

export interface YutMoveRecord {
  owner: string;
  pieceIds: number[];
  /** Nodes visited, starting with the origin (-1 when entering). */
  path: number[];
  result: YutResultName;
  captured: {owner: string; pieceIds: number[]}[];
  extraThrow: boolean;
  createdAt: number;
}

export interface YutPublicState {
  gameType: YutGameId;
  status: "playing" | "finished";
  finishReason?: "winner" | "manual" | "insufficientPlayers";
  phase: YutPhase;
  round: number;
  revision: number;
  turnUid: string | null;
  turnTeam: YutTeam | null;
  turnDeadlineAt: number | null;
  choiceCount: number;
  players: Record<string, YutPlayer>;
  /** Classic mode keys pieces by player UID; strategy mode keys by team. */
  pieces: Record<string, YutPiece[]>;
  /** Results thrown this turn and not yet used. Yut and mo throw again. */
  pool: YutPoolEntry[];
  lastRoll: YutRoll | null;
  lastMove: YutMoveRecord | null;
  history: YutRoll[];
  winnerUid: string | null;
  winningTeam: YutTeam | null;
  interruption?: PublicGameInterruption;
  startedAt: number;
  updatedAt: number;
  gameInstanceId?: string;
  phaseSeq?: number;
  turnSeq?: number;
  dataSeq?: number;
  resumeEpoch?: number;
  recovery?: Record<string, unknown>;
}

export interface YutPrivatePlayer {
  choiceSubmitted: boolean;
  choice?: boolean;
}

export interface YutGameState {
  public: YutPublicState;
  private: Record<string, YutPrivatePlayer>;
  server: {
    interruption?: ServerGameInterruption;
  };
}

export interface YutRoom {
  controllerUid?: string;
  controllerSessionId?: string;
  hostUid?: string;
  status?: string;
  selectedGame?: string;
  players?: Record<string, Record<string, unknown>>;
  game?: YutGameState;
}
