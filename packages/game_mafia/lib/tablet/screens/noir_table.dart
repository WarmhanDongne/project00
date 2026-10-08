// [noir_table.dart] 는 마피아 태블릿 Noir Poster 시안의 공용 조각을 구성하는 파일이다.
//
// - [Package] : 마피아
// - [TabletScreen] : 참가자 카드 줄, 타이머 액자, 신분 카드 분배 연출을 구성함
//
// 즉, 태블릿의 여러 단계 화면이 같은 자리·같은 모양으로 참가자를 보여 주기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:game_kit/game_flow/game_presentation_clock.dart';
import 'package:game_mafia/game_assets.dart';
import 'package:game_mafia/game_theme.dart';
import 'package:game_mafia/gen/assets.gen.dart';
import 'package:game_mafia/shared/animations/role_deal_toss_animation.dart';
import 'package:game_mafia/shared/models/player.dart';
import 'package:game_mafia/shared/models/role.dart';
import 'package:game_mafia/shared/widgets/noir.dart';
import 'package:game_mafia/tablet/screens/game_layout.dart';

// ============================================================

/// 참가자 카드 아래 한 줄 상태입니다(예: `확인 완료`, `고민 중…`).
@immutable
class MafiaTabletSeatLabel {
  const MafiaTabletSeatLabel(this.text, {this.strong = false});

  final String text;

  /// 강조(놋쇠·굵게)인지입니다. 아니면 흐린 글자입니다.
  final bool strong;
}

/// 시안 좌표에서 참가자 카드 줄의 배치입니다.
abstract final class MafiaTabletSeatRow {
  static const double left = 48;
  static const double width = 1098;
  static const double maxCardWidth = 112;
  static const double minGap = 12;

  /// [count]명일 때 카드 폭입니다. 8명까지는 시안 그대로 112입니다.
  static double cardWidth(int count) {
    if (count <= 0) return maxCardWidth;
    return math.min(maxCardWidth, (width - minGap * (count - 1)) / count);
  }

  /// [index]번째 카드의 왼쪽 위치입니다(시안 좌표).
  ///
  /// [centeredGap]이 있으면 그 간격으로 가운데에 모읍니다(투표 화면).
  /// 없으면 양 끝까지 고르게 벌립니다(밤·낮 화면).
  static double cardLeft(int index, int count, {double? centeredGap}) {
    final card = cardWidth(count);
    if (centeredGap != null) {
      final total = count * card + (count - 1) * centeredGap;
      return 597 - total / 2 + index * (card + centeredGap);
    }
    if (count <= 1) return 597 - card / 2;
    return left + index * (width - card) / (count - 1);
  }

  /// 카드 중심입니다(시안 좌표).
  static Offset cardCenter(
    int index,
    int count,
    double top, {
    double? centeredGap,
  }) {
    final card = cardWidth(count);
    return Offset(
      cardLeft(index, count, centeredGap: centeredGap) + card / 2,
      top + card * MafiaNoirPortraitCard.aspect / 2,
    );
  }
}

/// 화면 아래 참가자 카드 줄입니다(시안 태블릿 ②③⑤⑥).
///
/// 살아 있는 사람은 바랜 사진 카드, 떠난 사람은 공개된 신분 카드(없으면 흑백
/// 얼굴) 위에 `처형 · 이름` / `사망 · 이름` 띠를 두릅니다.
class MafiaTabletPlayerRow extends StatelessWidget {
  const MafiaTabletPlayerRow({
    super.key,
    required this.players,
    required this.top,
    this.revealedRoles = const {},
    this.labels = const {},
    this.dimmedUids = const {},
    this.centeredGap,
  });

  final List<MafiaPlayer> players;

  /// 시안 기준 top입니다.
  final double top;

  /// 모두에게 공개된 신분입니다. 처형된 사람의 카드에 씁니다.
  final Map<String, MafiaRole?> revealedRoles;

  /// 카드 아래 상태 줄입니다.
  final Map<String, MafiaTabletSeatLabel> labels;

  /// 흐리게(어두운 테두리) 그릴 사람입니다(아직 확인·투표하지 않음).
  final Set<String> dimmedUids;

  /// 가운데 모으기 간격입니다. null이면 양 끝까지 벌립니다.
  final double? centeredGap;

  @override
  Widget build(BuildContext context) {
    final count = players.length;
    final card = MafiaTabletSeatRow.cardWidth(count);
    final height = card * MafiaNoirPortraitCard.aspect;
    return Stack(
      children: [
        for (var index = 0; index < count; index++)
          MafiaTabletBox(
            rect: Rect.fromLTWH(
              MafiaTabletSeatRow.cardLeft(
                index,
                count,
                centeredGap: centeredGap,
              ),
              top,
              card,
              height + 34,
            ),
            child: _seat(players[index], card, height),
          ),
      ],
    );
  }

  Widget _seat(MafiaPlayer player, double card, double height) {
    final label = labels[player.uid];
    return LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / card;
        final width = card * scale;
        return Column(
          children: [
            AnimatedOpacity(
              opacity: dimmedUids.contains(player.uid) ? 0.55 : 1,
              duration: const Duration(milliseconds: 260),
              child: _card(player, width),
            ),
            if (label != null) ...[
              SizedBox(height: 10 * scale),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  child: Text(
                    label.text,
                    key: ValueKey(label.text),
                    maxLines: 1,
                    style: mafiaNoirBody(
                      14 * scale,
                      color: label.strong
                          ? MafiaColors.noirBrass
                          : const Color(0xFF6E6A5D),
                      weight: label.strong ? FontWeight.w700 : FontWeight.w400,
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _card(MafiaPlayer player, double width) {
    if (player.isAlive) {
      return MafiaNoirPortraitCard(
        player: player,
        width: width,
        innerHairline: true,
        borderColor: dimmedUids.contains(player.uid)
            ? const Color(0xFF3A3F3C)
            : MafiaColors.noirBrass,
      );
    }
    final role = revealedRoles[player.uid];
    final cause = player.wasExecuted ? '처형' : '사망';
    return MafiaNoirPortraitCard(
      player: player,
      width: width,
      borderColor: MafiaColors.noirFaded,
      grayscale: true,
      coverImage: role?.card,
      banner: MafiaNoirBannerSpec(
        label: '$cause · ${player.nickname}',
        top: 0.28,
        angle: -24,
        letterSpacing: 0,
      ),
    );
  }
}

/// 놋쇠 테두리 타이머 액자입니다(시안 태블릿 ③ 밤 0:42).
class MafiaTabletTimerBox extends StatelessWidget {
  const MafiaTabletTimerBox({
    super.key,
    required this.rect,
    required this.seconds,
    this.fontSize = 46,
  });

  final Rect rect;
  final int seconds;
  final double fontSize;

  @override
  Widget build(BuildContext context) => MafiaTabletBox(
    rect: rect,
    child: LayoutBuilder(
      builder: (context, constraints) {
        final scale = constraints.maxWidth / rect.width;
        return MafiaNoirFrame(
          color: MafiaColors.noirSlab,
          borderWidth: 2,
          inset: 5 * scale + 2,
          child: Text(
            mafiaNoirClock(seconds),
            style: mafiaNoirDisplay(
              fontSize * scale,
              color: MafiaColors.noirBrass,
            ),
          ),
        );
      },
    ),
  );
}

/// 신분 카드 분배 연출입니다(시안 태블릿 ②).
///
/// 가운데 카드 더미가 위에서 내려온 뒤, 한 장씩 아래 참가자 카드로 날아갑니다.
/// 시간표는 [MafiaRoleDealTossAnimation]의 값을 그대로 씁니다. 휴대폰이 같은
/// 값으로 '카드를 건네받는' 순간을 맞추기 때문입니다.
class MafiaTabletNoirDeal extends StatefulWidget {
  const MafiaTabletNoirDeal({
    super.key,
    required this.playerCount,
    required this.rowTop,
    this.onDeckCleared,
  });

  final int playerCount;

  /// 참가자 카드 줄의 시안 top입니다.
  final double rowTop;
  final VoidCallback? onDeckCleared;

  /// 카드 더미 자리입니다(시안 좌표).
  static const Rect pile = Rect.fromLTWH(522, 168, 150, 220);

  @override
  State<MafiaTabletNoirDeal> createState() => _MafiaTabletNoirDealState();
}

class _MafiaTabletNoirDealState extends State<MafiaTabletNoirDeal>
    with SingleTickerProviderStateMixin, GamePresentationState {
  @override
  Iterable<AnimationController> get presentationAnimations => [_deal];

  late final AnimationController _deal = AnimationController(
    vsync: this,
    duration: MafiaRoleDealTossAnimation.totalDuration(widget.playerCount),
  )..addStatusListener(_handleStatus);

  bool _cleared = false;

  @override
  void initState() {
    super.initState();
    _deal.forward();
  }

  void _handleStatus(AnimationStatus status) {
    if (status != AnimationStatus.completed || _cleared) return;
    _cleared = true;
    widget.onDeckCleared?.call();
  }

  @override
  void dispose() {
    _deal
      ..removeStatusListener(_handleStatus)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final back = Assets.games.mafia.images.cards.roleBack.game;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = MafiaTabletDesign.resolve(constraints);
        final scale = MafiaTabletDesign.scaleOf(size);
        final offset = Offset(
          (size.width - MafiaTabletDesign.size.width * scale) / 2,
          (size.height - MafiaTabletDesign.size.height * scale) / 2,
        );
        Offset map(Offset design) => offset + design * scale;

        return AnimatedBuilder(
          animation: _deal,
          builder: (context, _) {
            final totalMs = _deal.duration!.inMilliseconds;
            final elapsed = _deal.value * totalMs;
            final entryMs =
                MafiaRoleDealTossAnimation.deckEntryDuration.inMilliseconds;
            final entry = Curves.easeOutCubic.transform(
              (elapsed / entryMs).clamp(0.0, 1.0),
            );
            final pile = MafiaTabletNoirDeal.pile;
            final pileTop =
                map(pile.topLeft) +
                Offset(0, -(pile.bottom * scale) * (1 - entry));
            final dealtAll = elapsed >= totalMs;
            final cardCount = widget.playerCount;
            final flights = <Widget>[];
            for (var index = 0; index < cardCount; index++) {
              final start =
                  entryMs +
                  MafiaRoleDealTossAnimation.launchGap.inMilliseconds * index;
              final t =
                  ((elapsed - start) /
                          MafiaRoleDealTossAnimation
                              .cardFlightDuration
                              .inMilliseconds)
                      .clamp(0.0, 1.0);
              if (t <= 0 || t >= 1) continue;
              final eased = Curves.easeInOutCubic.transform(t);
              final from = map(pile.center);
              final to = map(
                MafiaTabletSeatRow.cardCenter(index, cardCount, widget.rowTop),
              );
              final position =
                  Offset.lerp(from, to, eased)! +
                  Offset(0, -math.sin(eased * math.pi) * 60 * scale);
              final width =
                  (pile.width +
                      (MafiaTabletSeatRow.cardWidth(cardCount) - pile.width) *
                          eased) *
                  scale;
              final height = width * pile.height / pile.width;
              flights.add(
                Positioned(
                  left: position.dx - width / 2,
                  top: position.dy - height / 2,
                  width: width,
                  height: height,
                  child: Opacity(
                    opacity: t > 0.85 ? (1 - t) / 0.15 : 1,
                    child: Transform.rotate(
                      angle: (1 - eased) * (index.isEven ? -0.2 : 0.2),
                      child: _CardBack(image: back, scale: scale),
                    ),
                  ),
                ),
              );
            }
            return IgnorePointer(
              child: Stack(
                children: [
                  // 남은 장수만큼 더미가 얇아집니다. 다 나눠 주면 사라집니다.
                  if (!dealtAll)
                    for (final (dx, angle) in const [
                      (-26.0, -0.07),
                      (24.0, 0.06),
                      (0.0, 0.0),
                    ])
                      Positioned(
                        left: pileTop.dx + dx * scale,
                        top: pileTop.dy,
                        width: pile.width * scale,
                        height: pile.height * scale,
                        child: Opacity(
                          opacity: entry,
                          child: Transform.rotate(
                            angle: angle,
                            child: _CardBack(image: back, scale: scale),
                          ),
                        ),
                      ),
                  ...flights,
                ],
              ),
            );
          },
        );
      },
    );
  }
}

class _CardBack extends StatelessWidget {
  const _CardBack({required this.image, required this.scale});

  final GameImage image;
  final double scale;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(8 * scale),
      border: Border.all(color: MafiaColors.noirBrass, width: 2),
      boxShadow: const [
        BoxShadow(
          color: Color(0x99000000),
          blurRadius: 18,
          offset: Offset(0, 10),
        ),
      ],
    ),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(6 * scale),
      child: image.image(fit: BoxFit.cover),
    ),
  );
}
