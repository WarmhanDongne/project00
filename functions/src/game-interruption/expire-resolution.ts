/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {
  finishGameForInsufficientPlayers,
  FinishNowRoom,
} from "./finish-now-resolution.js";
import {completeGameInterruption} from "./state.js";

export type InterruptionExpiryOutcome =
  "no-interruption" |
  "not-expired" |
  "continued" |
  "finished" |
  "unsupported-game";

export interface InterruptionExpiryResult {
  outcome: InterruptionExpiryOutcome;
  interruptionId?: string;
  removedUid?: string;
}

/**
 * 마감이 지난 중단을 해결합니다.
 *
 * `game_common_interruption_expire` callable의 본체를 그대로 옮긴 것이며,
 * Firebase 의존이 없어 단위 시험이 가능합니다. **서버 스케줄과 callable이 같은
 * 함수를 쓰는 것이 요점입니다.** 두 경로가 각자 상태를 만들면 "화면이 끝낸
 * 게임"과 "서버가 끝낸 게임"의 최종 상태가 갈립니다.
 *
 * `excludePlayer`(게임별 제외 처리)는 인자로 받습니다. 이 파일이 세 게임의
 * exclude 모듈을 직접 import하면 순환 참조가 생기고, 시험에서도 게임 상태를
 * 통째로 만들어야 합니다.
 *
 * @param room 방 전체 상태입니다. 트랜잭션 안에서 직접 수정합니다.
 * @param now 서버 기준 현재 시각입니다.
 * @param excludePlayer 계속 가능한 중단에서 부를 게임별 제외 처리입니다.
 * @returns 무엇을 했는지. 호출자가 응답과 로그에 씁니다.
 */
export function resolveExpiredInterruption(
  room: FinishNowRoom,
  now: number,
  excludePlayer: (room: FinishNowRoom, uid: string, now: number) => void,
): InterruptionExpiryResult {
  const game = room.game;
  const interruption = game?.public.interruption;
  if (!game || !interruption) return {outcome: "no-interruption"};
  // 이미 끝난 게임의 중단은 남은 잔여물입니다. 지우기만 하고 종료 사유를
  // 덮어쓰지 않습니다.
  if (game.public.status !== "playing") {
    completeGameInterruption(game, interruption.id, now);
    return {outcome: "no-interruption", interruptionId: interruption.id};
  }
  if (now < interruption.deadlineAt) {
    return {outcome: "not-expired", interruptionId: interruption.id};
  }

  const canContinue = interruption.canContinue;
  const playerUid = interruption.playerUid;

  if (!canContinue) {
    // 종료할 수 없는 게임이면 **중단 상태를 건드리기 전에** 멈춥니다. 그래야
    // 최악의 경우에도 기존 경로로 되돌아갈 수 있습니다(영구 정지가 아니라 지연).
    const revisionBefore = game.public.revision;
    if (!finishGameForInsufficientPlayers(room, now)) {
      return {outcome: "unsupported-game", interruptionId: interruption.id};
    }
    completeGameInterruption(game, interruption.id, now);
    delete room.players?.[playerUid];
    // 게임별 종료 함수의 revision 갱신 여부가 서로 다릅니다(final_call은 갱신하지
    // 않습니다). 여기서 정규화해 어떤 게임이든 정확히 한 번만 오르게 합니다.
    if (game.public.revision === revisionBefore) game.public.revision += 1;
    game.public.updatedAt = now;
    return {
      outcome: "finished",
      interruptionId: interruption.id,
      removedUid: playerUid,
    };
  }

  completeGameInterruption(game, interruption.id, now);
  delete room.players?.[playerUid];
  excludePlayer(room, playerUid, now);
  return {
    outcome: "continued",
    interruptionId: interruption.id,
    removedUid: playerUid,
  };
}
