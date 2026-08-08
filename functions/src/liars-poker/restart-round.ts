/* eslint-disable valid-jsdoc */

import {createDeck} from "./common/deck.js";
import {dealCards} from "./common/deal-card.js";
import {createTable} from "./common/table.js";
import {LiarsPokerGameState} from "./common/types.js";

export const CARDS_PER_PLAYER = 5;

/** 생존 플레이어의 손패를 재분배하고 새 라운드 상태를 만듭니다. */
export function restartRound(
  game: LiarsPokerGameState,
  starterUid: string,
  now: number,
): void {
  const players = game.public.players;
  const alivePlayers = Object.values(players).filter(
    (player) => player.status === "alive",
  );
  if (!alivePlayers.some((player) => player.uid === starterUid)) {
    throw new Error("새 라운드 시작 플레이어가 생존 상태가 아닙니다.");
  }

  const deck = createDeck(alivePlayers.length);
  const hands = dealCards(deck, players, CARDS_PER_PLAYER);
  const privateStates: LiarsPokerGameState["private"] = {};

  for (const player of Object.values(players)) {
    if (player.status === "alive") {
      player.remainingCardCount = CARDS_PER_PLAYER;
      privateStates[player.uid] = {hand: hands[player.uid]};
    } else {
      player.remainingCardCount = 0;
    }
  }

  // 새 라운드도 태블릿 딜링이 끝나기 전에는 휴대폰에 손패를 공개하지 않습니다.
  game.private = {};
  game.server.pendingHands = privateStates;
  game.public.phase = "dealing";
  game.public.round += 1;
  game.public.revision += 1;
  game.public.table = createTable();
  game.public.turnUid = starterUid;
  game.public.turnDeadlineAt = null;
  game.public.lastPlay = null;
  game.public.roundPlays = {};
  game.public.penaltyTargetUid = null;
  game.public.updatedAt = now;
  game.server.lastPlayCards = null;
  game.server.roundStarterUid = starterUid;
}
