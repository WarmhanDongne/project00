/* eslint-disable valid-jsdoc */

import {
  countPlayersWithCards,
  findNextAlivePlayer,
  findNextPlayerWithCards,
} from "./common/next-turn.js";
import {restartRound} from "./restart-round.js";
import {
  LAST_CARD_CHALLENGE_DURATION_MS,
  LiarsPokerGameState,
  TURN_DURATION_MS,
} from "./common/types.js";

/**
 * 마감이 지난 턴을 대신 해결합니다. `game_liars_poker_force_timeout`의
 * 본체이며, Firebase 의존 없이 게임 상태만 다뤄 단위 테스트가 가능합니다.
 *
 * 해결 정책은 휴대폰 타임아웃(`_handleTurnTimeout`)과 같습니다.
 * 1. 마지막 카드 도전 단계 → FOLD (자신이 벌칙 룰렛)
 * 2. 직전 제출이 있으면 → LIAR 선언
 * 3. 그 외 → 손패에서 카드 한 장 자동 제출
 *
 * @returns callable이 그대로 돌려줄 응답. 마감 전이면 success:false,
 * 해결할 턴이 없으면 ignored:true를 담습니다.
 */
export function resolveForcedTimeout(
  game: LiarsPokerGameState,
  now: number,
): Record<string, unknown> {
  if (
    game.public.status !== "playing" ||
    (game.public.phase !== "playing" &&
      game.public.phase !== "lastCardChallenge")
  ) {
    return {success: true, ignored: true, phase: game.public.phase};
  }

  const turnUid = game.public.turnUid;
  const deadline = game.public.turnDeadlineAt;
  if (!turnUid || deadline === null) {
    return {success: true, ignored: true, phase: game.public.phase};
  }

  // 마감 전 호출은 무시합니다. 태블릿 시계가 앞서가도 턴이 잘리지 않습니다.
  if (now < deadline) {
    return {success: false, reason: "notExpired", turnDeadlineAt: deadline};
  }

  const player = game.public.players[turnUid];
  if (!player || player.status !== "alive") {
    return {success: true, ignored: true, phase: game.public.phase};
  }

  const lastPlay = game.public.lastPlay;
  const actualCards = game.server.lastPlayCards;
  const canFold = game.public.phase === "lastCardChallenge" &&
    player.remainingCardCount > 0 &&
    countPlayersWithCards(game.public.players) === 1;
  const canLiar = lastPlay !== null &&
    !!actualCards && actualCards.length > 0;

  if (canFold) {
    // 1. FOLD — pass-challenge와 같은 상태 전이입니다.
    game.public.phase = "penalty";
    game.public.turnUid = null;
    game.public.turnDeadlineAt = null;
    game.public.penaltyTargetUid = turnUid;
    delete game.public.penaltyResult;
    delete game.server.penaltyCountIncrementedBeforeRoulette;
    game.public.revision += 1;
    game.public.updatedAt = now;
    return {
      success: true,
      type: "forcedFold",
      turnUid,
      revision: game.public.revision,
    };
  }

  if (canLiar && lastPlay && actualCards) {
    // 2. LIAR — call-liar와 같은 판정·상태 전이입니다.
    const truthful = actualCards.every(
      (card) => card.rank === game.public.table || card.rank === "JOKER",
    );
    const penaltyTargetUid = truthful ? turnUid : lastPlay.playerUid;
    const alivePlayerCount = Object.values(game.public.players).filter(
      (candidate) => candidate.status === "alive",
    ).length;
    const shouldIncreasePenaltyBeforeRoulette =
      (alivePlayerCount === 2 ||
        game.public.phase === "lastCardChallenge") && truthful;
    if (shouldIncreasePenaltyBeforeRoulette) {
      player.penaltyCount += 1;
      game.server.penaltyCountIncrementedBeforeRoulette = true;
    } else {
      delete game.server.penaltyCountIncrementedBeforeRoulette;
    }

    const actualRanks = actualCards.map((card) => card.rank);
    const revealedLastPlay = {...lastPlay, revealed: true, actualRanks};
    game.public.phase = "penalty";
    game.public.turnUid = null;
    game.public.turnDeadlineAt = null;
    game.public.penaltyTargetUid = penaltyTargetUid;
    delete game.public.penaltyResult;
    game.public.lastPlay = revealedLastPlay;
    game.public.roundPlays ??= {};
    game.public.roundPlays[lastPlay.playId] = revealedLastPlay;
    game.public.revision += 1;
    game.public.updatedAt = now;
    return {
      success: true,
      type: "forcedLiar",
      truthful,
      challengerUid: turnUid,
      challengedUid: lastPlay.playerUid,
      penaltyTargetUid,
      revision: game.public.revision,
    };
  }

  // 3. 자동 제출 — submit-card와 같은 상태 전이입니다(카드 한 장).
  const hand = game.private[turnUid]?.hand ?? {};
  const cardIds = Object.keys(hand);
  if (cardIds.length === 0) {
    // 손패가 비어 있는 예외 상태에서는 새 라운드로 복구합니다.
    restartRound(game, findNextAlivePlayer(game.public.players, turnUid), now);
    return {
      success: true,
      type: "forcedRestartRound",
      revision: game.public.revision,
    };
  }

  const cardId = cardIds[0];
  const submittedCard = hand[cardId];
  delete hand[cardId];
  const remainingCardCount = Object.keys(hand).length;
  player.remainingCardCount = remainingCardCount;

  const isLastCardChallenge = remainingCardCount === 0 &&
    countPlayersWithCards(game.public.players) === 1;
  const nextTurnUid = findNextPlayerWithCards(game.public.players, turnUid);

  const play = {
    playId: `forced_${now}`,
    round: game.public.round,
    playerUid: turnUid,
    cardCount: 1,
    declaredRank: game.public.table,
    revealed: false,
    submittedAt: now,
  };
  game.public.lastPlay = play;
  game.public.roundPlays ??= {};
  game.public.roundPlays[play.playId] = play;
  game.server.lastPlayCards = [submittedCard];

  if (nextTurnUid === null) {
    restartRound(game, findNextAlivePlayer(game.public.players, turnUid), now);
  } else {
    game.public.phase = isLastCardChallenge ?
      "lastCardChallenge" : "playing";
    game.public.turnUid = nextTurnUid;
    game.public.turnDeadlineAt = now +
      (isLastCardChallenge ?
        LAST_CARD_CHALLENGE_DURATION_MS : TURN_DURATION_MS);
    game.public.isFirstTurnReady = true;
    game.public.revision += 1;
    game.public.updatedAt = now;
  }

  return {
    success: true,
    type: "forcedSubmit",
    turnUid,
    nextTurnUid: game.public.turnUid,
    phase: game.public.phase,
    revision: game.public.revision,
  };
}
