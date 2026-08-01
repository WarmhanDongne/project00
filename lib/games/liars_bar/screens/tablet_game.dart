import 'package:flutter/material.dart';
import 'package:project00/games/liars_bar/widgets/result.dart';
import 'package:project00/games/liars_bar/widgets/sideblock.dart';
import 'package:project00/games/liars_bar/animations/card_deal.dart';
import 'package:project00/games/liars_bar/animations/card_play_animation.dart';
import 'package:project00/games/liars_bar/animations/round_start_reveal.dart';

class TabletGame extends StatefulWidget {
  const TabletGame({super.key});

  @override
  State<TabletGame> createState() => _TabletGameState();
}

class _TabletGameState extends State<TabletGame> {
  static const int _playerCount = 6;
  static const int _cardsPerPlayer = 5;

  final playKey = GlobalKey<CardPlayAnimationState>();
  final List<int> _remainingCardCounts = List<int>.filled(
    _playerCount,
    _cardsPerPlayer,
  );
  final String table = 'K';
  GameStatus gameStatus = GameStatus.starting;

  bool showTableImage = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: ClipRect(
              child: Transform.scale(
                scale: 1.1,
                child: Image.asset(
                  'assets/games/liars_bar/images/background/background.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          // 게임 시작 전
          if (gameStatus == GameStatus.waiting)
            const Center(
              child: Text(
                '게임 시작 대기 중',
                style: TextStyle(color: Colors.white, fontSize: 32),
              ),
            ),

          // 게임 시작 애니메이션
          if (gameStatus == GameStatus.starting)
            Positioned.fill(
              child: CardDealAnimation(
                playerCount: _playerCount,
                cardsPerPlayer: _cardsPerPlayer,
                duration: const Duration(milliseconds: 2800),
                onCompleted: () {
                  if (!mounted) return;

                  setState(() {
                    gameStatus = GameStatus.playing;
                    showTableImage = true;
                  });
                },
              ),
            ),

          // 게임 진행 중 테이블 이미지
          if (gameStatus == GameStatus.playing && showTableImage)
            Positioned.fill(
              child: RoundStartReveal(
                tableAsset:
                    'assets/games/liars_bar/images/background/$table.png',
                playerCount: _playerCount,
                remainingCardCounts: _remainingCardCounts,
                tableWidth: 300,
              ),
            ),

          // 게임 진행 중 카드 제출 애니메이션
          if (gameStatus == GameStatus.playing)
            CardPlayAnimation(
              key: playKey,
              playerCount: _playerCount,
              fromPlayerIndex: 0,
              frontCardAssets: const [
                'assets/games/liars_bar/images/cards/white Q.png',
                'assets/games/liars_bar/images/cards/white Q.png',
                'assets/games/liars_bar/images/cards/white Joker.png',
              ],
              onCardsPlayed: () {
                // 다음 플레이어 턴 처리
              },
              onRevealed: () {
                // 라이어 판정 처리
              },
            ),

          // 게임 종료 후
          if (gameStatus == GameStatus.result) const Center(child: Result()),

          const Positioned(top: 20, right: 20, child: SideBlock()),
        ],
      ),
    );
  }
}

enum GameStatus {
  waiting, // 대기
  starting, // 시작 연출
  playing, // 진행 중
  result, // 결과 화면
  finished, // 종료
}
