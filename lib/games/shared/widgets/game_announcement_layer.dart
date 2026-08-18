import 'package:flutter/material.dart';
import 'package:project00/games/shared/animations/fade_hold_fade.dart';
import 'package:project00/games/shared/animations/phone_game_start_animation.dart';
import 'package:project00/games/shared/game_flow/game_announcement.dart';

/// 모든 게임에서 동일한 위치에 유지하는 문구 레이어의 시각 설정입니다.
@immutable
class GameAnnouncementStyle {
  const GameAnnouncementStyle({
    this.neutralColor = Colors.white,
    this.positiveColor = const Color(0xFF34C759),
    this.negativeColor = const Color(0xFFFF3B30),
    this.fontFamily = 'BebasNeue',
    this.fontSize = 48,
    this.gameStartFontSize = 58,
    this.fontWeight = FontWeight.w700,
    this.height = 1.15,
    this.letterSpacing = 3,
    this.textAlign = TextAlign.center,
    this.shadows = const [Shadow(color: Colors.black87, blurRadius: 14)],
    this.scrimColor = const Color(0x66000000),
    this.beginScale = 1,
    this.endScale = 1,
  });

  const GameAnnouncementStyle.phone({Color textColor = Colors.white})
    : this(neutralColor: textColor, fontSize: 48);

  const GameAnnouncementStyle.tablet({Color textColor = Colors.white})
    : this(
        neutralColor: textColor,
        fontSize: 58,
        letterSpacing: 3.2,
        shadows: const [Shadow(color: Colors.black87, blurRadius: 18)],
      );

  final Color neutralColor;
  final Color positiveColor;
  final Color negativeColor;
  final String? fontFamily;
  final double fontSize;
  final double gameStartFontSize;
  final FontWeight fontWeight;
  final double height;
  final double letterSpacing;
  final TextAlign textAlign;
  final List<Shadow> shadows;
  final Color scrimColor;
  final double beginScale;
  final double endScale;

  Color colorFor(GameAnnouncementTone tone) => switch (tone) {
    GameAnnouncementTone.neutral => neutralColor,
    GameAnnouncementTone.positive => positiveColor,
    GameAnnouncementTone.negative => negativeColor,
  };

  TextStyle textStyleFor(GameAnnouncement announcement) => TextStyle(
    fontFamily: fontFamily,
    color: colorFor(announcement.tone),
    fontSize: announcement.kind == GameAnnouncementKind.gameStart
        ? gameStartFontSize
        : fontSize,
    fontWeight: fontWeight,
    height: height,
    letterSpacing: letterSpacing,
    shadows: shadows,
  );
}

/// `GAME START`, `ROUND N`, 상태 안내와 판정 문구를 한 슬롯에서 렌더링합니다.
///
/// 부모의 `Stack`에 이 위젯을 항상 유지하고 [announcement]만 교체하면, 문구가
/// 바뀔 때 게임 보드와 카드 애니메이션 State가 제거되거나 다시 생성되지 않습니다.
/// 이 레이어는 시각적 안내만 담당하며 모든 포인터 이벤트를 하위 게임 UI로
/// 통과시킵니다.
class GameAnnouncementLayer extends StatelessWidget {
  const GameAnnouncementLayer({
    super.key,
    required this.announcement,
    this.style = const GameAnnouncementStyle(),
    this.alignment = Alignment.center,
    this.padding = const EdgeInsets.symmetric(horizontal: 32),
    this.offset = Offset.zero,
    this.displayDuration,
    this.onCompleted,
  });

  final GameAnnouncement? announcement;
  final GameAnnouncementStyle style;
  final Alignment alignment;
  final EdgeInsetsGeometry padding;
  final Offset offset;

  /// 모델의 기본 시간 대신 이 레이어에서 표시할 시간을 일괄 지정합니다.
  final Duration? displayDuration;
  final ValueChanged<GameAnnouncement>? onCompleted;

  @override
  Widget build(BuildContext context) {
    final current = announcement;
    return IgnorePointer(
      ignoring: true,
      child: ColoredBox(
        color: current?.showScrim == true
            ? style.scrimColor
            : Colors.transparent,
        child: Padding(
          padding: padding,
          child: Align(
            alignment: alignment,
            child: Transform.translate(
              offset: offset,
              child: current == null
                  ? const SizedBox.shrink()
                  : _buildAnnouncement(current),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncement(GameAnnouncement current) {
    final textStyle = style.textStyleFor(current);
    final duration = displayDuration ?? current.duration;
    if (!current.animate && current.kind != GameAnnouncementKind.persistent) {
      return _StaticTimedAnnouncement(
        key: ValueKey(current.id),
        duration: duration,
        onCompleted: () => onCompleted?.call(current),
        child: Text(current.text, textAlign: style.textAlign, style: textStyle),
      );
    }
    return switch (current.kind) {
      GameAnnouncementKind.gameStart => PhoneGameStartAnimation(
        key: ValueKey(current.id),
        text: current.text,
        textStyle: textStyle,
        duration: duration,
        onCompleted: () => onCompleted?.call(current),
      ),
      GameAnnouncementKind.round ||
      GameAnnouncementKind.transient => FadeHoldFade(
        key: ValueKey(current.id),
        duration: duration,
        beginScale: style.beginScale,
        endScale: style.endScale,
        onCompleted: () => onCompleted?.call(current),
        child: Text(current.text, textAlign: style.textAlign, style: textStyle),
      ),
      GameAnnouncementKind.persistent => Text(
        current.text,
        key: ValueKey(current.id),
        textAlign: style.textAlign,
        style: textStyle,
      ),
    };
  }
}

/// 애니메이션을 끈 문구도 유지시간 후 정상적으로 단계를 완료하게 합니다.
///
/// 단순 [Text]만 반환하면 완료 콜백이 호출되지 않아 `GAME START` 또는
/// `ROUND N` 단계에 영구적으로 머무를 수 있으므로 별도 타이머가 필요합니다.
class _StaticTimedAnnouncement extends StatefulWidget {
  const _StaticTimedAnnouncement({
    super.key,
    required this.child,
    required this.duration,
    required this.onCompleted,
  });

  final Widget child;
  final Duration duration;
  final VoidCallback onCompleted;

  @override
  State<_StaticTimedAnnouncement> createState() =>
      _StaticTimedAnnouncementState();
}

class _StaticTimedAnnouncementState extends State<_StaticTimedAnnouncement> {
  @override
  void initState() {
    super.initState();
    Future<void>.delayed(widget.duration, () {
      if (mounted) widget.onCompleted();
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
