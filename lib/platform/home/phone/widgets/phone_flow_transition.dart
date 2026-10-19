import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';

/// 휴대폰의 화면 전체 배경이 바뀌는 방향입니다.
enum PhoneBackgroundWipeDirection {
  /// 새 색이 화면 위에서 아래로 내려옵니다.
  topDown,

  /// 새 색이 오른쪽 위에서 왼쪽 아래로 퍼집니다.
  topRightToBottomLeft,
}

/// 지정한 진행률만큼 화면을 방향성 그라데이션 색으로 덮습니다.
class PhoneBackgroundReveal extends StatelessWidget {
  const PhoneBackgroundReveal({
    super.key,
    required this.color,
    required this.progress,
    this.direction = PhoneBackgroundWipeDirection.topRightToBottomLeft,
  });

  final Color color;
  final double progress;
  final PhoneBackgroundWipeDirection direction;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      gradient: _phoneDirectionalGradient(
        solid: color,
        progress: progress.clamp(0, 1),
        direction: direction,
      ),
    ),
  );
}

/// 기존 배경을 계속 칠한 상태에서 새 색을 방향성 그라데이션으로 덮습니다.
///
/// 두 색을 화면 전체에서 보간하면 중간색이 한 프레임 번쩍이는 것처럼 보일 수
/// 있습니다. 이 위젯은 이전 색을 빈틈 없이 유지하고, 새 색의 부드러운 경계만
/// 이동시켜 전환 중에도 흰색·검정색 기본 배경이 드러나지 않게 합니다.
class PhoneBackgroundWipe extends StatefulWidget {
  const PhoneBackgroundWipe({
    super.key,
    required this.color,
    required this.child,
    this.direction = PhoneBackgroundWipeDirection.topRightToBottomLeft,
    this.duration = const Duration(milliseconds: 460),
  });

  final Color color;
  final Widget child;
  final PhoneBackgroundWipeDirection direction;
  final Duration duration;

  @override
  State<PhoneBackgroundWipe> createState() => _PhoneBackgroundWipeState();
}

class _PhoneBackgroundWipeState extends State<PhoneBackgroundWipe>
    with SingleTickerProviderStateMixin {
  late Color _previousColor = widget.color;
  late Color _targetColor = widget.color;
  Color? _queuedColor;
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
    value: 1,
  )..addStatusListener(_handleStatus);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant PhoneBackgroundWipe oldWidget) {
    super.didUpdateWidget(oldWidget);
    _controller.duration = widget.duration;
    if (_controller.isAnimating) {
      // 현재 경계를 갑자기 전체색으로 바꾸지 않고 마지막 선택만 이어서 재생합니다.
      // 여러 책을 빠르게 넘겨도 중간의 낡은 선택은 큐에 쌓이지 않습니다.
      _queuedColor = widget.color == _targetColor ? null : widget.color;
      return;
    }
    if (widget.color == _targetColor) return;

    _previousColor = _targetColor;
    _targetColor = widget.color;
    if (MediaQuery.disableAnimationsOf(context) ||
        widget.duration == Duration.zero) {
      _previousColor = _targetColor;
      _controller.value = 1;
    } else {
      _controller.forward(from: 0);
    }
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || !mounted) return;
    final queued = _queuedColor;
    _queuedColor = null;
    if (queued == null || queued == _targetColor) {
      setState(() => _previousColor = _targetColor);
      return;
    }
    if (MediaQuery.disableAnimationsOf(context) ||
        widget.duration == Duration.zero) {
      setState(() {
        _previousColor = queued;
        _targetColor = queued;
      });
      return;
    }
    setState(() {
      _previousColor = _targetColor;
      _targetColor = queued;
      _controller.value = 0;
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      ColoredBox(
        key: const Key('phone-background-wipe-base'),
        color: _previousColor,
      ),
      AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          final progress = Curves.easeInOutCubic.transform(_controller.value);
          return IgnorePointer(
            child: ExcludeSemantics(
              child: PhoneBackgroundReveal(
                key: const Key('phone-background-wipe-reveal'),
                color: _targetColor,
                progress: progress,
                direction: widget.direction,
              ),
            ),
          );
        },
      ),
      widget.child,
    ],
  );
}

LinearGradient _phoneDirectionalGradient({
  required Color solid,
  required double progress,
  required PhoneBackgroundWipeDirection direction,
}) {
  final begin = switch (direction) {
    PhoneBackgroundWipeDirection.topDown => Alignment.topCenter,
    PhoneBackgroundWipeDirection.topRightToBottomLeft => Alignment.topRight,
  };
  final end = switch (direction) {
    PhoneBackgroundWipeDirection.topDown => Alignment.bottomCenter,
    PhoneBackgroundWipeDirection.topRightToBottomLeft => Alignment.bottomLeft,
  };
  if (progress <= 0) {
    return LinearGradient(
      begin: begin,
      end: end,
      colors: const [Colors.transparent, Colors.transparent],
    );
  }
  if (progress >= 1) {
    return LinearGradient(begin: begin, end: end, colors: [solid, solid]);
  }

  const feather = .085;
  final solidEdge = (progress - feather).clamp(0.0, 1.0);
  final clearEdge = (progress + feather).clamp(0.0, 1.0);
  return LinearGradient(
    begin: begin,
    end: end,
    colors: [
      solid,
      solid,
      solid.withValues(alpha: 0),
      solid.withValues(alpha: 0),
    ],
    stops: [0, solidEdge, clearEdge, 1],
  );
}

/// 휴대폰 로비 흐름에서 화면 전체를 좌우로 밀지 않고 내용을 교체합니다.
///
/// 새 화면은 기존 화면 위를 오른쪽 위부터 부드럽게 덮습니다. 이전 route는 제자리에
/// 남으므로 홈, 코드 입력, 프로필 선택 사이에서 배경이 옆으로 끌리거나 빈 canvas가
/// 한 프레임 드러나지 않습니다.
class PhoneFlowRoute<T> extends PageRouteBuilder<T> {
  PhoneFlowRoute({required WidgetBuilder builder})
    : super(
        transitionDuration: MosiMotion.enter,
        reverseTransitionDuration: MosiMotion.exit,
        pageBuilder: (context, _, _) => builder(context),
        transitionsBuilder: (context, animation, _, child) {
          if (MediaQuery.maybeDisableAnimationsOf(context) == true) {
            return child;
          }
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return AnimatedBuilder(
            animation: curved,
            child: child,
            builder: (context, child) {
              final progress = curved.value;
              if (progress >= 1) return child!;
              return ShaderMask(
                key: const Key('phone-flow-background-reveal'),
                blendMode: BlendMode.dstIn,
                shaderCallback: (bounds) => _phoneDirectionalGradient(
                  solid: Colors.white,
                  progress: progress,
                  direction: PhoneBackgroundWipeDirection.topRightToBottomLeft,
                ).createShader(bounds),
                child: child,
              );
            },
          );
        },
      );
}

/// 한 화면 안에서 공통 요소를 둔 채 달라지는 내용만 부드럽게 교체합니다.
class PhoneFlowContentSwap extends StatelessWidget {
  const PhoneFlowContentSwap({
    super.key,
    required this.stateKey,
    required this.child,
    this.alignment = Alignment.topCenter,
  });

  final Object stateKey;
  final Widget child;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final duration = MosiMotion.of(context, const Duration(milliseconds: 280));
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: alignment,
      child: AnimatedSwitcher(
        duration: duration,
        reverseDuration: MosiMotion.of(context, MosiMotion.exit),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        layoutBuilder: (current, previous) => Stack(
          alignment: alignment,
          children: [
            for (final child in previous)
              ExcludeFocus(
                child: ExcludeSemantics(child: IgnorePointer(child: child)),
              ),
            ?current,
          ],
        ),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.985, end: 1).animate(animation),
            alignment: alignment,
            child: child,
          ),
        ),
        child: KeyedSubtree(key: ValueKey<Object>(stateKey), child: child),
      ),
    );
  }
}
