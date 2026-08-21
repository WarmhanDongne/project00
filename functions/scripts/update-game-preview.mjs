/* eslint-disable max-len, no-console, require-jsdoc */

import {getApps, initializeApp} from "firebase-admin/app";
import {getFirestore} from "firebase-admin/firestore";
import {pathToFileURL} from "node:url";

export const gamePreviewDescriptions = Object.freeze({
  liars_poker: "정해진 키 카드에 맞춰 패를 내되, 원하는 카드를 숨겨 블러핑할 수 있습니다. 상대의 거짓말을 정확히 간파해 라이어를 선언하세요. 판정에서 패배하면 점점 위험해지는 룰렛을 돌리며, 마지막까지 살아남은 플레이어가 승리합니다.",
  final_call: "네 가지 색의 숫자 카드를 모아 가장 높은 조합을 만드는 2대2 팀전입니다. 카드를 교체하며 팀의 패를 완성하고, 승부의 순간에는 CALL을 선언하세요. 같은 색 또는 같은 숫자의 합으로 점수를 겨루며, 상대 팀의 하트를 먼저 모두 없애면 승리합니다.",
  mafia: "시민과 마피아가 정체를 숨긴 채 토론과 투표, 밤의 능력으로 승부하는 심리 추리 게임입니다. 시민은 단서를 모아 마피아를 찾아내고, 마피아는 의심을 피해 시민을 제거해야 합니다. 다양한 직업의 능력과 거짓말을 활용해 자신의 진영을 승리로 이끄세요.",
});

export async function updateGamePreviewDescriptions({dryRun = false} = {}) {
  if (dryRun) {
    for (const [gameId, tabletDescription] of
      Object.entries(gamePreviewDescriptions)) {
      console.log(`${gameId}: ${tabletDescription.length} characters`);
    }
    return;
  }

  if (getApps().length === 0) {
    initializeApp({projectId: process.env.GCLOUD_PROJECT ?? "project0000-ec01e"});
  }
  const firestore = getFirestore();
  const batch = firestore.batch();
  for (const [gameId, tabletDescription] of
    Object.entries(gamePreviewDescriptions)) {
    batch.set(
      firestore.collection("games").doc(gameId),
      {tabletDescription},
      {merge: true},
    );
  }
  await batch.commit();
  console.log(
    `Updated preview descriptions for ${Object.keys(gamePreviewDescriptions).length} games.`,
  );
}

const isMain = process.argv[1] &&
  import.meta.url === pathToFileURL(process.argv[1]).href;
if (isMain) {
  try {
    await updateGamePreviewDescriptions({
      dryRun: process.argv.includes("--dry-run"),
    });
  } catch (error) {
    const message = error instanceof Error ? error.message : String(error);
    console.error(`Game preview update failed: ${message}`);
    console.error(
      "Authenticate with Application Default Credentials, then run " +
      "npm run catalog:preview:update again.",
    );
    process.exitCode = 1;
  }
}
