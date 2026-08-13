import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/games/shared/animations/mat_unroll_animation.dart';

typedef GameLoadingPrepare = Future<void> Function(BuildContext context);

/// 서버 상태·이미지·사운드를 모두 준비한 뒤 실제 게임 화면을 여는 공용 화면입니다.
///
/// 게임별 배경과 팁만 주입하며 RTDB 구독을 새로 만들지 않습니다. 준비 작업은
/// [prepare]가 기존 게임 컨트롤러를 이용해 수행하고, 완료되면 매트를 다시 말아
/// 올린 뒤 [gameBuilder]를 처음 생성합니다.
class GameLoadingScreen extends StatefulWidget {
  const GameLoadingScreen({
    super.key,
    required this.background,
    required this.tips,
    required this.prepare,
    required this.gameBuilder,
    this.maxAttempts = 3,
    this.attemptTimeout = const Duration(seconds: 10),
    this.minimumVisibleDuration = const Duration(seconds: 2),
  }) : assert(tips.length > 0),
       assert(maxAttempts > 0);

  final ImageProvider background;
  final List<String> tips;
  final GameLoadingPrepare prepare;
  final WidgetBuilder gameBuilder;
  final int maxAttempts;
  final Duration attemptTimeout;
  final Duration minimumVisibleDuration;

  @override
  State<GameLoadingScreen> createState() => _GameLoadingScreenState();
}

class _GameLoadingScreenState extends State<GameLoadingScreen>
    with TickerProviderStateMixin {
  late final AnimationController _matController;
  late final AnimationController _pulseController;
  late String _tip;

  bool _isReady = false;
  bool _showGameBehindMat = false;
  bool _isPreparing = false;
  int _attempt = 1;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _tip = widget.tips[math.Random().nextInt(widget.tips.length)];
    _matController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
      reverseDuration: const Duration(milliseconds: 820),
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(_startLoading());
    });
  }

  Future<void> _startLoading() async {
    if (_isPreparing) return;
    setState(() {
      _isPreparing = true;
      _error = null;
      _attempt = 1;
    });

    final startedAt = DateTime.now();
    await _matController.forward();
    if (!mounted) return;

    Object? lastError;
    for (var attempt = 1; attempt <= widget.maxAttempts; attempt += 1) {
      if (!mounted) return;
      setState(() => _attempt = attempt);

      try {
        await widget.prepare(context).timeout(widget.attemptTimeout);
        final elapsed = DateTime.now().difference(startedAt);
        final remaining = widget.minimumVisibleDuration - elapsed;
        if (remaining > Duration.zero) await Future<void>.delayed(remaining);
        if (!mounted) return;

        setState(() => _showGameBehindMat = true);
        // 실제 게임을 매트 아래에 한 프레임 먼저 배치합니다. TickerMode가 꺼져
        // 있으므로 게임 애니메이션은 매트가 완전히 사라진 뒤부터 시작됩니다.
        await WidgetsBinding.instance.endOfFrame;
        if (!mounted) return;
        await _matController.reverse();
        if (!mounted) return;
        setState(() {
          _isReady = true;
          _isPreparing = false;
        });
        return;
      } catch (error) {
        lastError = error;
        if (attempt < widget.maxAttempts) {
          await Future<void>.delayed(Duration(milliseconds: 350 * attempt));
        }
      }
    }

    if (!mounted) return;
    setState(() {
      _error = lastError;
      _isPreparing = false;
    });
  }

  @override
  void dispose() {
    _matController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_showGameBehindMat)
            TickerMode(
              enabled: _isReady,
              child: IgnorePointer(
                ignoring: !_isReady,
                child: widget.gameBuilder(context),
              ),
            ),
          if (!_isReady)
            AnimatedBuilder(
              animation: Listenable.merge([_matController, _pulseController]),
              builder: (context, _) {
                return MatUnrollAnimation(
                  progress: _matController.value,
                  child: _buildLoadingMat(context),
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildLoadingMat(BuildContext context) {
    final isPhone = MediaQuery.sizeOf(context).shortestSide < 600;
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final pulse = Curves.easeInOut.transform(_pulseController.value);

    return Stack(
      fit: StackFit.expand,
      children: [
        Image(image: widget.background, fit: BoxFit.cover),
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              stops: [0, 0.55, 1],
              colors: [Color(0x14000000), Color(0x26000000), Color(0xDB000000)],
            ),
          ),
        ),
        Positioned(
          left: isPhone ? 28 : 64,
          right: isPhone ? 28 : 64,
          bottom: bottomPadding + (isPhone ? 42 : 48),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (_error == null) ...[
                Opacity(
                  opacity: 0.72 + (0.28 * pulse),
                  child: Text(
                    _attempt > 1
                        ? '연결 재시도 중 ($_attempt/${widget.maxAttempts})'
                        : '로딩 중...',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: isPhone ? 20 : 25,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                      shadows: const [
                        Shadow(color: Colors.black, blurRadius: 12),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 18),
              ] else ...[
                const Text(
                  '게임 정보를 불러오지 못했습니다',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _isPreparing
                      ? null
                      : () => unawaited(_startLoading()),
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF6D397F),
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('다시 시도'),
                ),
                const SizedBox(height: 18),
              ],
              Text(
                '게임 꿀팁',
                style: TextStyle(
                  color: const Color(0xFFE7C8F2),
                  fontSize: isPhone ? 15 : 18,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.6,
                  shadows: const [Shadow(color: Colors.black, blurRadius: 10)],
                ),
              ),
              const SizedBox(height: 7),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: isPhone ? 430 : 760),
                child: Text(
                  _tip,
                  textAlign: TextAlign.center,
                  maxLines: isPhone ? 3 : 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFEDE7F0),
                    fontSize: isPhone ? 14 : 17,
                    height: 1.45,
                    fontWeight: FontWeight.w500,
                    shadows: const [
                      Shadow(color: Colors.black, blurRadius: 10),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
