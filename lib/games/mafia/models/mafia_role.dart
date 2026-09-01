import 'package:flutter/widgets.dart';
import 'package:project00/core/assets/game_image.dart';

//=======================마피아 역할 모델==============================
// 역할이 40개 이상으로 늘어도 화면·서버를 고치지 않도록, 역할을 코드 분기가
// 아니라 **데이터**로 정의합니다. 실제 역할 목록은 `mafia_roles.dart`,
// 인원별 구성과 밤 해결 순서는 `mafia_composition.dart`에 있습니다.
//
// 화면은 역할 이름(`id == 'mafia'`)으로 분기하지 마세요. 아래 축으로만
// 분기하면 새 역할이 자동으로 동작합니다:
//   - [MafiaRole.nightAction] : 밤에 무엇을 하는가 (대상 선택 UI 결정)
//   - [MafiaRole.nightOrder]  : 밤 결과를 몇 번째로 판정하는가
//   - [MafiaRole.faction]     : 어느 진영인가 (색·승패)
//   - [MafiaRole.abilityTiming] : 언제 발동하는가

/// 진영 색입니다. 시민 파랑 · 마피아 빨강 · 중립 노랑.
///
/// 값은 여기 한곳에만 둡니다. 역할 목록이 `const`라서 [MafiaFaction.color]
/// getter를 그대로 쓸 수 없어 상수로 분리했습니다.
abstract final class MafiaFactionColors {
  static const Color citizen = Color(0xFF0D00FF);
  static const Color mafia = Color(0xFFFF0000);
  static const Color neutral = Color(0xFFFFC400);
}

/// 진영입니다. 중립은 역할마다 개별 승리 조건을 가집니다.
enum MafiaFaction {
  citizen,
  mafia,
  neutral;

  bool get isMafia => this == MafiaFaction.mafia;
  bool get isNeutral => this == MafiaFaction.neutral;

  /// 진영 색입니다. 시민 파랑 · 마피아 빨강 · 중립 노랑.
  ///
  /// 역할 이름·결과 문구를 강조할 때 씁니다. 밤 화면의 강조색은 이 값이 아니라
  /// [MafiaNightAction.accentColor]입니다(행동 의미와 진영이 다르기 때문).
  Color get color => switch (this) {
    MafiaFaction.citizen => MafiaFactionColors.citizen,
    MafiaFaction.mafia => MafiaFactionColors.mafia,
    MafiaFaction.neutral => MafiaFactionColors.neutral,
  };

  /// 결과 화면에 쓰는 이름입니다. 예: `마피아 승리`.
  String get displayName => switch (this) {
    MafiaFaction.citizen => '시민',
    MafiaFaction.mafia => '마피아',
    MafiaFaction.neutral => '중립',
  };
}

/// 역할 등급입니다. 게임 생성 시 어떤 역할 풀을 쓸지 고르는 기준입니다.
enum MafiaRoleTier {
  /// 시민·마피아·경찰·의사.
  basic,

  /// 경호원·자경단원·사냥꾼·시장·마피아 보스·프레이머·침묵술사·광대·처형자.
  extended,

  /// 감시자·추적자·밀러·역할 차단자·정보원·변장자·배신자·연쇄살인마·방화범·생존자.
  advanced,

  /// 교주·광신도·피리 부는 사나이·뱀파이어·모집자·야쿠자.
  specialMode,
}

/// 능력이 발동하는 시점입니다.
enum MafiaAbilityTiming {
  /// 능력이 없습니다(시민).
  none,

  /// 밤에 대상을 고릅니다. 해결 순서는 [MafiaRole.nightOrder]가 정합니다.
  night,

  /// 낮에 작동합니다(시장의 가중 투표 등).
  day,

  /// 게임 시작 시 한 번 처리합니다(메이슨 상호 확인, 처형자 목표 지정).
  gameStart,

  /// 자신이 사망하는 순간 발동합니다(사냥꾼).
  onDeath,

  /// 조작 없이 상시 적용됩니다(밀러, 마피아 보스의 조사 면역).
  passive,
}

/// 밤에 대상을 고르는 행동의 종류입니다.
///
/// 밤 화면은 역할 이름이 아니라 이 값으로 UI를 고릅니다. 새 역할이 기존 행동을
/// 쓰면 밤 화면은 **수정 없이 동작합니다**.
enum MafiaNightAction {
  /// 밤에 대상을 고르지 않습니다.
  ///
  /// 옆 사람이 훔쳐봐도 신분이 드러나지 않도록, 행동을 끝낸 특수직도 이 화면과
  /// 똑같은 모습으로 전환합니다.
  none,

  /// 제거 대상을 고릅니다(마피아·자경단원·연쇄살인마).
  eliminate,

  /// 보호 대상을 고릅니다(의사·경호원).
  protect,

  /// 진영을 조사합니다(경찰). 결과를 즉시 보여줍니다.
  investigate,

  /// 역할까지 조사합니다(정보원).
  investigateRole,

  /// 밤 능력을 차단합니다(역할 차단자).
  roleblock,

  /// 조사 결과를 조작합니다(프레이머·변장자).
  frame,

  /// 자기 진영으로 전향시킵니다(교주·뱀파이어·모집자·야쿠자).
  convert,

  /// 다음 낮의 발언을 막습니다(침묵술사).
  silence,

  /// 방문자를 확인합니다(감시자).
  watch,

  /// 대상이 누구에게 능력을 썼는지 확인합니다(추적자).
  track,

  /// 표식을 남깁니다(방화범).
  mark,

  /// 지목한 사람의 신분을 **다음 아침에 전체 공개**합니다(기자).
  ///
  /// 조사([investigate])와 다릅니다. 조사는 본인만 결과를 보고, 이건 살아 있는
  /// 모두가 봅니다. 그래서 결과를 `private`이 아니라 `public.revealedRoles`에
  /// 씁니다.
  expose,

  /// **사망자**의 직업을 훔쳐 자신이 그 직업이 됩니다(도둑).
  ///
  /// 밤이 끝날 때 배분표(`server.roles`)가 바뀌는 유일한 행동입니다. 그래서
  /// 진영까지 바뀌고, 승패 판정도 새 직업을 따릅니다.
  steal;

  /// 밤 화면에서 이 행동을 강조하는 색입니다.
  ///
  /// **진영 색과 다릅니다.** 행동의 의미를 색으로 알려주는 값이라, 시민팀인
  /// 의사도 초록(치료), 경찰은 하늘색(조사)을 씁니다. 시안에서 확정된 값:
  /// 제거 `#FF0000` · 치료 `#00FF3C` · 조사 `#44ABFF`.
  ///
  /// 아직 시안이 없는 행동은 가장 가까운 의미의 색을 임시로 씁니다.
  Color get accentColor => switch (this) {
    MafiaNightAction.none => const Color(0xFFFFFFFF),
    // 목숨을 빼앗는 행동
    MafiaNightAction.eliminate => const Color(0xFFFF0000),
    // 살리는 행동
    MafiaNightAction.protect => const Color(0xFF00FF3C),
    // 정보를 얻는 행동
    MafiaNightAction.investigate ||
    MafiaNightAction.investigateRole ||
    MafiaNightAction.watch ||
    MafiaNightAction.track ||
    MafiaNightAction.expose => const Color(0xFF44ABFF),
    // 방해하는 행동 (시안 미확정)
    MafiaNightAction.roleblock ||
    MafiaNightAction.frame ||
    MafiaNightAction.silence => const Color(0xFFB388FF),
    // 진영을 바꾸는 행동 (시안 미확정)
    MafiaNightAction.convert ||
    MafiaNightAction.steal ||
    MafiaNightAction.mark => const Color(0xFFFFC400),
  };
}

/// 밤에 고를 수 있는 대상의 범위입니다.
///
/// 대부분의 역할은 살아 있는 사람만 고릅니다. 영매·도둑은 **사망자**를 고릅니다.
/// 밤 화면과 서버 검증이 같은 값을 봐야 하므로 데이터로 둡니다.
enum MafiaNightTargetScope {
  /// 살아 있는 사람만 고릅니다.
  alive,

  /// 사망한 사람만 고릅니다(영매·도둑).
  dead,
}

/// 밤 행동의 처리 유형입니다.
///
/// 실제 역할별 판정 순서는 [MafiaRole.nightOrder]가 정합니다.
/// 이 값은 마피아 다수결 공격과 독립 공격처럼 해결 방식을 구분합니다.
enum MafiaNightPhase {
  /// 행동 차단. 차단된 대상의 이후 능력은 무효입니다.
  roleblock,

  /// 보호.
  protect,

  /// 조사 결과 조작.
  frame,

  /// 전향. 진영이 바뀝니다.
  convert,

  /// 조사.
  investigate,

  /// 마피아 다수결 공격.
  mafiaAttack,

  /// 독립 공격(연쇄살인마·자경단원·방화범).
  independentAttack,

  /// 다음 낮이나 아침에 적용되는 상태 효과.
  statusEffect;
}

/// 경찰 조사에 어떻게 보이는지입니다.
enum MafiaInvestigationAppearance {
  /// 실제 진영대로 보입니다.
  actual,

  /// 실제 진영과 무관하게 마피아로 보입니다(밀러).
  asMafia,

  /// 실제 진영과 무관하게 시민으로 보입니다(마피아 보스·배신자).
  asCitizen,
}

/// 승리 조건입니다. 중립은 진영이 아니라 개별 조건으로 판정합니다.
enum MafiaWinCondition {
  /// 소속 진영의 승리 조건을 따릅니다(시민·마피아).
  faction,

  /// 자신이 낮 투표로 처형되면 승리합니다(광대).
  lynchedSelf,

  /// 지정된 목표가 낮 투표로 처형되면 승리합니다(처형자).
  lynchTarget,

  /// 게임이 끝날 때 살아 있으면 승리합니다(생존자).
  surviveToEnd,

  /// 다른 모두를 제거하고 최후에 남으면 승리합니다(연쇄살인마·방화범).
  lastStanding,

  /// 자기 세력이 판을 장악하면 승리합니다(교주·뱀파이어·피리 부는 사나이).
  factionDominance,
}

/// 역할 하나의 정의입니다.
@immutable
class MafiaRole {
  const MafiaRole({
    required this.id,
    required this.displayName,
    required this.faction,
    required this.tier,
    required this.abilityTiming,
    required this.accentColor,
    this.nightAction = MafiaNightAction.none,
    this.nightPhase,
    this.nightOrder,
    this.winCondition = MafiaWinCondition.faction,
    this.investigationAppearance = MafiaInvestigationAppearance.actual,
    this.nightTargetScope = MafiaNightTargetScope.alive,
    this.maxUses,
    this.defenseCharges = 0,
    this.voteWeight = 1,
    this.blocksTargetVote = false,
    this.blocksAbility = false,
    this.selfDestructsOnAllyKill = false,
    this.convertsTargetTo,
    this.nightPromptVerb = '',
    this.knowsAllies = false,
    this.description = '',
    this.card,
    this.squareCard,
    this.icon,
    this.isImplemented = false,
  }) : assert(
         nightAction == MafiaNightAction.none || nightPhase != null,
         '밤에 대상을 고르는 역할은 해결 단계(nightPhase)를 지정해야 합니다.',
       ),
       assert(
         !isImplemented ||
             nightAction == MafiaNightAction.none ||
             nightOrder != null,
         '구현된 밤 역할은 판정 순서(nightOrder)를 지정해야 합니다.',
       );

  /// 서버·클라이언트가 공유하는 식별자입니다. 카드 파일명(`role_<id>.png`)과
  /// 같게 씁니다.
  final String id;

  /// 화면에 보여줄 이름입니다. 예: `마피아`.
  final String displayName;

  final MafiaFaction faction;
  final MafiaRoleTier tier;
  final MafiaAbilityTiming abilityTiming;

  /// 역할 이름을 강조할 **진영 색**입니다.
  /// 시민 파란색 · 마피아 빨간색 · 중립 노란색.
  ///
  /// 밤 화면의 강조색은 이 값이 아니라 [MafiaNightAction.accentColor]를 씁니다.
  /// 행동 의미(치료=초록 등)와 진영이 다르기 때문입니다.
  final Color accentColor;

  final MafiaNightAction nightAction;

  /// 밤 행동의 처리 유형입니다. 밤 행동이 없으면 null입니다.
  final MafiaNightPhase? nightPhase;

  /// 역할별 밤 판정 순서입니다. 작을수록 먼저 처리합니다.
  ///
  /// 수동 행동이 없는 스파이도 정보 확인 위치(10)를 명세하기 위해 값을
  /// 가집니다.
  final int? nightOrder;

  final MafiaWinCondition winCondition;
  final MafiaInvestigationAppearance investigationAppearance;

  /// 밤에 고를 수 있는 대상의 범위입니다. 기본은 살아 있는 사람입니다.
  ///
  /// 영매·도둑만 [MafiaNightTargetScope.dead]입니다. 밤 화면은 이 값으로 명단을
  /// 고르고, 서버도 같은 값으로 검증합니다.
  final MafiaNightTargetScope nightTargetScope;

  /// 게임당 능력 사용 횟수 제한입니다. null이면 제한이 없습니다(자경단원 등).
  final int? maxUses;

  /// 밤 공격을 스스로 막아내는 횟수입니다. 0이면 막지 못합니다(군인 1).
  ///
  /// 의사의 보호와 다릅니다. 보호는 남이 걸어 주는 것이고, 이 값은 대상이 되는
  /// 순간 **자동으로** 소모됩니다. 소모 기록은 서버에만 둡니다.
  final int defenseCharges;

  /// 낮 투표에서 이 사람의 표가 몇 표로 세어지는지입니다(정치인 2).
  final int voteWeight;

  /// 밤에 지목한 대상의 **다음 낮 투표권**을 막는지입니다(마담·건달).
  final bool blocksTargetVote;

  /// 밤에 지목한 대상의 **밤 능력**을 막는지입니다(마담).
  ///
  /// 확정(2026-08): 건달은 능력이 아니라 **투표권만** 막습니다. 그래서
  /// "지목해서 막는다"를 두 값으로 나눴습니다 — 마담은 둘 다, 건달은 투표권만.
  /// 밤 구간은 이 값이 아니라 [nightOrder]로 정합니다.
  final bool blocksAbility;

  /// 같은 편을 제거했을 때 자신도 함께 죽는지입니다(자경단원 오발).
  final bool selfDestructsOnAllyKill;

  /// 전향([MafiaNightAction.convert])에 성공한 대상이 되는 역할 id입니다.
  ///
  /// 교주는 `cultist`(광신도)로 만듭니다. null이면 전향 결과가 정의되지 않은
  /// 역할이라 서버가 아무 일도 하지 않습니다.
  final String? convertsTargetTo;

  /// 밤 화면 안내 문구에서 강조하는 동사입니다. 예: `제거`·`보호`·`조사`.
  ///
  /// 문구는 공용 템플릿 `{동사} 할 대상을 선택하세요`로 만들고, 이 동사만
  /// [accentColor]로 강조합니다. 그래서 새 역할은 이 값만 넣으면 밤 화면이
  /// 그대로 동작합니다.
  final String nightPromptVerb;

  /// 같은 편이 누구인지 서로 알고 시작하는지입니다(마피아·메이슨).
  final bool knowsAllies;

  /// 역할 카드 화면에 표시하는 설명입니다. 비어 있으면 그 영역을 그리지 않습니다.
  final String description;

  /// 역할 카드 앞면입니다. 세로로 긴 카드(286 : 419)입니다.
  ///
  /// 에셋이 아직 없으면 null이고, 화면은 뒷면으로 대신 표시하므로 게임이
  /// 깨지지 않습니다.
  final GameImage? card;

  /// 정사각형 역할 카드입니다. 관전 명단(P8)처럼 정사각형 칸에 쓰입니다.
  ///
  /// 세로 카드를 정사각형 칸에 넣으면 아래 1/3이 잘려 인쇄된 역할 이름이
  /// 사라집니다. 그래서 정사각형 전용 이미지를 따로 받습니다.
  ///
  /// 아직 없으면 null이고, 화면은 [card]를 잘라 쓰거나 뒷면 + 이름으로
  /// 대신 표시합니다.
  final GameImage? squareCard;

  /// 역할을 한눈에 알려 주는 **작은 아이콘**입니다(시안 80 × 80).
  ///
  /// 역할 배치 화면(게임 시작 전 구성 고르기)과 추천 조합 안내에 씁니다.
  /// 카드와 달리 진영 색이 그림에 들어 있어, **고르지 않은 역할은 회색으로**
  /// 바꿔 그립니다.
  ///
  /// 아직 그림이 없는 역할은 null입니다. 화면은 그 자리를 비워 두지 않고
  /// 이름만으로 그립니다.
  final GameImage? icon;

  /// 이 빌드가 **동작까지** 구현한 역할인지입니다.
  ///
  /// 정의만 있고 서버 처리가 없는 역할을 실수로 배분하면 게임이 진행되지 않습니다.
  /// 역할 배분은 이 값이 true인 역할만 사용합니다.
  final bool isImplemented;

  /// 밤에 대상을 골라야 하는 역할인지입니다.
  bool get actsAtNight => nightAction != MafiaNightAction.none;

  /// 진영 승리가 아니라 개별 조건으로 판정하는 역할인지입니다.
  bool get hasIndividualWinCondition =>
      winCondition != MafiaWinCondition.faction;

  /// 밤에 **사망자**를 골라야 하는 역할인지입니다(영매·도둑).
  bool get targetsDead => nightTargetScope == MafiaNightTargetScope.dead;
}
