/* eslint-disable max-len, no-console, require-jsdoc */

import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {pathToFileURL} from "node:url";

export const gameRules = Object.freeze({
  mafia: `🌙 게임 기본 규칙

[게임 목표]
- 시민팀: 모든 마피아를 찾아 처형하면 승리합니다.
- 마피아팀: 마피아 생존자 수가 시민 생존자 수 이상이 되면 승리합니다.

[낮의 턴]
- 모든 생존자는 자유롭게 토론한 뒤 한 명에게 비밀 투표합니다.
- 최다 득표자는 즉시 처형되며 직업이 모두에게 공개됩니다.
- 최다 득표자가 여러 명이면 아무도 처형되지 않습니다.

[밤의 턴]
- 밤에는 능력이 있는 직업들이 동시에 행동하고 시민은 대기합니다.
- 마피아의 공격과 시민팀의 보호·조사가 처리된 뒤 아침에 결과가 발표됩니다.
- 사망한 플레이어는 관전자로 전환되어 모든 플레이어의 직업을 볼 수 있습니다.

[시민팀 직업]
- 시민: 특별한 능력은 없으며 토론과 투표로 마피아를 찾아야 합니다.
- 경찰: 밤마다 한 명을 조사해 마피아 여부를 확인합니다.
- 의사: 밤마다 한 명을 선택해 마피아의 공격으로부터 보호합니다.
- 경호원: 현재 버전에서는 의사와 동일하게 한 명을 보호합니다.

[마피아팀 직업]
- 마피아: 밤마다 시민 한 명을 지목해 제거하며 다른 마피아를 알고 시작합니다.
- 마피아 보스: 마피아와 동일하게 행동하지만 경찰 조사에서는 시민으로 표시됩니다.`,
  liars_poker: `- 구성: 킹 6장, 퀸 6장, 에이스 6장, 조커 2장으로 총 20장을 사용하며, 게임 시작 시 각자 5장씩 받습니다.
- 진행: 매 판 지정되는 키 카드에 맞는 카드를 뒤집어서 냅니다.
- 블러핑: 키 카드가 없으면 다른 카드를 속여서 낼 수 있으며 조커는 만능 카드로 사용합니다.
- 의심: 상대가 거짓말했다고 생각하면 라이어를 선언해 카드를 공개합니다.
- 거짓이었다면 카드를 낸 사람이, 진실이었다면 의심한 사람이 룰렛을 돌립니다.
- 룰렛이 검정 영역에 멈추면 생존하고 빨간 영역에 멈추면 사망합니다. 최대 세 번의 기회가 주어지며 시도할 때마다 빨간 영역이 넓어지고, 세 번째에는 한 칸을 제외한 모든 칸이 빨간색이 됩니다.`,
  final_call: `🃏 게임 기본 규칙

[게임 목표]
- Final Call은 4명이 2대2로 진행하는 팀전입니다.
- 서로 마주 보는 플레이어가 같은 팀이 되며 빨간 팀과 파란 팀으로 나뉩니다.
- 모든 플레이어는 하트 3개로 시작하며, 팀원 중 한 명이라도 하트를 모두 잃으면 해당 팀이 패배합니다.

[카드와 점수]
- 카드는 네 가지 색과 1~10의 숫자로 구성된 총 40장이며 각 플레이어는 4장을 받습니다.
- 점수는 같은 색 카드의 숫자 합과 같은 숫자 카드의 합 중 더 높은 값입니다.
- 최종 제출 시 손패 중 점수로 사용할 카드 1~4장을 직접 선택합니다.

[턴 진행]
- 자신의 턴에는 카드 더미 또는 공개된 버림 카드에서 한 장을 가져옵니다.
- 가져온 카드를 손패 한 장과 교체하거나 그대로 버릴 수 있습니다.
- 각 행동과 최종 제출에는 30초의 제한 시간이 적용됩니다.

[CALL 선언]
- 자신의 턴에 카드를 가져오기 전 CALL을 선언할 수 있습니다.
- 선언자가 최종 조합을 제출하면 나머지 플레이어는 마지막 교체를 한 번 진행한 뒤 최종 조합을 제출합니다.
- 모든 제출이 끝나면 선택한 카드와 점수를 공개합니다.

[라운드 판정]
- 최저 점수 플레이어는 하트 1개를 잃고, CALL 선언자가 최하위라면 하트 2개를 잃습니다.
- 최하위가 여러 명이면 해당 플레이어 모두가 하트를 잃습니다.
- CALL 선언자가 같은 숫자 카드 4장을 제출하면 점수 비교 없이 상대 팀 두 명이 각각 하트 1개를 잃습니다.
- 카드 더미가 소진되면 서버가 각 플레이어의 최고 점수 조합을 선택해 자동 판정합니다.

[다음 라운드와 승리]
- 직전 라운드에서 하트를 잃은 생존자가 다음 라운드를 시작합니다.
- 후보가 여러 명이면 남은 하트가 가장 적은 플레이어, 그다음 좌석 순서로 정합니다.
- 한 팀의 플레이어가 하트를 모두 잃으면 상대 팀이 승리하며, 양 팀이 동시에 조건을 충족하면 무승부입니다.`,
});

export async function updateGameRules({dryRun = false} = {}) {
  if (dryRun) {
    for (const [gameId, rules] of Object.entries(gameRules)) {
      console.log(`${gameId}: ${rules.length} characters`);
    }
    return;
  }

  if (getApps().length === 0) {
    initializeApp({projectId: process.env.GCLOUD_PROJECT ?? "project0000-ec01e"});
  }
  const firestore = getFirestore();
  const batch = firestore.batch();
  for (const [gameId, rules] of Object.entries(gameRules)) {
    batch.set(
      firestore.collection("games").doc(gameId),
      {rules, accessType: "free"},
      {merge: true},
    );
  }
  await batch.commit();
  console.log(`Updated rules for ${Object.keys(gameRules).length} games.`);
}

const isMain = process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  try {
    await updateGameRules({dryRun: process.argv.includes("--dry-run")});
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Game rules update failed: ${message}`);
    console.error(
      "Authenticate with Application Default Credentials, then run " +
      "npm run catalog:rules:update again.",
    );
    process.exitCode = 1;
  }
}
