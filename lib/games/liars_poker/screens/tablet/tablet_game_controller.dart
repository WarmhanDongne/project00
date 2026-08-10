import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:project00/games/liars_poker/models/player_layout_model.dart';
import 'package:project00/games/liars_poker/screens/tablet/game_status.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_helper.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/penalty/roulette.dart';

typedef TabletGameErrorHandler = void Function(String message, Object error);

/// 태블릿 게임 화면의 상태와 Realtime Database 구독을 관리합니다.
///
/// Cloud Function은 게임 규칙과 데이터 변경을 담당하고, 이 컨트롤러는
/// `game/public`을 읽어서 태블릿 전용 화면 상태로 변환합니다.
class TabletGameController extends ChangeNotifier {
  TabletGameController({
    required this.playerLayout,
    required this.roomCode,
    required this.gameService,
    required this.onError,
  }) : remainingCardCounts = List<int>.filled(
         playerLayout.playerCount,
         cardsPerPlayer,
       );

  final PlayerLayoutModel playerLayout;
  final String roomCode;
  final LiarsPokerService gameService;
  final TabletGameErrorHandler onError;

  StreamSubscription<DatabaseEvent>? _publicGameSubscription;

  GameStatus status = GameStatus.waiting;
  String table = 'K';
  String serverPhase = 'playing';
  int roundNumber = 1;
  int cardPileVersion = 0;
  int penaltyAttemptCount = 0;
  int rouletteRetry = 0;
  bool isResolvingPenalty = false;
  bool isProcessingMenuCommand = false;
  String? turnUid;
  String? winnerUid;
  PlayerLayoutPlayer? winnerPlayer;
  String? penaltyTargetUid;
  List<SubmittedPlay> roundPlays = const [];
  String? activeAnimationPlayId;

  List<int> remainingCardCounts;

  bool _hasReceivedPublicGame = false;

  int get playerCount => playerLayout.playerCount;

  List<int> get seatIndexes => playerLayout.seatIndexes;

  int? get currentTurnPlayerIndex {
    final currentTurnUid = turnUid;
    if (currentTurnUid == null) return null;

    final index = playerLayout.players.indexWhere(
      (player) => player.uid == currentTurnUid,
    );
    return index < 0 ? null : index;
  }

  bool get shouldShowSubmittedPlay {
    if (roundPlays.isEmpty) return false;
    return switch (status) {
      GameStatus.playing ||
      GameStatus.cardsPlaying ||
      GameStatus.cardsRevealing ||
      GameStatus.penalty => true,
      _ => false,
    };
  }

  void initialize() {
    _publicGameSubscription?.cancel();
    unawaited(_warmUpGameplayCommands());
    _publicGameSubscription = gameService.query
        .watchPublicGame(roomCode)
        .listen(_handlePublicGame, onError: _handlePublicGameError);
  }

  Future<void> _warmUpGameplayCommands() async {
    try {
      await gameService.command.warmUpGameplayCommands();
    } catch (_) {
      // 사전 준비 실패는 실제 명령의 자동 재시도로 복구되므로 UI에 표시하지 않습니다.
    }
  }

  Future<void> _warmUpLiarCommand() async {
    try {
      await gameService.command.warmUpLiarCommand();
    } catch (_) {
      // 실제 라이어 명령에서 재시도하므로 사전 준비 오류는 무시합니다.
    }
  }

  void _handlePublicGame(DatabaseEvent event) {
    final snapshot = TabletPublicGameSnapshot.tryParse(event.snapshot.value);
    if (snapshot == null) return;

    final isFirstSnapshot = !_hasReceivedPublicGame;
    final wasDealing = serverPhase == 'dealing';
    final isRoundChanged = snapshot.round != roundNumber;
    final shouldResetCardPile = isRoundChanged || snapshot.phase == 'dealing';

    // 새 라운드 및 게임 재시작으로 배분 단계에 다시 들어오면 카드 더미
    // 위젯 자체를 새 인스턴스로 만들어 남아 있던 애니메이션까지 종료합니다.
    if (snapshot.phase == 'dealing' &&
        (isFirstSnapshot || !wasDealing || isRoundChanged)) {
      cardPileVersion += 1;
    }
    final previousPlays = <String, SubmittedPlay>{
      for (final play in roundPlays) play.eventId: play,
    };
    final nextRoundPlays = <SubmittedPlay>[];
    var hasNewSubmission = false;
    var hasNewReveal = false;
    String? nextActiveAnimationPlayId;

    for (final publicPlay
        in shouldResetCardPile
            ? const <PublicLastPlay>[]
            : snapshot.roundPlays) {
      final playerIndex = playerLayout.players.indexWhere(
        (player) => player.uid == publicPlay.playerUid,
      );
      if (playerIndex < 0) continue;

      final previousPlay = previousPlays[publicPlay.playId];
      final isNewSubmission = previousPlay == null;
      final isNewReveal =
          publicPlay.revealed && previousPlay?.isRevealed != true;
      final ranks = publicPlay.revealed && publicPlay.actualRanks.isNotEmpty
          ? publicPlay.actualRanks
          : List<String>.filled(publicPlay.cardCount, publicPlay.declaredRank);

      nextRoundPlays.add(
        SubmittedPlay(
          eventId: publicPlay.playId,
          playerIndex: playerIndex,
          frontCardAssets: ranks.map(cardAssetForRank).toList(growable: false),
          submittedAt: publicPlay.submittedAt,
          isRevealed: publicPlay.revealed,
          // 첫 구독 때 복원한 카드는 중앙에 즉시 표시합니다.
          animateEntry: previousPlay?.animateEntry ?? !isFirstSnapshot,
        ),
      );

      if (!isFirstSnapshot && isNewSubmission) {
        hasNewSubmission = true;
        nextActiveAnimationPlayId = publicPlay.playId;
      }
      if (!isFirstSnapshot && isNewReveal) {
        hasNewReveal = true;
        nextActiveAnimationPlayId = publicPlay.playId;
      }
    }

    _hasReceivedPublicGame = true;
    table = snapshot.table;
    serverPhase = snapshot.phase;
    roundNumber = snapshot.round;
    remainingCardCounts = snapshot.remainingCardCounts(playerLayout);
    turnUid = snapshot.turnUid;
    winnerUid = snapshot.winnerUid;
    winnerPlayer = snapshot.playerByUid(winnerUid, playerLayout);
    penaltyTargetUid = snapshot.penaltyTargetUid;
    penaltyAttemptCount = snapshot.penaltyAttemptCount;
    isResolvingPenalty = false;

    roundPlays = shouldResetCardPile
        ? const []
        : List.unmodifiable(nextRoundPlays);
    activeAnimationPlayId = shouldResetCardPile
        ? null
        : nextActiveAnimationPlayId ?? activeAnimationPlayId;

    // 서버 상태보다 한 번만 실행해야 하는 애니메이션 상태를 우선합니다.
    if (snapshot.status == 'finished') {
      status = GameStatus.result;
    } else if (snapshot.phase == 'dealing') {
      // 더미 초기화를 먼저 반영하고 새 라운드 카드 배분만 표시합니다.
      status = GameStatus.dealing;
    } else if (hasNewReveal) {
      status = GameStatus.cardsRevealing;
    } else if (hasNewSubmission) {
      status = GameStatus.cardsPlaying;
      unawaited(_warmUpLiarCommand());
    } else if (snapshot.phase == 'penalty' &&
        status != GameStatus.cardsRevealing) {
      status = GameStatus.penalty;
    } else if (isRoundChanged) {
      // 새 라운드에서도 태블릿 카드 배분 애니메이션을 다시 실행합니다.
      status = GameStatus.roundStarting;
    } else if (isFirstSnapshot && roundPlays.isEmpty) {
      // 게임 화면에 처음 들어왔을 때만 카드 배분 애니메이션을 실행합니다.
      status = GameStatus.dealing;
    } else if (isFirstSnapshot) {
      // 진행 중 재접속이면 기존 더미를 복원하고 바로 현재 단계로 진입합니다.
      status = snapshot.phase == 'penalty'
          ? GameStatus.penalty
          : GameStatus.playing;
    }

    notifyListeners();
  }

  void _handlePublicGameError(Object error) {
    onError('게임 상태를 불러오지 못했습니다.', error);
  }

  /// 현재 방과 좌석은 유지하고 게임 데이터만 새로 만듭니다.
  Future<bool> restartGame() async {
    if (isProcessingMenuCommand) return false;

    isProcessingMenuCommand = true;
    notifyListeners();
    try {
      await gameService.command.restartGame(roomCode: roomCode);
      return true;
    } catch (error) {
      onError('게임을 재시작하지 못했습니다.', error);
      return false;
    } finally {
      isProcessingMenuCommand = false;
      notifyListeners();
    }
  }

  /// RTDB 방은 삭제하지 않고 현재 게임 상태만 종료합니다.
  Future<bool> endGame() async {
    if (isProcessingMenuCommand) return false;

    isProcessingMenuCommand = true;
    notifyListeners();
    try {
      await gameService.command.endGame(roomCode: roomCode);
      return true;
    } catch (error) {
      onError('게임을 종료하지 못했습니다.', error);
      return false;
    } finally {
      isProcessingMenuCommand = false;
      notifyListeners();
    }
  }

  /// 룰렛 결과만 Cloud Function에 전달합니다.
  /// 실제 탈락 및 새 라운드 처리는 서버가 결정합니다.
  Future<void> resolveRoulette(RouletteResult result) async {
    if (isResolvingPenalty || penaltyTargetUid == null) return;

    isResolvingPenalty = true;
    notifyListeners();

    try {
      await gameService.command.resolvePenalty(
        roomCode: roomCode,
        result: result.name,
      );
    } catch (error) {
      isResolvingPenalty = false;
      rouletteRetry += 1;
      notifyListeners();
      onError('룰렛 결과를 반영하지 못했습니다.', error);
    }
  }

  // -------------------------------------------------------------------------
  // 화면 애니메이션 완료 이벤트
  // -------------------------------------------------------------------------

  Future<void> onDealCompleted() async {
    changeStatus(GameStatus.roundStarting);

    // 이전 서버 버전이나 개발용 로컬 상태에서는 별도 완료 호출이 필요 없습니다.
    if (serverPhase != 'dealing') return;

    try {
      await gameService.command.completeDealing(roomCode: roomCode);
    } catch (error) {
      onError('카드 배분 완료 상태를 반영하지 못했습니다.', error);
    }
  }

  void onRoundRevealCompleted() {
    if (status == GameStatus.roundStarting) {
      changeStatus(GameStatus.playing);
    }
  }

  void onCardsPlayed() {
    if (status == GameStatus.cardsPlaying) {
      changeStatus(GameStatus.playing);
    }
  }

  void onCardsRevealed() {
    if (status != GameStatus.cardsRevealing) return;
    changeStatus(
      serverPhase == 'penalty' ? GameStatus.penalty : GameStatus.playing,
    );
  }

  void changeStatus(GameStatus nextStatus) {
    if (status == nextStatus) return;
    status = nextStatus;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // 기존 외부 호출 API
  // -------------------------------------------------------------------------

  void startDealing() {
    roundPlays = const [];
    activeAnimationPlayId = null;
    cardPileVersion += 1;
    changeStatus(GameStatus.dealing);
  }

  void startNextRound({
    required String table,
    required List<int> remainingCardCounts,
  }) {
    if (remainingCardCounts.length != playerCount) {
      throw ArgumentError.value(
        remainingCardCounts,
        'remainingCardCounts',
        '잔여 카드 수는 플레이어 수와 같아야 합니다.',
      );
    }

    this.table = table;
    this.remainingCardCounts = List<int>.from(remainingCardCounts);
    roundNumber += 1;
    roundPlays = const [];
    activeAnimationPlayId = null;
    cardPileVersion += 1;
    status = GameStatus.roundStarting;
    notifyListeners();
  }

  void showSubmittedCards({
    required String eventId,
    required String playerId,
    required int cardCount,
  }) {
    if (cardCount < 1 || cardCount > 3) {
      throw ArgumentError.value(cardCount, 'cardCount', '카드는 1~3장이어야 합니다.');
    }

    final playerIndex = playerLayout.players.indexWhere(
      (player) => player.uid == playerId,
    );
    if (playerIndex < 0) {
      throw ArgumentError.value(
        playerId,
        'playerId',
        '플레이어 배치에서 사용자를 찾을 수 없습니다.',
      );
    }

    final submittedAt = DateTime.now().millisecondsSinceEpoch;
    final play = SubmittedPlay(
      eventId: eventId,
      playerIndex: playerIndex,
      frontCardAssets: List.filled(cardCount, cardAssetForRank('Q')),
      submittedAt: submittedAt,
    );
    roundPlays = List.unmodifiable([...roundPlays, play]);
    activeAnimationPlayId = eventId;
    status = GameStatus.cardsPlaying;
    notifyListeners();
  }

  void revealSubmittedCards(List<String> actualRanks) {
    if (roundPlays.isEmpty) return;
    final currentPlay = roundPlays.last;

    if (actualRanks.length != currentPlay.frontCardAssets.length) {
      throw ArgumentError.value(
        actualRanks,
        'actualRanks',
        '공개 카드 수와 제출 카드 수가 같아야 합니다.',
      );
    }

    final revealedPlay = currentPlay.copyWith(
      frontCardAssets: actualRanks
          .map(cardAssetForRank)
          .toList(growable: false),
      isRevealed: true,
    );
    roundPlays = List.unmodifiable([
      ...roundPlays.take(roundPlays.length - 1),
      revealedPlay,
    ]);
    activeAnimationPlayId = currentPlay.eventId;
    status = GameStatus.cardsRevealing;
    notifyListeners();
  }

  // -------------------------------------------------------------------------
  // 개발 빌드 전용 상태 선택기
  // -------------------------------------------------------------------------

  void selectDebugStatus(GameStatus? nextStatus) {
    if (nextStatus == null) return;

    switch (nextStatus) {
      case GameStatus.cardsPlaying:
        _showTestCardSubmitAnimation();
      case GameStatus.cardsRevealing:
        _showTestCardRevealAnimation();
      case GameStatus.waiting:
      case GameStatus.dealing:
      case GameStatus.roundStarting:
      case GameStatus.result:
      case GameStatus.finished:
        roundPlays = const [];
        activeAnimationPlayId = null;
        status = nextStatus;
        notifyListeners();
      case GameStatus.playing:
      case GameStatus.penalty:
        status = nextStatus;
        notifyListeners();
    }
  }

  void _showTestCardSubmitAnimation() {
    if (playerCount <= 0) return;

    final eventId = 'test-submit-${DateTime.now().microsecondsSinceEpoch}';
    final play = SubmittedPlay(
      eventId: eventId,
      playerIndex: 0,
      frontCardAssets: [cardAssetForRank('Q'), cardAssetForRank('Q')],
      submittedAt: DateTime.now().millisecondsSinceEpoch,
    );
    roundPlays = List.unmodifiable([...roundPlays, play]);
    activeAnimationPlayId = eventId;
    status = GameStatus.cardsPlaying;
    notifyListeners();
  }

  void _showTestCardRevealAnimation() {
    if (playerCount <= 0) return;

    final previousPlay = roundPlays.isEmpty ? null : roundPlays.last;
    final playerIndex = previousPlay?.playerIndex ?? 0;
    final cardCount = previousPlay?.frontCardAssets.length ?? 2;
    const ranks = ['Q', 'K', 'A'];

    final eventId =
        previousPlay?.eventId ??
        'test-reveal-${DateTime.now().microsecondsSinceEpoch}';
    final revealedPlay = SubmittedPlay(
      eventId: eventId,
      playerIndex: playerIndex,
      frontCardAssets: List.generate(
        cardCount,
        (index) => cardAssetForRank(ranks[index % ranks.length]),
        growable: false,
      ),
      submittedAt:
          previousPlay?.submittedAt ?? DateTime.now().millisecondsSinceEpoch,
      isRevealed: true,
      animateEntry: previousPlay?.animateEntry ?? true,
    );
    roundPlays = previousPlay == null
        ? [revealedPlay]
        : List.unmodifiable([
            ...roundPlays.take(roundPlays.length - 1),
            revealedPlay,
          ]);
    activeAnimationPlayId = eventId;
    status = GameStatus.cardsRevealing;
    notifyListeners();
  }

  @override
  void dispose() {
    _publicGameSubscription?.cancel();
    super.dispose();
  }
}
