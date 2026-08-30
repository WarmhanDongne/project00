/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {HttpsError} from "firebase-functions/v2/https";

import {finishFinalCallForInsufficientPlayers} from "../final-call/exclude-player.js";
import {FinalCallGameState} from "../final-call/types.js";
import {finishLiarsPokerForInsufficientPlayers} from "../liars-poker/exclude-player.js";
import {LiarsPokerGameState} from "../liars-poker/common/types.js";
import {finishMafiaForInsufficientPlayers} from "../mafia/exclude-player.js";
import {MafiaGameState} from "../mafia/types.js";
import {assertControllerSession} from "../room/controller-session.js";
import {completeGameInterruption, InterruptibleRoom} from "./state.js";
import {InterruptibleGameState} from "./types.js";

/**
 * 인원 부족 종료를 지원하는 게임 표입니다. **게임을 추가하면 여기에 한 줄
 * 추가하세요.**
 *
 * `functions.ts:finishForInsufficientPlayers`의 private 디스패처와 같은 대상을
 * 다룹니다. 그쪽은 default 분기가 없어 알 수 없는 게임에서 조용히 no-op이
 * 되지만, 이 표는 키의 존재 여부로 사전 검증을 할 수 있게 만들었습니다
 * (아래 `supportsInsufficientPlayerFinish`).
 */
const FINISH_FOR_INSUFFICIENT_PLAYERS: Record<
  string,
  (game: InterruptibleGameState, now: number) => void
> = {
  final_call: (game, now) =>
    finishFinalCallForInsufficientPlayers(
      game as unknown as FinalCallGameState,
      now,
    ),
  liars_poker: (game, now) =>
    finishLiarsPokerForInsufficientPlayers(
      game as unknown as LiarsPokerGameState,
      now,
    ),
  mafia: (game, now) =>
    finishMafiaForInsufficientPlayers(game as unknown as MafiaGameState, now),
};

export interface FinishNowRoom extends InterruptibleRoom {
  controllerUid?: string;
  controllerSessionId?: string;
  hostUid?: string;
  selectedGame?: string;
}

export interface FinishNowInput {
  uid: string;
  interruptionId: string;
  controllerSessionId?: unknown;
  now: number;
}

/**
 * 이 게임이 인원 부족 종료를 지원하는지입니다.
 *
 * `MINIMUM_PLAYER_COUNTS`(functions.ts)는 알 수 없는 게임에 2를 폴백하므로
 * 판정 근거로 쓸 수 없습니다. **실제로 호출할 종료 함수가 있는지**가 유일한
 * 기준입니다.
 */
export function supportsInsufficientPlayerFinish(selectedGame: unknown): boolean {
  return (
    typeof selectedGame === "string" &&
    Object.prototype.hasOwnProperty.call(
      FINISH_FOR_INSUFFICIENT_PLAYERS,
      selectedGame,
    )
  );
}

/** 종료를 실제로 실행했으면 true. 지원하지 않는 게임이면 아무것도 하지 않고 false. */
export function finishGameForInsufficientPlayers(
  room: FinishNowRoom,
  now: number,
): boolean {
  const game = room.game;
  if (!game || !supportsInsufficientPlayerFinish(room.selectedGame)) {
    return false;
  }
  FINISH_FOR_INSUFFICIENT_PLAYERS[room.selectedGame as string](game, now);
  return true;
}

/**
 * 인원 부족이 확정된 중단을 60초 마감 전에 즉시 정상 종료합니다.
 *
 * `game_common_interruption_finish_now`의 본체이며, Firebase 의존 없이 방
 * 상태만 다뤄 단위 테스트가 가능합니다. 만드는 최종 상태는
 * `game_common_interruption_expire`의 `canContinue === false` 분기와 **같습니다**
 * (`finishReason`도 `insufficientPlayers`를 재사용합니다). 그래야 휴대폰·태블릿이
 * "만료로 끝난 게임"과 "즉시 종료된 게임"을 구분하는 코드를 갖지 않아도 됩니다.
 *
 * @returns callable이 그대로 돌려줄 응답. 이미 처리된 중단이면
 * alreadyResolved:true를 담고 아무것도 바꾸지 않습니다.
 */
export function resolveInterruptionFinishNow(
  room: FinishNowRoom,
  input: FinishNowInput,
): Record<string, unknown> {
  const {uid, interruptionId, now} = input;
  const game = room.game;
  const interruption = game?.public.interruption;

  // 1) 멱등: 이미 처리·취소된 중단이면 아무것도 하지 않습니다. 0초 자동 만료와
  //    경합해도 먼저 도착한 쪽이 처리하고 나머지는 여기서 조용히 끝납니다.
  if (!game || !interruption || interruption.id !== interruptionId) {
    return {success: true, finished: false, alreadyResolved: true};
  }
  // 2) 이미 끝난 게임의 finishReason·finishedAt을 덮어쓰지 않습니다.
  if (game.public.status !== "playing") {
    return {
      success: true,
      finished: false,
      alreadyResolved: true,
      gameStatus: game.public.status,
    };
  }

  // 3) 권한: 살아 있는 남은 참가자이거나, 유효한 세션을 가진 진행 태블릿만.
  //
  //    `eligibleVoterUids`가 아니라 `game.public.players`의 alive로 판정합니다.
  //    그 목록은 중단 시작 시점의 접속자 스냅샷이라(state.ts:beginGameInterruption),
  //    그때 끊겨 있다가 뒤에 복귀한 사람은 살아 있는데도 목록에 없습니다.
  //
  //    controller 판정도 `(controllerUid ?? hostUid) === uid`로 통일합니다.
  //    `uid === controllerUid || uid === hostUid`로 판정하면 controllerUid와
  //    hostUid가 다른 방에서 host가 assertControllerSession에 막힙니다.
  const isRemainingPlayer =
    uid !== interruption.playerUid &&
    game.public.players[uid]?.status === "alive";
  const isController = (room.controllerUid ?? room.hostUid) === uid;
  if (!isRemainingPlayer && !isController) {
    throw new HttpsError("permission-denied", "게임을 종료할 권한이 없습니다.");
  }
  if (!isRemainingPlayer) {
    assertControllerSession(room, uid, input.controllerSessionId);
  }

  // 4) 계속할 수 있는 중단은 기존 투표·`제외하고 계속하기` 흐름의 몫입니다.
  //    game_common_interruption_exclude_player의 `!canContinue` 거부와
  //    정확히 대칭이라, 두 callable이 서로의 여집합만 담당합니다.
  if (interruption.canContinue) {
    throw new HttpsError(
      "failed-precondition",
      "남은 인원이 충분해 바로 종료할 수 없습니다.",
    );
  }

  // 5) 종료할 수 없는 게임이면 **중단 상태를 건드리기 전에** 멈춥니다. 트랜잭션
  //    콜백에서 던지면 abort되어 중단이 그대로 보존되므로, 최악의 경우에도
  //    기존 60초 만료 경로로 되돌아갈 수 있습니다(영구 정지가 아니라 지연).
  if (!supportsInsufficientPlayerFinish(room.selectedGame)) {
    throw new HttpsError(
      "failed-precondition",
      "이 게임은 인원 부족 종료를 지원하지 않습니다.",
    );
  }

  // 6) finish를 **먼저** 부릅니다. completeGameInterruption의
  //    restoreTurnDeadline은 status === "playing"일 때만 턴 마감을 되살리므로
  //    (state.ts:restoreTurnDeadline), 여기서 이미 finished가 되면 그 가드를
  //    통과하지 못합니다. 좀비 턴 마감이 원천 차단됩니다.
  const revisionBefore = game.public.revision;
  if (!finishGameForInsufficientPlayers(room, now)) {
    throw new HttpsError("internal", "게임을 종료하지 못했습니다.");
  }
  completeGameInterruption(game, interruption.id, now);

  // 60초 안에 같은 UID가 돌아올 여지는 여기서 끝났으므로 방 참가자 노드를
  // 지웁니다. expire와 같은 범위(이탈 당사자 하나)만 지웁니다. 먼저 끊긴 채
  // 남은 다른 유령 참가자 정리는 C-03/C-10 소관입니다.
  delete room.players?.[interruption.playerUid];

  // 게임별 종료 함수의 revision 갱신 여부가 서로 다릅니다(final_call은 갱신하지
  // 않습니다). 여기서 정규화해 어떤 게임이든 정확히 한 번만 오르게 합니다.
  if (game.public.revision === revisionBefore) {
    game.public.revision += 1;
  }
  game.public.updatedAt = now;

  return {
    success: true,
    finished: true,
    finishReason: "insufficientPlayers",
    gameStatus: game.public.status,
    removedUid: interruption.playerUid,
    revision: game.public.revision,
  };
}
