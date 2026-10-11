part of '../game_screen.dart';

/// 허위 선언 판정에서 벌칙 진행 화면으로 전환합니다.
///
/// 판정 문구와 벌칙 프로필 모두 화면 중앙에서 페이드·미세 확대 애니메이션으로
/// 등장하며, 오른쪽에서 밀려오는 이동은 사용하지 않습니다.
class _PenaltyStageSwitcher extends StatefulWidget {
  const _PenaltyStageSwitcher({
    required this.verdictMessage,
    required this.verdictPending,
    required this.player,
    required this.result,
    required this.meUid,
    required this.lieRevealed,
    required this.caller,
  });

  /// 직전 카드의 거짓·진실 판정 문구와 공개 대기 상태입니다.
  final String? verdictMessage;
  final bool verdictPending;

  /// 룰렛을 돌리는 사람과 그 결과(`safe`/`eliminated`)입니다.
  final PhoneGamePlayer? player;
  final String? result;

  final String meUid;

  /// LIAR가 거짓을 밝혀냈는지입니다. 이 경우 역할별 공개 화면을 씁니다.
  final bool lieRevealed;
  final PhoneGamePlayer? caller;

  bool get _hasResult => result == 'safe' || result == 'eliminated';

  String get stageId {
    if (_hasResult && player != null) return 'roulette-result';
    if (verdictPending) return 'verdict-pending';
    if (lieRevealed && player != null) return 'lie-reveal';
    return verdictMessage == null
        ? 'penalty-status'
        : 'verdict-$verdictMessage';
  }

  Widget buildStage() {
    final target = player;
    if (_hasResult && target != null) {
      return PhoneRouletteResult(
        key: ValueKey('roulette-result-${target.uid}'),
        player: target,
        eliminated: result == 'eliminated',
        isMe: target.uid == meUid,
      );
    }
    if (verdictPending) {
      return const SizedBox.expand(key: ValueKey('verdict-pending'));
    }
    if (lieRevealed && target != null) {
      return PhoneLiarReveal(
        key: const ValueKey('lie-reveal'),
        meUid: meUid,
        caller: caller,
        caught: target,
      );
    }
    final message = verdictMessage;
    return message != null
        ? SizedBox.expand(key: ValueKey('verdict-$message'))
        : PhonePenaltyStatus(
            key: const ValueKey('penalty-status'),
            player: player,
            result: result,
          );
  }

  @override
  State<_PenaltyStageSwitcher> createState() => _PenaltyStageSwitcherState();
}

class _PenaltyStageSwitcherState extends State<_PenaltyStageSwitcher>
    with SingleTickerProviderStateMixin {
  static const _transitionDuration =
      LiarsPokerPhoneTiming.phonePenaltyStageSwitch;

  late final AnimationController _controller;
  late String _displayedStageId;
  late Widget _displayedStage;
  String? _pendingStageId;
  Widget? _pendingStage;
  bool _hasSwappedStage = true;

  @override
  void initState() {
    super.initState();
    _displayedStageId = widget.stageId;
    _displayedStage = widget.buildStage();
    _controller =
        AnimationController(
            vsync: this,
            duration: _transitionDuration,
            value: 1,
          )
          ..addListener(_handleAnimationProgress)
          ..addStatusListener(_handleAnimationStatus);
  }

  @override
  void didUpdateWidget(_PenaltyStageSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);

    final nextStageId = widget.stageId;
    final nextStage = widget.buildStage();

    if (_controller.isAnimating) {
      if (nextStageId == _pendingStageId) {
        _pendingStage = nextStage;
        if (_hasSwappedStage) _displayedStage = nextStage;
      } else if (nextStageId == _displayedStageId) {
        _displayedStage = nextStage;
      }
      return;
    }

    if (nextStageId == _displayedStageId) {
      _displayedStage = nextStage;
      return;
    }

    _pendingStageId = nextStageId;
    _pendingStage = nextStage;
    _hasSwappedStage = false;
    _controller.forward(from: 0);
  }

  void _handleAnimationProgress() {
    if (_hasSwappedStage || _controller.value < 0.5) return;

    final pendingStageId = _pendingStageId;
    final pendingStage = _pendingStage;
    if (pendingStageId == null || pendingStage == null || !mounted) return;

    setState(() {
      _displayedStageId = pendingStageId;
      _displayedStage = pendingStage;
      _hasSwappedStage = true;
    });
  }

  void _handleAnimationStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed) return;
    _pendingStageId = null;
    _pendingStage = null;
    _hasSwappedStage = true;
  }

  @override
  void dispose() {
    _controller.removeListener(_handleAnimationProgress);
    _controller.removeStatusListener(_handleAnimationStatus);
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final travelDistance = constraints.maxWidth;

          return AnimatedBuilder(
            animation: _controller,
            child: _displayedStage,
            builder: (context, child) {
              final value = _controller.value;
              final isExitingVerdict =
                  value < 0.5 &&
                  (_displayedStageId.startsWith('verdict-') ||
                      _displayedStageId == 'lie-reveal');
              if (isExitingVerdict) {
                final exitProgress = Curves.easeInCubic.transform(value * 2);
                return Opacity(
                  opacity: 1 - exitProgress,
                  child: Transform.scale(
                    scale: 1 - (0.04 * exitProgress),
                    child: child,
                  ),
                );
              }

              final isCenteredEntry =
                  value >= 0.5 &&
                  (_displayedStageId == 'penalty-status' ||
                      _displayedStageId == 'lie-reveal' ||
                      _displayedStageId == 'roulette-result' ||
                      _displayedStageId.startsWith('verdict-'));
              if (isCenteredEntry) return child ?? const SizedBox();

              final offsetX = value < 0.5
                  ? -travelDistance * Curves.easeInCubic.transform(value * 2)
                  : travelDistance *
                        (1 - Curves.easeOutCubic.transform((value - 0.5) * 2));

              return Transform.translate(
                offset: Offset(offsetX, 0),
                child: child,
              );
            },
          );
        },
      ),
    );
  }
}
