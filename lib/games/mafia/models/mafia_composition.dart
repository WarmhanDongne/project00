import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';

//=======================인원별 역할 구성과 진행 순서==============================
// 전달받은 명세의 "인원별 가장 추천하는 기본 구성"(4~12인)과 밤/낮 해결 순서를
// 코드로 고정합니다. 서버 배분과 클라이언트 안내가 같은 표를 보게 하려고
// 한곳에 둡니다.

/// 게임 생성 시 고르는 역할 풀입니다.
enum MafiaGameMode {
  /// 시민·마피아·경찰·의사만 사용합니다.
  classic,

  /// 클래식 + 일반 확장 역할 일부.
  extended,

  /// 클래식/확장 + 중립 역할 일부.
  withNeutral,

  /// 정의된 모든 역할을 사용합니다.
  chaos;

  /// 이 모드가 쓸 수 있는 등급입니다.
  List<MafiaRoleTier> get allowedTiers => switch (this) {
    MafiaGameMode.classic => const [MafiaRoleTier.basic],
    MafiaGameMode.extended => const [
      MafiaRoleTier.basic,
      MafiaRoleTier.extended,
    ],
    MafiaGameMode.withNeutral => const [
      MafiaRoleTier.basic,
      MafiaRoleTier.extended,
      MafiaRoleTier.advanced,
    ],
    MafiaGameMode.chaos => const [
      MafiaRoleTier.basic,
      MafiaRoleTier.extended,
      MafiaRoleTier.advanced,
      MafiaRoleTier.specialMode,
    ],
  };
}

abstract final class MafiaComposition {
  /// 지원 인원입니다.
  static const int minPlayers = 4;
  static const int maxPlayers = 12;

  /// 인원별 권장 기본 구성입니다(명세 8항).
  ///
  /// 값은 `역할 id → 인원수`입니다. 합계는 반드시 인원과 같아야 하며,
  /// `mafia_composition_test.dart`가 이를 검증합니다.
  static const Map<int, Map<String, int>> recommended = {
    4: {'mafia': 1, 'police': 1, 'citizen': 2},
    5: {'mafia': 1, 'police': 1, 'doctor': 1, 'citizen': 2},
    6: {'mafia': 1, 'police': 1, 'doctor': 1, 'soldier': 1, 'citizen': 2},
    7: {'mafia': 2, 'police': 1, 'doctor': 1, 'soldier': 1, 'citizen': 2},
    8: {
      'mafia': 2,
      'police': 1,
      'doctor': 1,
      'soldier': 1,
      'politician': 1,
      'citizen': 2,
    },
    9: {
      'mafia': 2,
      'spy': 1,
      'police': 1,
      'doctor': 1,
      'soldier': 1,
      'reporter': 1,
      'citizen': 2,
    },
    10: {
      'mafia': 2,
      'spy': 1,
      'police': 1,
      'doctor': 1,
      'soldier': 1,
      'reporter': 1,
      'detective': 1,
      'citizen': 2,
    },
    11: {
      'mafia': 2,
      'spy': 1,
      'madam': 1,
      'police': 1,
      'doctor': 1,
      'soldier': 1,
      'reporter': 1,
      'detective': 1,
      'politician': 1,
      'citizen': 1,
    },
    12: {
      'mafia': 2,
      'spy': 1,
      'madam': 1,
      'police': 1,
      'doctor': 1,
      'soldier': 1,
      'reporter': 1,
      'detective': 1,
      'politician': 1,
      'gangster': 1,
      'jester': 1,
    },
  };

  /// 배분표에는 없지만 **구현은 끝난** 역할입니다.
  ///
  /// 연습장(`mafia_practice_screen.dart`)에서 직접 골라 시험할 수 있습니다.
  /// 기본 구성에 넣지 않은 이유는 각각 다릅니다.
  ///   - `beast`(짐승인간)·`serial_killer`(연쇄살인마) — 밤 사망자가 둘로 늘어
  ///     기본 구성의 균형이 무너집니다.
  ///   - `thief`(도둑)·`medium`(영매) — 사망자가 나온 뒤에야 능력을 씁니다.
  ///   - `executioner`(처형자)·`cult_leader`(교주) — 개별 승리 조건이 판을
  ///     크게 바꿉니다.
  ///   - `cultist`(광신도) — 전향으로만 생기므로 배분 대상이 아닙니다.
  static const List<String> playableOutsideComposition = [
    'beast',
    'serial_killer',
    'thief',
    'medium',
    'executioner',
    'cult_leader',
    'cultist',
  ];

  /// [playerCount]에 쓸 구성입니다. 지원 인원 밖이면 null입니다.
  static Map<String, int>? recommendedFor(int playerCount) =>
      recommended[playerCount];

  /// 구성에 등장하는 역할 중 **아직 동작이 구현되지 않은** 역할입니다.
  ///
  /// 비어 있지 않으면 그 인원수는 아직 시작할 수 없습니다. 서버가 배분 전에
  /// 반드시 확인해, 정의만 있는 역할이 배분되어 게임이 멈추는 일을 막습니다.
  static List<String> unimplementedRolesFor(int playerCount) {
    final composition = recommended[playerCount];
    if (composition == null) return const [];
    return composition.keys
        .where((id) => MafiaRoles.find(id)?.isImplemented != true)
        .toList(growable: false);
  }

  /// 지금 빌드에서 실제로 시작할 수 있는 인원수입니다.
  static List<int> get playableCounts => recommended.keys
      .where((count) => unimplementedRolesFor(count).isEmpty)
      .toList(growable: false);

  /// 밤 행동을 처리하는 역할 순서입니다.
  ///
  /// 서버는 각 역할의 [MafiaRole.nightOrder]를 같은 값으로 가지고 이 순서로
  /// 해결합니다. 경호원·마피아 보스처럼 동일 능력의 파생 역할은 같은
  /// 순서를 공유합니다.
  static final List<MafiaRole> nightResolutionOrder = List.unmodifiable(
    MafiaRoles.implemented.where((role) => role.nightOrder != null).toList()
      ..sort(
        (left, right) => left.nightOrder!.compareTo(right.nightOrder!),
      ),
  );
}
