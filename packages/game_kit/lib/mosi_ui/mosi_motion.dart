// [mosi_motion.dart] 는 로비 화면들이 함께 쓰는 짧은 연출 위젯을 모아 둔 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 등장·선택·흔들림·준비 완료·체크 같은 로비 마이크로 인터랙션
//
// 즉, 로비의 여러 화면이 같은 시간·같은 곡선으로 움직이게 하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';

// ============================================================

/// 로비 연출 시간표입니다. 화면마다 따로 숫자를 쓰지 않습니다.
abstract final class MosiMotion {
  /// 새 항목이 작게 나타나 안착하는 시간입니다.
  static const enter = Duration(milliseconds: 420);

  /// 항목이 흐려지며 빠지는 시간입니다.
  static const exit = Duration(milliseconds: 260);

  /// 남은 항목이 빈자리를 메우는 시간입니다.
  static const settle = Duration(milliseconds: 360);

  /// 선택한 것이 커졌다 안착하는 시간입니다.
  static const select = Duration(milliseconds: 360);

  /// 잘못된 칸이 흔들리는 시간입니다.
  static const shake = Duration(milliseconds: 360);

  /// 오류 설명이 펼쳐지는 시간입니다.
  static const reveal = Duration(milliseconds: 220);

  /// 버튼이 준비되어 한 번 들리는 시간입니다.
  static const lift = Duration(milliseconds: 520);

  /// 체크 표시를 그리는 시간입니다.
  static const check = Duration(milliseconds: 380);

  /// 접근성 설정에서 움직임을 줄이면 0으로 바꿉니다.
  static Duration of(BuildContext context, Duration duration) =>
      MediaQuery.maybeDisableAnimationsOf(context) == true
      ? Duration.zero
      : duration;
}

// ---------------------------------------------------------------------------
// 1. 목록 입장·퇴장
// ---------------------------------------------------------------------------
/// 세로 목록에서 새 항목은 작게 나타나 안착하고, 빠지는 항목은 흐려진 뒤
/// 자리를 접어 아래 항목들이 미끄러지듯 빈자리를 메웁니다.
///
/// 처음 그릴 때 이미 있던 항목은 움직이지 않고 그대로 보입니다.
class MosiAnimatedItems<T> extends StatefulWidget {
  const MosiAnimatedItems({
    super.key,
    required this.items,
    required this.keyOf,
    required this.itemBuilder,
    this.spacing = 0,
  });

  final List<T> items;
  final Object Function(T item) keyOf;
  final Widget Function(BuildContext context, T item) itemBuilder;

  /// 항목 사이 간격입니다. 빠질 때 간격도 함께 접힙니다.
  final double spacing;

  @override
  State<MosiAnimatedItems<T>> createState() => _MosiAnimatedItemsState<T>();
}

class _ItemEntry<T> {
  _ItemEntry(this.key, this.item, {this.entering = false});

  final Object key;
  T item;
  bool entering;
  bool removing = false;
}

class _MosiAnimatedItemsState<T> extends State<MosiAnimatedItems<T>> {
  late List<_ItemEntry<T>> _entries = [
    for (final item in widget.items) _ItemEntry(widget.keyOf(item), item),
  ];

  @override
  void didUpdateWidget(covariant MosiAnimatedItems<T> oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = <Object, T>{
      for (final item in widget.items) widget.keyOf(item): item,
    };
    final byKey = {for (final entry in _entries) entry.key: entry};
    final merged = <_ItemEntry<T>>[];
    for (final item in widget.items) {
      final key = widget.keyOf(item);
      final existing = byKey[key];
      if (existing != null && !existing.removing) {
        existing.item = item;
        merged.add(existing);
      } else {
        merged.add(_ItemEntry(key, item, entering: true));
      }
    }
    // 빠지는 항목은 원래 자리 근처에 남겨 접히는 모습을 보여 줍니다.
    for (var index = 0; index < _entries.length; index++) {
      final entry = _entries[index];
      if (next.containsKey(entry.key) && !entry.removing) continue;
      if (next.containsKey(entry.key)) continue;
      entry.removing = true;
      merged.insert(math.min(index, merged.length), entry);
    }
    _entries = merged;
  }

  void _removeEntry(Object key) {
    if (!mounted) return;
    setState(() => _entries.removeWhere((e) => e.key == key && e.removing));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (index, entry) in _entries.indexed)
          _MosiAnimatedItem(
            key: ValueKey(entry.key),
            entering: entry.entering,
            removing: entry.removing,
            onRemoved: () => _removeEntry(entry.key),
            child: Padding(
              padding: EdgeInsets.only(top: index == 0 ? 0 : widget.spacing),
              child: widget.itemBuilder(context, entry.item),
            ),
          ),
      ],
    );
  }
}

class _MosiAnimatedItem extends StatefulWidget {
  const _MosiAnimatedItem({
    super.key,
    required this.entering,
    required this.removing,
    required this.onRemoved,
    required this.child,
  });

  final bool entering;
  final bool removing;
  final VoidCallback onRemoved;
  final Widget child;

  @override
  State<_MosiAnimatedItem> createState() => _MosiAnimatedItemState();
}

class _MosiAnimatedItemState extends State<_MosiAnimatedItem>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    value: widget.entering ? 0 : 1,
  );

  static final _pop = TweenSequence<double>([
    TweenSequenceItem(tween: Tween(begin: 0.6, end: 1.06), weight: 70),
    TweenSequenceItem(tween: Tween(begin: 1.06, end: 1), weight: 30),
  ]);

  @override
  void initState() {
    super.initState();
    if (widget.entering) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.animateTo(
          1,
          duration: MosiMotion.of(context, MosiMotion.enter),
        );
      });
    }
    if (widget.removing) _leave();
  }

  @override
  void didUpdateWidget(covariant _MosiAnimatedItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.removing && !oldWidget.removing) _leave();
  }

  Future<void> _leave() async {
    await _controller
        .animateBack(
          0,
          duration: MosiMotion.of(context, MosiMotion.exit + MosiMotion.settle),
        )
        .orCancel
        .catchError((_) {});
    if (mounted) widget.onRemoved();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        final leaving = widget.removing;
        // 빠질 때: 앞부분에서 흐려지고, 뒷부분에서 자리가 접힙니다.
        final exitSplit =
            MosiMotion.exit.inMilliseconds /
            (MosiMotion.exit + MosiMotion.settle).inMilliseconds;
        final double size;
        final double opacity;
        final double scale;
        if (leaving) {
          final fade = ((t - (1 - exitSplit)) / exitSplit).clamp(0.0, 1.0);
          size = Curves.easeInOutCubic.transform(
            (t / (1 - exitSplit)).clamp(0.0, 1.0),
          );
          opacity = fade;
          scale = 0.7 + 0.3 * fade;
        } else {
          size = Curves.easeOutCubic.transform((t / 0.6).clamp(0.0, 1.0));
          opacity = Curves.easeOut.transform((t / 0.5).clamp(0.0, 1.0));
          scale = _pop.transform(Curves.easeOut.transform(t));
        }
        return ClipRect(
          child: Align(
            alignment: Alignment.topCenter,
            heightFactor: size,
            child: Opacity(
              opacity: opacity,
              child: Transform.scale(scale: scale, child: child),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// 2. 선택하면 커졌다 안착
// ---------------------------------------------------------------------------
/// [selected]가 새로 켜질 때 한 번 커졌다가 제자리에 안착합니다.
class MosiSelectPop extends StatefulWidget {
  const MosiSelectPop({
    super.key,
    required this.selected,
    required this.child,
    this.peak = 1.18,
  });

  final bool selected;
  final Widget child;
  final double peak;

  @override
  State<MosiSelectPop> createState() => _MosiSelectPopState();
}

class _MosiSelectPopState extends State<MosiSelectPop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void didUpdateWidget(covariant MosiSelectPop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selected && !oldWidget.selected) {
      _controller.duration = MosiMotion.of(context, MosiMotion.select);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final t = _controller.value;
      final rise = t < 0.4
          ? Curves.easeOut.transform(t / 0.4)
          : 1 - Curves.easeOutBack.transform((t - 0.4) / 0.6);
      return Transform.scale(
        scale: 1 + (widget.peak - 1) * rise.clamp(-0.3, 1.0),
        child: child,
      );
    },
  );
}

/// 보일 때 톡 튀어나오는 작은 표식입니다(선택 체크 등).
class MosiPopBadge extends StatelessWidget {
  const MosiPopBadge({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: visible ? 1 : 0,
    duration: MosiMotion.of(context, const Duration(milliseconds: 260)),
    curve: visible ? Curves.easeOutBack : Curves.easeIn,
    child: child,
  );
}

// ---------------------------------------------------------------------------
// 3·10. 흔들림과 펼쳐지는 안내
// ---------------------------------------------------------------------------
/// [trigger]가 바뀔 때마다 좌우로 짧게 흔들립니다. null이면 흔들지 않습니다.
///
/// 잘못된 칸만 감쌉니다. 화면 전체를 흔들지 않습니다.
class MosiShake extends StatefulWidget {
  const MosiShake({super.key, required this.trigger, required this.child});

  final Object? trigger;
  final Widget child;

  @override
  State<MosiShake> createState() => _MosiShakeState();
}

class _MosiShakeState extends State<MosiShake>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void didUpdateWidget(covariant MosiShake oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trigger != null && widget.trigger != oldWidget.trigger) {
      _controller.duration = MosiMotion.of(context, MosiMotion.shake);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final t = _controller.value;
      // 점점 줄어드는 사인파: 6px → 0.
      final dx = math.sin(t * math.pi * 4) * 6 * (1 - t);
      return Transform.translate(offset: Offset(dx, 0), child: child);
    },
  );
}

/// 보일 때 자리를 부드럽게 펼치며 나타나고, 사라질 때 접히는 안내입니다.
class MosiReveal extends StatelessWidget {
  const MosiReveal({super.key, required this.visible, required this.child});

  final bool visible;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final duration = MosiMotion.of(context, MosiMotion.reveal);
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: visible
          ? TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: duration,
              builder: (context, value, child) =>
                  Opacity(opacity: value, child: child),
              child: child,
            )
          : const SizedBox(width: double.infinity),
    );
  }
}

// ---------------------------------------------------------------------------
// 4. 준비되면 한 번 들림
// ---------------------------------------------------------------------------
/// [ready]가 새로 켜지는 순간 위로 살짝 들렸다 내려옵니다. 한 번만 움직이고
/// 계속 깜빡이지 않습니다.
class MosiReadyLift extends StatefulWidget {
  const MosiReadyLift({super.key, required this.ready, required this.child});

  final bool ready;
  final Widget child;

  @override
  State<MosiReadyLift> createState() => _MosiReadyLiftState();
}

class _MosiReadyLiftState extends State<MosiReadyLift>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);

  @override
  void didUpdateWidget(covariant MosiReadyLift oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.ready && !oldWidget.ready) {
      _controller.duration = MosiMotion.of(context, MosiMotion.lift);
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final t = _controller.value;
      final up = t < 0.4
          ? Curves.easeOut.transform(t / 0.4)
          : 1 - Curves.easeOutBack.transform((t - 0.4) / 0.6);
      return Transform.translate(
        offset: Offset(0, -7 * up.clamp(-0.4, 1.0)),
        child: child,
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 3·9. 버튼 안 진행 점과 성공 체크
// ---------------------------------------------------------------------------
/// 버튼 안에서 통통 튀는 점 세 개입니다. 입력 영역은 그대로 두고 버튼만
/// 바뀌어 "누른 것이 진행 중"임을 알립니다.
class MosiLoadingDots extends StatefulWidget {
  const MosiLoadingDots({super.key, required this.color, this.size = 7});

  final Color color;
  final double size;

  @override
  State<MosiLoadingDots> createState() => _MosiLoadingDotsState();
}

class _MosiLoadingDotsState extends State<MosiLoadingDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Semantics(
    label: '진행 중',
    child: AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var index = 0; index < 3; index++)
            Builder(
              builder: (context) {
                final phase = (_controller.value - index * 0.16) % 1.0;
                final bounce = phase < 0.4
                    ? math.sin(phase / 0.4 * math.pi)
                    : 0.0;
                return Container(
                  width: widget.size,
                  height: widget.size,
                  margin: EdgeInsets.symmetric(horizontal: widget.size * 0.3),
                  transform: Matrix4.translationValues(
                    0,
                    -widget.size * 0.6 * bounce,
                    0,
                  ),
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.35 + 0.65 * bounce),
                    shape: BoxShape.circle,
                  ),
                );
              },
            ),
        ],
      ),
    ),
  );
}

/// 선을 그리듯 나타나는 체크 표시입니다(입장 성공·저장 완료).
class MosiDrawnCheck extends StatelessWidget {
  const MosiDrawnCheck({super.key, required this.color, this.size = 22});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    tween: Tween(begin: 0, end: 1),
    duration: MosiMotion.of(context, MosiMotion.check),
    curve: Curves.easeOut,
    builder: (context, progress, _) => CustomPaint(
      size: Size.square(size),
      painter: _CheckPainter(color: color, progress: progress),
    ),
  );
}

class _CheckPainter extends CustomPainter {
  const _CheckPainter({required this.color, required this.progress});

  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(size.width * 0.18, size.height * 0.53)
      ..lineTo(size.width * 0.4, size.height * 0.74)
      ..lineTo(size.width * 0.83, size.height * 0.27);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.14
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    for (final metric in path.computeMetrics()) {
      canvas.drawPath(metric.extractPath(0, metric.length * progress), paint);
    }
  }

  @override
  bool shouldRepaint(_CheckPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

// ---------------------------------------------------------------------------
// 6. 글자가 차례로 나타남
// ---------------------------------------------------------------------------
/// 글자가 앞에서부터 한 자씩 또렷해집니다(방 코드).
///
/// 글자 수만큼 위젯을 쪼개지 않고 한 줄 [Text.rich]로 그려, 복사·찾기·화면
/// 읽기에는 원래 문자열 그대로 보입니다. [text]가 바뀔 때마다 다시 재생합니다.
class MosiStaggeredText extends StatefulWidget {
  const MosiStaggeredText({
    super.key,
    required this.text,
    required this.style,
    this.step = const Duration(milliseconds: 80),
    this.charDuration = const Duration(milliseconds: 260),
    this.delay = Duration.zero,
  });

  final String text;
  final TextStyle style;
  final Duration step;
  final Duration charDuration;
  final Duration delay;

  @override
  State<MosiStaggeredText> createState() => _MosiStaggeredTextState();
}

class _MosiStaggeredTextState extends State<MosiStaggeredText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(vsync: this);
  Timer? _delay;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _play());
  }

  @override
  void didUpdateWidget(covariant MosiStaggeredText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text) _play();
  }

  void _play() {
    if (!mounted) return;
    final total =
        widget.step * math.max(0, widget.text.length - 1) + widget.charDuration;
    final duration = MosiMotion.of(context, total);
    if (duration == Duration.zero) {
      _controller.value = 1;
      return;
    }
    _controller
      ..duration = duration
      ..value = 0;
    _delay?.cancel();
    _delay = Timer(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _delay?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, _) {
      final totalMs = (_controller.duration ?? Duration.zero).inMilliseconds;
      final elapsed = _controller.value * totalMs;
      final color = widget.style.color ?? const Color(0xFF000000);
      final chars = widget.text.characters.toList();
      return Text.rich(
        TextSpan(
          children: [
            for (var index = 0; index < chars.length; index++)
              TextSpan(
                text: chars[index],
                style: TextStyle(
                  color: color.withValues(
                    alpha:
                        color.a *
                        (totalMs == 0
                            ? 1
                            : Curves.easeOut.transform(
                                ((elapsed -
                                            widget.step.inMilliseconds *
                                                index) /
                                        widget.charDuration.inMilliseconds)
                                    .clamp(0.0, 1.0),
                              )),
                  ),
                ),
              ),
          ],
        ),
        style: widget.style,
      );
    },
  );
}

// ---------------------------------------------------------------------------
// 8. 누른 자리에서 펼쳐지는 모달
// ---------------------------------------------------------------------------
/// 위젯이 화면에서 차지하는 영역입니다. 모달을 그 자리에서 펼칠 때 씁니다.
Rect? mosiOriginOf(BuildContext context) {
  final box = context.findRenderObject();
  if (box is! RenderBox || !box.hasSize || !box.attached) return null;
  final topLeft = box.localToGlobal(Offset.zero);
  return topLeft & box.size;
}
