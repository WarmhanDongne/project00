import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/animations/card_deal.dart';
import 'package:project00/games/liars_poker/animations/card_play_animation.dart';
import 'package:project00/games/liars_poker/animations/round_start_reveal.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/games/liars_poker/widgets/result.dart';
import 'package:project00/games/liars_poker/widgets/sideblock.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

class TabletGame extends StatefulWidget {
  const TabletGame({super.key, required this.playerLayout,required this.provider});

  final PlayerLayoutModel playerLayout;
 final RoomProvider provider;

  @override
  State<TabletGame> createState() => TabletGameState();
}

class TabletGameState extends State<TabletGame> {
  //5장씩 나눠주기
  static const int _cardsPerPlayer = 5;

  //각 플레이어 남은 카드수
  late List<int> _remainingCardCounts;

  //처음 게임들어오면 패 분배부터 시작
  GameStatus _gameStatus = GameStatus.cardsPlaying;

  //현재 테이블
  String _table = 'K';
  //라운드 넘버
  int _roundNumber = 1;
  _SubmittedPlay? _submittedPlay;

  int get _playerCount => widget.playerLayout.playerCount;
  List<int> get _seatIndexes => widget.playerLayout.seatIndexes;
  GameStatus get gameStatus => _gameStatus;

  @override
  void initState() {
    super.initState();
    _remainingCardCounts = List<int>.filled(_playerCount, _cardsPerPlayer);
  }

  /// 백엔드의 게임 시작 이벤트를 받았을 때 호출합니다.
  void startDealing() {
    if (!mounted) return;
    setState(() {
      _submittedPlay = null;
      _gameStatus = GameStatus.dealing;
    });
  }

  /// 백엔드의 새 라운드 이벤트를 받았을 때 호출합니다.
  void startNextRound({
    required String table,
    required List<int> remainingCardCounts,
  }) {
    if (remainingCardCounts.length != _playerCount) {
      throw ArgumentError.value(
        remainingCardCounts,
        'remainingCardCounts',
        '잔여 카드 수는 플레이어 수와 같아야 합니다.',
      );
    }
    if (!mounted) return;

    setState(() {
      _roundNumber += 1;
      _table = table;
      _remainingCardCounts = List<int>.from(remainingCardCounts);
      _submittedPlay = null;
      _gameStatus = GameStatus.roundStarting;
    });
  }

  /// 백엔드의 cardsSubmitted 이벤트를 카드 제출 애니메이션으로 표시합니다.
  void showSubmittedCards({
    required String eventId,
    required String playerId,
    required int cardCount,
  }) {
    if (cardCount < 1 || cardCount > 3) {
      throw ArgumentError.value(cardCount, 'cardCount', '카드는 1~3장이어야 합니다.');
    }

    final playerIndex = widget.playerLayout.players.indexWhere(
      (player) => player.uid == playerId,
    );
    if (playerIndex < 0) {
      throw ArgumentError.value(
        playerId,
        'playerId',
        '플레이어 배치에서 사용자를 찾을 수 없습니다.',
      );
    }
    if (!mounted) return;

    setState(() {
      _submittedPlay = _SubmittedPlay(
        eventId: eventId,
        playerIndex: playerIndex,
        frontCardAssets: List<String>.filled(cardCount, _cardAssetForRank('Q')),
      );
      _gameStatus = GameStatus.cardsPlaying;
    });
  }

  /// 백엔드의 liarChallenged 이벤트를 실제 카드 공개 애니메이션으로 표시합니다.
  void revealSubmittedCards(List<String> actualRanks) {
    final submittedPlay = _submittedPlay;
    if (submittedPlay == null) return;
    if (actualRanks.length != submittedPlay.frontCardAssets.length) {
      throw ArgumentError.value(
        actualRanks,
        'actualRanks',
        '공개 카드 수와 제출 카드 수가 같아야 합니다.',
      );
    }
    if (!mounted) return;

    setState(() {
      _submittedPlay = submittedPlay.copyWith(
        frontCardAssets: actualRanks
            .map(_cardAssetForRank)
            .toList(growable: false),
      );
      _gameStatus = GameStatus.cardsRevealing;
    });
  }

  void showPenalty() => _changeStatus(GameStatus.penalty);

  void showResult() => _changeStatus(GameStatus.result);

  void finishGame() => _changeStatus(GameStatus.finished);

  void _changeStatus(GameStatus nextStatus) {
    if (!mounted || _gameStatus == nextStatus) return;
    setState(() {
      _gameStatus = nextStatus;
    });
  }

  String _cardAssetForRank(String rank) {
    return switch (rank.toUpperCase()) {
      'A' => 'assets/games/liars_poker/images/cards/white A.png',
      'K' => 'assets/games/liars_poker/images/cards/white K.png',
      'Q' => 'assets/games/liars_poker/images/cards/white Q.png',
      'JOKER' => 'assets/games/liars_poker/images/cards/white Joker.png',
      _ => 'assets/games/liars_poker/images/cards/white back.png',
    };
  }

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
                  'assets/games/liars_poker/images/background/background.png',
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
          Positioned.fill(child: _buildStatusLayer()),
          if (_shouldShowSubmittedPlay)
            Positioned.fill(child: _buildSubmittedPlayLayer()),
          if (_gameStatus == GameStatus.penalty)
            const Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    '벌칙 진행 중',
                    style: TextStyle(color: Colors.white, fontSize: 32),
                  ),
                ),
              ),
            ),
          Positioned(top: 20, right: 20, child: SideBlock(provider:widget.provider)),
        ],
      ),
    );
  }

  Widget _buildStatusLayer() {
    switch (_gameStatus) {
      case GameStatus.waiting:
        return const Center(
          child: Text(
            '게임 시작 대기 중',
            style: TextStyle(color: Colors.white, fontSize: 32),
          ),
        );

      case GameStatus.dealing:
        return CardDealAnimation(
          playerCount: _playerCount,
          playerSeatIndexes: _seatIndexes,
          cardsPerPlayer: _cardsPerPlayer,
          duration: const Duration(milliseconds: 2800),
          onCompleted: () => _changeStatus(GameStatus.roundStarting),
        );

      case GameStatus.roundStarting:
      case GameStatus.playing:
      case GameStatus.cardsPlaying:
      case GameStatus.cardsRevealing:
      case GameStatus.penalty:
        return RoundStartReveal(
          key: ValueKey(_roundNumber),
          tableAsset: 'assets/games/liars_poker/images/background/$_table.png',
          playerCount: _playerCount,
          playerSeatIndexes: _seatIndexes,
          remainingCardCounts: _remainingCardCounts,
          tableWidth: 300,
          onCompleted: () {
            if (_gameStatus == GameStatus.roundStarting) {
              _changeStatus(GameStatus.playing);
            }
          },
        );

      case GameStatus.result:
        return const Center(child: Result());

      case GameStatus.finished:
        return const SizedBox.shrink();
    }
  }

  bool get _shouldShowSubmittedPlay {
    if (_submittedPlay == null) return false;

    return switch (_gameStatus) {
      GameStatus.playing ||
      GameStatus.cardsPlaying ||
      GameStatus.cardsRevealing ||
      GameStatus.penalty => true,
      _ => false,
    };
  }

  Widget _buildSubmittedPlayLayer() {
    final submittedPlay = _submittedPlay!;

    return CardPlayAnimation(
      key: ValueKey(submittedPlay.eventId),
      playerCount: _playerCount,
      playerSeatIndexes: _seatIndexes,
      fromPlayerIndex: submittedPlay.playerIndex,
      frontCardAssets: submittedPlay.frontCardAssets,
      revealCards: _gameStatus == GameStatus.cardsRevealing,
      onCardsPlayed: () {
        if (_gameStatus == GameStatus.cardsPlaying) {
          _changeStatus(GameStatus.playing);
        }
      },
      onRevealed: () {
        if (_gameStatus == GameStatus.cardsRevealing) {
          _changeStatus(GameStatus.penalty);
        }
      },
    );
  }
}

class _SubmittedPlay {
  const _SubmittedPlay({
    required this.eventId,
    required this.playerIndex,
    required this.frontCardAssets,
  });

  final String eventId;
  final int playerIndex;
  final List<String> frontCardAssets;

  _SubmittedPlay copyWith({List<String>? frontCardAssets}) {
    return _SubmittedPlay(
      eventId: eventId,
      playerIndex: playerIndex,
      frontCardAssets: frontCardAssets ?? this.frontCardAssets,
    );
  }
}

enum GameStatus {
  waiting,
  dealing,
  roundStarting,
  playing,
  cardsPlaying,
  cardsRevealing,
  penalty,
  result,
  finished,
}
