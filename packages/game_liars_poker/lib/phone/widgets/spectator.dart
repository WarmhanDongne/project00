// [spectator.dart] 탈락한 휴대폰 플레이어에게
// 남은 사람과 각자의 룰렛 단계를 보여 주는 관전 화면 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_liars_poker/game_copy.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_liars_poker/phone/widgets/exit_modal.dart';
import 'package:game_liars_poker/phone/widgets/top_bar.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';
import 'package:game_liars_poker/shared/widgets/noir_ui.dart';
import 'package:game_kit/errors/widgets/leave_failure_notice.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/phone/widgets/ripple_dialog.dart';
import 'package:game_kit/phone/widgets/rule_dialog.dart';
import 'package:game_liars_poker/game_theme.dart';

// ============================================================

/// 남은 사람과 각자의 손패 수·룰렛 단계를 보여 주는 휴대폰 관전 화면입니다.
class PhoneSpectator extends StatelessWidget {
  const PhoneSpectator({
    super.key,
    required this.players,
    required this.meUid,
    required this.turnUid,
    required this.provider,
    required this.onExitRoom,
  });

  /// 탈락자를 포함한 모든 참가자입니다.
  final List<PhoneGamePlayer> players;
  final String meUid;
  final String? turnUid;
  final GameRoomContext provider;
  final Future<bool> Function() onExitRoom;

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.orientationOf(context) == Orientation.landscape;
    final me = players.where((player) => player.uid == meUid).firstOrNull;
    final survivors = [
      for (final player in players)
        if (player.status != 'eliminated') player,
    ]..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
    final list = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              '남은 사람 ${survivors.length}명',
              style: LiarsPokerFonts.text(
                size: 13,
                color: LiarsPokerColors.muted,
              ),
            ),
            Text(
              '룰렛 생존 · 다음 확률',
              style: LiarsPokerFonts.text(
                size: 13,
                color: LiarsPokerColors.muted,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        for (final player in survivors) ...[
          _SurvivorRow(player: player, isTurn: player.uid == turnUid),
          const SizedBox(height: 8),
        ],
        if (me != null) _EliminatedRow(player: me),
      ],
    );
    final heading = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'SPECTATOR',
          style: LiarsPokerFonts.western(
            size: 20,
            color: LiarsPokerColors.gold,
            letterSpacing: 1.6,
          ),
        ),
        const SizedBox(height: 4),
        Text('관전 중', style: LiarsPokerFonts.headline(size: 32)),
      ],
    );
    final footer = Text(
      '마지막 한 명이 남을 때까지 지켜봐요',
      style: LiarsPokerFonts.text(size: 13, color: LiarsPokerColors.muted),
    );

    return Scaffold(
      backgroundColor: LiarsPokerColors.night,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            18,
            isLandscape ? 10 : 20,
            18,
            isLandscape ? 10 : 30,
          ),
          child: Column(
            children: [
              PhoneGameTopBar(
                characterId: me?.characterId ?? 'frog',
                nickname: me?.nickname ?? '나',
                penaltyCount: me?.penaltyCount ?? 0,
                statusLabel: LiarsPokerCopy.eliminated,
                statusColor: LiarsPokerColors.pink,
                eliminated: true,
                onTipPressedAt: (origin) => _showRules(context, origin),
                onOutPressedAt: (origin) =>
                    unawaited(_showExitModal(context, origin: origin)),
              ),
              Expanded(
                child: isLandscape
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                heading,
                                const SizedBox(height: 16),
                                footer,
                              ],
                            ),
                          ),
                          SizedBox(
                            width: 360,
                            child: SingleChildScrollView(child: list),
                          ),
                        ],
                      )
                    : Column(
                        children: [
                          const SizedBox(height: 26),
                          heading,
                          const SizedBox(height: 22),
                          Expanded(
                            child: SingleChildScrollView(
                              child: ConstrainedBox(
                                constraints: const BoxConstraints(
                                  maxWidth: 400,
                                ),
                                child: list,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          footer,
                        ],
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showRules(BuildContext context, Offset origin) {
    showPhoneRippleDialog<void>(
      context: context,
      origin: origin,
      builder: (_) => const PhoneGameRuleDialog(
        title: "LIAR'S POKER",
        rules: LiarsPokerCopy.phoneRules,
        surfaceColor: LiarsPokerColors.night,
        foregroundColor: Colors.white,
        showSurface: false,
        dismissOnAnyTap: true,
      ),
    );
  }

  Future<void> _showExitModal(
    BuildContext context, {
    required Offset origin,
  }) async {
    final shouldExit = await PhoneExitModal.show(context, origin: origin);
    if (!context.mounted || shouldExit != true) return;
    final left = await onExitRoom();
    if (!context.mounted || left) return;
    showLeaveFailureNotice(context, provider);
  }
}

class _SurvivorRow extends StatelessWidget {
  const _SurvivorRow({required this.player, required this.isTurn});

  final PhoneGamePlayer player;
  final bool isTurn;

  @override
  Widget build(BuildContext context) {
    final back = Assets.games.liarsPoker.images.cards.whiteBack.game;
    final danger = liarsPokerIsDanger(player.penaltyCount);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isTurn ? LiarsPokerColors.panelRaised : LiarsPokerColors.panel,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isTurn ? LiarsPokerColors.gold : LiarsPokerColors.panelEdge,
          width: 2,
        ),
      ),
      child: Row(
        children: [
          NoirAvatar(characterId: player.characterId, size: 44),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      TextSpan(text: player.nickname),
                      if (isTurn)
                        const TextSpan(
                          text: '  차례',
                          style: TextStyle(
                            fontSize: 12,
                            color: LiarsPokerColors.goldLight,
                          ),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LiarsPokerFonts.text(
                    size: 16,
                    weight: FontWeight.w700,
                    color: danger
                        ? LiarsPokerColors.pink
                        : LiarsPokerColors.ivory,
                  ),
                ),
                const SizedBox(height: 4),
                Semantics(
                  label: '남은 카드 ${player.remainingCardCount}장',
                  excludeSemantics: true,
                  child: Row(
                    children: [
                      for (var i = 0; i < player.remainingCardCount; i++)
                        Padding(
                          padding: const EdgeInsets.only(right: 3),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(2),
                            child: back.image(width: 16, height: 23),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              NoirRouletteDots(
                penaltyCount: player.penaltyCount,
                size: 10,
                gap: 3,
              ),
              const SizedBox(height: 4),
              Text(
                liarsPokerOddsLabel(player.penaltyCount),
                style: LiarsPokerFonts.text(
                  size: 12,
                  weight: danger ? FontWeight.w700 : FontWeight.w500,
                  color: danger
                      ? LiarsPokerColors.pink
                      : LiarsPokerColors.muted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _EliminatedRow extends StatelessWidget {
  const _EliminatedRow({required this.player});

  final PhoneGamePlayer player;

  @override
  Widget build(BuildContext context) {
    final round = switch (player.penaltyCount) {
      <= 1 => '첫 번째',
      2 => '두 번째',
      _ => '세 번째',
    };
    return Opacity(
      opacity: .55,
      child: CustomPaint(
        painter: const _DashedBorderPainter(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Row(
            children: [
              NoirAvatar(
                characterId: player.characterId,
                size: 44,
                grayscale: true,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${player.nickname} (나)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: LiarsPokerFonts.text(
                    size: 16,
                    weight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '$round 룰렛에서 탈락',
                style: LiarsPokerFonts.text(
                  size: 13,
                  color: LiarsPokerColors.pink,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DashedBorderPainter extends CustomPainter {
  const _DashedBorderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = LiarsPokerColors.panelEdge
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(16)),
      );
    for (final metric in path.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += 10) {
        canvas.drawPath(metric.extractPath(d, d + 5), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter oldDelegate) => false;
}
