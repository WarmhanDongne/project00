import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:game_holdem/game_theme.dart';
import 'package:game_holdem/shared/widgets/card_view.dart';
import 'package:game_holdem/shared/widgets/table_ui.dart';
import 'package:game_kit/localization/game_locale.dart';

/// 좌석에서 테이블 중앙으로 이동하는 홀덤 행동 연출입니다.
///
/// 베팅은 좌석 앞의 칩 더미가 중앙 방향으로 쓰러진 뒤 칩이 하나씩 미끄러져
/// 테이블 중앙에 던져집니다. 폴드는 두 장의 카드가 중앙으로 미끄러져 사라집니다.
/// 체크는 중앙으로 아무것도 보내지 않고 좌석 프로필 옆 표시로만 알립니다.
/// 올인은 칩 이동 위에 충격파·불꽃·'ALL IN' 띠를 더해 크게 보여 줍니다.
class HoldemTableActionMotion extends StatelessWidget {
  const HoldemTableActionMotion({
    super.key,
    required this.progress,
    required this.kind,
    required this.amount,
    required this.source,
    required this.potTarget,
    required this.tableCenter,
    required this.scale,
  });

  final Animation<double> progress;
  final String kind;
  final int amount;
  final Offset source;
  final Offset potTarget;
  final Offset tableCenter;
  final double scale;

  bool get _movesChips =>
      const {'blind', 'bet', 'call', 'raise', 'allIn'}.contains(kind);

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: progress,
        builder: (_, _) {
          if (kind == 'fold') return _buildFold();
          if (_movesChips) return _buildChips();
          return const SizedBox.expand();
        },
      ),
    ),
  );

  Widget _buildChips() {
    final value = progress.value;
    final count = _chipCount(amount);
    return Semantics(
      label: kind == 'blind'
          ? GameLocale.select(
              ko: '블라인드 칩 이동',
              en: 'Blind chips moving',
              zhHans: '盲注筹码移动',
              zhHant: '盲注籌碼移動',
            )
          : GameLocale.select(
              ko: '베팅 칩 이동',
              en: 'Bet chips moving',
              zhHans: '下注筹码移动',
              zhHant: '下注籌碼移動',
            ),
      excludeSemantics: true,
      child: SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            if (kind == 'allIn') ..._allInBurst(value),
            for (var index = 0; index < count; index++)
              _animatedChip(index, count, value),
            if (amount > 0) _animatedAmount(value),
            if (kind == 'allIn') _allInBanner(value),
          ],
        ),
      ),
    );
  }

  Widget _animatedChip(int index, int count, double value) {
    const landingOffsets = [
      Offset(-10, 1),
      Offset(7, -5),
      Offset(-4, 7),
      Offset(12, 4),
      Offset(-13, -6),
      Offset(3, 10),
      Offset(15, -8),
      Offset(-8, 12),
      Offset(1, -12),
    ];
    const settledOffsets = [
      Offset(-46, 5),
      Offset(-29, -3),
      Offset(-13, 7),
      Offset(4, -5),
      Offset(20, 6),
      Offset(37, -2),
      Offset(-20, 12),
      Offset(12, 13),
      Offset(48, 10),
    ];
    final toCenter = tableCenter - source;
    final distance = math.max(toCenter.distance, 1.0).toDouble();
    final direction = toCenter / distance;
    final tangent = Offset(-direction.dy, direction.dx);
    final stackStart = source - Offset(0, index * 5.2 * scale);
    final fallen =
        source +
        direction * (index * 8.5 * scale) +
        tangent * ((index.isEven ? -1 : 1) * 2.2 * scale);

    // 먼저 쌓인 칩 전체가 투척 방향으로 넘어지고, 아래쪽 칩부터 순서대로
    // 빠져나가 중앙으로 미끄러집니다.
    final tip = _interval(value, 0, .22, Curves.easeInCubic);
    final delay = .18 + index * .025;
    final travel = _interval(
      value,
      delay,
      .61 + index * .012,
      Curves.easeOutCubic,
    );
    final settle = _interval(
      value,
      .68 + index * .015,
      .93,
      Curves.easeOutCubic,
    );
    final launch = Offset.lerp(stackStart, fallen, tip)!;
    final landing = tableCenter + landingOffsets[index] * scale;
    final curveSide = index.isEven ? 1.0 : -1.0;
    final control =
        Offset.lerp(fallen, landing, .5)! +
        tangent * (12 + index % 3 * 4) * scale * curveSide;
    var position = _quadratic(launch, control, landing, travel);
    position = Offset.lerp(
      position,
      potTarget + settledOffsets[index] * scale,
      settle,
    )!;

    final exit = _interval(value, .94, 1, Curves.easeIn);
    final slideLift = math.sin(travel * math.pi);
    final chipSize = 28 * scale;
    final fallAngle = math.atan2(direction.dy, direction.dx) + math.pi / 2;
    final rotation =
        fallAngle * tip * (1 - travel) +
        (index.isEven ? .32 : -.28) * slideLift +
        (index - count / 2) * .018 * settle;
    final sizeScale = .9 + slideLift * .12 - settle * .03;

    return Positioned(
      left: position.dx - chipSize / 2,
      top: position.dy - chipSize / 2,
      width: chipSize,
      height: chipSize + 5 * scale,
      child: Opacity(
        opacity: (1 - exit).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: sizeScale,
            child: HoldemChip(size: chipSize),
          ),
        ),
      ),
    );
  }

  Widget _animatedAmount(double value) {
    final appear = _interval(value, .34, .5, Curves.easeOut);
    final exit = _interval(value, .82, 1, Curves.easeIn);
    final position = Offset.lerp(
      source,
      tableCenter + Offset(0, -62 * scale),
      _interval(value, .2, .66, Curves.easeOutCubic),
    )!;
    return Positioned(
      left: position.dx - 70 * scale,
      top: position.dy - 18 * scale,
      width: 140 * scale,
      child: Opacity(
        opacity: (appear * (1 - exit)).clamp(0.0, 1.0),
        child: Text(
          '+${holdemChips(amount)}',
          textAlign: TextAlign.center,
          style: HoldemFonts.numbers(size: 25 * scale).copyWith(
            shadows: const [Shadow(color: Color(0xB3000000), blurRadius: 10)],
          ),
        ),
      ),
    );
  }

  Widget _buildFold() {
    final value = progress.value;
    return Semantics(
      label: GameLocale.select(
        ko: '폴드 카드 이동',
        en: 'Folded cards moving',
        zhHans: '弃牌移动',
        zhHant: '棄牌移動',
      ),
      excludeSemantics: true,
      child: SizedBox.expand(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            for (var index = 0; index < 2; index++) _foldCard(index, value),
          ],
        ),
      ),
    );
  }

  Widget _foldCard(int index, double value) {
    final delay = index * .055;
    final travel = _interval(value, delay, .73 + delay, Curves.easeOutCubic);
    final fade = _interval(value, .66 + delay, .96, Curves.easeInCubic);
    final start = source + Offset((index * 2 - 1) * 12 * scale, 0);
    final target = tableCenter + Offset((index * 2 - 1) * 9 * scale, 0);
    final direction = target - start;
    final distance = math.max(direction.distance, 1.0).toDouble();
    final tangent = Offset(-direction.dy, direction.dx) / distance;
    final control =
        Offset.lerp(start, target, .46)! +
        tangent * (index == 0 ? -38 : 38) * scale;
    final position = _quadratic(start, control, target, travel);
    final width = 50 * scale;
    final rotation =
        (index == 0 ? -.12 : .1) + travel * (index == 0 ? -.8 : .75);
    final lift = math.sin(travel * math.pi);

    return Positioned(
      left: position.dx - width / 2,
      top: position.dy - width * .7 - lift * 18 * scale,
      child: Opacity(
        opacity: (1 - fade).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: rotation,
          child: Transform.scale(
            scale: 1 - fade * .42,
            child: HoldemCardView(width: width, faceDown: true),
          ),
        ),
      ),
    );
  }

  /// 칩이 중앙에 닿을 때 퍼지는 금빛 충격파와 불꽃입니다.
  List<Widget> _allInBurst(double value) {
    final wave = _interval(value, .55, .95, Curves.easeOutCubic);
    final glow =
        _interval(value, .05, .5, Curves.easeOut) *
        (1 - _interval(value, .8, 1, Curves.easeIn));
    final ringSize = (80 + 340 * wave) * scale;
    return [
      // 테이블 전체가 잠깐 금빛으로 달아오릅니다.
      Positioned(
        left: tableCenter.dx - 320 * scale,
        top: tableCenter.dy - 220 * scale,
        width: 640 * scale,
        height: 440 * scale,
        child: Opacity(
          opacity: (glow * .55).clamp(0.0, 1.0),
          child: const DecoratedBox(
            decoration: BoxDecoration(
              gradient: RadialGradient(
                colors: [Color(0xCCFFD45C), Color(0x00FFD45C)],
              ),
            ),
          ),
        ),
      ),
      Positioned(
        left: tableCenter.dx - ringSize / 2,
        top: tableCenter.dy - ringSize / 2,
        width: ringSize,
        height: ringSize,
        child: Opacity(
          opacity: (wave > 0 ? 1.0 - wave : 0.0).clamp(0.0, 1.0),
          child: DecoratedBox(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFFFFD45C),
                width: 10 * scale * (1 - wave) + 2,
              ),
            ),
          ),
        ),
      ),
      for (var i = 0; i < 14; i++) _spark(i, value),
    ];
  }

  Widget _spark(int index, double value) {
    final start = .58 + (index % 3) * .02;
    final fly = _interval(value, start, start + .3, Curves.easeOutCubic);
    if (fly <= 0) return const SizedBox.shrink();
    final angle = index / 14 * 2 * math.pi + (index.isEven ? .12 : -.08);
    final reach = (150 + (index % 4) * 38) * scale;
    final position =
        tableCenter + Offset(math.cos(angle), math.sin(angle)) * reach * fly;
    final size = (index.isEven ? 12 : 8) * scale;
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2,
      width: size,
      height: size,
      child: Opacity(
        opacity: (1 - fly).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: angle + fly * 3,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: index % 3 == 0 ? Colors.white : const Color(0xFFFFD45C),
              borderRadius: BorderRadius.circular(2),
              boxShadow: const [
                BoxShadow(color: Color(0xAAFFD45C), blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// 테이블 위로 쾅 내려앉는 'ALL IN' 띠입니다.
  Widget _allInBanner(double value) {
    final slam = _interval(value, .04, .26, Curves.easeOutBack);
    final exit = _interval(value, .86, 1, Curves.easeIn);
    final shake = value > .24 && value < .4
        ? math.sin((value - .24) * 90) * 8 * (1 - (value - .24) / .16)
        : 0.0;
    final width = 420 * scale;
    final height = 110 * scale;
    return Positioned(
      left: tableCenter.dx - width / 2 + shake * scale,
      top: tableCenter.dy - 210 * scale,
      width: width,
      height: height,
      child: Opacity(
        opacity: (slam.clamp(0.0, 1.0) * (1 - exit)).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: -.06,
          child: Transform.scale(
            scale: 2.2 - 1.2 * slam,
            child: Container(
              alignment: Alignment.center,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE08A), Color(0xFFFFB82E)],
                ),
                borderRadius: BorderRadius.circular(18 * scale),
                border: Border.all(color: HoldemColors.ink, width: 4 * scale),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFFFD45C).withValues(alpha: .8),
                    blurRadius: 40 * scale,
                    spreadRadius: 4 * scale,
                  ),
                ],
              ),
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  'ALL IN',
                  style: HoldemFonts.title(
                    size: 72 * scale,
                    color: HoldemColors.ink,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  int _chipCount(int value) {
    if (value >= 1600) return 9;
    if (value >= 800) return 8;
    if (value >= 400) return 7;
    if (value >= 200) return 6;
    if (value >= 100) return 5;
    return 4;
  }

  double _interval(double value, double begin, double end, Curve curve) {
    if (value <= begin) return 0;
    if (value >= end) return 1;
    return curve.transform((value - begin) / (end - begin));
  }

  Offset _quadratic(Offset start, Offset control, Offset end, double value) {
    final inverse = 1 - value;
    return start * (inverse * inverse) +
        control * (2 * inverse * value) +
        end * (value * value);
  }
}

/// 판이 끝났을 때 중앙 팟의 칩을 승자 좌석으로 보내는 연출입니다.
class HoldemPotAwardMotion extends StatelessWidget {
  const HoldemPotAwardMotion({
    super.key,
    required this.progress,
    required this.amount,
    required this.source,
    required this.target,
    required this.scale,
    this.delay = 0,
  });

  final Animation<double> progress;
  final int amount;
  final Offset source;
  final Offset target;
  final double scale;
  final double delay;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: AnimatedBuilder(
        animation: progress,
        builder: (_, _) {
          final value = progress.value;
          if (value <= .19 || value >= 1) return const SizedBox.expand();
          return Semantics(
            label: GameLocale.select(
              ko: '승리 칩 이동 ${holdemChips(amount)}',
              en: 'Winning chips moving ${holdemChips(amount)}',
              zhHans: '获胜筹码移动 ${holdemChips(amount)}',
              zhHant: '獲勝籌碼移動 ${holdemChips(amount)}',
            ),
            excludeSemantics: true,
            child: SizedBox.expand(
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var index = 0; index < 8; index++) _chip(index, value),
                  _amount(value),
                ],
              ),
            ),
          );
        },
      ),
    ),
  );

  Widget _chip(int index, double value) {
    const starts = [
      Offset(-14, 8),
      Offset(10, 5),
      Offset(-9, 0),
      Offset(13, -4),
      Offset(-6, -10),
      Offset(8, -14),
      Offset(-2, -20),
      Offset(4, -25),
    ];
    const arrivals = [
      Offset(-34, -8),
      Offset(-20, 10),
      Offset(-5, -16),
      Offset(10, 8),
      Offset(24, -10),
      Offset(35, 5),
      Offset(-12, -28),
      Offset(18, -25),
    ];
    // 중앙 칩 더미를 먼저 잠깐 보여 준 뒤 승자 쪽으로 한꺼번에 흘려 보냅니다.
    final begin = .2 + delay + index * .012;
    final travel = _interval(value, begin, .83 + delay, Curves.easeInOutCubic);
    final fade = _interval(value, .88 + delay, 1, Curves.easeIn);
    final start = source + starts[index] * scale;
    final end = target + arrivals[index] * scale;
    final direction = end - start;
    final distance = math.max(direction.distance, 1.0).toDouble();
    final tangent = Offset(-direction.dy, direction.dx) / distance;
    final control =
        Offset.lerp(start, end, .48)! +
        tangent * (index.isEven ? 42 : -42) * scale;
    final position = _quadratic(start, control, end, travel);
    final lift = math.sin(travel * math.pi);
    final size = 33 * scale;
    return Positioned(
      left: position.dx - size / 2,
      top: position.dy - size / 2 - lift * 22 * scale,
      width: size,
      height: size + 5 * scale,
      child: Opacity(
        opacity: (1 - fade).clamp(0.0, 1.0),
        child: Transform.rotate(
          angle: (index.isEven ? .32 : -.28) * lift,
          child: HoldemChip(size: size),
        ),
      ),
    );
  }

  Widget _amount(double value) {
    final appear = _interval(value, delay + .4, delay + .55, Curves.easeOut);
    final fade = _interval(value, .88 + delay, 1, Curves.easeIn);
    final position = Offset.lerp(
      source,
      target + Offset(0, -58 * scale),
      _interval(value, delay + .2, .8 + delay, Curves.easeOutCubic),
    )!;
    return Positioned(
      left: position.dx - 80 * scale,
      top: position.dy - 18 * scale,
      width: 160 * scale,
      child: Opacity(
        opacity: (appear * (1 - fade)).clamp(0.0, 1.0),
        child: Text(
          '+${holdemChips(amount)}',
          textAlign: TextAlign.center,
          style: HoldemFonts.numbers(size: 27 * scale).copyWith(
            shadows: const [Shadow(color: Color(0xCC000000), blurRadius: 12)],
          ),
        ),
      ),
    );
  }

  double _interval(double value, double begin, double end, Curve curve) {
    if (value <= begin) return 0;
    if (value >= end) return 1;
    return curve.transform((value - begin) / (end - begin));
  }

  Offset _quadratic(Offset start, Offset control, Offset end, double value) {
    final inverse = 1 - value;
    return start * (inverse * inverse) +
        control * (2 * inverse * value) +
        end * (value * value);
  }
}

/// 중앙에 모인 팟을 낮게 쓰러져 포개진 칩 더미로 보여 줍니다.
class HoldemPotChipStack extends StatelessWidget {
  const HoldemPotChipStack({
    super.key,
    required this.amount,
    required this.scale,
  });

  final int amount;
  final double scale;

  @override
  Widget build(BuildContext context) {
    if (amount <= 0) return const SizedBox.shrink();
    final count = amount >= 2400
        ? 9
        : amount >= 1200
        ? 8
        : amount >= 600
        ? 7
        : amount >= 300
        ? 6
        : 5;
    const chipOffsets = [
      Offset(0, 12),
      Offset(17, 7),
      Offset(34, 13),
      Offset(51, 6),
      Offset(68, 12),
      Offset(85, 8),
      Offset(24, 18),
      Offset(58, 19),
      Offset(94, 17),
    ];
    final size = 29 * scale;
    return Semantics(
      label: GameLocale.select(
        ko: '팟 칩 ${holdemChips(amount)}',
        en: 'Pot ${holdemChips(amount)} chips',
        zhHans: '底池 ${holdemChips(amount)} 筹码',
        zhHant: '底池 ${holdemChips(amount)} 籌碼',
      ),
      child: TweenAnimationBuilder<double>(
        key: ValueKey(amount),
        tween: Tween(begin: .88, end: 1),
        duration: const Duration(milliseconds: 620),
        curve: Curves.easeOutBack,
        builder: (_, value, child) => Transform.scale(
          scale: value,
          alignment: Alignment.center,
          child: child,
        ),
        child: SizedBox(
          width: 124 * scale,
          height: 52 * scale,
          child: Stack(
            children: [
              for (var index = 0; index < count; index++)
                Positioned(
                  left: chipOffsets[index].dx * scale,
                  top: chipOffsets[index].dy * scale,
                  child: Transform.rotate(
                    angle: index.isEven ? -.1 : .08,
                    child: HoldemChip(size: size),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
