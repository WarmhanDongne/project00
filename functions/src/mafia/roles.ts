/* eslint-disable max-len, valid-jsdoc, require-jsdoc */

import {
  MafiaFactionId,
  MafiaInvestigationAppearanceId,
  MafiaNightActionId,
  MafiaNightPhaseId,
} from "./types.js";

// =========================================================================
// 역할 카탈로그 (서버용)
//
// Dart `lib/games/mafia/models/mafia_roles.dart`의 **거울**입니다. 서버는 Dart를
// 읽을 수 없어 같은 표를 두 곳에 둡니다. 두 표가 갈리면 규칙이 조용히 깨지므로
// `functions/test/mafia-role-parity.test.mjs`가 Dart 파일을 파싱해 대조합니다.
//
// 여기에는 **서버가 판정에 쓰는 값만** 둡니다. 화면 문구·색·설명은 Dart에만
// 있습니다. 역할을 추가할 때는 배분표(`MAFIA_COMPOSITION`)에 등장하는 역할만
// 여기에 추가하면 됩니다.
//
// 이 파일은 역할 이름으로 분기하지 않습니다. 아래 값으로만 판정하므로 새 역할은
// 표에 한 줄 추가하면 밤 해결·조사·승패가 그대로 동작합니다.
// =========================================================================

export interface MafiaServerRole {
  id: string;
  faction: MafiaFactionId;
  nightAction: MafiaNightActionId;
  /** 밤 행동이 없으면 null입니다. */
  nightPhase: MafiaNightPhaseId | null;
  investigationAppearance: MafiaInvestigationAppearanceId;
  /** 같은 편을 서로 알고 시작하는지입니다. */
  knowsAllies: boolean;
  /** 이 빌드가 동작까지 구현한 역할인지입니다. 배분은 이 값이 true인 것만 씁니다. */
  isImplemented: boolean;
}

/** 배분에 쓰이는 역할입니다. Dart 카탈로그와 값이 같아야 합니다. */
export const MAFIA_ROLES: Record<string, MafiaServerRole> = {
  citizen: {
    id: "citizen",
    faction: "citizen",
    nightAction: "none",
    nightPhase: null,
    investigationAppearance: "actual",
    knowsAllies: false,
    isImplemented: true,
  },
  police: {
    id: "police",
    faction: "citizen",
    nightAction: "investigate",
    nightPhase: "investigate",
    investigationAppearance: "actual",
    knowsAllies: false,
    isImplemented: true,
  },
  doctor: {
    id: "doctor",
    faction: "citizen",
    nightAction: "protect",
    nightPhase: "protect",
    investigationAppearance: "actual",
    knowsAllies: false,
    isImplemented: true,
  },
  // 경호원은 지금 **의사와 같은 보호**로 동작합니다. 고전 규칙(대상 대신 죽음)이
  // 필요하면 데이터에 표시를 추가하고 해결 엔진에 한 갈래를 더해야 합니다.
  bodyguard: {
    id: "bodyguard",
    faction: "citizen",
    nightAction: "protect",
    nightPhase: "protect",
    investigationAppearance: "actual",
    knowsAllies: false,
    isImplemented: true,
  },
  // 밤에 지목한 사람의 신분을 다음 아침에 **전체 공개**합니다.
  reporter: {
    id: "reporter",
    faction: "citizen",
    nightAction: "expose",
    nightPhase: "statusEffect",
    investigationAppearance: "actual",
    knowsAllies: false,
    isImplemented: true,
  },
  // 대상이 누구에게 능력을 썼는지 조사합니다(시안 카드 이름은 '탐정').
  tracker: {
    id: "tracker",
    faction: "citizen",
    nightAction: "track",
    nightPhase: "investigate",
    investigationAppearance: "actual",
    knowsAllies: false,
    isImplemented: true,
  },
  mafia: {
    id: "mafia",
    faction: "mafia",
    nightAction: "eliminate",
    nightPhase: "mafiaAttack",
    investigationAppearance: "actual",
    knowsAllies: true,
    isImplemented: true,
  },
  // 마피아 보스는 마피아와 같지만 **조사에서 시민으로 보입니다.**
  godfather: {
    id: "godfather",
    faction: "mafia",
    nightAction: "eliminate",
    nightPhase: "mafiaAttack",
    investigationAppearance: "asCitizen",
    knowsAllies: true,
    isImplemented: true,
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
  6: {mafia: 1, police: 1, doctor: 1, citizen: 3},
  7: {mafia: 2, police: 1, doctor: 1, citizen: 3},
  8: {mafia: 2, police: 1, doctor: 1, citizen: 4},
  9: {mafia: 2, police: 1, doctor: 1, citizen: 5},
  10: {godfather: 1, mafia: 2, police: 1, doctor: 1, citizen: 5},
  11: {godfather: 1, mafia: 2, police: 1, doctor: 1, bodyguard: 1, citizen: 5},
  12: {godfather: 1, mafia: 2, police: 1, doctor: 1, bodyguard: 1, citizen: 6},
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
