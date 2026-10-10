// [game_connection_led.dart] 는 게임 휴대폰 화면 맨 아래에 서버 연결 상태를 LED 전광판처럼 알리는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [Widget] : 끊김(oFF) → 다시 연결 중(2-5) → 복구(on)를 한 줄 LED 띠로 보여 줌
//
// 즉, 네 게임이 같은 구조의 연결 알림을 각자의 색으로 보여 주기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:flutter/material.dart';
import 'package:game_kit/recovery/widgets/connection_notice_host.dart';

export 'package:game_kit/recovery/widgets/connection_notice_host.dart'
    show ConnectionNoticePhase;

// ============================================================

/// 게임별 LED 띠 색과 문구입니다(시안 '서버 연결 알림 · 하단 LED 띠').
///
/// 구조는 네 게임이 같고, 바탕·숫자·글씨 색과 문구만 게임마다 다릅니다.
@immutable
class GameConnectionLedStyle {
  const GameConnectionLedStyle({
    required this.background,
    required this.offColor,
    required this.retryColor,
    required this.onColor,
    required this.textColor,
    this.topLineColor,
    this.dividerColor = const Color(0x33FFFFFF),
    this.lostLabel = '연결이 끊겼어요',
    this.reconnectingLabel = '다시 연결하는 중…',
    this.restoredLabel = '다시 연결됐어요',
    this.fontFamily,
    this.fontPackage,
  });

  /// 라이어스 포커 기본형입니다. 타이머와 같은 LED 전광판입니다.
  static const classic = GameConnectionLedStyle(
    background: Color(0xFF0D0A0C),
    topLineColor: Color(0x22FFFFFF),
    offColor: Color(0xFFFF4B3E),
    retryColor: Color(0xFFFFB627),
    onColor: Color(0xFF3BE38F),
    textColor: Color(0xFFE9E3DA),
  );

  final Color background;

  /// 위쪽 가는 선 색입니다(홀덤: 금색 빛 한 줄). 없으면 그리지 않습니다.
  final Color? topLineColor;

  /// 끊김(`oFF`) 숫자 색입니다.
  final Color offColor;

  /// 다시 연결 중(`2-5`) 숫자 색입니다.
  final Color retryColor;

  /// 복구(`on`) 숫자 색입니다.
  final Color onColor;

  /// 문구 색입니다.
  final Color textColor;
  final Color dividerColor;
  final String lostLabel;
  final String reconnectingLabel;
  final String restoredLabel;

  /// 문구 글꼴입니다(게임 본문 글꼴). 숫자는 늘 LED 글꼴입니다.
  final String? fontFamily;
  final String? fontPackage;
}

/// 게임 휴대폰 화면 맨 아래 LED 연결 띠를 얹습니다.
///
/// 로비는 MosiConnectionBandHost를 씁니다. 이 위젯은 게임 화면 전용입니다.
class GameConnectionLedHost extends StatelessWidget {
  const GameConnectionLedHost({
    super.key,
    required this.child,
    required this.connectionChanges,
    this.style = GameConnectionLedStyle.classic,
  });

  final Widget child;
  final Stream<bool>? connectionChanges;
  final GameConnectionLedStyle style;

  @override
  Widget build(BuildContext context) => ConnectionNoticeHost(
    connectionChanges: connectionChanges,
    builder: (context, phase, step) =>
        GameConnectionLed(phase: phase, step: step, style: style),
    child: child,
  );
}

/// LED 띠 한 줄입니다. 아래 안전 영역까지 바탕이 채워집니다.
class GameConnectionLed extends StatelessWidget {
  const GameConnectionLed({
    super.key,
    required this.phase,
    required this.style,
    this.step = 1,
    this.maxSteps = 5,
  });

  final ConnectionNoticePhase phase;
  final GameConnectionLedStyle style;

  /// 다시 연결 중 단계입니다(`2-5`의 2).
  final int step;
  final int maxSteps;

  /// 띠 높이입니다(안전 영역 제외).
  static const double height = 24;

  /// LED 숫자 글꼴입니다. 앱이 번들한 7세그먼트 글꼴입니다.
  static const String digitalFamily = 'DigitalTimer';

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final (code, codeColor, label) = switch (phase) {
      ConnectionNoticePhase.lost ||
      ConnectionNoticePhase.hidden => ('oFF', style.offColor, style.lostLabel),
      ConnectionNoticePhase.reconnecting => (
        '$step-$maxSteps',
        style.retryColor,
        style.reconnectingLabel,
      ),
      ConnectionNoticePhase.restored => (
        'on',
        style.onColor,
        style.restoredLabel,
      ),
    };
    return Semantics(
      liveRegion: true,
      label: label,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: style.background,
          border: style.topLineColor == null
              ? null
              : Border(top: BorderSide(color: style.topLineColor!)),
        ),
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: SizedBox(
            height: height,
            child: Center(
              // 좁은 화면에서도 넘치지 않게 한 줄을 그대로 줄여 맞춥니다.
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _LedCode(code: code, color: codeColor),
                    Container(
                      width: 1,
                      height: 11,
                      margin: const EdgeInsets.symmetric(horizontal: 8),
                      color: style.dividerColor,
                    ),
                    AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: Text(
                        label,
                        key: ValueKey(label),
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: style.fontFamily,
                          package: style.fontPackage,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: style.textColor,
                          height: 1.2,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 빛이 번지는 LED 숫자입니다. 바뀔 때 한 번 깜빡입니다.
class _LedCode extends StatelessWidget {
  const _LedCode({required this.code, required this.color});

  final String code;
  final Color color;

  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
    key: ValueKey(code),
    tween: Tween(begin: 0.25, end: 1),
    duration: const Duration(milliseconds: 320),
    builder: (context, glow, child) => Opacity(opacity: glow, child: child),
    child: Text(
      code,
      style: TextStyle(
        fontFamily: GameConnectionLed.digitalFamily,
        fontSize: 16,
        height: 1.1,
        color: color,
        shadows: [Shadow(color: color.withValues(alpha: 0.7), blurRadius: 6)],
      ),
    ),
  );
}
