// [game_turn_countdown_face.dart] 는 턴 남은 시간 표시와 초읽기 소리를 결합하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 남은 시간 표시에 초읽기 소리를 붙여 주는 껍데기를 구성함
//
// 즉, 게임마다 같은 초읽기 수명주기를 다시 쓰지 않기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/sound/countdown_tick_cue.dart';
import 'package:game_kit/shared/widgets/game_turn_countdown.dart';

// ============================================================

//=======================초읽기 소리가 붙은 남은 시간==============================
/// [GameTurnCountdown] 에 **마지막 5초 초읽기 소리**를 붙인 위젯입니다.
///
/// 시간을 세는 일은 [GameTurnCountdown] 이, 소리는 [CountdownTickCue] 가
/// 합니다. 이 위젯이 하는 일은 둘을 잇는 **수명주기 관리**뿐입니다.
///
/// - 붙을 때 마감 시각을 예약합니다.
/// - 마감 시각이 바뀌면 다시 예약합니다(다음 사람 차례).
/// - 떨어질 때 멈춥니다. 제한시간 전에 행동을 마치면 이 위젯이 사라지는데,
///   그때 멈추지 않으면 다음 사람 차례까지 소리가 이어집니다.
///
/// 이 세 가지를 게임마다 다시 쓰다가 하나를 빠뜨리면, 소리가 남의 차례까지
/// 새는 버그가 그 게임에만 생깁니다. 그래서 껍데기를 공용으로 둡니다.
///
/// **생김새는 [builder] 에 맡깁니다.** 게임마다 타이머 모양이 달라서
/// (라이어스포커는 `분.초` 패널, 파이널콜은 `00:초` 글자) 여기서 그리지
/// 않습니다.
class GameTurnCountdownFace extends StatefulWidget {
  const GameTurnCountdownFace({
    super.key,
    required this.expiresAt,
    required this.builder,
    this.onTimeout,
  });

  /// 마감 시각(서버 기준 밀리초)입니다.
  final int? expiresAt;

  /// 남은 시간을 받아 화면을 그립니다. 남은 시간이 아직 없으면 null입니다.
  final Widget Function(BuildContext context, Duration? remaining) builder;

  /// 마감 순간 한 번 불립니다.
  final VoidCallback? onTimeout;

  @override
  State<GameTurnCountdownFace> createState() => _GameTurnCountdownFaceState();
}

class _GameTurnCountdownFaceState extends State<GameTurnCountdownFace> {
  final CountdownTickCue _tickCue = CountdownTickCue();

  @override
  void initState() {
    super.initState();
    _tickCue.schedule(widget.expiresAt);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tickCue.attach(context);
  }

  @override
  void didUpdateWidget(covariant GameTurnCountdownFace oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.expiresAt != oldWidget.expiresAt) {
      _tickCue.schedule(widget.expiresAt);
    }
  }

  @override
  void dispose() {
    _tickCue.stop();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GameTurnCountdown(
      expiresAt: widget.expiresAt,
      onTimeout: widget.onTimeout,
      builder: widget.builder,
    );
  }
}
