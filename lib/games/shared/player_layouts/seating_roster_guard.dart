import 'package:flutter/widgets.dart';
import 'package:project00/platform/home/room/models/room_player.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

/// 자리 배치·역할 구성 화면이 열려 있는 동안 참가자 구성이 바뀌면 알립니다.
///
/// **왜 필요한가.** 자리 배치 초안은 태블릿 메모리에만 있습니다. 화면에 넘기는
/// `PlayerLayoutModel`은 라우트를 push할 때 한 번 만들어지고
/// (`tablet_game_preview_modal.dart`의 `PlayerLayoutFactory.create`), 그 뒤로
/// 갱신되지 않습니다. 그동안 참가자가 나가면 화면은 옛 명단을 그대로 들고 있고,
/// 서버는 좌석 저장을 거부합니다(`saveRealtimePlayerSeatIndexes`는 좌석 UID
/// 집합과 `players` 키 집합의 완전 일치를 요구합니다). 진행자에게는 원인을 알 수
/// 없는 실패만 보입니다.
///
/// **왜 공용 위젯인가.** 공용 `PlayerLayoutEditor`와 마피아 전용 역할 구성 화면이
/// 모두 같은 문제를 갖습니다. 두 화면을 각각 고치면 게임을 추가할 때마다 같은
/// 코드를 또 씁니다. 자리 배치 화면을 만드는 한곳(`_buildStartSetup`)에서 감싸면
/// 게임별 분기 없이 모두 적용됩니다.
///
/// **판정 근거는 활성 참가자 UID 집합뿐입니다.** `players` 노드는 10초 heartbeat
/// (`lastSeen`)마다 이벤트를 발생시키므로, 노드 내용을 통째로 비교하면 자리 배치가
/// 10초마다 취소됩니다. 연결이 끊긴 참가자(`isConnected == false`)도 노드가 남아
/// 있으면 그대로 둡니다 — 돌아올 수 있는 사람이지 나간 사람이 아닙니다.
class SeatingRosterGuard extends StatefulWidget {
  const SeatingRosterGuard({
    super.key,
    required this.provider,
    required this.onRosterChanged,
    required this.child,
  });

  final RoomProvider provider;

  /// 활성 참가자 UID 집합이 진입 시점과 달라졌을 때 **한 번만** 호출됩니다.
  ///
  /// 자리 배치를 취소하고 대기실로 돌아가는 처리를 여기서 합니다. 여러 번
  /// 불리면 취소 요청이 중복되므로 이 위젯이 1회로 제한합니다.
  final VoidCallback onRosterChanged;

  final Widget child;

  /// 참가자 구성 비교에 쓰는 UID 집합입니다.
  ///
  /// 자리 배치 대상과 같은 기준(`isActive && isPlayer`)을 씁니다. 태블릿
  /// 진행자는 `players`에 없으므로 자연히 빠집니다.
  static Set<String> seatedUids(List<RoomPlayer> players) {
    return {
      for (final player in players)
        if (player.isActive && player.isPlayer) player.uid,
    };
  }

  @override
  State<SeatingRosterGuard> createState() => _SeatingRosterGuardState();
}

class _SeatingRosterGuardState extends State<SeatingRosterGuard> {
  late Set<String> _baseline;
  bool _notified = false;

  @override
  void initState() {
    super.initState();
    _baseline = SeatingRosterGuard.seatedUids(widget.provider.players);
    widget.provider.addListener(_handleRoomChanged);
  }

  @override
  void didUpdateWidget(SeatingRosterGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.provider, widget.provider)) {
      oldWidget.provider.removeListener(_handleRoomChanged);
      widget.provider.addListener(_handleRoomChanged);
      _baseline = SeatingRosterGuard.seatedUids(widget.provider.players);
      _notified = false;
    }
  }

  void _handleRoomChanged() {
    if (_notified || !mounted) return;
    final current = SeatingRosterGuard.seatedUids(widget.provider.players);
    // 방을 떠난 뒤(clearRoom)에는 players가 비어 있습니다. 그 순간을 참가자
    // 변경으로 읽으면 이미 닫히는 화면에서 취소 요청이 한 번 더 나갑니다.
    if (widget.provider.roomCode == null) return;
    if (_setEquals(current, _baseline)) return;
    _notified = true;
    widget.onRosterChanged();
  }

  @override
  void dispose() {
    widget.provider.removeListener(_handleRoomChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

bool _setEquals(Set<String> left, Set<String> right) {
  if (left.length != right.length) return false;
  return left.containsAll(right);
}
