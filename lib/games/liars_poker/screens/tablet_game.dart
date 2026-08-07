import 'package:flutter/material.dart';
import 'package:project00/games/liars_poker/animations/card_deal.dart';
import 'package:project00/games/liars_poker/animations/card_play_animation.dart';
import 'package:project00/games/liars_poker/animations/round_start_reveal.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/games/liars_poker/widgets/result.dart';
import 'package:project00/games/liars_poker/widgets/sideblock.dart';
import 'package:project00/games/penalty/roulette.dart';
import 'package:project00/platform/home/room/providers/room_provider.dart';

class TabletGame extends StatefulWidget {
  const TabletGame({
    super.key,
    required this.playerLayout,
    required this.provider,
  });

  final PlayerLayoutModel playerLayout;
  final RoomProvider provider;

  @override
  State<TabletGame> createState() => TabletGameState();
}

class TabletGameState extends State<TabletGame> {
  static const int _cardsPerPlayer = 5;

  late List<int> _remainingCardCounts;

  // 처음에는 기본 게임 진행 화면 표시
  GameStatus _gameStatus = GameStatus.playing;

  String _table = 'K';
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

  // ---------------------------------------------------------------------------
  // 실제 게임 이벤트
  // ---------------------------------------------------------------------------

  /// 게임 시작 시 카드 분배
  void startDealing() {
    if (!mounted) return;

    setState(() {
      _submittedPlay = null;
      _gameStatus = GameStatus.dealing;
    });
  }

  /// 새 라운드 시작
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

  /// 백엔드에서 카드 제출 이벤트를 받았을 때 호출
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

  /// 백엔드에서 카드 공개 이벤트를 받았을 때 호출
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

  void showPenalty() {
    _changeStatus(GameStatus.penalty);
  }

  void showResult() {
    _changeStatus(GameStatus.result);
  }

  void finishGame() {
    _changeStatus(GameStatus.finished);
  }

  void _changeStatus(GameStatus nextStatus) {
    if (!mounted || _gameStatus == nextStatus) return;

    setState(() {
      _gameStatus = nextStatus;
    });
  }

  // ---------------------------------------------------------------------------
  // 개발용 테스트 셀렉터
  // ---------------------------------------------------------------------------

  void _selectGameStatus(GameStatus? nextStatus) {
    if (nextStatus == null) return;

    switch (nextStatus) {
      case GameStatus.cardsPlaying:
        _showTestCardSubmitAnimation();
        return;

      case GameStatus.cardsRevealing:
        _showTestCardRevealAnimation();
        return;

      case GameStatus.waiting:
      case GameStatus.dealing:
      case GameStatus.roundStarting:
      case GameStatus.result:
      case GameStatus.finished:
        setState(() {
          _submittedPlay = null;
          _gameStatus = nextStatus;
        });
        return;

      case GameStatus.playing:
      case GameStatus.penalty:
        setState(() {
          _gameStatus = nextStatus;
        });
        return;
    }
  }

  /// 셀렉터에서 카드 제출을 선택했을 때 테스트 애니메이션 실행
  void _showTestCardSubmitAnimation() {
    if (_playerCount <= 0) {
      debugPrint('플레이어가 없어 카드 제출 애니메이션을 실행할 수 없습니다.');
      return;
    }

    setState(() {
      _submittedPlay = _SubmittedPlay(
        // ValueKey가 매번 달라져 애니메이션이 다시 실행됨
        eventId: 'test-submit-${DateTime.now().microsecondsSinceEpoch}',

        // 첫 번째 플레이어가 카드를 내는 것으로 테스트
        playerIndex: 0,

        // 테스트용 카드 2장
        frontCardAssets: [_cardAssetForRank('Q'), _cardAssetForRank('Q')],
      );

      _gameStatus = GameStatus.cardsPlaying;
    });
  }

  /// 셀렉터에서 카드 공개를 선택했을 때 테스트 애니메이션 실행
  void _showTestCardRevealAnimation() {
    if (_playerCount <= 0) {
      debugPrint('플레이어가 없어 카드 공개 애니메이션을 실행할 수 없습니다.');
      return;
    }

    final previousPlay = _submittedPlay;

    final playerIndex = previousPlay?.playerIndex ?? 0;
    final cardCount = previousPlay?.frontCardAssets.length ?? 2;

    final testRanks = <String>['Q', 'K', 'A'];

    setState(() {
      _submittedPlay = _SubmittedPlay(
        eventId: 'test-reveal-${DateTime.now().microsecondsSinceEpoch}',
        playerIndex: playerIndex,
        frontCardAssets: List<String>.generate(
          cardCount,
          (index) => _cardAssetForRank(testRanks[index % testRanks.length]),
          growable: false,
        ),
      );

      _gameStatus = GameStatus.cardsRevealing;
    });
  }

  String _gameStatusLabel(GameStatus status) {
    return switch (status) {
      GameStatus.waiting => '게임 대기',
      GameStatus.dealing => '카드 배분',
      GameStatus.roundStarting => '라운드 시작',
      GameStatus.playing => '게임 진행',
      GameStatus.cardsPlaying => '카드 제출 애니메이션',
      GameStatus.cardsRevealing => '카드 공개 애니메이션',
      GameStatus.penalty => '벌칙 룰렛',
      GameStatus.result => '결과',
      GameStatus.finished => '게임 종료',
    };
  }

  // ---------------------------------------------------------------------------
  // 카드 이미지
  // ---------------------------------------------------------------------------

  String _cardAssetForRank(String rank) {
    return switch (rank.toUpperCase()) {
      'A' => 'assets/games/liars_poker/images/cards/white A.png',
      'K' => 'assets/games/liars_poker/images/cards/white K.png',
      'Q' => 'assets/games/liars_poker/images/cards/white Q.png',
      'JOKER' => 'assets/games/liars_poker/images/cards/white Joker.png',
      _ => 'assets/games/liars_poker/images/cards/white back.png',
    };
  }

  // ---------------------------------------------------------------------------
  // 화면
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // 배경
          Positioned.fill(
            child: ColoredBox(
              color: Colors.black,
              child: Image.asset(
                'assets/games/liars_poker/images/background/background.png',
                fit: BoxFit.contain,
                alignment: Alignment.center,
              ),
            ),
          ),

          // 게임 상태 화면
          Positioned.fill(child: _buildStatusLayer()),

          // 카드 제출/공개 애니메이션
          if (_shouldShowSubmittedPlay)
            Positioned.fill(child: _buildSubmittedPlayLayer()),

          // 벌칙 룰렛
          if (_gameStatus == GameStatus.penalty)
            Positioned.fill(
              child: Center(
                child: PenaltyRoulette(
                  attemptCount: 0,
                  onResult: (result) async {
                    await widget.provider.sendRouletteResult(result as String);
                  },
                ),
              ),
            ),

          // 벌칙 안내
          if (_gameStatus == GameStatus.penalty)
            const Positioned(
              top: 25,
              left: 0,
              right: 0,
              child: IgnorePointer(
                child: Center(
                  child: Text(
                    '벌칙 진행 중',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      shadows: [
                        Shadow(
                          color: Colors.black,
                          blurRadius: 8,
                          offset: Offset(0, 3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          // 왼쪽 위 상태 선택
          Positioned(top: 20, left: 20, child: _buildGameStatusSelector()),

          // 오른쪽 위 메뉴
          Positioned(
            top: 20,
            right: 20,
            child: SideBlock(provider: widget.provider),
          ),
        ],
      ),
    );
  }

  Widget _buildGameStatusSelector() {
    return Container(
      width: 270,
      height: 58,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      decoration: BoxDecoration(
        color: const Color(0xee151515),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white38, width: 1.5),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 12,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<GameStatus>(
          value: _gameStatus,
          isExpanded: true,
          borderRadius: BorderRadius.circular(14),
          dropdownColor: const Color(0xff202020),
          icon: const Icon(
            Icons.keyboard_arrow_down_rounded,
            color: Colors.white,
            size: 28,
          ),
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w700,
          ),
          items: GameStatus.values
              .map((status) {
                return DropdownMenuItem<GameStatus>(
                  value: status,
                  child: Text(
                    _gameStatusLabel(status),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                );
              })
              .toList(growable: false),
          onChanged: _selectGameStatus,
        ),
      ),
    );
  }

  Widget _buildStatusLayer() {
    switch (_gameStatus) {
      case GameStatus.waiting:
        return const Center(
          child: Text(
            '게임 시작 대기 중',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
        );

      case GameStatus.dealing:
        return CardDealAnimation(
          playerCount: _playerCount,
          playerSeatIndexes: _seatIndexes,
          cardsPerPlayer: _cardsPerPlayer,
          duration: const Duration(milliseconds: 2800),
          onCompleted: () {
            _changeStatus(GameStatus.roundStarting);
          },
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
        return const Center(
          child: Text(
            '게임이 종료되었습니다.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 32,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
    }
  }

  bool get _shouldShowSubmittedPlay {
    if (_submittedPlay == null) {
      return false;
    }

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
      // eventId가 달라질 때마다 새로운 애니메이션 실행
      key: ValueKey(submittedPlay.eventId),
      playerCount: _playerCount,
      playerSeatIndexes: _seatIndexes,
      fromPlayerIndex: submittedPlay.playerIndex,
      frontCardAssets: submittedPlay.frontCardAssets,
      revealCards: _gameStatus == GameStatus.cardsRevealing,
      onCardsPlayed: () {
        if (_gameStatus == GameStatus.cardsPlaying) {
          // 제출 애니메이션이 끝나면 중앙의 카드를 유지한 채 playing으로 전환
          _changeStatus(GameStatus.playing);
        }
      },
      onRevealed: () {
        if (_gameStatus == GameStatus.cardsRevealing) {
          // 카드 공개가 끝나면 벌칙 화면으로 전환
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

  _SubmittedPlay copyWith({
    String? eventId,
    int? playerIndex,
    List<String>? frontCardAssets,
  }) {
    return _SubmittedPlay(
      eventId: eventId ?? this.eventId,
      playerIndex: playerIndex ?? this.playerIndex,
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
