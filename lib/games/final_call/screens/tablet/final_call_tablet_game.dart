import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/games/final_call/controllers/final_call_controller.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/final_call/widgets/final_call_card_view.dart';
import 'package:project00/games/final_call/widgets/final_call_result.dart';
import 'package:project00/games/final_call/widgets/final_call_timer.dart';
import 'package:project00/gen/assets.gen.dart';

/// 아이패드에서 전체 테이블, 라운드 공개, 결과와 재시작을 진행합니다.
class FinalCallTabletGame extends StatefulWidget {
  const FinalCallTabletGame({
    super.key,
    required this.roomCode,
    required this.service,
  });

  final String roomCode;
  final FinalCallService service;

  @override
  State<FinalCallTabletGame> createState() => _FinalCallTabletGameState();
}

class _FinalCallTabletGameState extends State<FinalCallTabletGame> {
  FinalCallController? controller;
  String? initializationError;
  String? previousPhase;
  Timer? phaseTimer;

  @override
  void initState() {
    super.initState();
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      initializationError = '게임 진행 기기 인증을 확인할 수 없습니다.';
      return;
    }
    controller =
        FinalCallController(
            roomCode: widget.roomCode,
            uid: uid,
            service: widget.service,
            watchPrivateHand: false,
          )
          ..addListener(_handleState)
          ..initialize();
  }

  void _handleState() {
    final game = controller;
    if (game == null || !mounted) return;
    final enteredPhase = previousPhase != game.phase;
    previousPhase = game.phase;
    if (game.phase == 'dealing' && enteredPhase) {
      phaseTimer?.cancel();
      phaseTimer = Timer(const Duration(milliseconds: 1200), () async {
        if (!mounted || controller?.phase != 'dealing') return;
        await controller?.completeDealing();
      });
    }
    if (game.phase == 'roundResult' && enteredPhase) {
      phaseTimer?.cancel();
      phaseTimer = Timer(const Duration(seconds: 5), () async {
        if (!mounted || controller?.phase != 'roundResult') return;
        await controller?.nextRound();
      });
    }
  }

  @override
  void dispose() {
    phaseTimer?.cancel();
    controller
      ?..removeListener(_handleState)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = controller;
    if (game == null) {
      return Scaffold(
        body: Center(child: Text(initializationError ?? '게임을 열 수 없습니다.')),
      );
    }
    return AnimatedBuilder(
      animation: game,
      builder: (context, _) {
        return Scaffold(
          body: Stack(
            fit: StackFit.expand,
            children: [
              Assets.games.finalCall.images.background.background.image(
                fit: BoxFit.cover,
              ),
              if (!game.loading) _Table(controller: game),
              if (game.isFinished)
                FinalCallResultOverlay(
                  winner: game.players[game.winnerUid],
                  onRestart: () => game.restartGame(),
                  onHome: () => Navigator.of(context).pop(),
                ),
              if (game.commandInFlight)
                const Positioned(
                  right: 22,
                  bottom: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.controller});
  final FinalCallController controller;

  @override
  Widget build(BuildContext context) {
    final players = controller.players.values.toList()
      ..sort((a, b) => a.seatIndex.compareTo(b.seatIndex));
    final result = controller.roundResult;
    return SafeArea(
      child: Stack(
        children: [
          Positioned(
            top: 15,
            left: 24,
            child: Text(
              'FINAL CALL  ·  ROUND ${controller.round}',
              style: const TextStyle(
                color: Colors.black87,
                fontSize: 24,
                fontWeight: FontWeight.w900,
                letterSpacing: 1.8,
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 20,
            child: Row(
              children: [
                Assets.games.finalCall.images.icons.iconRole.image(width: 38),
                const SizedBox(width: 12),
                Assets.games.finalCall.images.icons.iconSetting.image(
                  width: 42,
                ),
              ],
            ),
          ),
          if (controller.turnDeadlineAt != null &&
              controller.phase != 'roundResult')
            Positioned(
              top: 13,
              left: 0,
              right: 0,
              child: Center(
                child: FinalCallTimer(
                  key: ValueKey(controller.turnDeadlineAt),
                  deadline: controller.turnDeadlineAt!,
                  onTimeout: () => controller.timeoutTurn(),
                ),
              ),
            ),
          Center(child: _CenterDeck(controller: controller)),
          for (var index = 0; index < players.length; index++)
            Align(
              alignment: _seatAlignment(index, players.length),
              child: Padding(
                padding: const EdgeInsets.all(34),
                child: _PlayerSeat(
                  player: players[index],
                  isTurn: players[index].uid == controller.turnUid,
                  cards: result?.revealedHands[players[index].uid],
                  score: result?.scores[players[index].uid],
                  lifeLoss: result?.lifeLosses[players[index].uid],
                ),
              ),
            ),
          if (controller.phase == 'dealing')
            const Center(child: _MessagePanel(message: '카드를 나누는 중입니다')),
          if (controller.phase == 'finalTurns')
            Positioned(
              left: 0,
              right: 0,
              bottom: 25,
              child: Center(
                child: _MessagePanel(
                  message:
                      '${controller.players[controller.callerUid]?.nickname ?? ''} CALL\n마지막 카드 교체를 진행합니다',
                ),
              ),
            ),
          if (controller.phase == 'roundResult' && result != null)
            Center(child: _RoundResultPanel(controller: controller)),
        ],
      ),
    );
  }

  Alignment _seatAlignment(int index, int count) {
    if (count == 2) {
      return index == 0 ? Alignment.bottomCenter : Alignment.topCenter;
    }
    if (count == 3) {
      return const [
        Alignment.bottomCenter,
        Alignment(-0.82, -0.65),
        Alignment(0.82, -0.65),
      ][index];
    }
    return const [
      Alignment.bottomCenter,
      Alignment.centerRight,
      Alignment.topCenter,
      Alignment.centerLeft,
    ][index];
  }
}

class _CenterDeck extends StatelessWidget {
  const _CenterDeck({required this.controller});
  final FinalCallController controller;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FinalCallCardView(faceDown: true, width: 100),
            const SizedBox(height: 6),
            Text(
              '${controller.deckRemainingCount}',
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(width: 22),
        FinalCallCardView(card: controller.discardCard, width: 100),
      ],
    );
  }
}

class _PlayerSeat extends StatelessWidget {
  const _PlayerSeat({
    required this.player,
    required this.isTurn,
    required this.cards,
    required this.score,
    required this.lifeLoss,
  });
  final FinalCallPlayer player;
  final bool isTurn;
  final List<FinalCallCard>? cards;
  final int? score;
  final int? lifeLoss;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 320),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isTurn ? const Color(0xCCFFFFFF) : const Color(0x88FFFFFF),
        borderRadius: BorderRadius.circular(14),
        boxShadow: isTurn
            ? const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ]
            : const [],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _Profile(imageUrl: player.profileImageUrl),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    player.nickname,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  Row(
                    children: [
                      for (var index = 0; index < player.lives; index++)
                        Assets.games.finalCall.images.icons.iconHeart.image(
                          width: 14,
                        ),
                      if (score != null) ...[
                        const SizedBox(width: 8),
                        Text(
                          '$score점',
                          style: const TextStyle(fontWeight: FontWeight.w900),
                        ),
                      ],
                      if (lifeLoss != null)
                        Text(
                          '  ♥ -$lifeLoss',
                          style: const TextStyle(color: Colors.red),
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 7),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cards == null)
                for (var index = 0; index < 4; index++)
                  const Padding(
                    padding: EdgeInsets.symmetric(horizontal: 2),
                    child: FinalCallCardView(faceDown: true, width: 34),
                  )
              else
                for (final card in cards!)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: FinalCallCardView(card: card, width: 34),
                  ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Profile extends StatelessWidget {
  const _Profile({required this.imageUrl});
  final String imageUrl;

  @override
  Widget build(BuildContext context) {
    return ClipOval(
      child: SizedBox(
        width: 44,
        height: 44,
        child: imageUrl.isEmpty
            ? const ColoredBox(color: Colors.black12, child: Icon(Icons.person))
            : Image.network(
                imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => const ColoredBox(
                  color: Colors.black12,
                  child: Icon(Icons.person),
                ),
              ),
      ),
    );
  }
}

class _RoundResultPanel extends StatelessWidget {
  const _RoundResultPanel({required this.controller});
  final FinalCallController controller;

  @override
  Widget build(BuildContext context) {
    final result = controller.roundResult!;
    return Container(
      width: 310,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xF5FFFFFF),
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [BoxShadow(color: Color(0x55000000), blurRadius: 22)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            result.automaticCall ? 'AUTO CALL' : 'ROUND RESULT',
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 12),
          for (final player in controller.players.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  Expanded(child: Text(player.nickname)),
                  Text('${result.scores[player.uid] ?? 0}점'),
                  SizedBox(
                    width: 54,
                    child: Text(
                      result.lifeLosses[player.uid] == null
                          ? ''
                          : '♥ -${result.lifeLosses[player.uid]}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MessagePanel extends StatelessWidget {
  const _MessagePanel({required this.message});
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xEFFFFFFF),
        borderRadius: BorderRadius.circular(14),
        boxShadow: const [BoxShadow(color: Color(0x44000000), blurRadius: 15)],
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
    );
  }
}
