import 'package:flutter/material.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/home/room/models/room_character.dart';

/// Final Call 태블릿에서 최종 승리자를 발표하는 결과 화면입니다.
///
/// 서버의 [winners]를 그대로 표시하고, 버튼 동작은 태블릿 게임
/// 진입점에서 주입한 재시작·홈 콜백을 사용합니다.
class FinalCallResultOverlay extends StatelessWidget {
  const FinalCallResultOverlay({
    super.key,
    required this.winners,
    required this.winningTeam,
    this.isDraw = false,
    this.onRestart,
    this.onHome,
    this.showActions = true,
  });

  final List<FinalCallPlayer> winners;
  final FinalCallTeam? winningTeam;
  final bool isDraw;
  final VoidCallback? onRestart;
  final VoidCallback? onHome;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: _ResultColors.paper,
      child: SafeArea(
        child: Stack(
          fit: StackFit.expand,
          children: [
            Assets.games.finalCall.images.background.background.image(
              fit: BoxFit.cover,
              filterQuality: FilterQuality.high,
            ),
            const Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(painter: _AccentPainter()),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: FittedBox(
                fit: BoxFit.contain,
                child: SizedBox(
                  width: _ResultLayout.width,
                  height: _ResultLayout.height,
                  child: _ResultContent(
                    winners: winners,
                    winningTeam: winningTeam,
                    isDraw: isDraw,
                    onRestart: onRestart,
                    onHome: onHome,
                    showActions: showActions,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

abstract final class _ResultLayout {
  static const width = 1440.0;
  static const height = 1080.0;
}

abstract final class _ResultColors {
  static const paper = Color(0xFFF8F8F6);
  static const ink = Color(0xFF061525);
  static const navy = Color(0xFF071B2C);
  static const navyLight = Color(0xFF102D44);
  static const red = Color(0xFFD20B13);
  static const redDark = Color(0xFFA70008);
  static const gold = Color(0xFFFFC423);
}

class _ResultContent extends StatelessWidget {
  const _ResultContent({
    required this.winners,
    required this.winningTeam,
    required this.isDraw,
    required this.onRestart,
    required this.onHome,
    required this.showActions,
  });

  final List<FinalCallPlayer> winners;
  final FinalCallTeam? winningTeam;
  final bool isDraw;
  final VoidCallback? onRestart;
  final VoidCallback? onHome;
  final bool showActions;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const Positioned(left: 0, right: 0, top: 76, child: _ResultTitle()),
        Positioned(
          left: 120,
          right: 94,
          top: 316,
          height: 352,
          child: _WinnerPresentation(
            winners: winners,
            winningTeam: winningTeam,
            isDraw: isDraw,
          ),
        ),
        if (showActions)
          Positioned(
            left: 246,
            right: 246,
            bottom: 74,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _AngledActionButton(
                  key: const Key('final-call-restart-button'),
                  label: '다시하기',
                  onTap: onRestart,
                  colors: const [_ResultColors.red, _ResultColors.redDark],
                ),
                _AngledActionButton(
                  key: const Key('final-call-home-button'),
                  label: 'HOME',
                  onTap: onHome,
                  colors: const [_ResultColors.navyLight, _ResultColors.navy],
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ResultTitle extends StatelessWidget {
  const _ResultTitle();

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Transform(
          transform: Matrix4.skewX(-0.08),
          alignment: Alignment.center,
          child: const Text(
            '게임 종료',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: _ResultColors.ink,
              fontSize: 118,
              height: 0.92,
              fontWeight: FontWeight.w900,
              letterSpacing: -8,
              shadows: [
                Shadow(
                  color: Color(0x25000000),
                  blurRadius: 1,
                  offset: Offset(5, 6),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 25),
        Container(
          width: 300,
          height: 5,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Colors.transparent,
                _ResultColors.red,
                Colors.transparent,
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _WinnerPresentation extends StatelessWidget {
  const _WinnerPresentation({
    required this.winners,
    required this.winningTeam,
    required this.isDraw,
  });

  final List<FinalCallPlayer> winners;
  final FinalCallTeam? winningTeam;
  final bool isDraw;

  @override
  Widget build(BuildContext context) {
    final nickname = winners
        .map((winner) => winner.nickname.trim())
        .where((nickname) => nickname.isNotEmpty)
        .join('  ·  ');
    final accentColor = winningTeam == FinalCallTeam.blue
        ? const Color(0xFF1686E8)
        : _ResultColors.red;
    final victoryLabel = isDraw
        ? '무승부'
        : winningTeam == FinalCallTeam.blue
        ? '블루팀 승리'
        : '레드팀 승리';
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 152,
          right: 0,
          top: 72,
          height: 252,
          child: CustomPaint(painter: _WinnerBannerPainter()),
        ),
        Positioned(
          left: 435,
          right: 164,
          top: 122,
          child: Column(
            children: [
              Text(
                victoryLabel,
                key: const Key('final-call-winning-team-label'),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 72,
                  height: 1,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -1.5,
                  shadows: [
                    Shadow(
                      color: Color(0x99000000),
                      blurRadius: 7,
                      offset: Offset(3, 5),
                    ),
                  ],
                ),
              ),
              if (nickname.isNotEmpty) ...[
                const SizedBox(height: 15),
                Text(
                  nickname,
                  key: const Key('final-call-winner-nickname'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Color(0xFFE4E9ED),
                    fontSize: 34,
                    height: 1,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -0.5,
                    shadows: [
                      Shadow(
                        color: Color(0x99000000),
                        blurRadius: 5,
                        offset: Offset(2, 3),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 18),
              _WinnerDivider(color: accentColor),
              const SizedBox(height: 13),
              const Text(
                'FINAL CALL WINNER',
                style: TextStyle(
                  color: Color(0xFFC7D0D8),
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 6,
                ),
              ),
            ],
          ),
        ),
        if (!isDraw)
          for (var index = 0; index < winners.take(2).length; index++)
            Positioned(
              left: winners.length > 1 ? 12 + index * 178 : 62,
              top: winners.length > 1 ? 68 : 34,
              width: winners.length > 1 ? 232 : 310,
              height: winners.length > 1 ? 232 : 310,
              child: _WinnerProfile(
                key: ValueKey('final-call-winner-profile-$index'),
                characterId: winners[index].characterId,
                accentColor: accentColor,
              ),
            ),
        if (!isDraw)
          const Positioned(
            left: 118,
            top: -32,
            width: 196,
            height: 134,
            child: IgnorePointer(child: CustomPaint(painter: _CrownPainter())),
          ),
      ],
    );
  }
}

class _WinnerDivider extends StatelessWidget {
  const _WinnerDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: SizedBox(height: 2, child: ColoredBox(color: color)),
        ),
        const SizedBox(width: 13),
        Transform.rotate(
          angle: 0.785,
          child: Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: _ResultColors.navy,
              border: Border.all(color: color, width: 3),
            ),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: SizedBox(height: 2, child: ColoredBox(color: color)),
        ),
      ],
    );
  }
}

class _WinnerProfile extends StatelessWidget {
  const _WinnerProfile({
    super.key,
    required this.characterId,
    required this.accentColor,
  });

  final String characterId;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Color(0x40000000),
            blurRadius: 26,
            offset: Offset(0, 14),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(9),
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: accentColor, width: 10),
          ),
          child: Padding(
            padding: const EdgeInsets.all(9),
            child: ClipOval(
              child: _WinnerProfileImage(characterId: characterId),
            ),
          ),
        ),
      ),
    );
  }
}

class _WinnerProfileImage extends StatelessWidget {
  const _WinnerProfileImage({required this.characterId});

  final String characterId;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      roomCharacterAssetPath(characterId),
      fit: BoxFit.contain,
      filterQuality: FilterQuality.high,
    );
  }
}

class _AngledActionButton extends StatefulWidget {
  const _AngledActionButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.colors,
  });

  final String label;
  final VoidCallback? onTap;
  final List<Color> colors;

  @override
  State<_AngledActionButton> createState() => _AngledActionButtonState();
}

class _AngledActionButtonState extends State<_AngledActionButton> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onTap != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => _setPressed(true) : null,
        onTapCancel: enabled ? () => _setPressed(false) : null,
        onTapUp: enabled
            ? (_) {
                _setPressed(false);
                widget.onTap?.call();
              }
            : null,
        child: AnimatedOpacity(
          opacity: enabled ? 1 : 0.48,
          duration: const Duration(milliseconds: 100),
          child: AnimatedSlide(
            offset: _pressed ? const Offset(0, 0.045) : Offset.zero,
            duration: const Duration(milliseconds: 100),
            curve: Curves.easeOutCubic,
            child: AnimatedScale(
              scale: _pressed ? 0.96 : 1,
              duration: const Duration(milliseconds: 100),
              curve: Curves.easeOutCubic,
              child: ClipPath(
                clipper: _ActionButtonClipper(),
                child: Container(
                  width: 420,
                  height: 104,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: widget.colors),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x40000000),
                        blurRadius: 16,
                        offset: Offset(0, 9),
                      ),
                    ],
                  ),
                  child: CustomPaint(
                    painter: const _ActionButtonPainter(),
                    child: Center(
                      child: Text(
                        widget.label,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 43,
                          height: 1,
                          fontWeight: FontWeight.w900,
                          fontStyle: FontStyle.italic,
                          letterSpacing: -1,
                          shadows: [
                            Shadow(
                              color: Color(0x88000000),
                              blurRadius: 4,
                              offset: Offset(2, 3),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionButtonClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) => Path()
    ..moveTo(32, 0)
    ..lineTo(size.width, 0)
    ..lineTo(size.width - 34, size.height)
    ..lineTo(0, size.height)
    ..close();

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _ActionButtonPainter extends CustomPainter {
  const _ActionButtonPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final border = Paint()
      ..color = Colors.white.withValues(alpha: 0.85)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3;
    final path = Path()
      ..moveTo(42, 9)
      ..lineTo(size.width - 12, 9)
      ..lineTo(size.width - 42, size.height - 9)
      ..lineTo(13, size.height - 9)
      ..close();
    canvas.drawPath(path, border);

    final accent = Paint()
      ..color = Colors.white.withValues(alpha: 0.92)
      ..strokeWidth = 5;
    canvas.drawLine(
      Offset(size.width - 72, size.height - 6),
      Offset(size.width - 42, size.height - 6),
      accent,
    );
    canvas.drawLine(
      Offset(size.width - 48, size.height - 6),
      Offset(size.width - 19, size.height - 6),
      accent,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WinnerBannerPainter extends CustomPainter {
  const _WinnerBannerPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final bannerPath = Path()
      ..moveTo(58, 6)
      ..lineTo(size.width - 104, 6)
      ..lineTo(size.width - 224, size.height - 6)
      ..lineTo(0, size.height - 6)
      ..close();
    final bannerPaint = Paint()
      ..shader = const LinearGradient(
        colors: [_ResultColors.navy, Color(0xFF0A2033), Color(0xFF06131F)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(bannerPath, bannerPaint);

    final topLine = Paint()
      ..color = const Color(0xFFB9C5CE)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(size.width * 0.67, 0),
      Offset(size.width * 0.85, 0),
      topLine,
    );

    final red = Paint()..color = _ResultColors.red;
    final firstStripe = Path()
      ..moveTo(size.width - 94, 6)
      ..lineTo(size.width - 42, 6)
      ..lineTo(size.width - 162, size.height - 6)
      ..lineTo(size.width - 214, size.height - 6)
      ..close();
    canvas.drawPath(firstStripe, red);
    final secondStripe = Path()
      ..moveTo(size.width - 31, 6)
      ..lineTo(size.width, 6)
      ..lineTo(size.width - 120, size.height - 6)
      ..lineTo(size.width - 151, size.height - 6)
      ..close();
    canvas.drawPath(secondStripe, red);

    final detail = Paint()
      ..color = Colors.white.withValues(alpha: 0.8)
      ..strokeWidth = 3;
    canvas.drawLine(
      Offset(size.width - 172, 28),
      Offset(size.width - 208, 103),
      detail,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final crown = Path()
      ..moveTo(size.width * 0.12, size.height * 0.76)
      ..lineTo(size.width * 0.06, size.height * 0.28)
      ..lineTo(size.width * 0.34, size.height * 0.52)
      ..lineTo(size.width * 0.50, size.height * 0.10)
      ..lineTo(size.width * 0.66, size.height * 0.52)
      ..lineTo(size.width * 0.94, size.height * 0.28)
      ..lineTo(size.width * 0.88, size.height * 0.76)
      ..close();
    final fill = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFFF18B), _ResultColors.gold, Color(0xFFE18400)],
      ).createShader(Offset.zero & size);
    final outline = Paint()
      ..color = const Color(0xFFB56300)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4;
    canvas.drawShadow(crown, const Color(0x77000000), 8, true);
    canvas.drawPath(crown, fill);
    canvas.drawPath(crown, outline);

    final band = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        size.width * 0.11,
        size.height * 0.70,
        size.width * 0.78,
        size.height * 0.18,
      ),
      const Radius.circular(8),
    );
    canvas.drawRRect(band, fill);
    canvas.drawRRect(band, outline);

    final jewel = Paint()..color = _ResultColors.red;
    for (final x in [0.28, 0.50, 0.72]) {
      final center = Offset(size.width * x, size.height * 0.76);
      final path = Path()
        ..moveTo(center.dx, center.dy - 8)
        ..lineTo(center.dx + 7, center.dy)
        ..lineTo(center.dx, center.dy + 8)
        ..lineTo(center.dx - 7, center.dy)
        ..close();
      canvas.drawPath(path, jewel);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AccentPainter extends CustomPainter {
  const _AccentPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final navy = Paint()
      ..color = _ResultColors.navy.withValues(alpha: 0.055)
      ..strokeWidth = 2;
    final red = Paint()
      ..color = _ResultColors.red.withValues(alpha: 0.08)
      ..strokeWidth = 4;
    canvas.drawLine(
      Offset(size.width * 0.02, size.height * 0.34),
      Offset(size.width * 0.22, size.height * 0.03),
      navy,
    );
    canvas.drawLine(
      Offset(size.width * 0.04, size.height * 0.38),
      Offset(size.width * 0.24, size.height * 0.07),
      red,
    );
    canvas.drawLine(
      Offset(size.width * 0.80, size.height * 0.93),
      Offset(size.width * 0.98, size.height * 0.66),
      navy,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
