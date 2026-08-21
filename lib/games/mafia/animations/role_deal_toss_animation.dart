import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:project00/core/assets/game_image.dart';
import 'package:project00/core/sound/app_sounds.dart';
import 'package:project00/core/sound/sound_effects.dart';
import 'package:project00/games/shared/player_layouts/player_slot_positions.dart';
import 'package:project00/gen/assets.gen.dart';

//=======================T1 역할 카드 나눠 주기==============================
/// 중앙 더미에서 역할 카드를 **한 사람당 한 장씩**, 그 사람이 앉은 방향으로
/// 던져 화면 밖까지 내보내는 연출입니다(확정 2026-08).
///
/// 마피아는 카드가 태블릿 위에 남지 않습니다 — 신분은 각자의 휴대폰으로
/// 가므로, 카드가 좌석 방향으로 날아가 화면을 벗어나는 것이 곧 "그 사람에게
/// 전달됐다"는 뜻입니다. 그래서 공용 분배 연출(카드가 좌석에 착지해 남는
/// `shared/animations/card_deal.dart`) 대신 이 전용 연출을 씁니다.
///
/// 카드는 처음부터 끝까지 **뒷면**입니다. 분배음은 카드가 더미를 떠나는
/// 순간(더미와의 접촉이 끝나는 순간)에 한 장마다 재생합니다.
class MafiaRoleDealTossAnimation extends StatefulWidget {
  const MafiaRoleDealTossAnimation({
    super.key,
    required this.playerSeatIndexes,
    required this.boardSeatCount,
    this.cardWidth = 168,
  }) : assert(boardSeatCount > 0);

  /// 카드를 받을 사람들의 실제 좌석 번호입니다(빈 좌석이 섞여 있어도 됩니다).
  final List<int> playerSeatIndexes;

  /// 방의 전체 좌석 수입니다. 좌석 방향은 이 크기 기준으로 계산해야
  /// 사람이 빠져도 방향이 흔들리지 않습니다.
  final int boardSeatCount;

  final double cardWidth;

  @override
  State<MafiaRoleDealTossAnimation> createState() =>
      _MafiaRoleDealTossAnimationState();
}

class _MafiaRoleDealTossAnimationState extends State<MafiaRoleDealTossAnimation>
    with TickerProviderStateMixin {
  /// 역할 카드의 가로:세로 비율입니다(휴대폰 P1과 같은 시안 값).
  static const double _cardAspectRatio = 286 / 419.39;

  /// 더미가 화면 위에서 중앙으로 내려오는 시간입니다(공용 분배와 같은 리듬).
  static const Duration _deckEntry = Duration(milliseconds: 620);

  /// 카드 한 장의 비행 시간과 발사 간격입니다.
  static const Duration _flight = Duration(milliseconds: 560);
  static const Duration _launchGap = Duration(milliseconds: 240);

  late final AnimationController _entryController;
  late final AnimationController _tossController;

  /// 좌석 번호 오름차순 = 나눠 주는 순서입니다.
  late final List<int> _order;

  /// 지금까지 분배음을 재생한 카드 수입니다.
  int _playedSoundCount = 0;

  @override
  void initState() {
    super.initState();
    _order = [...widget.playerSeatIndexes]..sort();
    final total = _launchGap * math.max(0, _order.length - 1) + _flight;
    _entryController = AnimationController(vsync: this, duration: _deckEntry);
    _tossController = AnimationController(vsync: this, duration: total)
      ..addListener(_playLaunchSounds);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _entryController.forward();
      if (!mounted) return;
      await _tossController.forward();
    });
  }

  @override
  void dispose() {
    _entryController.dispose();
    _tossController
      ..removeListener(_playLaunchSounds)
      ..dispose();
    super.dispose();
  }

  //=======================장별 진행도==============================
  /// [index]번째 카드의 비행 진행도(0 = 더미 안, 1 = 화면 밖)입니다.
  double _cardProgress(int index) {
    final totalMs = _tossController.duration!.inMilliseconds;
    final elapsedMs = _tossController.value * totalMs;
    final startMs = _launchGap.inMilliseconds * index;
    return ((elapsedMs - startMs) / _flight.inMilliseconds).clamp(0.0, 1.0);
  }

  /// 분배음은 각 카드가 더미를 떠나는 순간에 한 번씩 재생합니다.
  void _playLaunchSounds() {
    if (!mounted) return;
    var launched = 0;
    for (var i = 0; i < _order.length; i += 1) {
      if (_cardProgress(i) > 0) launched += 1;
    }
    while (_playedSoundCount < launched) {
      _playedSoundCount += 1;
      SoundEffects.play(context, AppSounds.dealing);
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final center = Offset(size.width / 2, size.height / 2);
        final cardWidth = widget.cardWidth;
        final cardHeight = cardWidth / _cardAspectRatio;
        // 어느 방향이든 확실히 화면을 벗어나는 이동 거리입니다.
        final travel = size.longestSide * 0.8 + cardHeight;
        final seatCenters = normalizedPlayerCenters(widget.boardSeatCount);

        return AnimatedBuilder(
          animation: Listenable.merge([_entryController, _tossController]),
          builder: (context, _) {
            final entry = Curves.easeOutCubic.transform(_entryController.value);
            // 더미는 화면 위 바깥에서 중앙으로 내려와 자리를 잡습니다.
            final deckTop =
                Offset(center.dx, -cardHeight) * (1 - entry) + center * entry;
            final launchedAll =
                _order.isNotEmpty && _cardProgress(_order.length - 1) > 0;

            final cards = <Widget>[];
            // 아직 날아가지 않은 카드 몫의 더미입니다. 마지막 장이 떠나면
            // 더미도 사라집니다(더미가 곧 나눠 줄 카드 전부이므로).
            if (!launchedAll) {
              cards.add(
                _buildCard(
                  position: deckTop,
                  rotation: 0,
                  cardWidth: cardWidth,
                  cardHeight: cardHeight,
                ),
              );
            }
            for (var i = 0; i < _order.length; i += 1) {
              final progress = _cardProgress(i);
              if (progress <= 0 || progress >= 1) continue;
              final seat = seatCenters[_order[i]];
              // 정규화 좌표(0~1)를 화면 비율에 맞춘 실제 방향으로 바꿉니다.
              final delta = Offset(
                (seat.dx - 0.5) * size.width,
                (seat.dy - 0.5) * size.height,
              );
              final direction = delta.distance == 0
                  ? const Offset(0, 1)
                  : delta / delta.distance;
              // 던진 카드가 점점 빨라지며 나갑니다.
              final eased = Curves.easeIn.transform(progress);
              final position = center + direction * (travel * eased);
              // 받는 사람 쪽에서 봤을 때 카드가 바로 서도록 돌립니다.
              final targetAngle = math.atan2(-direction.dx, direction.dy);
              final rotation = targetAngle * Curves.easeOut.transform(progress);
              cards.add(
                _buildCard(
                  position: position,
                  rotation: rotation,
                  cardWidth: cardWidth,
                  cardHeight: cardHeight,
                ),
              );
            }
            return Stack(fit: StackFit.expand, children: cards);
          },
        );
      },
    );
  }

  Widget _buildCard({
    required Offset position,
    required double rotation,
    required double cardWidth,
    required double cardHeight,
  }) {
    return Positioned(
      left: position.dx - cardWidth / 2,
      top: position.dy - cardHeight / 2,
      width: cardWidth,
      height: cardHeight,
      child: IgnorePointer(
        child: Transform.rotate(
          angle: rotation,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              boxShadow: const [
                BoxShadow(
                  color: Color(0x4D000000),
                  blurRadius: 6,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Assets.games.mafia.images.cards.roleBack.game.image(
                fit: BoxFit.cover,
                filterQuality: FilterQuality.high,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
