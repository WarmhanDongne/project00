/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {
  MafiaFactionId,
  MafiaInvestigationAppearanceId,
  MafiaNightActionId,
  MafiaNightPhaseId,
  MafiaNightTargetScopeId,
  MafiaWinConditionId,
} from "./types.js";

// =========================================================================
// 역할 카탈로그 (서버용)
//
// Dart `lib/games/mafia/models/mafia_roles.dart`의 **거울**입니다. 서버는 Dart를
// 읽을 수 없어 같은 표를 두 곳에 둡니다. 두 표가 갈리면 규칙이 조용히 깨지므로
// `functions/test/mafia-role-parity.test.mjs`가 Dart 파일을 파싱해 대조합니다.
//
// 여기에는 **서버가 판정에 쓰는 값만** 둡니다. 색·카드·긴 설명은 Dart에만
// 있습니다. 다만 `displayName`은 예외입니다 — 영매·도둑의 결과 문구("경찰"처럼
// 직업 이름)를 서버가 만들어 보내야 하기 때문입니다.
//
// 이 파일은 역할 이름으로 분기하지 않습니다. 아래 값으로만 판정하므로 새 역할은
// 표에 한 줄 추가하면 밤 해결·조사·승패가 그대로 동작합니다.
// =========================================================================

export interface MafiaServerRole {
  id: string;
  /** 결과 문구에 쓰는 이름입니다(영매의 "경찰", 도둑의 훔친 직업). */
  displayName: string;
  faction: MafiaFactionId;
  nightAction: MafiaNightActionId;
  /** 밤 행동이 없으면 null입니다. */
  nightPhase: MafiaNightPhaseId | null;
  /** 밤에 고를 수 있는 대상입니다. 영매·도둑만 "dead"입니다. */
  nightTargetScope: MafiaNightTargetScopeId;
  investigationAppearance: MafiaInvestigationAppearanceId;
  /** 진영 승리가 아니라 개별 조건으로 판정하는 역할인지입니다. */
  winCondition: MafiaWinConditionId;
  /** 같은 편을 서로 알고 시작하는지입니다. */
  knowsAllies: boolean;
  /** 게임당 능력 사용 횟수입니다. null이면 제한 없음(자경단원 1). */
  maxUses: number | null;
  /** 밤 공격을 스스로 막아내는 횟수입니다(군인 1). */
  defenseCharges: number;
  /** 낮 투표에서 이 사람의 표가 몇 표인지입니다(정치인 2). */
  voteWeight: number;
  /** 지목한 대상의 다음 낮 투표권까지 막는지입니다(마담·건달). */
  blocksTargetVote: boolean;
  /**
   * 지목한 대상의 **밤 능력**을 막는지입니다.
   *
   * 확정(2026-08): 건달은 밤 능력이 아니라 **낮 투표권**만 막습니다. 그래서
   * "지목해서 막는다"를 두 값으로 나눴습니다 — 마담은 둘 다 막고, 건달은
   * 투표권만 막습니다.
   */
  blocksAbility: boolean;
  /** 같은 편을 제거하면 자신도 죽는지입니다(자경단원 오발). */
  selfDestructsOnAllyKill: boolean;
  /** 전향에 성공한 대상이 되는 역할 id입니다(교주 → cultist). */
  convertsTargetTo: string | null;
  /** 이 빌드가 동작까지 구현한 역할인지입니다. 배분은 이 값이 true인 것만 씁니다. */
  isImplemented: boolean;
}

/** 표에 한 줄 적을 때 반복을 줄이는 기본값입니다. */
const BASE = {
  nightAction: "none",
  nightPhase: null,
  nightTargetScope: "alive",
  investigationAppearance: "actual",
  winCondition: "faction",
  knowsAllies: false,
  maxUses: null,
  defenseCharges: 0,
  voteWeight: 1,
  blocksTargetVote: false,
  blocksAbility: false,
  selfDestructsOnAllyKill: false,
  convertsTargetTo: null,
  isImplemented: true,
} satisfies Omit<MafiaServerRole, "id" | "displayName" | "faction">;

/** 배분에 쓰이는 역할입니다. Dart 카탈로그와 값이 같아야 합니다. */
export const MAFIA_ROLES: Record<string, MafiaServerRole> = {
  // ===== 시민 진영 =====
  citizen: {
    ...BASE, id: "citizen", displayName: "시민", faction: "citizen",
  },
  police: {
    ...BASE, id: "police", displayName: "경찰", faction: "citizen",
    nightAction: "investigate", nightPhase: "investigate",
  },
  doctor: {
    ...BASE, id: "doctor", displayName: "의사", faction: "citizen",
    nightAction: "protect", nightPhase: "protect",
  },
  // 경호원은 지금 **의사와 같은 보호**로 동작합니다. 고전 규칙(대상 대신 죽음)이
  // 필요하면 데이터에 표시를 추가하고 해결 엔진에 한 갈래를 더해야 합니다.
  bodyguard: {
    ...BASE, id: "bodyguard", displayName: "경호원", faction: "citizen",
    nightAction: "protect", nightPhase: "protect",
  },
  // 군인은 공격 대상이 되는 순간 방어를 하나 소모하고 살아남습니다. 밤에
  // 고르는 것이 없으므로 밤 행동 인원수에도 잡히지 않습니다.
  soldier: {
    ...BASE, id: "soldier", displayName: "군인", faction: "citizen",
    defenseCharges: 1,
  },
  // 정치인의 표는 2표로 셉니다.
  politician: {
    ...BASE, id: "politician", displayName: "정치인", faction: "citizen",
    voteWeight: 2,
  },
  // 영매는 **사망자**의 직업을 확인합니다. 경찰(진영)과 다릅니다.
  medium: {
    ...BASE, id: "medium", displayName: "영매", faction: "citizen",
    nightAction: "investigateRole", nightPhase: "investigate",
    nightTargetScope: "dead",
  },
  // 확정(2026-08): 건달은 **낮 투표권**을 막습니다. 밤 능력은 막지 않습니다.
  // 그래서 해결 단계도 차단(roleblock)이 아니라 상태 부여(statusEffect)입니다 —
  // 뒤 역할의 행동 가능 여부를 바꾸지 않으므로 먼저 처리할 이유가 없습니다.
  gangster: {
    ...BASE, id: "gangster", displayName: "건달", faction: "citizen",
    nightAction: "roleblock", nightPhase: "statusEffect",
    blocksTargetVote: true,
  },
  // 자경단원은 게임당 1회. 시민팀을 쏘면 오발로 자신도 함께 죽습니다.
  vigilante: {
    ...BASE, id: "vigilante", displayName: "자경단원", faction: "citizen",
    nightAction: "eliminate", nightPhase: "independentAttack",
    maxUses: 1, selfDestructsOnAllyKill: true,
  },
  // 밤에 지목한 사람의 신분을 다음 아침에 **전체 공개**합니다.
  reporter: {
    ...BASE, id: "reporter", displayName: "기자", faction: "citizen",
    nightAction: "expose", nightPhase: "statusEffect",
  },
  // 대상이 누구를 찾아갔는지 조사합니다.
  detective: {
    ...BASE, id: "detective", displayName: "사립탐정", faction: "citizen",
    nightAction: "track", nightPhase: "investigate",
  },

  // ===== 마피아 진영 =====
  mafia: {
    ...BASE, id: "mafia", displayName: "마피아", faction: "mafia",
    nightAction: "eliminate", nightPhase: "mafiaAttack", knowsAllies: true,
  },
  // 마피아 보스는 마피아와 같지만 **조사에서 시민으로 보입니다.**
  mafia_boss: {
    ...BASE, id: "mafia_boss", displayName: "마피아 보스", faction: "mafia",
    nightAction: "eliminate", nightPhase: "mafiaAttack",
    investigationAppearance: "asCitizen", knowsAllies: true,
  },
  // 스파이는 마피아를 알지만 밤에 하는 일이 없고 조사에 시민으로 보입니다.
  spy: {
    ...BASE, id: "spy", displayName: "스파이", faction: "mafia",
    investigationAppearance: "asCitizen", knowsAllies: true,
  },
  // 짐승인간은 마피아팀이지만 **혼자** 공격합니다(다수결에 참여하지 않습니다).
  // 동료를 모르므로 knowsAllies가 false입니다.
  beast: {
    ...BASE, id: "beast", displayName: "짐승인간", faction: "mafia",
    nightAction: "eliminate", nightPhase: "independentAttack",
  },
  // 마담은 능력 차단에 더해 대상의 **다음 낮 투표권**까지 막습니다.
  madam: {
    ...BASE, id: "madam", displayName: "마담", faction: "mafia",
    nightAction: "roleblock", nightPhase: "roleblock",
    blocksTargetVote: true, blocksAbility: true, knowsAllies: true,
  },
  // 도둑은 사망자의 직업을 훔쳐 그 직업이 됩니다(진영까지 바뀝니다).
  thief: {
    ...BASE, id: "thief", displayName: "도둑", faction: "mafia",
    nightAction: "steal", nightPhase: "statusEffect",
    nightTargetScope: "dead", knowsAllies: true,
  },

  // ===== 중립 진영 — 개별 승리 조건 =====
  jester: {
    ...BASE, id: "jester", displayName: "광대", faction: "neutral",
    winCondition: "lynchedSelf",
  },
  executioner: {
    ...BASE, id: "executioner", displayName: "처형자", faction: "neutral",
    winCondition: "lynchTarget",
  },
  serial_killer: {
    ...BASE, id: "serial_killer", displayName: "연쇄살인마",
    faction: "neutral",
    nightAction: "eliminate", nightPhase: "independentAttack",
    winCondition: "lastStanding",
  },
  cult_leader: {
    ...BASE, id: "cult_leader", displayName: "교주", faction: "neutral",
    nightAction: "convert", nightPhase: "convert",
    winCondition: "factionDominance",
    convertsTargetTo: "cultist", knowsAllies: true,
  },
  // 광신도는 **배분표로는 나오지 않습니다.** 교주의 전향으로만 생깁니다.
  cultist: {
    ...BASE, id: "cultist", displayName: "광신도", faction: "neutral",
    winCondition: "factionDominance", knowsAllies: true,
  },
};

/**
 * 밤 행동 해결 순서입니다. 값이 작을수록 먼저 처리합니다.
 *
 * Dart `MafiaNightPhase`의 order와 같습니다. 순서를 바꾸면 규칙이 깨집니다.
 */
export const MAFIA_NIGHT_PHASE_ORDER: Record<MafiaNightPhaseId, number> = {
  roleblock: 2,
  protect: 3,
  frame: 4,
  convert: 5,
  investigate: 6,
  mafiaAttack: 7,
  independentAttack: 8,
  statusEffect: 9,
};

/**
 * 인원별 권장 구성입니다. Dart `MafiaComposition.recommended`와 같아야 합니다.
 *
 * 값은 `역할 id → 인원수`이고 합계는 인원과 같습니다.
 */
export const MAFIA_COMPOSITION: Record<number, Record<string, number>> = {
  4: {mafia: 1, police: 1, citizen: 2},
  5: {mafia: 1, police: 1, doctor: 1, citizen: 2},
  6: {mafia: 1, police: 1, doctor: 1, soldier: 1, citizen: 2},
  7: {mafia: 2, police: 1, doctor: 1, soldier: 1, citizen: 2},
  8: {mafia: 2, police: 1, doctor: 1, soldier: 1, politician: 1, citizen: 2},
  9: {
    mafia: 2, spy: 1, police: 1, doctor: 1, soldier: 1, reporter: 1,
    citizen: 2,
  },
  10: {
    mafia: 2, spy: 1, police: 1, doctor: 1, soldier: 1, reporter: 1,
    detective: 1, citizen: 2,
  },
  11: {
    mafia: 2, spy: 1, madam: 1, police: 1, doctor: 1, soldier: 1, reporter: 1,
    detective: 1, politician: 1, citizen: 1,
  },
  12: {
    mafia: 2, spy: 1, madam: 1, police: 1, doctor: 1, soldier: 1, reporter: 1,
    detective: 1, politician: 1, gangster: 1, jester: 1,
  },
};

export const MAFIA_MIN_PLAYERS = 4;
export const MAFIA_MAX_PLAYERS = 12;

/** 역할을 찾습니다. 모르는 id면 null입니다. */
export function mafiaRole(roleId: string): MafiaServerRole | null {
  return MAFIA_ROLES[roleId] ?? null;
}

/** 밤에 대상을 골라야 하는 역할인지입니다. */
export function actsAtNight(roleId: string): boolean {
  const role = mafiaRole(roleId);
  return role !== null && role.nightAction !== "none";
}

/**
 * 밤의 **앞 구간**(차단)에 움직이는 역할인지입니다.
 *
 * 능력을 막는 역할만 먼저 움직입니다. 막힌 사람은 능력이 무효라, 이 판정이
 * 끝나야 뒤 역할들의 행동 가능 여부가 정해집니다.
 */
export function actsInBlockStage(roleId: string): boolean {
  return mafiaRole(roleId)?.blocksAbility === true;
}

/**
 * 배분에 쓸 구성입니다.
 *
 * 지원 인원이 아니거나, 구성에 **아직 구현되지 않은 역할**이 섞여 있으면
 * null입니다. 정의만 있는 역할이 배분되어 게임이 멈추는 일을 막습니다.
 */
export function mafiaCompositionFor(
  playerCount: number,
): Record<string, number> | null {
  const composition = MAFIA_COMPOSITION[playerCount];
  if (!composition) return null;
  for (const roleId of Object.keys(composition)) {
    if (!mafiaRole(roleId)?.isImplemented) return null;
  }
  return composition;
}
