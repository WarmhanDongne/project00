import assert from "node:assert/strict";
import test from "node:test";

import {resolveForcedTimeout} from "../lib/liars-poker/forced-timeout-resolution.js";

/**
 * 최소 게임 상태를 만듭니다. 필요한 부분만 덮어씁니다.
 * @param {object} overrides 덮어쓸 public/private/server 조각
 * @return {object} LiarsPokerGameState 모양의 상태
 */
function makeGame(overrides = {}) {
  const base = {
    public: {
      status: "playing",
      phase: "playing",
      round: 1,
      revision: 10,
      table: "A",
      turnUid: "p1",
      turnDeadlineAt: 1000,
      isFirstTurnReady: true,
      lastPlay: null,
      roundPlays: {},
      penaltyTargetUid: null,
      winnerUid: null,
      players: {
        p1: {
          uid: "p1", nickname: "일번", characterId: "c1", seatIndex: 0,
          status: "alive", penaltyCount: 0, remainingCardCount: 2,
        },
        p2: {
          uid: "p2", nickname: "이번", characterId: "c2", seatIndex: 1,
          status: "alive", penaltyCount: 0, remainingCardCount: 3,
        },
        p3: {
          uid: "p3", nickname: "삼번", characterId: "c3", seatIndex: 2,
          status: "alive", penaltyCount: 0, remainingCardCount: 3,
        },
      },
      startedAt: 0,
      updatedAt: 0,
    },
    private: {
      p1: {hand: {c1: {id: "c1", rank: "K"}, c2: {id: "c2", rank: "A"}}},
    },
    server: {
      lastPlayCards: null,
      processedCommands: {},
      roundStarterUid: "p1",
    },
  };
  return {
    public: {...base.public, ...(overrides.public ?? {})},
    private: overrides.private ?? base.private,
    server: {...base.server, ...(overrides.server ?? {})},
  };
}

test("마감 전에는 success:false notExpired로 거절한다", () => {
  const game = makeGame();
  const result = resolveForcedTimeout(game, 999);

  assert.equal(result.success, false);
  assert.equal(result.reason, "notExpired");
  // 상태는 조금도 바뀌지 않아야 합니다.
  assert.equal(game.public.revision, 10);
  assert.equal(game.public.turnUid, "p1");
});

test("턴이 이미 넘어간 뒤의 중복 호출은 무해하게 끝난다", () => {
  const game = makeGame({public: {turnUid: null, turnDeadlineAt: null}});
  const result = resolveForcedTimeout(game, 2000);

  assert.equal(result.success, true);
  assert.equal(result.ignored, true);
  assert.equal(game.public.revision, 10);
});

test("직전 제출이 없으면 손패에서 한 장을 자동 제출하고 턴을 넘긴다", () => {
  const game = makeGame();
  const result = resolveForcedTimeout(game, 2000);

  assert.equal(result.success, true);
  assert.equal(result.type, "forcedSubmit");
  assert.equal(game.public.players.p1.remainingCardCount, 1);
  assert.equal(game.public.turnUid, "p2");
  assert.equal(game.public.phase, "playing");
  assert.ok(game.public.turnDeadlineAt > 2000);
  assert.equal(game.public.lastPlay.playerUid, "p1");
  assert.equal(game.public.lastPlay.cardCount, 1);
  assert.equal(game.server.lastPlayCards.length, 1);
  assert.equal(game.public.revision, 11);
});

test("직전 제출이 있으면 LIAR를 대신 선언한다 — 거짓이면 제출자가 벌칙", () => {
  const game = makeGame({
    public: {
      lastPlay: {
        playId: "play1", round: 1, playerUid: "p3", cardCount: 1,
        declaredRank: "A", revealed: false, submittedAt: 900,
      },
    },
    server: {lastPlayCards: [{id: "x1", rank: "Q"}]},
  });
  const result = resolveForcedTimeout(game, 2000);

  assert.equal(result.type, "forcedLiar");
  assert.equal(result.truthful, false);
  assert.equal(result.penaltyTargetUid, "p3");
  assert.equal(game.public.phase, "penalty");
  assert.equal(game.public.turnUid, null);
  assert.equal(game.public.lastPlay.revealed, true);
});

test("직전 제출이 있으면 LIAR를 대신 선언한다 — 진실이면 자신이 벌칙", () => {
  const game = makeGame({
    public: {
      lastPlay: {
        playId: "play1", round: 1, playerUid: "p3", cardCount: 1,
        declaredRank: "A", revealed: false, submittedAt: 900,
      },
    },
    server: {lastPlayCards: [{id: "x1", rank: "A"}]},
  });
  const result = resolveForcedTimeout(game, 2000);

  assert.equal(result.type, "forcedLiar");
  assert.equal(result.truthful, true);
  assert.equal(result.penaltyTargetUid, "p1");
});

test("마지막 카드 도전 단계에서는 FOLD로 자신이 벌칙을 받는다", () => {
  const game = makeGame({
    public: {
      phase: "lastCardChallenge",
      players: {
        p1: {
          uid: "p1", nickname: "일번", characterId: "c1", seatIndex: 0,
          status: "alive", penaltyCount: 0, remainingCardCount: 2,
        },
        p2: {
          uid: "p2", nickname: "이번", characterId: "c2", seatIndex: 1,
          status: "alive", penaltyCount: 0, remainingCardCount: 0,
        },
      },
      lastPlay: {
        playId: "play9", round: 1, playerUid: "p2", cardCount: 1,
        declaredRank: "A", revealed: false, submittedAt: 900,
      },
    },
    server: {lastPlayCards: [{id: "x1", rank: "A"}]},
  });
  const result = resolveForcedTimeout(game, 2000);

  assert.equal(result.type, "forcedFold");
  assert.equal(game.public.phase, "penalty");
  assert.equal(game.public.penaltyTargetUid, "p1");
});

test("마지막 한 장 제출로 lastCardChallenge가 열리는 경우를 계산한다", () => {
  const game = makeGame({
    public: {
      players: {
        p1: {
          uid: "p1", nickname: "일번", characterId: "c1", seatIndex: 0,
          status: "alive", penaltyCount: 0, remainingCardCount: 1,
        },
        p2: {
          uid: "p2", nickname: "이번", characterId: "c2", seatIndex: 1,
          status: "alive", penaltyCount: 0, remainingCardCount: 2,
        },
      },
    },
    private: {p1: {hand: {c1: {id: "c1", rank: "K"}}}},
  });
  const result = resolveForcedTimeout(game, 2000);

  assert.equal(result.type, "forcedSubmit");
  assert.equal(game.public.players.p1.remainingCardCount, 0);
  // 잔여카드 보유자가 p2 하나 → 다음 턴은 p2의 lastCardChallenge가 아니라
  // '카드를 가진 다음 사람' 규칙을 그대로 따릅니다.
  assert.equal(game.public.turnUid, "p2");
});
