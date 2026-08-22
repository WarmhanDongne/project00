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

export type SeatSaveDecision =
  "save" |
  "not-seating" |
  "no-players" |
  "too-few-players" |
  "too-many-players" |
  "roster-changed" |
  "invalid-seats";

type SeatSaveState = {
  roomStatus: unknown;
  playerIds: string[];
  seatEntries: [string, unknown][];
  minPlayers: number;
  maxPlayers: number;
};

/**
 * 좌석 저장 요청을 트랜잭션 안에서 판정합니다.
 *
 * `roster-changed`와 `invalid-seats`를 **나눠서** 돌려주는 것이 이 함수의 요점
 * 입니다. 두 경우를 한 결과로 묶으면, 자리 배치 중 누가 나가서 생긴 실패까지
 * "중복 없이 지정하라"로 안내되어 진행자가 무엇을 고쳐야 하는지 알 수 없습니다.
 * 명단 불일치는 화면에서 고칠 수 있는 것이 아니라 배치를 다시 해야 하는
 * 상황입니다(C-13).
 *
 * @param {SeatSaveState} state 현재 방 상태와 요청된 좌석입니다.
 * @return {SeatSaveDecision} 트랜잭션이 적용할 결정입니다.
 */
export function decideSeatSave(state: SeatSaveState): SeatSaveDecision {
  if (state.roomStatus !== "seating") return "not-seating";
  if (state.playerIds.length === 0) return "no-players";
  if (state.playerIds.length < state.minPlayers) return "too-few-players";
  if (state.playerIds.length > state.maxPlayers) return "too-many-players";

  const seatPlayerIds = new Set(state.seatEntries.map(([uid]) => uid));
  const sameRoster = state.seatEntries.length === state.playerIds.length &&
    state.playerIds.every((uid) => seatPlayerIds.has(uid));
  if (!sameRoster) return "roster-changed";

  const seats = state.seatEntries.map(([, seatIndex]) => seatIndex);
  const validSeats = seats.every(Number.isInteger) &&
    new Set(seats).size === seats.length &&
    seats.every((seat) => typeof seat === "number" &&
      seat >= 0 && seat < state.playerIds.length);
  return validSeats ? "save" : "invalid-seats";
}
