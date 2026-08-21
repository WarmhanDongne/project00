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
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.rolePolice.game,
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
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleDoctor.game,
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
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleBodyguard.game,
    // 의사와 같은 보호로 동작하므로 서버 엔진이 그대로 처리합니다.
    // ⚠️ 고전 규칙(대상 대신 죽음)은 아직 넣지 않았습니다.
    isImplemented: true,
  );

  static final vigilante = MafiaRole(
    id: 'vigilante',
    nightPromptVerb: '제거',
    displayName: '자경단원',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.extended,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.eliminate,
    nightPhase: MafiaNightPhase.independentAttack,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleVigilante.game,
    // 게임당 사용 횟수 제한은 규칙마다 다릅니다. 우선 1회로 두고 확정 시 조정.
    maxUses: 1,
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
    // 확정 명세는 '추적자'였지만 시안 카드가 '탐정'이라 카드를 따릅니다.
    // 능력(대상이 누구에게 능력을 썼는지 조사)은 같은 역할입니다.
    displayName: '탐정',
    faction: MafiaFaction.citizen,
    tier: MafiaRoleTier.advanced,
    abilityTiming: MafiaAbilityTiming.night,
    nightAction: MafiaNightAction.track,
    nightPhase: MafiaNightPhase.investigate,
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleDetective.game,
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
    accentColor: _citizenColor,
    card: Assets.games.mafia.images.cards.roleReporter.game,
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
    accentColor: _mafiaColor,
    description:
        '밤마다 한 명을 지목해 제거하세요.\n'
        '정체를 숨기고 시민들 사이에 숨어\n'
        '끝까지 살아남아야 합니다.',
    card: Assets.games.mafia.images.cards.roleMafia.game,
    knowsAllies: true,
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
    investigationAppearance: MafiaInvestigationAppearance.asCitizen,
    accentColor: _mafiaColor,
    card: Assets.games.mafia.images.cards.roleMafiaBoss.game,
    knowsAllies: true,
    // 마피아와 같은 제거 + 조사에 시민으로 보이기. 둘 다 데이터로 처리되므로
    // 서버 엔진을 고치지 않고 동작합니다.
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
    winCondition: MafiaWinCondition.lastStanding,
    accentColor: _neutralColor,
    card: Assets.games.mafia.images.cards.roleSerialKiller.game,
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
    winCondition: MafiaWinCondition.factionDominance,
    accentColor: _neutralColor,
    card: Assets.games.mafia.images.cards.roleCultLeader.game,
  );

  static final cultist = MafiaRole(
    id: 'cultist',
    displayName: '광신도',
    faction: MafiaFaction.neutral,
    tier: MafiaRoleTier.specialMode,
    abilityTiming: MafiaAbilityTiming.passive,
    winCondition: MafiaWinCondition.factionDominance,
    accentColor: _neutralColor,
    card: Assets.games.mafia.images.cards.roleCultist.game,
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
    citizen, police, doctor, bodyguard, vigilante, hunter, mayor, sheriff,
    mason, watcher, detective, miller, witness, roleblocker, reporter,
    // 마피아 진영
    mafia, mafiaBoss, member, traitor, framer, silencer, information,
    mafiaRoleblocker, disguiser, recruiter, yakuza,
    // 중립 진영
    serialKiller, arsonist, jester, executioner, survivor, cultLeader,
    cultist, piedPiper, vampire,
  ];

  /// 서버 처리까지 완성돼 실제로 배분해도 되는 역할입니다.
  static List<MafiaRole> get implemented =>
      all.where((role) => role.isImplemented).toList(growable: false);

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
