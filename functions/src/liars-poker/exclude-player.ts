/* eslint-disable valid-jsdoc, require-jsdoc */

import {
  findNextAlivePlayer,
  findNextPlayerWithCards,
} from "./common/next-turn.js";
import {
  LiarsPokerGameState,
  TURN_DURATION_MS,
} from "./common/types.js";
import {restartRound} from "./restart-round.js";

/** 투표가 승인된 플레이어를 게임에서 제외하고 다음 유효 상태를 만듭니다. */
export function excludeLiarsPokerPlayer(
  game: LiarsPokerGameState,
  uid: string,
  now: number,
): void {
  const gamePlayer = game.public.players[uid];
  if (!gamePlayer || gamePlayer.status !== "alive") return;

  gamePlayer.status = "eliminated";
  gamePlayer.remainingCardCount = 0;
  delete game.private[uid];
  delete game.server.pendingHands?.[uid];

  const alivePlayers = Object.values(game.public.players).filter(
    (player) => player.status === "alive",
  );
  if (alivePlayers.length < 2) {
    finishLiarsPokerForInsufficientPlayers(game, now);
    return;
  }

  const nextAliveUid = findNextAlivePlayer(game.public.players, uid);
  const penaltyTargetLeft =
    game.public.phase === "penalty" && game.public.penaltyTargetUid === uid;
  const lastPlayOwnerLeft =
    game.public.phase === "lastCardChallenge" &&
    game.public.lastPlay?.playerUid === uid;

  if (penaltyTargetLeft || lastPlayOwnerLeft) {
    restartRound(game, nextAliveUid, now);
  } else {
    if (game.public.turnUid === uid) {
      // 카드가 없는 자리로는 턴을 넘기지 않습니다.
      // 진행 중인 라운드에서는 손패가 남은 사람에게만 턴이 갑니다. 나간 사람이
      // 마지막 카드 보유자였다면 이어갈 사람이 없으므로 라운드를 새로 엽니다.
      const nextTurnUid = game.public.phase === "playing" ?
        findNextPlayerWithCards(game.public.players, uid) :
        nextAliveUid;
      if (nextTurnUid === null) {
        restartRound(game, nextAliveUid, now);
        return;
      }
      game.public.turnUid = nextTurnUid;
      const timerHasStarted = game.public.isFirstTurnReady === true;
      game.public.turnDeadlineAt =
        game.public.phase === "dealing" || !timerHasStarted ?
          null : now + TURN_DURATION_MS;
    }
    if (game.server.roundStarterUid === uid) {
      game.server.roundStarterUid = nextAliveUid;
    }
    game.public.revision += 1;
    game.public.updatedAt = now;
  }
}

export function finishLiarsPokerForInsufficientPlayers(
  game: LiarsPokerGameState,
  now: number,
): void {
  game.public.status = "finished";
  game.public.finishReason = "insufficientPlayers";
  game.public.phase = "finished";
  game.public.turnUid = null;
  game.public.turnDeadlineAt = null;
  game.public.penaltyTargetUid = null;
  game.public.winnerUid = null;
  game.public.revision += 1;
  game.public.updatedAt = now;
  game.public.finishedAt = now;
  game.private = {};
  game.server.lastPlayCards = null;
  delete game.server.pendingHands;
}
