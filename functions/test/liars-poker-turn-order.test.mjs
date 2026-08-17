import assert from "node:assert/strict";
import test from "node:test";

import {
  countPlayersWithCards,
  findNextAlivePlayer,
  findNextPlayerWithCards,
} from "../lib/liars-poker/common/next-turn.js";

// 좌석 순서대로 플레이어를 만듭니다. cards로 각자 남은 손패 수를 지정합니다.
function players(cards, {eliminated = []} = {}) {
  return Object.fromEntries(
    cards.map((remainingCardCount, index) => {
      const uid = `uid${index + 1}`;
      return [uid, {
        uid,
        nickname: uid,
        seatIndex: index,
        status: eliminated.includes(uid) ? "eliminated" : "alive",
        penaltyCount: 0,
        remainingCardCount,
      }];
    }),
  );
}

test("손패가 남은 다음 자리로 턴이 넘어간다", () => {
  const seats = players([3, 2, 4]);
  assert.equal(findNextPlayerWithCards(seats, "uid1"), "uid2");
});

// 3인 이상에서 누군가 손패를 비워도 라운드는 끊기지 않아야 합니다. 카드를 다 낸
// 자리는 건너뛰고 남은 사람들끼리 계속 제출하거나 라이어를 외칩니다.
test("카드를 다 쓴 자리는 건너뛴다", () => {
  const seats = players([3, 0, 4]);
  assert.equal(findNextPlayerWithCards(seats, "uid1"), "uid3");
});

test("여러 자리가 비어 있어도 좌석 순서대로 건너뛴다", () => {
  const seats = players([2, 0, 0, 0, 1]);
  assert.equal(findNextPlayerWithCards(seats, "uid1"), "uid5");
});

test("마지막 자리에서는 첫 자리로 돌아간다", () => {
  const seats = players([1, 0, 0]);
  assert.equal(findNextPlayerWithCards(seats, "uid3"), "uid1");
});

test("탈락한 플레이어는 카드가 남아 있어도 건너뛴다", () => {
  const seats = players([3, 5, 2], {eliminated: ["uid2"]});
  assert.equal(findNextPlayerWithCards(seats, "uid1"), "uid3");
});

// 이어서 낼 사람이 없다는 신호입니다. submit-card는 이때 새 라운드를 엽니다.
test("자신 말고 카드를 가진 사람이 없으면 null을 돌려준다", () => {
  const seats = players([2, 0, 0]);
  assert.equal(findNextPlayerWithCards(seats, "uid1"), null);
});

test("모두가 손패를 비우면 null을 돌려준다", () => {
  const seats = players([0, 0, 0]);
  assert.equal(findNextPlayerWithCards(seats, "uid2"), null);
});

// 라운드 재분배·벌칙 이후 시작 자리를 고르는 기존 함수는 손패를 보지 않습니다.
// 그 시점에는 모두가 새 손패를 받기 때문입니다.
test("findNextAlivePlayer는 손패 수와 무관하게 다음 생존자를 고른다", () => {
  const seats = players([3, 0, 4]);
  assert.equal(findNextAlivePlayer(seats, "uid1"), "uid2");
});

// submit-card가 FOLD 단계를 여는 조건입니다.
//   손패를 모두 냈다 && countPlayersWithCards(...) === 1
// 살아 있는 인원이 아니라 카드를 가진 인원으로 세는 것이 핵심입니다.
function opensFoldStage(cards, submitterIndex, options) {
  const seats = players(cards, options);
  const submitter = `uid${submitterIndex + 1}`;
  return seats[submitter].remainingCardCount === 0 &&
    countPlayersWithCards(seats) === 1;
}

test("3인 모두 카드가 있을 때 한 명이 다 내도 FOLD가 열리지 않는다", () => {
  // uid1이 방금 손패를 비웠고 uid2·uid3에게는 아직 카드가 있습니다.
  assert.equal(opensFoldStage([0, 3, 2], 0), false);
});

test("먼저 손패를 비운 사람이 있어 둘만 남으면 FOLD가 열린다", () => {
  // uid3은 앞서 다 냈고, 이제 uid1이 마저 비웠습니다. uid2만 카드가 남습니다.
  assert.equal(opensFoldStage([0, 4, 0], 0), true);
});

test("2인 게임에서 한 명이 다 내면 FOLD가 열린다", () => {
  assert.equal(opensFoldStage([0, 2], 0), true);
});

test("손패가 남아 있으면 FOLD가 열리지 않는다", () => {
  assert.equal(opensFoldStage([1, 0, 0], 0), false);
});

test("탈락자의 카드는 세지 않는다", () => {
  // uid3은 탈락 상태라 카드 수와 무관합니다. 남은 카드 보유자는 uid2뿐입니다.
  assert.equal(
    opensFoldStage([0, 3, 5], 0, {eliminated: ["uid3"]}),
    true,
  );
});

test("카드를 가진 사람 수를 센다", () => {
  assert.equal(countPlayersWithCards(players([3, 0, 2, 0])), 2);
  assert.equal(countPlayersWithCards(players([0, 0, 0])), 0);
  assert.equal(
    countPlayersWithCards(players([4, 4], {eliminated: ["uid2"]})),
    1,
  );
});
