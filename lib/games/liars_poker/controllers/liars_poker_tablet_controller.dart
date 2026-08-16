import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_tablet_state.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/liars_poker/screens/tablet/tablet_game_helper.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/penalty/roulette.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';

typedef LiarsPokerTabletErrorHandler =
    void Function(String message, Object error);

/// 태블릿 게임 화면의 상태와 Realtime Database 구독을 관리합니다.
///
/// Cloud Function은 게임 규칙과 데이터 변경을 담당하고, 이 컨트롤러는
/// `game/public`을 읽어서 태블릿 전용 화면 상태로 변환합니다.
class LiarsPokerTabletController extends Notifier<LiarsPokerTabletState> {
  LiarsPokerTabletController({
    required this.playerLayout,
    required this.roomCode,
    required this.service,
    required this.onError,
  });

  final PlayerLayoutModel playerLayout;
  final String roomCode;
  final LiarsPokerService service;
  final LiarsPokerTabletErrorHandler onError;

  StreamSubscription<DatabaseEvent>? _publicGameSubscription;
  Timer? _penaltyTransitionTimer;

  bool _hasReceivedPublicGame = false;
  Completer<void> _initialDataCompleter = Completer<void>();
  late LiarsPokerTabletState _draft;

  @override
  LiarsPokerTabletState build() {
    _draft = LiarsPokerTabletState.initial(playerLayout.playerCount);
    initialize();
    ref.onDispose(() {
      _penaltyTransitionTimer?.cancel();
      unawaited(_publicGameSubscription?.cancel());
    });
    return _draft;
  }

  void _commit() {
    if (!ref.mounted) return;
    state = _draft;
  }

  //=======================불변 상태 호환 접근자==============================
  LiarsPokerTabletStage get stage => _draft.stage;
  set stage(LiarsPokerTabletStage value) =>
      _draft = _draft.copyWith(stage: value);
  String get table => _draft.table;
  set table(String value) => _draft = _draft.copyWith(table: value);
  String get serverPhase => _draft.serverPhase;
  set serverPhase(String value) => _draft = _draft.copyWith(serverPhase: value);
  int get roundNumber => _draft.roundNumber;
  set roundNumber(int value) => _draft = _draft.copyWith(roundNumber: value);
  int get cardPileVersion => _draft.cardPileVersion;
  set cardPileVersion(int value) =>
      _draft = _draft.copyWith(cardPileVersion: value);
  int get penaltyAttemptCount => _draft.penaltyAttemptCount;
  set penaltyAttemptCount(int value) =>
      _draft = _draft.copyWith(penaltyAttemptCount: value);
  int get rouletteRetry => _draft.rouletteRetry;
  set rouletteRetry(int value) =>
      _draft = _draft.copyWith(rouletteRetry: value);
  bool get isResolvingPenalty => _draft.isResolvingPenalty;
  set isResolvingPenalty(bool value) =>
      _draft = _draft.copyWith(isResolvingPenalty: value);
  bool get isProcessingMenuCommand => _draft.isProcessingMenuCommand;
  set isProcessingMenuCommand(bool value) =>
      _draft = _draft.copyWith(isProcessingMenuCommand: value);
  bool get isInsufficientPlayersEnding => _draft.isInsufficientPlayersEnding;
  set isInsufficientPlayersEnding(bool value) =>
      _draft = _draft.copyWith(isInsufficientPlayersEnding: value);
  String? get endingMessage => _draft.endingMessage;
  set endingMessage(String? value) =>
      _draft = _draft.copyWith(endingMessage: value);
  String? get turnUid => _draft.turnUid;
  set turnUid(String? value) => _draft = _draft.copyWith(turnUid: value);
  String? get winnerUid => _draft.winnerUid;
  set winnerUid(String? value) => _draft = _draft.copyWith(winnerUid: value);
  PlayerLayoutPlayer? get winnerPlayer => _draft.winnerPlayer;
  set winnerPlayer(PlayerLayoutPlayer? value) =>
      _draft = _draft.copyWith(winnerPlayer: value);
  String? get penaltyTargetUid => _draft.penaltyTargetUid;
  set penaltyTargetUid(String? value) =>
      _draft = _draft.copyWith(penaltyTargetUid: value);
  PlayerLayoutPlayer? get penaltyPlayer => _draft.penaltyPlayer;
  set penaltyPlayer(PlayerLayoutPlayer? value) =>
      _draft = _draft.copyWith(penaltyPlayer: value);
  List<SubmittedPlay> get roundPlays => _draft.roundPlays;
  set roundPlays(List<SubmittedPlay> value) =>
      _draft = _draft.copyWith(roundPlays: value);
  String? get activeAnimationPlayId => _draft.activeAnimationPlayId;
  set activeAnimationPlayId(String? value) =>
      _draft = _draft.copyWith(activeAnimationPlayId: value);
  List<String> get profileImageUrls => _draft.profileImageUrls;
  set profileImageUrls(List<String> value) =>
      _draft = _draft.copyWith(profileImageUrls: value);
  List<int> get remainingCardCounts => _draft.remainingCardCounts;
  set remainingCardCounts(List<int> value) =>
      _draft = _draft.copyWith(remainingCardCounts: value);
  GameInterruption? get interruption => _draft.interruption;
  set interruption(GameInterruption? value) =>
      _draft = _draft.copyWith(interruption: value);

  int get playerCount => playerLayout.playerCount;

  /// 서버에서 공개 게임 상태의 첫 유효 스냅샷을 받을 때까지 기다립니다.
  Future<void> waitForInitialData() {
    if (_hasReceivedPublicGame) return Future<void>.value();
    return _initialDataCompleter.future;
  }

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
    return switch (stage) {
      LiarsPokerTabletStage.playing ||
      LiarsPokerTabletStage.cardsPlaying ||
      LiarsPokerTabletStage.cardsRevealing => true,
      _ => false,
    };
  }

  void initialize() {
    _publicGameSubscription?.cancel();
    if (!_hasReceivedPublicGame) {
      _initialDataCompleter = Completer<void>();
    }
    unawaited(_warmUpGameplayCommands());
    _publicGameSubscription = service.query
        .watchPublicGame(roomCode)
        .listen(_handlePublicGame, onError: _handlePublicGameError);
  }

  Future<void> _warmUpGameplayCommands() async {
    try {
      await service.command.warmUpGameplayCommands();
    } catch (_) {
      // 사전 준비 실패는 실제 명령의 자동 재시도로 복구되므로 UI에 표시하지 않습니다.
    }
  }

  Future<void> _warmUpLiarCommand() async {
    try {
      await service.command.warmUpLiarCommand();
    } catch (_) {
      // 실제 라이어 명령에서 재시도하므로 사전 준비 오류는 무시합니다.
    }
  }

  void _handlePublicGame(DatabaseEvent event) {
    final snapshot = TabletPublicGameSnapshot.tryParse(event.snapshot.value);
    if (snapshot == null) return;

    if (snapshot.phase != 'penalty') {
      _penaltyTransitionTimer?.cancel();
      _penaltyTransitionTimer = null;
    }

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

    table = snapshot.table;
    serverPhase = snapshot.phase;
    roundNumber = snapshot.round;
    remainingCardCounts = snapshot.remainingCardCounts(playerLayout);
    turnUid = snapshot.turnUid;
    winnerUid = snapshot.winnerUid;
    winnerPlayer = snapshot.playerByUid(winnerUid, playerLayout);
    penaltyTargetUid = snapshot.penaltyTargetUid;
    penaltyPlayer = snapshot.playerByUid(penaltyTargetUid, playerLayout);
    profileImageUrls = List.unmodifiable(
      playerLayout.players
          .map((player) {
            final publicPlayer = snapshot.players[player.uid];
            if (publicPlayer is Map) {
              final url = publicPlayer['profileImageUrl'];
              if (url is String && url.trim().isNotEmpty) return url.trim();
            }
            return player.profileImageUrl.trim();
          })
          .where((url) => url.isNotEmpty),
    );
    penaltyAttemptCount = snapshot.penaltyAttemptCount;
    isResolvingPenalty = false;
    isInsufficientPlayersEnding =
        snapshot.status == 'finished' &&
        (snapshot.finishReason == 'insufficientPlayers' ||
            snapshot.finishReason == 'interruptionVoteExpired');
    endingMessage = switch (snapshot.finishReason) {
      'insufficientPlayers' => GameFlowCopy.insufficientPlayers,
      'interruptionVoteExpired' => GameFlowCopy.interruptionVoteExpired,
      _ => null,
    };
    interruption = snapshot.interruption;

    roundPlays = shouldResetCardPile
        ? const []
        : List.unmodifiable(nextRoundPlays);
    activeAnimationPlayId = shouldResetCardPile
        ? null
        : nextActiveAnimationPlayId ?? activeAnimationPlayId;

    // 서버 상태보다 한 번만 실행해야 하는 애니메이션 상태를 우선합니다.
    if (isInsufficientPlayersEnding) {
      // 태블릿에서 1초간 인원 부족 안내와 카드 더미 암전 상태를 보여준 뒤
      // 게임 화면만 닫습니다. 현재 표시 상태는 유지해 테이블이 사라지지 않습니다.
    } else if (snapshot.status == 'finished') {
      stage = LiarsPokerTabletStage.result;
    } else if (snapshot.phase == 'dealing') {
      // 더미 초기화를 먼저 반영하고 새 라운드 카드 배분만 표시합니다.
      stage = LiarsPokerTabletStage.dealing;
    } else if (hasNewReveal) {
      stage = LiarsPokerTabletStage.cardsRevealing;
    } else if (hasNewSubmission) {
      stage = LiarsPokerTabletStage.cardsPlaying;
      unawaited(_warmUpLiarCommand());
    } else if (snapshot.phase == 'penalty' &&
        stage != LiarsPokerTabletStage.cardsRevealing) {
      stage = LiarsPokerTabletStage.penalty;
    } else if (isRoundChanged) {
      // 새 라운드에서도 태블릿 카드 배분 애니메이션을 다시 실행합니다.
      stage = LiarsPokerTabletStage.roundStarting;
    } else if (isFirstSnapshot && roundPlays.isEmpty) {
      // 게임 화면에 처음 들어왔을 때만 카드 배분 애니메이션을 실행합니다.
      stage = LiarsPokerTabletStage.dealing;
    } else if (isFirstSnapshot) {
      // 진행 중 재접속이면 기존 더미를 복원하고 바로 현재 단계로 진입합니다.
      stage = snapshot.phase == 'penalty'
          ? LiarsPokerTabletStage.penalty
          : LiarsPokerTabletStage.playing;
    }

    //=======================최초 진입 데이터 준비 완료==============================
    // 프로필 URL을 포함한 모든 공개 상태를 먼저 저장한 뒤 로딩 화면을
    // 종료합니다. 완료 신호가 먼저 전달되면 프로필 캐시가 빈 목록으로
    // 실행되어 게임 화면에서 네트워크 이미지를 다시 기다리게 됩니다.
    _hasReceivedPublicGame = true;
    if (!_initialDataCompleter.isCompleted) {
      _initialDataCompleter.complete();
    }

    _commit();
  }

  void _handlePublicGameError(Object error) {
    if (!_initialDataCompleter.isCompleted) {
      _initialDataCompleter.completeError(error);
    }
    onError('게임 상태를 불러오지 못했습니다.', error);
  }

  /// 현재 방과 좌석은 유지하고 게임 데이터만 새로 만듭니다.
  Future<bool> restartGame() async {
    if (isProcessingMenuCommand) return false;

    isProcessingMenuCommand = true;
    _commit();
    try {
      await service.command.restartGame(roomCode: roomCode);
      return true;
    } catch (error) {
      onError('게임을 재시작하지 못했습니다.', error);
      return false;
    } finally {
      isProcessingMenuCommand = false;
      _commit();
    }
  }

  /// RTDB 방은 삭제하지 않고 현재 게임 상태만 종료합니다.
  Future<bool> endGame() async {
    if (isProcessingMenuCommand) return false;

    isProcessingMenuCommand = true;
    _commit();
    try {
      await service.command.endGame(roomCode: roomCode);
      return true;
    } catch (error) {
      onError('게임을 종료하지 못했습니다.', error);
      return false;
    } finally {
      isProcessingMenuCommand = false;
      _commit();
    }
  }

  Future<bool> expireInterruption() async {
    final current = interruption;
    if (current == null || isProcessingMenuCommand) return false;
    isProcessingMenuCommand = true;
    _commit();
    try {
      await service.interruption.expire(
        roomCode: roomCode,
        interruptionId: current.id,
      );
      return true;
    } catch (error) {
      onError('연결 중단 상태를 종료하지 못했습니다.', error);
      return false;
    } finally {
      isProcessingMenuCommand = false;
      _commit();
    }
  }

  /// 룰렛 결과만 Cloud Function에 전달합니다.
  /// 실제 탈락 및 새 라운드 처리는 서버가 결정합니다.
  Future<void> resolveRoulette(RouletteResult result) async {
    if (isResolvingPenalty || penaltyTargetUid == null) return;

    isResolvingPenalty = true;
    _commit();

    try {
      await service.command.resolvePenalty(
        roomCode: roomCode,
        result: result.name,
      );
    } catch (error) {
      isResolvingPenalty = false;
      rouletteRetry += 1;
      _commit();
      onError('룰렛 결과를 반영하지 못했습니다.', error);
    }
  }

  // -------------------------------------------------------------------------
  // 화면 애니메이션 완료 이벤트
  // -------------------------------------------------------------------------

  Future<void> onDealCompleted() async {
    changeStage(LiarsPokerTabletStage.roundStarting);

    // 이전 서버 버전이나 개발용 로컬 상태에서는 별도 완료 호출이 필요 없습니다.
    if (serverPhase != 'dealing') return;

    try {
      await service.command.completeDealing(roomCode: roomCode);
    } catch (error) {
      onError('카드 배분 완료 상태를 반영하지 못했습니다.', error);
    }
  }

  void onRoundRevealCompleted() {
    if (stage == LiarsPokerTabletStage.roundStarting) {
      changeStage(LiarsPokerTabletStage.playing);
    }
  }

  void onCardsPlayed() {
    if (stage == LiarsPokerTabletStage.cardsPlaying) {
      changeStage(LiarsPokerTabletStage.playing);
    }
  }

  void onCardsRevealed() {
    if (stage != LiarsPokerTabletStage.cardsRevealing) return;

    if (serverPhase != 'penalty') {
      changeStage(LiarsPokerTabletStage.playing);
      return;
    }
    if (_penaltyTransitionTimer != null) return;

    // 공개된 카드와 판정 결과를 충분히 확인한 뒤 룰렛 화면으로 전환합니다.
    _penaltyTransitionTimer = Timer(const Duration(seconds: 3), () {
      _penaltyTransitionTimer = null;
      if (serverPhase == 'penalty' &&
          stage == LiarsPokerTabletStage.cardsRevealing) {
        changeStage(LiarsPokerTabletStage.penalty);
      }
    });
  }

  void changeStage(LiarsPokerTabletStage nextStage) {
    if (stage == nextStage) return;
    stage = nextStage;
    _commit();
  }

  // -------------------------------------------------------------------------
  // 기존 외부 호출 API
  // -------------------------------------------------------------------------

  void startDealing() {
    roundPlays = const [];
    activeAnimationPlayId = null;
    cardPileVersion += 1;
    changeStage(LiarsPokerTabletStage.dealing);
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
    stage = LiarsPokerTabletStage.roundStarting;
    _commit();
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
    stage = LiarsPokerTabletStage.cardsPlaying;
    _commit();
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
    stage = LiarsPokerTabletStage.cardsRevealing;
    _commit();
  }

  // -------------------------------------------------------------------------
  // 개발 빌드 전용 상태 선택기
  // -------------------------------------------------------------------------

  void selectDebugStage(LiarsPokerTabletStage? nextStage) {
    if (nextStage == null) return;

    switch (nextStage) {
      case LiarsPokerTabletStage.cardsPlaying:
        _showTestCardSubmitAnimation();
      case LiarsPokerTabletStage.cardsRevealing:
        _showTestCardRevealAnimation();
      case LiarsPokerTabletStage.waiting:
      case LiarsPokerTabletStage.dealing:
      case LiarsPokerTabletStage.roundStarting:
      case LiarsPokerTabletStage.result:
      case LiarsPokerTabletStage.finished:
        roundPlays = const [];
        activeAnimationPlayId = null;
        stage = nextStage;
        _commit();
      case LiarsPokerTabletStage.playing:
      case LiarsPokerTabletStage.penalty:
        stage = nextStage;
        _commit();
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
    stage = LiarsPokerTabletStage.cardsPlaying;
    _commit();
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
    stage = LiarsPokerTabletStage.cardsRevealing;
    _commit();
  }
}
