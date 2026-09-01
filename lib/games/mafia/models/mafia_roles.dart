import 'package:project00/core/assets/game_image.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================마피아 역할 카탈로그==============================
// 전달받은 역할 명세 전체를 데이터로 등록합니다. 정의를 먼저 갖춰 두면 나중에
// 역할을 켤 때 화면과 서버를 다시 설계하지 않아도 됩니다.
//
// [MafiaRole.isImplemented]가 **동작 구현 여부**입니다. false인 역할은 정의만
// 있어서 배분에 쓰면 게임이 멈춥니다. 배분은 [implemented]만 사용합니다.
//
// ## 새 역할을 켜는 순서
// 1. `assets/games/mafia/images/cards/role_<id>.png` 추가 →
//    `dart run build_runner build` → 여기서 `card:` 연결
// 2. 서버(`functions/src/mafia/`)에 그 역할의 밤/낮 처리 추가
// 3. `isImplemented: true`로 바꾸고 `mafia_composition.dart` 구성표에 넣기

//=======================진영 색==============================
// 시민 파란색 · 마피아 빨간색 · 중립 노란색. 역할 이름을 강조할 때 씁니다.
// 밤 화면 강조색은 이것이 아니라 `MafiaNightAction.accentColor`입니다.
// 진영 색은 [MafiaFactionColors] 한곳에만 있습니다. 여기서 다시 정의하면
// 값이 갈릴 수 있어 그대로 가져다 씁니다.
const _citizenColor = MafiaFactionColors.citizen;
const _mafiaColor = MafiaFactionColors.mafia;
const _neutralColor = MafiaFactionColors.neutral;

abstract final class MafiaRoles {
  // ======================================================================
  // 시민 진영
  // ======================================================================

  static final citizen = MafiaRole(
    id: 'citizen',
    displayName: '시민',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.basic,
    abilityTiming: MafiaAbilityTiming.none,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleCitizen.game,
    icon: Assets.games.mafia.images.roles.roleIconCitizen.game,
    isImplemented: true,
  );

  static final police = MafiaRole(
    id: 'police',
    nightPromptVerb: '조사',
    displayName: '경찰',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.basic,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.investigate,
    nightPhase: MafiaNightPhase.investigate,
    nightOrder: 11,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.rolePolice.game,
    icon: Assets.games.mafia.images.roles.roleIconPolice.game,
    isImplemented: true,
  );

  static final doctor = MafiaRole(
    id: 'doctor',
    nightPromptVerb: '치료',
    displayName: '의사',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.basic,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.protect,
    nightPhase: MafiaNightPhase.protect,
    nightOrder: 9,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleDoctor.game,
    icon: Assets.games.mafia.images.roles.roleIconDoctor.game,
    isImplemented: true,
  );

  static final bodyguard = MafiaRole(
    id: 'bodyguard',
    // 시안 미확정입니다. 의사는 '치료'로 확정됐습니다.
    nightPromptVerb: '보호',
    displayName: '경호원',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.protect,
    nightPhase: MafiaNightPhase.protect,
    nightOrder: 9,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleBodyguard.game,
    // 의사와 같은 보호로 동작하므로 서버 엔진이 그대로 처리합니다.
    // ⚠️ 고전 규칙(대상 대신 죽음)은 아직 넣지 않았습니다.
    isImplemented: true,
  );

  /// 밤 공격을 한 번 스스로 막아냅니다(마피아42 군인).
  ///
  /// 의사의 보호와 다릅니다. 보호는 남이 걸어 주지만 군인은 공격받는 순간
  /// **자동으로** 방어를 소모합니다. 두 번째 공격에는 죽습니다.
  static final soldier = MafiaRole(
    id: 'soldier',
    displayName: '군인',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.passive,
    accentColor: _citizenColor,
    description:
        '밤에 공격을 받아도\n'
        '한 번은 스스로 막아냅니다.\n'
        '두 번째 공격에는 쓰러집니다.',
    defenseCharges: 1,
    card: Assets.games.mafia.images.cards.roleSoldier.game,
    icon: Assets.games.mafia.images.roles.roleIconSoldier.game,
    isImplemented: true,
  );

  /// 낮 투표에서 2표를 가집니다(마피아42 정치인).
  ///
  /// ⚠️ 개표 결과(`voteResult.tally`)는 가중치가 반영된 수라서, 2표가 몰린
  /// 자리를 보면 정치인이 어디에 찍었는지 유추할 수 있습니다. 규칙상 감수하는
  /// 노출입니다.
  static final politician = MafiaRole(
    id: 'politician',
    displayName: '정치인',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.day,
    accentColor: _citizenColor,
    description:
        '낮 투표에서 2표를 행사합니다.\n'
        '밤에는 아무 일도 하지 않습니다.',
    voteWeight: 2,
    card: Assets.games.mafia.images.cards.rolePolitician.game,
    icon: Assets.games.mafia.images.roles.roleIconPolitician.game,
    isImplemented: true,
  );

  /// 밤에 **사망자** 한 명의 직업을 확인합니다(마피아42 영매).
  ///
  /// 경찰과 다릅니다. 경찰은 살아 있는 사람의 진영만 보고, 영매는 죽은 사람의
  /// **직업 이름**을 봅니다. 그래서 대상 범위가 [MafiaNightTargetScope.dead]입니다.
  static final medium = MafiaRole(
    id: 'medium',
    nightPromptVerb: '교신',
    displayName: '영매',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.investigateRole,
    nightPhase: MafiaNightPhase.investigate,
    nightOrder: 14,
    nightTargetScope: MafiaNightTargetScope.dead,
    accentColor: _citizenColor,
    description:
        '밤마다 죽은 사람 한 명과 교신해\n'
        '그 사람의 직업을 알아냅니다.',
    card: Assets.games.mafia.images.cards.roleMedium.game,
    icon: Assets.games.mafia.images.roles.roleIconMedium.game,
    isImplemented: true,
  );

  /// 밤에 지목한 사람의 **다음 낮 투표권**을 막습니다(마피아42 건달).
  ///
  /// 확정(2026-08): 건달은 밤 능력을 막지 않습니다. 협박당한 사람은 밤에는
  /// 평소대로 움직이고, **낮에 표를 낼 수 없습니다.** 입력은 마담과 달리
  /// 일반 행동 구간에서 받지만, 실제 판정은 마담 다음인 4번으로 합니다.
  static final gangster = MafiaRole(
    id: 'gangster',
    nightPromptVerb: '협박',
    displayName: '건달',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.roleblock,
    nightPhase: MafiaNightPhase.statusEffect,
    nightOrder: 4,
    accentColor: _citizenColor,
    description:
        '밤마다 한 명을 협박해\n'
        '다음 낮의 투표권을 막습니다.',
    blocksTargetVote: true,
    card: Assets.games.mafia.images.cards.roleGangster.game,
    icon: Assets.games.mafia.images.roles.roleIconGangster.game,
    isImplemented: true,
  );

  static final vigilante = MafiaRole(
    id: 'vigilante',
    // 확정(2026-08): 자경단원의 밤 문구는 '제거'가 아니라 '처형'입니다.
    nightPromptVerb: '처형',
    displayName: '자경단원',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.eliminate,
    nightPhase: MafiaNightPhase.independentAttack,
    nightOrder: 5,
    accentColor: _citizenColor,
    description:
        '밤에 한 명을 처형합니다.\n'
        '능력은 게임당 1번만 쓸 수 있고,\n'
        '시민을 공격하면 자신도 죽습니다.',
    card: Assets.games.mafia.images.cards.roleVigilante.game,
    // 마피아42 기준: 게임당 1회. 시민팀을 쏘면 오발로 자신도 함께 죽습니다.
    maxUses: 1,
    selfDestructsOnAllyKill: true,
    icon: Assets.games.mafia.images.roles.roleIconVigilante.game,
    isImplemented: true,
  );

  static final hunter = MafiaRole(
    id: 'hunter',
    displayName: '사냥꾼',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.onDeath,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleHunter.game,
  );

  static final mayor = MafiaRole(
    id: 'mayor',
    displayName: '시장',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.day,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleMayor.game,
  );

  static final sheriff = MafiaRole(
    id: 'sheriff',
    displayName: '보안관',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.day,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleSheriff.game,
  );

  static final mason = MafiaRole(
    id: 'mason',
    displayName: '메이슨',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.gameStart,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleMason.game,
    knowsAllies: true,
  );

  static final watcher = MafiaRole(
    id: 'watcher',
    nightPromptVerb: '감시',
    displayName: '감시자',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.watch,
    nightPhase: MafiaNightPhase.investigate,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleWatcher.game,
  );

  static final detective = MafiaRole(
    id: 'detective',
    nightPromptVerb: '추적',
    // 시안 카드는 '탐정', 확정 명세는 '사립탐정'입니다. 능력(대상이 누구를
    // 찾아갔는지 조사)은 같은 역할이라 이름만 명세를 따릅니다.
    displayName: '사립탐정',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.track,
    nightPhase: MafiaNightPhase.investigate,
    nightOrder: 12,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleDetective.game,
    icon: Assets.games.mafia.images.roles.roleIconDetective.game,
    isImplemented: true,
  );

  /// 실제로는 시민이지만 조사에서 마피아로 나옵니다.
  static final miller = MafiaRole(
    id: 'miller',
    displayName: '밀러',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.passive,
    investigationAppearance: MafiaInvestigationAppearance.asMafia,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleMiller.game,
  );

  static final witness = MafiaRole(
    id: 'witness',
    displayName: '증인',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.gameStart,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleWitness.game,
  );

  static final roleblocker = MafiaRole(
    id: 'roleblocker',
    nightPromptVerb: '차단',
    displayName: '역할 차단자',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.roleblock,
    nightPhase: MafiaNightPhase.roleblock,
    blocksAbility: true,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleRoleblocker.game,
  );

  /// 밤에 지목한 사람의 신분을 **다음 아침에 전체 공개**합니다.
  ///
  /// 경찰과 다릅니다. 경찰은 결과를 혼자 보지만 기자는 모두가 봅니다. 그래서
  /// 결과가 `private`이 아니라 `public.revealedRoles`로 갑니다. 공개는 아침
  /// 발표에 맞춰야 하므로 해결 단계가 [MafiaNightPhase.statusEffect]입니다.
  static final reporter = MafiaRole(
    id: 'reporter',
    nightPromptVerb: '취재',
    displayName: '기자',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.expose,
    nightPhase: MafiaNightPhase.statusEffect,
    nightOrder: 13,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleReporter.game,
    icon: Assets.games.mafia.images.roles.roleIconReporter.game,
    isImplemented: true,
  );

  // ======================================================================
  // 마피아 진영
  // ======================================================================

  static final mafia = MafiaRole(
    id: 'mafia',
    nightPromptVerb: '제거',
    displayName: '마피아',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.basic,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.eliminate,
    nightPhase: MafiaNightPhase.mafiaAttack,
    nightOrder: 6,
    accentColor: _mafiaColor,
    description:
        '밤마다 한 명을 지목해 제거하세요.\n'
        '정체를 숨기고 시민들 사이에 숨어\n'
        '끝까지 살아남아야 합니다.',
    card: Assets.games.mafia.images.cards.roleMafia.game,
    knowsAllies: true,
    icon: Assets.games.mafia.images.roles.roleIconMafia.game,
    isImplemented: true,
  );

  /// 조사에서 시민으로 보이는 마피아 우두머리입니다.
  static final mafiaBoss = MafiaRole(
    id: 'mafia_boss',
    nightPromptVerb: '제거',
    displayName: '마피아 보스',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.eliminate,
    nightPhase: MafiaNightPhase.mafiaAttack,
    nightOrder: 6,
    investigationAppearance: MafiaInvestigationAppearance.asCitizen,
    accentColor: _mafiaColor,
    card: Assets.games.mafia.images.cards.roleMafiaBoss.game,
    knowsAllies: true,
    // 마피아와 같은 제거 + 조사에 시민으로 보이기. 둘 다 데이터로 처리되므로
    // 서버 엔진을 고치지 않고 동작합니다.
    isImplemented: true,
  );

  /// 마피아를 알고 있지만 조사에는 시민으로 보입니다(마피아42 스파이).
  ///
  /// 밤에 하는 일이 없어 **밤 행동 인원수에도 잡히지 않습니다.** 그래서 조사만
  /// 피하면 끝까지 시민처럼 보입니다.
  static final spy = MafiaRole(
    id: 'spy',
    displayName: '스파이',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.passive,
    nightOrder: 10,
    investigationAppearance: MafiaInvestigationAppearance.asCitizen,
    accentColor: _mafiaColor,
    description:
        '마피아가 누구인지 알고 있습니다.\n'
        '조사를 받아도 시민으로 보입니다.\n'
        '밤에는 아무 일도 하지 않습니다.',
    knowsAllies: true,
    card: Assets.games.mafia.images.cards.roleSpy.game,
    icon: Assets.games.mafia.images.roles.roleIconSpy.game,
    isImplemented: true,
  );

  /// 마피아팀이지만 **혼자** 공격합니다(마피아42 짐승인간).
  ///
  /// 마피아와 다릅니다. 마피아는 다수결로 한 명만 죽이지만 짐승인간은 자기
  /// 대상을 따로 죽입니다(해결 단계가 [MafiaNightPhase.independentAttack]).
  /// 동료를 모르고 동료도 그를 모릅니다([knowsAllies]가 false).
  static final beast = MafiaRole(
    id: 'beast',
    nightPromptVerb: '사냥',
    displayName: '짐승인간',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.eliminate,
    nightPhase: MafiaNightPhase.independentAttack,
    nightOrder: 7,
    accentColor: _mafiaColor,
    description:
        '밤마다 혼자 한 명을 사냥합니다.\n'
        '마피아와 같은 편이지만\n'
        '서로가 누구인지 모릅니다.',
    card: Assets.games.mafia.images.cards.roleBeast.game,
    icon: Assets.games.mafia.images.roles.roleIconBeast.game,
    isImplemented: true,
  );

  /// 밤에 지목한 사람의 능력과 **다음 낮 투표권**까지 막습니다(마피아42 마담).
  static final madam = MafiaRole(
    id: 'madam',
    nightPromptVerb: '유혹',
    displayName: '마담',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.roleblock,
    nightPhase: MafiaNightPhase.roleblock,
    nightOrder: 3,
    accentColor: _mafiaColor,
    description:
        '밤마다 한 명을 유혹해\n'
        '능력과 다음 낮의 투표권을\n'
        '함께 막습니다.',
    blocksTargetVote: true,
    blocksAbility: true,
    knowsAllies: true,
    card: Assets.games.mafia.images.cards.roleMadam.game,
    icon: Assets.games.mafia.images.roles.roleIconMadam.game,
    isImplemented: true,
  );

  /// 밤에 **사망자**의 직업을 훔쳐 자신이 그 직업이 됩니다(마피아42 도둑).
  ///
  /// 훔친 직업의 **진영까지** 따라갑니다. 시민 직업을 훔치면 그 순간부터 시민팀
  /// 승리 조건으로 판정합니다.
  static final thief = MafiaRole(
    id: 'thief',
    nightPromptVerb: '절도',
    displayName: '도둑',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.steal,
    nightPhase: MafiaNightPhase.statusEffect,
    nightOrder: 1,
    nightTargetScope: MafiaNightTargetScope.dead,
    accentColor: _mafiaColor,
    description:
        '밤에 죽은 사람 한 명의 직업을\n'
        '훔쳐 그 직업이 됩니다.\n'
        '진영도 함께 바뀝니다.',
    knowsAllies: true,
    card: Assets.games.mafia.images.cards.roleThief.game,
    icon: Assets.games.mafia.images.roles.roleIconThief.game,
    isImplemented: true,
  );

  static final member = MafiaRole(
    id: 'member',
    nightPromptVerb: '제거',
    displayName: '조직원',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.eliminate,
    nightPhase: MafiaNightPhase.mafiaAttack,
    accentColor: _mafiaColor,
    card: Assets.games.mafia.images.cards.roleMember.game,
    knowsAllies: true,
  );

  /// 시민으로 보이지만 마피아 승리를 돕습니다.
  static final traitor = MafiaRole(
    id: 'traitor',
    displayName: '배신자',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.passive,
    investigationAppearance: MafiaInvestigationAppearance.asCitizen,
    accentColor: _mafiaColor,
    card: Assets.games.mafia.images.cards.roleTraitor.game,
  );

  static final framer = MafiaRole(
    id: 'framer',
    nightPromptVerb: '누명',
    displayName: '프레이머',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.frame,
    nightPhase: MafiaNightPhase.frame,
    accentColor: _mafiaColor,
    card: Assets.games.mafia.images.cards.roleFramer.game,
    knowsAllies: true,
  );

  static final silencer = MafiaRole(
    id: 'silencer',
    nightPromptVerb: '침묵',
    displayName: '침묵술사',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.silence,
    nightPhase: MafiaNightPhase.statusEffect,
    accentColor: _mafiaColor,
    card: Assets.games.mafia.images.cards.roleSilencer.game,
    knowsAllies: true,
  );

  static final information = MafiaRole(
    id: 'information',
    nightPromptVerb: '조사',
    displayName: '정보원',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.investigateRole,
    nightPhase: MafiaNightPhase.investigate,
    accentColor: _mafiaColor,
    card: Assets.games.mafia.images.cards.roleInformation.game,
    knowsAllies: true,
  );

  static final mafiaRoleblocker = MafiaRole(
    id: 'mafia_roleblocker',
    nightPromptVerb: '차단',
    displayName: '마피아 역할 차단자',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.roleblock,
    nightPhase: MafiaNightPhase.roleblock,
    blocksAbility: true,
    accentColor: _mafiaColor,
    card: Assets.games.mafia.images.cards.roleMafiaRoleblocker.game,
    knowsAllies: true,
  );

  static final disguiser = MafiaRole(
    id: 'disguiser',
    nightPromptVerb: '교란',
    displayName: '변장자',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.frame,
    nightPhase: MafiaNightPhase.frame,
    accentColor: _mafiaColor,
    card: Assets.games.mafia.images.cards.roleDisguiser.game,
    knowsAllies: true,
  );

  static final recruiter = MafiaRole(
    id: 'recruiter',
    nightPromptVerb: '전향',
    displayName: '모집자',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.specialMode,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.convert,
    nightPhase: MafiaNightPhase.convert,
    accentColor: _mafiaColor,
    card: Assets.games.mafia.images.cards.roleRecruiter.game,
    knowsAllies: true,
  );

  static final yakuza = MafiaRole(
    id: 'yakuza',
    nightPromptVerb: '전향',
    displayName: '야쿠자',
    faction: MafiaFaction.mafia,
    tier: MafiaRoleTier.specialMode,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.convert,
    nightPhase: MafiaNightPhase.convert,
    accentColor: _mafiaColor,
    card: Assets.games.mafia.images.cards.roleYakuza.game,
    knowsAllies: true,
  );

  // ======================================================================
  // 중립 진영 — 개별 승리 조건
  // ======================================================================

  static final serialKiller = MafiaRole(
    id: 'serial_killer',
    nightPromptVerb: '제거',
    displayName: '연쇄살인마',
    faction: MafiaFaction.neutral,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.eliminate,
    nightPhase: MafiaNightPhase.independentAttack,
    nightOrder: 8,
    winCondition: MafiaWinCondition.lastStanding,
    accentColor: _neutralColor,
    card: Assets.games.mafia.images.cards.roleSerialKiller.game,
    description:
        '밤마다 혼자 한 명을 제거합니다.\n'
        '마지막까지 남으면 혼자 승리합니다.',
    icon: Assets.games.mafia.images.roles.roleIconSerialKiller.game,
    isImplemented: true,
  );

  static final arsonist = MafiaRole(
    id: 'arsonist',
    nightPromptVerb: '표식',
    displayName: '방화범',
    faction: MafiaFaction.neutral,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.mark,
    nightPhase: MafiaNightPhase.independentAttack,
    winCondition: MafiaWinCondition.lastStanding,
    accentColor: _neutralColor,
    card: Assets.games.mafia.images.cards.roleArsonist.game,
  );

  /// 낮 투표로 자신이 처형되면 승리합니다.
  static final jester = MafiaRole(
    id: 'jester',
    displayName: '광대',
    faction: MafiaFaction.neutral,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.passive,
    winCondition: MafiaWinCondition.lynchedSelf,
    accentColor: _neutralColor,
    card: Assets.games.mafia.images.cards.roleJester.game,
    description:
        '낮 투표로 처형되면\n'
        '그 자리에서 혼자 승리합니다.',
    icon: Assets.games.mafia.images.roles.roleIconJester.game,
    isImplemented: true,
  );

  /// 지정된 목표가 낮 투표로 처형되면 승리합니다.
  static final executioner = MafiaRole(
    id: 'executioner',
    displayName: '처형자',
    faction: MafiaFaction.neutral,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.gameStart,
    winCondition: MafiaWinCondition.lynchTarget,
    accentColor: _neutralColor,
    card: Assets.games.mafia.images.cards.roleExecutioner.game,
    description:
        '지목된 목표가 낮 투표로 처형되면\n'
        '그 자리에서 혼자 승리합니다.',
    icon: Assets.games.mafia.images.roles.roleIconExecutioner.game,
    isImplemented: true,
  );

  static final survivor = MafiaRole(
    id: 'survivor',
    nightPromptVerb: '보호',
    displayName: '생존자',
    faction: MafiaFaction.neutral,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.protect,
    nightPhase: MafiaNightPhase.protect,
    winCondition: MafiaWinCondition.surviveToEnd,
    accentColor: _neutralColor,
    card: Assets.games.mafia.images.cards.roleSurvivor.game,
    maxUses: 2,
  );

  static final cultLeader = MafiaRole(
    id: 'cult_leader',
    nightPromptVerb: '전향',
    displayName: '교주',
    faction: MafiaFaction.neutral,
    tier: MafiaRoleTier.specialMode,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.convert,
    nightPhase: MafiaNightPhase.convert,
    nightOrder: 2,
    winCondition: MafiaWinCondition.factionDominance,
    accentColor: _neutralColor,
    card: Assets.games.mafia.images.cards.roleCultLeader.game,
    description:
        '밤마다 한 명을 광신도로 만듭니다.\n'
        '살아남은 사람이 모두 교단이면\n'
        '교단이 승리합니다.',
    // 전향에 성공하면 대상은 광신도가 됩니다.
    convertsTargetTo: 'cultist',
    knowsAllies: true,
    icon: Assets.games.mafia.images.roles.roleIconCultLeader.game,
    isImplemented: true,
  );

  /// 교주가 전향시킨 사람입니다. **배분표로는 나오지 않습니다.**
  ///
  /// 게임 중 [cultLeader]의 전향으로만 생깁니다. 그래서 인원별 구성표에는 절대
  /// 넣지 않지만, 전향 결과를 화면이 그릴 수 있어야 하므로 구현 역할입니다.
  static final cultist = MafiaRole(
    id: 'cultist',
    displayName: '광신도',
    faction: MafiaFaction.neutral,
    tier: MafiaRoleTier.specialMode,
    abilityTiming: MafiaAbilityTiming.passive,
    winCondition: MafiaWinCondition.factionDominance,
    accentColor: _neutralColor,
    card: Assets.games.mafia.images.cards.roleCultist.game,
    description:
        '교주의 부름을 받았습니다.\n'
        '살아남은 사람이 모두 교단이면\n'
        '교단이 승리합니다.',
    knowsAllies: true,
    isImplemented: true,
  );

  static final piedPiper = MafiaRole(
    id: 'pied_piper',
    nightPromptVerb: '매혹',
    displayName: '피리 부는 사나이',
    faction: MafiaFaction.neutral,
    tier: MafiaRoleTier.specialMode,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.mark,
    nightPhase: MafiaNightPhase.statusEffect,
    winCondition: MafiaWinCondition.factionDominance,
    accentColor: _neutralColor,
    card: Assets.games.mafia.images.cards.rolePiedPiper.game,
  );

  static final vampire = MafiaRole(
    id: 'vampire',
    nightPromptVerb: '전향',
    displayName: '뱀파이어',
    faction: MafiaFaction.neutral,
    tier: MafiaRoleTier.specialMode,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.convert,
    nightPhase: MafiaNightPhase.convert,
    winCondition: MafiaWinCondition.factionDominance,
    accentColor: _neutralColor,
    card: Assets.games.mafia.images.cards.roleVampire.game,
  );

  // ======================================================================

  /// 정의된 모든 역할입니다. 새 역할을 추가하면 여기에도 등록합니다.
  static final all = <MafiaRole>[
    // 시민 진영
    citizen, police, doctor, bodyguard, soldier, politician, medium, gangster,
    vigilante, hunter, mayor, sheriff, mason, watcher, detective, miller,
    witness, roleblocker, reporter,
    // 마피아 진영
    mafia, mafiaBoss, spy, beast, madam, thief, member, traitor, framer,
    silencer, information, mafiaRoleblocker, disguiser, recruiter, yakuza,
    // 중립 진영
    serialKiller, arsonist, jester, executioner, survivor, cultLeader,
    cultist, piedPiper, vampire,
  ];

  /// 서버 처리까지 완성돼 실제로 배분해도 되는 역할입니다.
  static List<MafiaRole> get implemented =>
      all.where((role) => role.isImplemented).toList(growable: false);

  /// 전향([MafiaRole.convertsTargetTo])으로만 생기는 역할의 id입니다.
  ///
  /// 광신도가 여기 들어옵니다. 교주 없이 광신도로 시작하면 교단 승리 조건이
  /// 성립하지 않으므로 배분 대상이 아닙니다.
  static Set<String> get convertOnlyIds => {
    for (final role in all)
      if (role.convertsTargetTo != null) role.convertsTargetTo!,
  };

  /// 게임 **시작 시 배분해도 되는** 역할입니다.
  ///
  /// [implemented]에서 전향으로만 생기는 역할을 뺀 목록입니다. 구성표와 연습장
  /// 역할 선택이 이 목록을 씁니다.
  static List<MafiaRole> get distributable {
    final convertOnly = convertOnlyIds;
    return implemented
        .where((role) => !convertOnly.contains(role.id))
        .toList(growable: false);
  }

  /// 서버가 보낸 역할 id를 정의로 바꿉니다.
  ///
  /// 이 빌드가 모르는 id(나중에 추가된 역할)는 null입니다. 화면은 null을
  /// '역할 미확인'으로 다루고 게임을 강제로 끝내지 않습니다.
  static MafiaRole? find(String? id) {
    if (id == null || id.isEmpty) return null;
    for (final role in all) {
      if (role.id == id) return role;
    }
    return null;
  }

  /// 등급별 역할 풀입니다. 게임 모드가 이 값으로 후보를 고릅니다.
  static List<MafiaRole> byTier(MafiaRoleTier tier) =>
      all.where((role) => role.tier == tier).toList(growable: false);
}
