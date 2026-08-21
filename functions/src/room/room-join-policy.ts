export const GAME_PREPARATION_STARTED_MESSAGE =
  "이미 게임 준비가 시작된 방입니다.";

export type RoomJoinDecision =
  "new-player" |
  "reconnect" |
  "room-closed" |
  "room-finished" |
  "inactive-player" |
  "game-preparing";

type RoomJoinState = {
  roomStatus: unknown;
  gameStatus?: unknown;
  playerExists: boolean;
  playerStatus?: unknown;
};

/**
 * 서버의 현재 방 상태와 UID 존재 여부로 참가 종류를 판정합니다.
 * @param {RoomJoinState} state 현재 방과 참가자 상태입니다.
 * @return {RoomJoinDecision} 서버가 적용할 참가 처리 종류입니다.
 */
export function decideRoomJoin(state: RoomJoinState): RoomJoinDecision {
  if (state.roomStatus === "closed") return "room-closed";
  const roomStatus = state.roomStatus ?? "waiting";
  const roomIsWaitingOrSeating =
    roomStatus === "waiting" || roomStatus === "seating";
  if (roomStatus === "finished" ||
      (!roomIsWaitingOrSeating && state.gameStatus === "finished")) {
    return "room-finished";
  }

  if (state.playerExists) {
    return state.playerStatus === undefined || state.playerStatus === "active" ?
      "reconnect" :
      "inactive-player";
  }

  if (roomStatus !== "waiting" || state.gameStatus === "playing") {
    return "game-preparing";
  }
  return "new-player";
}
