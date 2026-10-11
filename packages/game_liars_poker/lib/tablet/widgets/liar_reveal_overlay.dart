// [liar_reveal_overlay.dart] LIAR로 거짓이 밝혀졌을 때 태블릿 테이블 위에
// 조명을 낮추고 직전 카드를 한 장씩 뒤집어 판정을 보여 주는 파일이다.
//
// 0.0s 테이블이 어두워지고 스포트라이트가 켜짐
// 0.3s 직전에 낸 카드가 떠올라 가운데로 커짐
// 0.7s 0.35초 간격으로 한 장씩 뒤집힘
// 마지막 카드가 뒤집히면 LIAR!가 내려찍히고 진실/거짓 표시와 판정 띠가 올라옴

// ========================[ import ]==========================
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_liars_poker/game_theme.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_liars_poker/game_copy.dart';
import 'package:game_liars_poker/shared/widgets/noir_ui.dart';
import 'package:game_liars_poker/tablet/screens/card_presentation.dart';
import 'package:game_liars_poker/tablet/widgets/seat_plate.dart';

// ============================================================

/// 판정 화면에 보여 줄 사람 한 명입니다.
@immutable
class TabletRevealPerson {
  const TabletRevealPerson({
    required this.nickname,
    required this.characterId,
    this.penaltyCount = 0,
  });

  final String nickname;
  final String characterId;
  final int penaltyCount;
}

class TabletLiarRevealOverlay extends StatefulWidget {
  const TabletLiarRevealOverlay({
    super.key,
    required this.tableCardValue,
    required this.cardValues,
    required this.caught,
    this.caller,
  });

  final String tableCardValue;

  /// 공개된 실제 카드(`A`, `Q`, `JOKER` ...)입니다.
  final List<String> cardValues;

  /// 거짓이 들켜 룰렛을 돌리는 사람입니다.
  final TabletRevealPerson caught;

  /// LIAR를 외친 사람입니다. 재접속 직후에는 모를 수 있습니다.
  final TabletRevealPerson? caller;

  @override
  State<TabletLiarRevealOverlay> createState() =>
      _TabletLiarRevealOverlayState();
}

class _TabletLiarRevealOverlayState extends State<TabletLiarRevealOverlay>
    with SingleTickerProviderStateMixin {
  static const _dim = 300;
  static const _rise = 400;
  static const _flipGap = 350;
  static const _slam = 450;
  static const _band = 400;

  late final int _flipsEnd = _dim + _rise + widget.cardValues.length * _flipGap;
  late final AnimationController _timeline = AnimationController(
    vsync: this,
    duration: Duration(milliseconds: _flipsEnd + _slam + _band),
  )..forward();

  double _phase(int startMs, int lengthMs, [Curve curve = Curves.easeOut]) {
    final total = _timeline.duration!.inMilliseconds;
    final t = (_timeline.value * total - startMs) / lengthMs;
    return curve.transform(t.clamp(0.0, 1.0));
  }

  bool _isTruth(String value) {
    final upper = value.toUpperCase();
    return upper == widget.tableCardValue.toUpperCase() || upper == 'JOKER';
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final board = constraints.biggest;
          final unit = tabletDesignScale(board);
          return AnimatedBuilder(
            animation: _timeline,
            builder: (context, _) {
              final dim = _phase(0, _dim);
              final slam = _phase(_flipsEnd, _slam, Curves.easeOutBack);
              final judged = _phase(_flipsEnd, 200);
              final band = _phase(
                _flipsEnd + _slam ~/ 2,
                _band,
                Curves.easeOutCubic,
              );
              final shake = judged > 0 && judged < 1
                  ? math.sin(judged * math.pi * 6) * 6 * (1 - judged)
                  : 0.0;
              return Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: dim,
                    child: const ColoredBox(color: Color(0x8C0D0912)),
                  ),
                  Opacity(
                    opacity: .5 + .5 * judged,
                    child: ClipPath(
                      clipper: _SpotlightClipper(.44 - .02 * judged),
                      child: ColoredBox(
                        color: LiarsPokerColors.ivory.withValues(
                          alpha: .04 + .03 * judged,
                        ),
                      ),
                    ),
                  ),
                  Center(
                    child: SizedBox.fromSize(
                      size: tabletDesignSize * unit,
                      child: FittedBox(
                        child: SizedBox.fromSize(
                          size: tabletDesignSize,
                          child: Transform.translate(
                            offset: Offset(shake, 0),
                            child: _buildContent(dim, slam, judged, band),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildContent(double dim, double slam, double judged, double band) {
    final values = widget.cardValues;
    final caller = widget.caller;
    final caught = widget.caught;
    return Stack(
      children: [
        // 외친 사람과 LIAR! 입니다.
        Positioned(
          left: 0,
          right: 0,
          top: 40,
          child: Column(
            children: [
              Opacity(
                opacity: judged,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(6, 6, 18, 6),
                  decoration: BoxDecoration(
                    color: LiarsPokerColors.panel,
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: LiarsPokerColors.panelEdge,
                      width: 2,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      NoirAvatar(
                        characterId: caller?.characterId ?? caught.characterId,
                        size: 40,
                      ),
                      const SizedBox(width: 10),
                      Text.rich(
                        TextSpan(
                          children: [
                            if (caller != null) ...[
                              TextSpan(
                                text: caller.nickname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '${liarsPokerSubjectParticle(caller.nickname)} ',
                              ),
                            ],
                            TextSpan(
                              text:
                                  '${caught.nickname}의 "${widget.tableCardValue.toUpperCase()} ${values.length}장"을 의심했어요',
                            ),
                          ],
                        ),
                        style: LiarsPokerFonts.text(size: 17),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Opacity(
                opacity: (.28 + .72 * slam).clamp(0.0, 1.0),
                child: Transform.scale(
                  scale: 1.4 - .4 * slam,
                  child: const NoirLiarMark(size: 120),
                ),
              ),
            ],
          ),
        ),
        // 공개된 카드입니다.
        Positioned(
          left: 0,
          right: 0,
          top: 300,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var index = 0; index < values.length; index++) ...[
                if (index > 0) const SizedBox(width: 46),
                _buildCard(index, values[index], judged),
              ],
            ],
          ),
        ),
        // 판정 띠입니다.
        Positioned(
          left: 0,
          right: 0,
          top: 640,
          child: Opacity(
            opacity: band,
            child: Transform.translate(
              offset: Offset(0, 40 * (1 - band)),
              child: Column(
                children: [
                  Text(
                    '거짓이 밝혀졌습니다.',
                    style: LiarsPokerFonts.headline(size: 34),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.fromLTRB(8, 8, 22, 8),
                    decoration: BoxDecoration(
                      color: LiarsPokerColors.panelRaised,
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: LiarsPokerColors.red, width: 2),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        NoirAvatar(
                          characterId: caught.characterId,
                          size: 48,
                          ringColor: LiarsPokerColors.red,
                          ringWidth: 3,
                        ),
                        const SizedBox(width: 14),
                        Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: caught.nickname,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              TextSpan(
                                text:
                                    '${liarsPokerSubjectParticle(caught.nickname)} 룰렛을 돌립니다',
                              ),
                            ],
                          ),
                          style: LiarsPokerFonts.text(size: 19),
                        ),
                        const SizedBox(width: 14),
                        NoirOddsPill(
                          penaltyCount: caught.penaltyCount,
                          fontSize: 15,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCard(int index, String value, double judged) {
    final rise = _phase(_dim, _rise, Curves.easeOutCubic);
    final flip = _phase(
      _dim + _rise + index * _flipGap,
      _flipGap,
      Curves.easeInOut,
    );
    final faceUp = flip >= .5;
    final squash = (1 - flip * 2).abs();
    final truth = _isTruth(value);
    final tilt = (index - (widget.cardValues.length - 1) / 2) * 5;
    final ring = truth ? LiarsPokerColors.gold : LiarsPokerColors.red;
    final asset = faceUp
        ? cardAssetForValue(value)
        : Assets.games.liarsPoker.images.cards.whiteBack.game;
    final label = value.toUpperCase() == 'JOKER' ? '조커' : value.toUpperCase();
    return Opacity(
      opacity: rise,
      child: Transform.translate(
        offset: Offset(0, 60 * (1 - rise)),
        child: Transform.scale(
          scale: .7 + .3 * rise,
          child: Column(
            children: [
              SizedBox(
                width: 160,
                height: 234,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Transform.rotate(
                      angle: tilt * math.pi / 180,
                      child: Transform(
                        alignment: Alignment.center,
                        transform: Matrix4.diagonal3Values(
                          math.max(.02, squash),
                          1,
                          1,
                        ),
                        child: Container(
                          width: 160,
                          height: 234,
                          clipBehavior: Clip.antiAlias,
                          decoration: BoxDecoration(
                            color: LiarsPokerColors.ivory,
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: [
                              if (judged > 0)
                                BoxShadow(
                                  color: ring.withValues(alpha: judged),
                                  spreadRadius: 4,
                                ),
                              const BoxShadow(
                                color: Color(0x80000000),
                                blurRadius: 40,
                                offset: Offset(0, 20),
                              ),
                            ],
                          ),
                          child: asset.image(fit: BoxFit.cover),
                        ),
                      ),
                    ),
                    if (!truth && judged > 0)
                      Positioned(
                        left: 10,
                        top: 70,
                        child: Opacity(
                          opacity: judged,
                          child: Transform.scale(
                            scale: 1.6 - .6 * judged,
                            child: Transform.rotate(
                              angle: -16 * math.pi / 180,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                ),
                                decoration: BoxDecoration(
                                  color: LiarsPokerColors.ivory.withValues(
                                    alpha: .85,
                                  ),
                                  border: Border.all(
                                    color: LiarsPokerColors.red,
                                    width: 5,
                                  ),
                                ),
                                child: Text(
                                  '거짓',
                                  style: LiarsPokerFonts.headline(
                                    size: 40,
                                    color: LiarsPokerColors.red,
                                    height: 1.2,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Opacity(
                opacity: judged,
                child: Text(
                  '$label · ${truth ? '진실' : '거짓'}',
                  style: LiarsPokerFonts.text(
                    size: 16,
                    weight: FontWeight.w700,
                    color: truth
                        ? LiarsPokerColors.goldLight
                        : LiarsPokerColors.pink,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SpotlightClipper extends CustomClipper<Path> {
  const _SpotlightClipper(this.topEdge);

  /// 위쪽 빛 폭의 왼쪽 끝 비율입니다(오른쪽은 대칭).
  final double topEdge;

  @override
  Path getClip(Size size) {
    final bottomEdge = topEdge - .22;
    return Path()
      ..moveTo(size.width * topEdge, 0)
      ..lineTo(size.width * (1 - topEdge), 0)
      ..lineTo(size.width * (1 - bottomEdge), size.height)
      ..lineTo(size.width * bottomEdge, size.height)
      ..close();
  }

  @override
  bool shouldReclip(_SpotlightClipper oldClipper) =>
      topEdge != oldClipper.topEdge;
}
