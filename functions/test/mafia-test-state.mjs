// =========================================================================
// 마피아 테스트용 상태 만들기
//
// 역할만 정해 주면 나머지 필드를 채워 줍니다. 여러 테스트 파일이 같은 모양의
// 상태를 써야 결과를 서로 비교할 수 있어 한곳에 둡니다.
// =========================================================================

/** 역할만 정해 주면 나머지는 채워 주는 시험용 상태입니다. */
export function makeGame(roleMap, {phase = "night", round = 1} = {}) {
  const players = {};
  Object.keys(roleMap).forEach((uid, index) => {
    players[uid] = {
      uid,
      nickname: uid,
      profileImageUrl: "",
      seatIndex: index,
      status: "alive",
    };
  });
  const privateState = {};
  for (const uid of Object.keys(roleMap)) {
    privateState[uid] = {roleId: roleMap[uid]};
  }
  return {
    public: {
      gameType: "mafia",
      status: "playing",
      phase,
      round,
      revision: 1,
      turnDeadlineAt: null,
      players,
      roleRevealedUids: [],
      nightSubmittedCount: 0,
      nightActorCount: 0,
      discussionSkipCount: 0,
      voteSubmittedCount: 0,
      voteEligibleCount: Object.keys(roleMap).length,
      winner: null,
      winnerUids: [],
      startedAt: 0,
      updatedAt: 0,
    },
    private: privateState,
    server: {roles: {...roleMap}},
  };
}

/** 그 사람을 사망 상태로 만듭니다(밤 해결을 거치지 않는 준비용입니다). */
export function killForTest(game, uid, cause = "nightAttack") {
  game.public.players[uid].status = "dead";
  game.public.players[uid].deathCause = cause;
  game.public.players[uid].diedRound = game.public.round;
}
