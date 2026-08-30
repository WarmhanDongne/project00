import 'dart:async';
import 'package:project00/core/error/user_error_message.dart';
import 'package:project00/core/time/server_clock.dart';

import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/games/liars_poker/liars_poker_copy.dart';
import 'package:project00/games/liars_poker/models/liars_poker_models.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_game_state.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';
import 'package:project00/games/penalty/roulette.dart';
import 'package:project00/games/shared/game_flow/game_finish.dart';
import 'package:project00/games/shared/game_flow/game_flow_copy.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/core/assets/game_image.dart';

export 'package:project00/games/liars_poker/models/liars_poker_models.dart'
    show PhoneGamePlayer, PhoneHandCard, PhonePenaltyResult, PublicLastPlay;

typedef LiarsPokerErrorHandler = void Function(String message, Object error);

//=======================Liar's Poker Riverpod 게임 컨트롤러==============================
/// Final Call처럼 휴대폰과 태블릿이 함께 쓰는 단일 서버 미러 컨트롤러입니다.
///
/// 서버 상태는 불변 [LiarsPokerGameState]로 발행하고, 태블릿 전용 연출 상태
/// (stage, 카드 더미 버전, 제출 연출)는 태블릿 화면 State가 소유합니다.
/// Provider가 폐기되면 Realtime Database 구독도 종료됩니다.
class LiarsPokerController extends Notifier<LiarsPokerGameState> {
  static const int _cardsPerNewHand = 5;

  LiarsPokerController({
    required this.roomCode,
    required this.uid,
    required this.service,
    this.watchPrivateHand = true,
    this.onError,
  });

  final String roomCode;
  final String uid;
  final LiarsPokerService service;

  /// 휴대폰은 true(내 손패 구독), 태블릿(진행 기기)은 false입니다.
  final bool watchPrivateHand;

  /// 태블릿이 SnackBar로 명령 실패를 알릴 때 씁니다. 휴대폰은 전달하지 않고
  /// [errorMessage] 상태를 사용합니다.
  final LiarsPokerErrorHandler? onError;

  StreamSubscription<DatabaseEvent>? _publicSubscription;
  StreamSubscription<DatabaseEvent>? _handSubscription;
  bool _hasPublicSnapshot = false;
  bool _hasHandSnapshot = false;
  Completer<void> _initialDataCompleter = Completer<void>();
  String? _lastDealtHandSignature;

  /// 새로운 5장 손패가 실제로 도착할 때마다 증가합니다.
  ///
  /// 라운드 번호가 다시 1부터 시작하는 게임 재시작에서도 손패 위젯을 새로
  /// 만들 수 있도록 화면의 key에는 [round] 대신 이 값을 사용합니다.
  Timer? _liarVerdictDelayTimer;
  Timer? _liarVerdictTimer;
  Timer? _penaltyResultTimer;
  String? _activePenaltyResultKey;

  late LiarsPokerGameState _draft;

  @override
  LiarsPokerGameState build() {
    _draft = LiarsPokerGameState.initial();
    initialize();
    ref.onDispose(() {
      _liarVerdictDelayTimer?.cancel();
      _liarVerdictTimer?.cancel();
      _penaltyResultTimer?.cancel();
      unawaited(_publicSubscription?.cancel());
      unawaited(_handSubscription?.cancel());
    });
    return _draft;
  }

  void _commit() {
    if (!ref.mounted) return;
    state = _draft;
  }

  //=======================불변 상태 호환 접근자==============================
  String get status => _draft.status;
  set status(String value) => _draft = _draft.copyWith(status: value);
  String? get finishReason => _draft.finishReason;
  set finishReason(String? value) =>
      _draft = _draft.copyWith(finishReason: value);
  String get phase => _draft.phase;
  set phase(String value) => _draft = _draft.copyWith(phase: value);
  String get table => _draft.table;
  set table(String value) => _draft = _draft.copyWith(table: value);
  String? get turnUid => _draft.turnUid;
  set turnUid(String? value) => _draft = _draft.copyWith(turnUid: value);
  String? get winnerUid => _draft.winnerUid;
  set winnerUid(String? value) => _draft = _draft.copyWith(winnerUid: value);
  String? get penaltyTargetUid => _draft.penaltyTargetUid;
  set penaltyTargetUid(String? value) =>
      _draft = _draft.copyWith(penaltyTargetUid: value);
  String? get lastPlayPlayerUid => _draft.lastPlayPlayerUid;
  set lastPlayPlayerUid(String? value) =>
      _draft = _draft.copyWith(lastPlayPlayerUid: value);
  String? get lastPlayId => _draft.lastPlayId;
  set lastPlayId(String? value) => _draft = _draft.copyWith(lastPlayId: value);
  bool get lastPlayRevealed => _draft.lastPlayRevealed;
  set lastPlayRevealed(bool value) =>
      _draft = _draft.copyWith(lastPlayRevealed: value);
  int get lastPlayCardCount => _draft.lastPlayCardCount;
  set lastPlayCardCount(int value) =>
      _draft = _draft.copyWith(lastPlayCardCount: value);
  int get round => _draft.round;
  set round(int value) => _draft = _draft.copyWith(round: value);
  int get revision => _draft.revision;
  set revision(int value) => _draft = _draft.copyWith(revision: value);
  int? get turnDeadlineAt => _draft.turnDeadlineAt;
  set turnDeadlineAt(int? value) =>
      _draft = _draft.copyWith(turnDeadlineAt: value);
  Map<String, PhoneGamePlayer> get players => _draft.players;
  set players(Map<String, PhoneGamePlayer> value) =>
      _draft = _draft.copyWith(players: value);
  List<PublicLastPlay> get roundPlays => _draft.roundPlays;
  set roundPlays(List<PublicLastPlay> value) =>
      _draft = _draft.copyWith(roundPlays: value);
  List<PhoneHandCard> get handCards => _draft.handCards;
  set handCards(List<PhoneHandCard> value) =>
      _draft = _draft.copyWith(handCards: value);
  List<GameImage> get handCardAssets => _draft.handCardAssets;
  set handCardAssets(List<GameImage> value) =>
      _draft = _draft.copyWith(handCardAssets: value);
  bool get isCommandInFlight => _draft.isCommandInFlight;
  set isCommandInFlight(bool value) =>
      _draft = _draft.copyWith(isCommandInFlight: value);
  bool get isMenuCommandInFlight => _draft.isMenuCommandInFlight;
  set isMenuCommandInFlight(bool value) =>
      _draft = _draft.copyWith(isMenuCommandInFlight: value);
  bool get isResolvingPenalty => _draft.isResolvingPenalty;
  set isResolvingPenalty(bool value) =>
      _draft = _draft.copyWith(isResolvingPenalty: value);
  int get rouletteRetry => _draft.rouletteRetry;
  set rouletteRetry(int value) =>
      _draft = _draft.copyWith(rouletteRetry: value);
  bool get hasRevealedHand => _draft.hasRevealedHand;
  set hasRevealedHand(bool value) =>
      _draft = _draft.copyWith(hasRevealedHand: value);
  int get handDealVersion => _draft.handDealVersion;
  set handDealVersion(int value) =>
      _draft = _draft.copyWith(handDealVersion: value);
  String? get errorMessage => _draft.errorMessage;
  set errorMessage(String? value) =>
      _draft = _draft.copyWith(errorMessage: value);
  String? get liarVerdictMessage => _draft.liarVerdictMessage;
  set liarVerdictMessage(String? value) =>
      _draft = _draft.copyWith(liarVerdictMessage: value);
  bool get liarVerdictIsFalse => _draft.liarVerdictIsFalse;
  set liarVerdictIsFalse(bool value) =>
      _draft = _draft.copyWith(liarVerdictIsFalse: value);
  bool get isLiarVerdictPending => _draft.isLiarVerdictPending;
  set isLiarVerdictPending(bool value) =>
      _draft = _draft.copyWith(isLiarVerdictPending: value);
  PhonePenaltyResult? get penaltyResult => _draft.penaltyResult;
  set penaltyResult(PhonePenaltyResult? value) =>
      _draft = _draft.copyWith(penaltyResult: value);
  bool get isPenaltyResultVisible => _draft.isPenaltyResultVisible;
  set isPenaltyResultVisible(bool value) =>
      _draft = _draft.copyWith(isPenaltyResultVisible: value);
  GameInterruption? get interruption => _draft.interruption;
  set interruption(GameInterruption? value) =>
      _draft = _draft.copyWith(interruption: value);

  bool get isInitialLoading => watchPrivateHand
      ? (!_hasPublicSnapshot || !_hasHandSnapshot)
      : !_hasPublicSnapshot;

  bool get isEntryDataReady {
    // 태블릿은 손패가 없으므로 첫 공개 상태 도착이 곧 준비 완료입니다.
    if (!watchPrivateHand) return _hasPublicSnapshot;
    if (isInitialLoading || phase == 'dealing') return false;
    final publicPlayer = players[uid];
    return handCards.isNotEmpty ||
        publicPlayer?.remainingCardCount == 0 ||
        publicPlayer?.status == 'eliminated' ||
        isFinished;
  }

  /// 첫 스냅샷이 도착할 때까지 기다립니다. 휴대폰은 공개 상태와 내 손패,
  /// 태블릿은 공개 상태만 기다립니다.
  Future<void> waitForInitialData() {
    if (isEntryDataReady) return Future<void>.value();
    return _initialDataCompleter.future;
  }

  bool get isMyTurn => turnUid == uid;
  bool get isFinished => status == 'finished';
  bool get isNaturalResult => isNaturalGameResult(
    isFinished: isFinished,
    winnerUid: winnerUid,
    finishReason: finishReason,
  );
  bool get isEliminated => players[uid]?.status == 'eliminated';
  int get alivePlayerCount =>
      players.values.where((player) => player.status == 'alive').length;
  int get playersWithCardsCount => players.values
      .where(
        (player) => player.status == 'alive' && player.remainingCardCount > 0,
      )
      .length;
  bool get isOnlyPlayerWithCards =>
      !isEliminated &&
      (players[uid]?.remainingCardCount ?? 0) > 0 &&
      playersWithCardsCount == 1;

  bool get showPenaltyHandOverlay =>
      liarVerdictMessage != null ||
      (status == 'playing' && phase == 'penalty') ||
      isPenaltyResultVisible;
  PhoneGamePlayer? get penaltyStatusPlayer {
    final targetUid = isPenaltyResultVisible
        ? penaltyResult?.targetUid
        : penaltyTargetUid;
    return players[targetUid];
  }

  String? get visiblePenaltyResult =>
      isPenaltyResultVisible ? penaltyResult?.result : null;

  /// 공개 상태 기준으로 현재 플레이어가 이번 라운드의 패를 모두 냈는지입니다.
  bool get hasSubmittedAllCards =>
      !isEliminated && players[uid]?.remainingCardCount == 0;

  /// 패를 모두 낸 휴대폰에 표시할 중앙 대기 문구입니다.
  String? get emptyHandWaitingMessage {
    if (!hasSubmittedAllCards || phase == 'penalty' || isFinished) return null;
    return lastPlayPlayerUid == uid
        ? LiarsPokerCopy.waitingForOpponent
        : LiarsPokerCopy.waitingForNextRound;
  }

  /// 마지막 남은 한 명에게 FOLD 선택지를 보여줄지 여부입니다.
  ///
  /// 이번 라운드 제출 횟수와 무관하게 잔여카드를 가진 생존자가 본인 한 명일
  /// 때만 LIAR/FOLD 선택을 표시합니다.
  bool get showFoldPrompt =>
      phase == 'lastCardChallenge' &&
      isMyTurn &&
      isOnlyPlayerWithCards &&
      lastPlayPlayerUid != null &&
      lastPlayPlayerUid != uid;

  bool get canSelectCards =>
      status == 'playing' &&
      interruption == null &&
      phase == 'playing' &&
      !isEliminated &&
      !isOnlyPlayerWithCards &&
      handCards.isNotEmpty;

  bool get canSubmitCards => canSelectCards && isMyTurn && !isCommandInFlight;

  bool get canCallLiar =>
      status == 'playing' &&
      interruption == null &&
      (phase == 'playing' || phase == 'lastCardChallenge') &&
      isMyTurn &&
      !isEliminated &&
      lastPlayPlayerUid != null &&
      !isCommandInFlight;

  bool get canFoldLastCardChallenge =>
      status == 'playing' &&
      interruption == null &&
      phase == 'lastCardChallenge' &&
      isMyTurn &&
      !isEliminated &&
      isOnlyPlayerWithCards &&
      !isCommandInFlight;

  String get turnNickname => players[turnUid]?.nickname ?? '다른 플레이어';

  String? get statusMessage {
    if (isFinished) {
      final winner = players[winnerUid]?.nickname;
      return winner == null
          ? GameFlowCopy.gameFinished
          : LiarsPokerCopy.winner(winner);
    }
    if (isEliminated) return LiarsPokerCopy.eliminated;
    if (phase == 'dealing') return LiarsPokerCopy.dealingOnTablet;
    if (phase == 'penalty') {
      return penaltyTargetUid == uid
          ? LiarsPokerCopy.myPenaltyInProgress
          : LiarsPokerCopy.penaltyInProgress;
    }
    if (phase == 'lastCardChallenge') {
      return isMyTurn
          ? LiarsPokerCopy.decideLastCard
          : LiarsPokerCopy.waitingForDecision(turnNickname);
    }
    return null;
  }

  //=======================태블릿 파생 상태==============================
  /// 벌칙 대상의 지금까지 벌칙 횟수입니다. 룰렛의 탈락 확률 단계를 정합니다.
  int get penaltyAttemptCount => players[penaltyTargetUid]?.penaltyCount ?? 0;

  /// 인원 부족·중단 만료로 승자 없이 끝났는지 여부입니다.
  bool get isInsufficientPlayersEnding =>
      status == 'finished' &&
      (finishReason == 'insufficientPlayers' ||
          finishReason == 'interruptionVoteExpired');

  String? get endingMessage => switch (finishReason) {
    'insufficientPlayers' => GameFlowCopy.insufficientPlayers,
    'interruptionVoteExpired' => GameFlowCopy.interruptionVoteExpired,
    _ => null,
  };

  void initialize() {
    _publicSubscription?.cancel();
    _handSubscription?.cancel();

    if (!isEntryDataReady) {
      _initialDataCompleter = Completer<void>();
    }

    // 태블릿(진행 기기)은 첫 카드 제출과 라이어 함수의 콜드 스타트를 미리
    // 끝냅니다. 휴대폰은 명령을 보내는 시점이 제각각이라 준비하지 않습니다.
    if (!watchPrivateHand) {
      unawaited(_warmUpGameplayCommands());
    }

    _publicSubscription = service.query
        .watchPublicGame(roomCode)
        .listen(_handlePublicGame, onError: _handleSubscriptionError);
    if (watchPrivateHand) {
      _handSubscription = service.query
          .watchPrivateHand(roomCode: roomCode, uid: uid)
          .listen(_handleHand, onError: _handleSubscriptionError);
    }
  }

  Future<void> _warmUpGameplayCommands() async {
    try {
      await service.command.warmUpGameplayCommands();
    } catch (_) {
      // 사전 준비 실패는 실제 명령의 자동 재시도로 복구되므로 UI에 표시하지 않습니다.
    }
  }

  /// 카드가 제출된 직후 라이어 선언 함수가 바로 응답하도록 준비합니다.
  Future<void> warmUpLiarCommand() async {
    try {
      await service.command.warmUpLiarCommand();
    } catch (_) {
      // 실제 라이어 명령에서 재시도하므로 사전 준비 오류는 무시합니다.
    }
  }

  void _handlePublicGame(DatabaseEvent event) {
    final value = event.snapshot.value;

    if (value is! Map) {
      // 연결 직후의 빈 로컬 캐시는 방 삭제를 의미하지 않으므로 무시합니다.
      return;
    }

    final hadPublicSnapshot = _hasPublicSnapshot;
    final data = Map<Object?, Object?>.from(value);
    final nextStatus = _string(data['status'], fallback: 'playing');
    final nextFinishReason = _nullableString(data['finishReason']);
    final nextPhase = _string(data['phase'], fallback: 'playing');
    final nextTable = _string(data['table'], fallback: 'K').toUpperCase();
    final nextTurnUid = _nullableString(data['turnUid']);
    final nextWinnerUid = _nullableString(data['winnerUid']);
    final nextPenaltyTargetUid = _nullableString(data['penaltyTargetUid']);
    final nextRound = _integer(data['round']) ?? 1;
    final nextRevision = _integer(data['revision']) ?? revision;
    final nextTurnDeadlineAt = _integer(data['turnDeadlineAt']);
    final nextPenaltyResult = _parsePenaltyResult(data['penaltyResult']);
    final rawInterruption = data['interruption'];
    final nextInterruption = rawInterruption is Map
        ? GameInterruption.fromMap(Map<Object?, Object?>.from(rawInterruption))
        : null;
    final Map<String, PhoneGamePlayer> nextPlayers = Map.unmodifiable(
      _parsePlayers(data['players']),
    );
    final nextRoundPlays = mergeRoundPlays(
      roundPlaysValue: data['roundPlays'],
      lastPlayValue: data['lastPlay'],
      round: nextRound,
    );

    final lastPlay = data['lastPlay'];
    String? nextLastPlayId;
    String? nextLastPlayPlayerUid;
    var nextLastPlayRevealed = false;
    var nextLastPlayCardCount = 0;
    var nextActualRanks = const <String>[];
    if (lastPlay is Map) {
      final lastPlayData = Map<Object?, Object?>.from(lastPlay);
      nextLastPlayId = _nullableString(lastPlayData['playId']);
      nextLastPlayPlayerUid = _nullableString(lastPlayData['playerUid']);
      nextLastPlayRevealed = lastPlayData['revealed'] == true;
      nextLastPlayCardCount = _integer(lastPlayData['cardCount']) ?? 0;
      nextActualRanks = _stringList(lastPlayData['actualRanks']);
    }

    final didRevealLiarCards =
        _hasPublicSnapshot &&
        nextPhase == 'penalty' &&
        nextLastPlayRevealed &&
        (lastPlayId != nextLastPlayId || !lastPlayRevealed);
    final declarationWasFalse = nextActualRanks.any(
      (rank) => rank != nextTable && rank != 'JOKER',
    );
    //=======================플레이어별 판정 문구==============================
    // penalty 전환 직전의 turnUid는 LIAR를 외친 플레이어이고,
    // lastPlay.playerUid는 패를 내서 의심받은 플레이어입니다.
    final isChallengedPlayer = uid == nextLastPlayPlayerUid;
    final isChallenger = uid == turnUid;
    final delayedVerdictMessage = isChallenger && !isChallengedPlayer
        ? declarationWasFalse
              ? LiarsPokerCopy.challengeSucceeded
              : LiarsPokerCopy.challengeFailed
        : declarationWasFalse
        ? LiarsPokerCopy.lieRevealed
        : LiarsPokerCopy.truthProven;
    final nextLiarVerdictMessage = didRevealLiarCards
        ? null
        : nextPhase == 'penalty'
        ? liarVerdictMessage
        : null;
    final nextLiarVerdictIsFalse = didRevealLiarCards
        ? false
        : nextPhase == 'penalty' && liarVerdictIsFalse;
    final nextLiarVerdictPending = didRevealLiarCards
        ? true
        : nextPhase == 'penalty' && isLiarVerdictPending;

    final shouldResetReveal =
        nextPhase == 'dealing' && (phase != 'dealing' || round != nextRound);
    final nextHasRevealedHand = shouldResetReveal ? false : hasRevealedHand;
    final playersChanged = !_samePlayers(players, nextPlayers);
    final roundPlaysChanged = !_sameRoundPlays(roundPlays, nextRoundPlays);
    final hasChanged =
        !_hasPublicSnapshot ||
        status != nextStatus ||
        finishReason != nextFinishReason ||
        phase != nextPhase ||
        table != nextTable ||
        turnUid != nextTurnUid ||
        winnerUid != nextWinnerUid ||
        penaltyTargetUid != nextPenaltyTargetUid ||
        !_samePenaltyResult(penaltyResult, nextPenaltyResult) ||
        round != nextRound ||
        turnDeadlineAt != nextTurnDeadlineAt ||
        lastPlayPlayerUid != nextLastPlayPlayerUid ||
        lastPlayId != nextLastPlayId ||
        lastPlayRevealed != nextLastPlayRevealed ||
        lastPlayCardCount != nextLastPlayCardCount ||
        liarVerdictMessage != nextLiarVerdictMessage ||
        liarVerdictIsFalse != nextLiarVerdictIsFalse ||
        isLiarVerdictPending != nextLiarVerdictPending ||
        hasRevealedHand != nextHasRevealedHand ||
        !_sameInterruption(interruption, nextInterruption) ||
        playersChanged ||
        roundPlaysChanged ||
        // 룰렛 결과 전송 중 표시는 서버 반영 확인(다음 공개 상태)과 함께 끝냅니다.
        isResolvingPenalty ||
        errorMessage != null;

    _hasPublicSnapshot = true;
    status = nextStatus;
    finishReason = nextFinishReason;
    phase = nextPhase;
    table = nextTable;
    turnUid = nextTurnUid;
    winnerUid = nextWinnerUid;
    penaltyTargetUid = nextPenaltyTargetUid;
    penaltyResult = nextPenaltyResult;
    round = nextRound;
    revision = nextRevision;
    turnDeadlineAt = nextTurnDeadlineAt;
    players = playersChanged ? nextPlayers : players;
    roundPlays = roundPlaysChanged ? nextRoundPlays : roundPlays;
    lastPlayId = nextLastPlayId;
    lastPlayPlayerUid = nextLastPlayPlayerUid;
    lastPlayRevealed = nextLastPlayRevealed;
    lastPlayCardCount = nextLastPlayCardCount;
    liarVerdictMessage = nextLiarVerdictMessage;
    liarVerdictIsFalse = nextLiarVerdictIsFalse;
    isLiarVerdictPending = nextLiarVerdictPending;
    hasRevealedHand = nextHasRevealedHand;
    errorMessage = null;
    interruption = nextInterruption;
    isResolvingPenalty = false;

    if (didRevealLiarCards) {
      _liarVerdictDelayTimer?.cancel();
      _liarVerdictTimer?.cancel();
      final verdictPlayId = nextLastPlayId;

      // 태블릿 카드 공개 상태를 받은 뒤 정확히 1초 후 판정 문구를 표시합니다.
      _liarVerdictDelayTimer = Timer(const Duration(seconds: 1), () {
        if (phase != 'penalty' || lastPlayId != verdictPlayId) return;
        isLiarVerdictPending = false;
        liarVerdictMessage = delayedVerdictMessage;
        liarVerdictIsFalse = declarationWasFalse;
        _commit();

        _liarVerdictTimer = Timer(const Duration(milliseconds: 2900), () {
          if (phase != 'penalty' || liarVerdictMessage == null) return;
          liarVerdictMessage = null;
          liarVerdictIsFalse = false;
          _commit();
        });
      });
    } else if (nextPhase != 'penalty') {
      _liarVerdictDelayTimer?.cancel();
      _liarVerdictDelayTimer = null;
      _liarVerdictTimer?.cancel();
      _liarVerdictTimer = null;
      isLiarVerdictPending = false;
    }

    _syncPenaltyResultVisibility(
      nextPenaltyResult,
      showFullDuration: hadPublicSnapshot,
    );
    _completeInitialDataIfReady();
    if (hasChanged) _commit();
  }

  void _handleHand(DatabaseEvent event) {
    final hadHandSnapshot = _hasHandSnapshot;
    _hasHandSnapshot = true;
    final parsedCards = <PhoneHandCard>[];
    final value = event.snapshot.value;

    if (value is Map) {
      for (final entry in value.entries) {
        if (entry.value is! Map) continue;
        final card = PhoneHandCard.fromMap(
          entry.key.toString(),
          Map<Object?, Object?>.from(entry.value as Map),
        );
        if (card != null) parsedCards.add(card);
      }
    }

    // RTDB Map의 순서에 의존하지 않고 카드 ID 기준으로 화면 순서를 고정합니다.
    parsedCards.sort((left, right) => left.id.compareTo(right.id));

    // 카드 배분 단계와 개인 손패 이벤트의 도착 순서는 기기마다 달라질 수
    // 있습니다. 따라서 공개 상태는 phase가 아니라 실제 새 5장 카드 ID를
    // 기준으로 초기화합니다. 카드 제출로 4장 이하가 되는 변화에는 반응하지
    // 않으므로 펼친 상태가 유지됩니다.
    var dealVersionChanged = false;
    if (parsedCards.length == _cardsPerNewHand) {
      final dealtHandSignature = parsedCards.map((card) => card.id).join('|');
      if (dealtHandSignature != _lastDealtHandSignature) {
        _lastDealtHandSignature = dealtHandSignature;
        hasRevealedHand = false;
        handDealVersion += 1;
        dealVersionChanged = true;
      }
    }

    final handChanged = !_sameHandCards(handCards, parsedCards);
    if (handChanged) {
      handCards = List.unmodifiable(parsedCards);
      handCardAssets = List.unmodifiable(
        parsedCards.map((card) => _cardAssetForRank(card.rank)),
      );
    }

    // 연결 복구 과정에서 동일한 snapshot이 다시 도착하면 카드 위젯과 선택
    // 상태를 그대로 유지합니다. 최초 빈 손패 수신은 로딩 종료를 위해 알립니다.
    // 진입 대기 완료 신호는 화면 갱신 여부와 무관하게 항상 검사해야
    // waitForInitialData()가 영구 대기하지 않습니다.
    _completeInitialDataIfReady();
    if (!handChanged && hadHandSnapshot && !dealVersionChanged) return;
    _commit();
  }

  void _completeInitialDataIfReady() {
    if (!isEntryDataReady || _initialDataCompleter.isCompleted) return;
    _initialDataCompleter.complete();
  }

  bool _sameHandCards(List<PhoneHandCard> left, List<PhoneHandCard> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;

    for (var index = 0; index < left.length; index++) {
      if (left[index].id != right[index].id ||
          left[index].rank != right[index].rank) {
        return false;
      }
    }
    return true;
  }

  bool _samePlayers(
    Map<String, PhoneGamePlayer> left,
    Map<String, PhoneGamePlayer> right,
  ) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;

    for (final entry in left.entries) {
      final other = right[entry.key];
      final player = entry.value;
      if (other == null ||
          player.uid != other.uid ||
          player.nickname != other.nickname ||
          player.characterId != other.characterId ||
          player.status != other.status ||
          player.remainingCardCount != other.remainingCardCount ||
          player.seatIndex != other.seatIndex ||
          player.penaltyCount != other.penaltyCount) {
        return false;
      }
    }
    return true;
  }

  bool _sameRoundPlays(List<PublicLastPlay> left, List<PublicLastPlay> right) {
    if (identical(left, right)) return true;
    if (left.length != right.length) return false;

    for (var index = 0; index < left.length; index++) {
      final leftPlay = left[index];
      final rightPlay = right[index];
      if (leftPlay.playId != rightPlay.playId ||
          leftPlay.playerUid != rightPlay.playerUid ||
          leftPlay.cardCount != rightPlay.cardCount ||
          leftPlay.declaredRank != rightPlay.declaredRank ||
          leftPlay.revealed != rightPlay.revealed ||
          leftPlay.submittedAt != rightPlay.submittedAt ||
          !listEquals(leftPlay.actualRanks, rightPlay.actualRanks)) {
        return false;
      }
    }
    return true;
  }

  Map<String, PhoneGamePlayer> _parsePlayers(Object? value) {
    if (value is! Map) return const {};

    final result = <String, PhoneGamePlayer>{};
    for (final entry in value.entries) {
      if (entry.value is! Map) continue;
      final player = PhoneGamePlayer.fromMap(
        entry.key.toString(),
        Map<Object?, Object?>.from(entry.value as Map),
      );
      result[player.uid] = player;
    }
    return result;
  }

  PhonePenaltyResult? _parsePenaltyResult(Object? value) {
    if (value is! Map) return null;
    return PhonePenaltyResult.fromMap(Map<Object?, Object?>.from(value));
  }

  bool _samePenaltyResult(PhonePenaltyResult? left, PhonePenaltyResult? right) {
    if (identical(left, right)) return true;
    if (left == null || right == null) return false;
    return left.targetUid == right.targetUid &&
        left.result == right.result &&
        left.resolvedAt == right.resolvedAt;
  }

  void _syncPenaltyResultVisibility(
    PhonePenaltyResult? result, {
    required bool showFullDuration,
  }) {
    if (result == null) {
      _penaltyResultTimer?.cancel();
      _penaltyResultTimer = null;
      _activePenaltyResultKey = null;
      isPenaltyResultVisible = false;
      return;
    }

    final resultKey = '${result.targetUid}-${result.resolvedAt}';
    if (_activePenaltyResultKey == resultKey) return;
    _activePenaltyResultKey = resultKey;
    _penaltyResultTimer?.cancel();

    final elapsed = ServerClock.nowMillis() - result.resolvedAt;
    final remainingMilliseconds = showFullDuration
        ? 3000
        : (3000 - elapsed).clamp(0, 3000).toInt();
    if (remainingMilliseconds <= 0) {
      isPenaltyResultVisible = false;
      return;
    }

    isPenaltyResultVisible = true;
    _penaltyResultTimer = Timer(
      Duration(milliseconds: remainingMilliseconds),
      () {
        isPenaltyResultVisible = false;
        _penaltyResultTimer = null;
        _commit();
      },
    );
  }

  //=======================휴대폰 게임 명령==============================
  Future<bool> submitCardIndexes(List<int> indexes) async {
    if (!canSubmitCards || indexes.isEmpty || indexes.length > 3) {
      return _reject('현재 카드를 제출할 수 없습니다.');
    }

    final cardIds = <String>[];
    for (final index in indexes) {
      if (index < 0 || index >= handCards.length) {
        return _reject('선택한 카드 정보가 바뀌었습니다. 다시 선택해주세요.');
      }
      cardIds.add(handCards[index].id);
    }

    if (isCommandInFlight) return false;

    isCommandInFlight = true;
    errorMessage = null;
    _commit();

    try {
      await service.command.submitCards(roomCode: roomCode, cardIds: cardIds);
      return true;
    } catch (_) {
      // Callable 응답만 유실됐을 수 있으므로 RTDB 개인 손패에서 제출 카드가
      // 제거됐는지 잠시 확인합니다. 서버 재시도와 상태 확인까지 모두 실패한
      // 경우에만 손패 위젯에 false를 반환해 카드 복귀를 실행합니다.
      if (await _waitForSubmittedCardsToDisappear(cardIds)) return true;
      errorMessage = '카드 제출 실패';
      return false;
    } finally {
      isCommandInFlight = false;
      _commit();
    }
  }

  Future<bool> _waitForSubmittedCardsToDisappear(List<String> cardIds) async {
    final submittedIds = cardIds.toSet();
    for (var attempt = 0; attempt < 6; attempt += 1) {
      final remainingIds = handCards.map((card) => card.id).toSet();
      if (submittedIds.every((cardId) => !remainingIds.contains(cardId))) {
        return true;
      }
      await Future<void>.delayed(const Duration(milliseconds: 140));
    }
    return false;
  }

  /// 마감이 지난 턴을 태블릿이 대신 해결합니다(휴대폰 타이머 백스톱).
  ///
  /// 판정 정책은 휴대폰 타임아웃과 같고 서버가 수행합니다. 마감 전 호출은
  /// 서버가 success:false로 거절하므로 _runCommand가 false를 돌려줍니다.
  Future<bool> forceTurnTimeout() =>
      _runCommand(() => service.command.forceTimeout(roomCode: roomCode));

  Future<bool> callLiar() {
    if (!canCallLiar) return Future.value(_reject('현재 라이어를 선언할 수 없습니다.'));
    return _runCommand(() => service.command.callLiar(roomCode: roomCode));
  }

  Future<bool> foldLastCardChallenge() {
    if (!canFoldLastCardChallenge) {
      return Future.value(_reject('현재 마지막 카드 도전을 통과할 수 없습니다.'));
    }
    return _runCommand(
      () => service.command.foldLastCardChallenge(roomCode: roomCode),
    );
  }

  Future<bool> voteToContinueInterruption() {
    final current = interruption;
    if (current == null) return Future.value(false);
    return _runCommand(
      () => service.interruption.voteToContinue(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }

  Future<bool> expireInterruption() {
    final current = interruption;
    if (current == null) return Future.value(false);
    return _runCommand(
      () => service.interruption.expire(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }

  /// 남은 인원이 부족한 중단을 마감 전에 즉시 종료합니다.
  ///
  /// [excludeInterruptedPlayerAndContinue]의 거울상입니다. 계속할 수 있는
  /// 중단은 투표·제외 흐름의 몫이므로 여기서 끝내지 않습니다.
  Future<bool> finishInterruptedGameNow() {
    final current = interruption;
    if (current == null || current.canContinue) return Future.value(false);
    return _runCommand(
      () => service.interruption.finishNow(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }

  //=======================태블릿(진행 기기) 게임 명령==============================
  /// 현재 방과 좌석은 유지하고 게임 데이터만 새로 만듭니다.
  Future<bool> restartGame() => _runMenuCommand(
    () => service.command.restartGame(roomCode: roomCode),
    failureMessage: '게임을 재시작하지 못했습니다.',
  );

  /// RTDB 방은 삭제하지 않고 현재 게임 상태만 종료합니다.
  Future<bool> endGame() => _runMenuCommand(
    () => service.command.endGame(roomCode: roomCode),
    failureMessage: '게임을 종료하지 못했습니다.',
  );

  /// 태블릿 중단 배너의 만료 처리입니다. 설정 메뉴 명령과 같은 잠금을 씁니다.
  Future<bool> expireInterruptionFromController() {
    final current = interruption;
    if (current == null) return Future.value(false);
    return _runMenuCommand(
      () => service.interruption.expire(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
      failureMessage: '연결 중단 상태를 종료하지 못했습니다.',
    );
  }

  Future<bool> excludeInterruptedPlayerAndContinue() {
    final current = interruption;
    if (current == null || !current.canContinue) return Future.value(false);
    return _runMenuCommand(
      () => service.interruption.excludeAndContinue(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
      failureMessage: '플레이어를 제외하고 게임을 계속하지 못했습니다.',
    );
  }

  /// 태블릿에서 인원 부족 중단을 즉시 종료합니다.
  ///
  /// 휴대폰용 [finishInterruptedGameNow]와 같은 명령이지만 잠금이 다릅니다.
  /// 태블릿 화면이 `isMenuCommandInFlight`를 보고 버튼을 잠그므로 여기서도
  /// 메뉴 잠금을 써야 합니다. 다른 잠금을 쓰면 표시 없이 조용히 드롭됩니다.
  Future<bool> finishInterruptedGameNowFromController() {
    final current = interruption;
    if (current == null || current.canContinue) return Future.value(false);
    return _runMenuCommand(
      () => service.interruption.finishNow(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
      failureMessage: GameFlowCopy.interruptionFinishNowFailed,
    );
  }

  /// 태블릿의 카드 배분 애니메이션이 끝났음을 서버에 알립니다.
  Future<void> completeDealing() async {
    // 이전 서버 버전이나 개발용 로컬 상태에서는 별도 완료 호출이 필요 없습니다.
    if (phase != 'dealing') return;

    try {
      await service.command.completeDealing(roomCode: roomCode);
    } catch (error) {
      _reportError('카드 배분 완료 상태를 반영하지 못했습니다.', error);
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
      _reportError('룰렛 결과를 반영하지 못했습니다.', error);
    }
  }

  Future<bool> _runCommand(Future<Object?> Function() command) async {
    if (isCommandInFlight) return false;

    isCommandInFlight = true;
    errorMessage = null;
    _commit();

    try {
      final result = await command();
      // 서버는 "아직 할 일이 아니다"를 예외가 아니라 정상 응답으로 알립니다
      // (예: 마감 전 타임아웃 호출 → {success: false, reason: "notExpired"}).
      // 이를 성공으로 넘기면 호출자가 재시도하지 않아 진행이 멈춥니다.
      // 명시적인 success:false만 실패로 봅니다(success 필드가 없는 명령도 있음).
      if (result is Map && result['success'] == false) return false;
      return true;
    } catch (error) {
      errorMessage =
          userErrorMessage(error, context: UserErrorContext.gameCommand) ??
          UserErrorCopy.requestFailed;
      return false;
    } finally {
      isCommandInFlight = false;
      _commit();
    }
  }

  Future<bool> _runMenuCommand(
    Future<Object?> Function() command, {
    required String failureMessage,
  }) async {
    if (isMenuCommandInFlight) return false;

    isMenuCommandInFlight = true;
    _commit();
    try {
      await command();
      return true;
    } catch (error) {
      _reportError(failureMessage, error);
      return false;
    } finally {
      isMenuCommandInFlight = false;
      _commit();
    }
  }

  void _reportError(String message, Object error) {
    final handler = onError;
    if (handler != null) {
      handler(message, error);
      return;
    }
    errorMessage = message;
    _commit();
  }

  bool _reject(String message) {
    errorMessage = message;
    _commit();
    return false;
  }

  void clearError() {
    if (errorMessage == null) return;
    errorMessage = null;
    _commit();
  }

  /// 방향 전환 뒤에도 같은 라운드의 공개된 손패 상태를 유지합니다.
  void markHandRevealed() {
    hasRevealedHand = true;
    _commit();
    if (isMyTurn && phase == 'playing') {
      unawaited(service.command.readyTurn(roomCode: roomCode));
    }
  }

  void _handleSubscriptionError(Object error) {
    // 정상 퇴장으로 권한이 사라진 경우와 연결 복구로 스스로 해결되는 네이티브
    // 오류는 사용자에게 표시하지 않습니다. 예전에는 예외 원문을 문구에 붙여
    // 정상 퇴장 중에도 permission-denied 영문 원문이 화면에 떴습니다.
    final message = userErrorMessage(
      error,
      context: UserErrorContext.gameSubscription,
    );

    // 태블릿은 SnackBar 안내를 위해 화면 콜백으로 전달합니다.
    if (onError != null) {
      if (!_initialDataCompleter.isCompleted) {
        _initialDataCompleter.completeError(error);
      }
      // 초기 데이터 대기는 표시 여부와 별개로 반드시 풀어 줍니다.
      if (message != null) onError!.call(message, error);
      return;
    }

    if (message == null) return;
    errorMessage = message;
    if (!_initialDataCompleter.isCompleted) {
      _initialDataCompleter.completeError(error);
    }
    _commit();
  }

  String _string(Object? value, {required String fallback}) {
    return value is String && value.isNotEmpty ? value : fallback;
  }

  String? _nullableString(Object? value) {
    return value is String && value.isNotEmpty ? value : null;
  }

  int? _integer(Object? value) {
    return value is int ? value : (value is num ? value.toInt() : null);
  }

  List<String> _stringList(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<String>()
        .map((rank) => rank.toUpperCase())
        .toList(growable: false);
  }

  GameImage _cardAssetForRank(String rank) {
    return switch (rank.toUpperCase()) {
      'A' => Assets.games.liarsPoker.images.cards.whiteA.game,
      'K' => Assets.games.liarsPoker.images.cards.whiteK.game,
      'Q' => Assets.games.liarsPoker.images.cards.whiteQ.game,
      'JOKER' => Assets.games.liarsPoker.images.cards.whiteJoker.game,
      _ => Assets.games.liarsPoker.images.cards.whiteBack.game,
    };
  }
}

bool _sameInterruption(GameInterruption? left, GameInterruption? right) {
  if (identical(left, right)) return true;
  if (left == null || right == null) return false;
  return left.id == right.id &&
      left.deadlineAt == right.deadlineAt &&
      left.requiredVotes == right.requiredVotes &&
      left.canContinue == right.canContinue &&
      setEquals(left.voterUids, right.voterUids);
}
