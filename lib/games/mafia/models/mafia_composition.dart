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
    6: {'mafia': 1, 'police': 1, 'doctor': 1, 'citizen': 3},
    7: {'mafia': 2, 'police': 1, 'doctor': 1, 'citizen': 3},
    8: {'mafia': 2, 'police': 1, 'doctor': 1, 'citizen': 4},
    9: {'mafia': 2, 'police': 1, 'doctor': 1, 'citizen': 5},
    10: {'mafia_boss': 1, 'mafia': 2, 'police': 1, 'doctor': 1, 'citizen': 5},
    11: {
      'mafia_boss': 1,
      'mafia': 2,
      'police': 1,
      'doctor': 1,
      'bodyguard': 1,
      'citizen': 5,
    },
    12: {
      'mafia_boss': 1,
      'mafia': 2,
      'police': 1,
      'doctor': 1,
      'bodyguard': 1,
      'citizen': 6,
    },
  };

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

  /// 밤 행동을 처리하는 순서입니다. 서버는 이 순서로만 해결합니다.
  ///
  /// 순서가 어긋나면 규칙이 깨집니다. 예를 들어 조사 조작([MafiaNightPhase.frame])을
  /// 조사([MafiaNightPhase.investigate])보다 나중에 처리하면 프레이머가 무효가 되고,
  /// 차단([MafiaNightPhase.roleblock])을 보호보다 나중에 처리하면 차단된 의사가
  /// 보호에 성공합니다.
  static final List<MafiaNightPhase> nightResolutionOrder = List.unmodifiable(
    MafiaNightPhase.values.toList()
      ..sort((left, right) => left.order.compareTo(right.order)),
  );
}
