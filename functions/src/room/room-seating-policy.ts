export type RoomSeatingDecision =
  "begin" |
  "already-seating" |
  "invalid-status" |
  "game-changed" |
  "invalid-player-count";

type RoomSeatingState = {
  roomStatus: unknown;
  gameStatus?: unknown;
  selectedGame: unknown;
  expectedGame: string;
  activePlayerCount: number;
  minPlayers: number;
  maxPlayers: number;
};

/**
 * 자리 배치 시작 트랜잭션 안에서 현재 서버 상태를 다시 판정합니다.
 * @param {RoomSeatingState} state 현재 방·게임·인원 상태입니다.
 * @return {RoomSeatingDecision} 트랜잭션이 적용할 결정입니다.
 */
export function decideRoomSeating(
  state: RoomSeatingState,
): RoomSeatingDecision {
  if (state.roomStatus === "seating" &&
      state.selectedGame === state.expectedGame) {
    return "already-seating";
  }
  if (state.roomStatus !== "waiting" || state.gameStatus === "playing") {
    return "invalid-status";
  }
  if (state.selectedGame !== state.expectedGame) return "game-changed";
  if (state.activePlayerCount < state.minPlayers ||
      state.activePlayerCount > state.maxPlayers) {
    return "invalid-player-count";
  }
  return "begin";
}

type MutableRoomSelection = {
  status?: string;
  selectedGame?: string;
  game?: unknown;
  finishedAt?: number;
  retainUntil?: number;
};

/**
 * 대기실에서 게임 선택을 바꿀 때 이전 게임의 종료 데이터를 제거합니다.
 * @param {MutableRoomSelection} room 변경할 방 상태입니다.
 * @param {string|null} gameId 새로 선택할 게임 ID입니다.
 */
export function applyWaitingGameSelection(
  room: MutableRoomSelection,
  gameId: string | null,
): void {
  if (gameId === null) delete room.selectedGame;
  else room.selectedGame = gameId;
  delete room.game;
  delete room.finishedAt;
  delete room.retainUntil;
  room.status = "waiting";
}
