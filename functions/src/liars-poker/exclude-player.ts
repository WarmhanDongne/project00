/* eslint-disable valid-jsdoc, require-jsdoc */

import {
  countPlayersWithCards,
  findNextAlivePlayer,
  findNextPlayerWithCards,
} from "./common/next-turn.js";
import {
  LAST_CARD_CHALLENGE_DURATION_MS,
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
  const challengePlayerLeft =
    game.public.phase === "lastCardChallenge" &&
    game.public.turnUid === uid;

  if (penaltyTargetLeft || lastPlayOwnerLeft || challengePlayerLeft) {
    restartRound(game, nextAliveUid, now);
  } else {
    if (game.public.phase === "playing") {
      const remainingCardHolderCount = countPlayersWithCards(
        game.public.players,
      );
      const soleCardHolder = Object.values(game.public.players).find(
        (player) =>
          player.status === "alive" && player.remainingCardCount > 0,
      );

      if (remainingCardHolderCount === 0 || !soleCardHolder) {
        restartRound(game, nextAliveUid, now);
        return;
      }

      // 제외 결과 실제 잔여카드를 가진 사람이 한 명만 남았고 직전 제출자가
      // 다른 사람이라면, 그 한 명에게만 LIAR/FOLD 선택을 엽니다.
      if (
        remainingCardHolderCount === 1 &&
        game.public.lastPlay &&
        game.public.lastPlay.playerUid !== soleCardHolder.uid
      ) {
        game.public.phase = "lastCardChallenge";
        game.public.turnUid = soleCardHolder.uid;
        game.public.turnDeadlineAt = now + LAST_CARD_CHALLENGE_DURATION_MS;
      } else if (remainingCardHolderCount === 1) {
        // 유일한 카드 보유자가 자신의 제출을 의심할 수는 없으므로 새 라운드로
        // 복구해 제출·FOLD가 모두 막힌 상태를 만들지 않습니다.
        restartRound(game, soleCardHolder.uid, now);
        return;
      } else if (game.public.turnUid === uid) {
        const nextTurnUid = findNextPlayerWithCards(
          game.public.players,
          uid,
        );
        if (nextTurnUid === null) {
          restartRound(game, nextAliveUid, now);
          return;
        }
        game.public.turnUid = nextTurnUid;
        const timerHasStarted = game.public.isFirstTurnReady === true;
        game.public.turnDeadlineAt = timerHasStarted ?
          now + TURN_DURATION_MS : null;
      }
    } else if (
      game.public.phase === "dealing" &&
      game.public.turnUid === uid
    ) {
      game.public.turnUid = nextAliveUid;
      game.public.turnDeadlineAt = null;
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
