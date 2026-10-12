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
  });

  final String? verdictMessage;
  final bool verdictPending;
  final PhoneGamePlayer? player;
  final String? result;

  String get stageId => verdictPending
      ? 'verdict-pending'
      : verdictMessage == null
      ? 'penalty-status'
      : 'verdict-$verdictMessage';

  Widget buildStage() {
    if (verdictPending) {
      return const SizedBox.expand(key: ValueKey('verdict-pending'));
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
                  value < 0.5 && _displayedStageId.startsWith('verdict-');
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
