import assert from "node:assert/strict";
import {readFileSync} from "node:fs";
import test from "node:test";

import {
  MAFIA_COMPOSITION,
  MAFIA_NIGHT_PHASE_ORDER,
  MAFIA_ROLES,
} from "../lib/mafia/roles.js";

// =========================================================================
// Dart ↔ TypeScript 역할 표 대조
//
// 역할 규칙은 Dart(화면)와 TypeScript(서버) 두 곳에 있습니다. 두 표가 갈리면
// 규칙이 **조용히** 깨집니다. 예를 들어 마피아 보스가 Dart에서는 조사에 시민으로
// 보이는데 서버에서는 마피아로 보이면, 화면과 판정이 어긋나도 아무 오류가
// 나지 않습니다.
//
// 그래서 Dart 파일을 직접 읽어 값을 비교합니다. 역할을 추가·수정할 때 한쪽만
// 고치면 이 테스트가 먼저 실패합니다.
// =========================================================================

// Dart 파일은 저장소 루트에 있습니다(functions/ 밖).
const DART_ROOT = "../../lib/games/mafia/models";
const roleSource = readFileSync(
  new URL(`${DART_ROOT}/mafia_roles.dart`, import.meta.url),
  "utf8",
);
const roleModelSource = readFileSync(
  new URL(`${DART_ROOT}/mafia_role.dart`, import.meta.url),
  "utf8",
);
const compositionSource = readFileSync(
  new URL(`${DART_ROOT}/mafia_composition.dart`, import.meta.url),
  "utf8",
);

/** Dart 역할 한 개의 정의 본문을 잘라 옵니다. */
function dartRoleBody(roleId) {
  const pattern = new RegExp(
    `MafiaRole\\(\\s*\\n\\s*id: '${roleId}',([\\s\\S]*?)\\n  \\);`,
  );
  const match = roleSource.match(pattern);
  assert.ok(match, `Dart 카탈로그에 '${roleId}' 역할이 없습니다.`);
  return match[1];
}

/** `field: Enum.value,` 형태에서 value를 뽑습니다. 없으면 기본값입니다. */
function dartEnumField(body, field, fallback) {
  const match = body.match(new RegExp(`${field}: \\w+\\.(\\w+),`));
  return match ? match[1] : fallback;
}

function dartBoolField(body, field, fallback) {
  const match = body.match(new RegExp(`${field}: (true|false),`));
  return match ? match[1] === "true" : fallback;
}

function dartIntField(body, field, fallback) {
  const match = body.match(new RegExp(`\\n\\s*${field}: (\\d+),`));
  return match ? Number(match[1]) : fallback;
}

/**
 * `field: '값',` 형태에서 값을 뽑습니다.
 *
 * 줄 시작에 붙여 찾습니다. 그러지 않으면 여러 줄로 이어진 `description:`
 * 안의 따옴표에 걸립니다.
 */
function dartStringField(body, field, fallback) {
  const match = body.match(new RegExp(`\\n\\s*${field}: '([^']*)',`));
  return match ? match[1] : fallback;
}

test("서버 역할 표가 Dart 카탈로그와 같다", () => {
  for (const [roleId, role] of Object.entries(MAFIA_ROLES)) {
    const body = dartRoleBody(roleId);

    assert.equal(
      role.faction,
      dartEnumField(body, "faction", null),
      `${roleId}: 진영이 다릅니다`,
    );
    assert.equal(
      role.nightAction,
      dartEnumField(body, "nightAction", "none"),
      `${roleId}: 밤 행동이 다릅니다`,
    );
    assert.equal(
      role.nightPhase,
      dartEnumField(body, "nightPhase", null),
      `${roleId}: 밤 해결 단계가 다릅니다`,
    );
    assert.equal(
      role.investigationAppearance,
      dartEnumField(body, "investigationAppearance", "actual"),
      `${roleId}: 조사에 보이는 모습이 다릅니다`,
    );
    assert.equal(
      role.knowsAllies,
      dartBoolField(body, "knowsAllies", false),
      `${roleId}: 동료를 아는지가 다릅니다`,
    );
    assert.equal(
      role.isImplemented,
      dartBoolField(body, "isImplemented", false),
      `${roleId}: 구현 여부가 다릅니다`,
    );

    // ===== 2026-08 추가된 규칙 축 =====
    assert.equal(
      role.displayName,
      dartStringField(body, "displayName", null),
      `${roleId}: 이름이 다릅니다`,
    );
    assert.equal(
      role.nightTargetScope,
      dartEnumField(body, "nightTargetScope", "alive"),
      `${roleId}: 밤 대상 범위가 다릅니다`,
    );
    assert.equal(
      role.winCondition,
      dartEnumField(body, "winCondition", "faction"),
      `${roleId}: 승리 조건이 다릅니다`,
    );
    assert.equal(
      role.maxUses,
      dartIntField(body, "maxUses", null),
      `${roleId}: 사용 횟수 제한이 다릅니다`,
    );
    assert.equal(
      role.defenseCharges,
      dartIntField(body, "defenseCharges", 0),
      `${roleId}: 자기 방어 횟수가 다릅니다`,
    );
    assert.equal(
      role.voteWeight,
      dartIntField(body, "voteWeight", 1),
      `${roleId}: 투표 가중치가 다릅니다`,
    );
    assert.equal(
      role.blocksTargetVote,
      dartBoolField(body, "blocksTargetVote", false),
      `${roleId}: 투표권 차단 여부가 다릅니다`,
    );
    assert.equal(
      role.selfDestructsOnAllyKill,
      dartBoolField(body, "selfDestructsOnAllyKill", false),
      `${roleId}: 오발 자멸 여부가 다릅니다`,
    );
    assert.equal(
      role.convertsTargetTo,
      dartStringField(body, "convertsTargetTo", null),
      `${roleId}: 전향 결과 역할이 다릅니다`,
    );
  }
});

test("서버 표에는 구현이 끝난 역할만 있다", () => {
  // 정의만 있는 역할을 서버 표에 넣으면 배분될 수 있습니다.
  for (const [roleId, role] of Object.entries(MAFIA_ROLES)) {
    assert.ok(role.isImplemented, `${roleId}: 미구현 역할이 서버 표에 있습니다`);
  }
});

test("전향으로만 생기는 역할은 배분표에 없다", () => {
  // 광신도는 교주의 전향 결과입니다. 처음부터 배분되면 교주 없는 광신도가
  // 생겨 승리 조건이 성립하지 않습니다.
  const convertOnly = new Set(
    Object.values(MAFIA_ROLES)
      .map((role) => role.convertsTargetTo)
      .filter((id) => id !== null),
  );
  for (const [count, composition] of Object.entries(MAFIA_COMPOSITION)) {
    for (const roleId of Object.keys(composition)) {
      assert.ok(
        !convertOnly.has(roleId),
        `${count}인 구성에 전향 전용 역할 '${roleId}'가 있습니다`,
      );
    }
  }
});

test("전향 결과로 지정한 역할은 서버 표에 있다", () => {
  for (const [roleId, role] of Object.entries(MAFIA_ROLES)) {
    if (role.convertsTargetTo === null) continue;
    assert.ok(
      MAFIA_ROLES[role.convertsTargetTo],
      `${roleId}의 전향 결과 '${role.convertsTargetTo}'가 서버 표에 없습니다`,
    );
  }
});

test("사망자를 고르는 역할은 밤 행동이 있다", () => {
  // 대상 범위만 dead인데 밤 행동이 없으면 아무 일도 일어나지 않습니다.
  for (const [roleId, role] of Object.entries(MAFIA_ROLES)) {
    if (role.nightTargetScope !== "dead") continue;
    assert.notEqual(
      role.nightAction,
      "none",
      `${roleId}: 사망자를 고르는데 밤 행동이 없습니다`,
    );
  }
});

test("밤 해결 순서가 Dart와 같다", () => {
  for (const [phase, order] of Object.entries(MAFIA_NIGHT_PHASE_ORDER)) {
    const match = roleModelSource.match(new RegExp(`\\n  ${phase}\\((\\d+)\\)`));
    assert.ok(match, `Dart에 ${phase} 단계가 없습니다.`);
    assert.equal(
      order,
      Number(match[1]),
      `${phase}: 해결 순서가 다릅니다`,
    );
  }
});

test("인원별 구성표가 Dart와 같다", () => {
  // Dart의 recommended 맵을 그대로 읽습니다.
  const block = compositionSource.match(
    /recommended = \{([\s\S]*?)\n  \};/,
  );
  assert.ok(block, "Dart 구성표를 찾지 못했습니다.");

  const dartComposition = {};
  const entryPattern = /(\d+):\s*\{([^}]*)\}/g;
  let entry;
  while ((entry = entryPattern.exec(block[1])) !== null) {
    const counts = {};
    const rolePattern = /'(\w+)':\s*(\d+)/g;
    let role;
    while ((role = rolePattern.exec(entry[2])) !== null) {
      counts[role[1]] = Number(role[2]);
    }
    dartComposition[Number(entry[1])] = counts;
  }

  assert.deepEqual(
    MAFIA_COMPOSITION,
    dartComposition,
    "서버 구성표가 Dart와 다릅니다",
  );
});

test("구성표에 등장하는 모든 역할이 서버 표에 있다", () => {
  for (const [count, composition] of Object.entries(MAFIA_COMPOSITION)) {
    const total = Object.values(composition)
      .reduce((sum, value) => sum + value, 0);
    assert.equal(total, Number(count), `${count}인 구성 합계가 인원과 다릅니다`);

    for (const roleId of Object.keys(composition)) {
      assert.ok(
        MAFIA_ROLES[roleId],
        `${count}인 구성의 '${roleId}'가 서버 역할 표에 없습니다`,
      );
    }
  }
});

test("모든 인원 구성에서 시민팀이 마피아팀보다 많다", () => {
  for (const [count, composition] of Object.entries(MAFIA_COMPOSITION)) {
    let mafia = 0;
    let others = 0;
    for (const [roleId, value] of Object.entries(composition)) {
      if (MAFIA_ROLES[roleId].faction === "mafia") mafia += value;
      else others += value;
    }
    assert.ok(
      others > mafia,
      `${count}인: 시작부터 마피아가 이깁니다 (마피아 ${mafia} / 나머지 ${others})`,
    );
  }
});
