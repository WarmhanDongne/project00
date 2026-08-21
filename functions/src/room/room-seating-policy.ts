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
