// [game_controller.dart] RTDB의 라이어스 포커 상태를 게임 상태 객체로 변환하고,
// 휴대폰·태블릿 화면과 서버 명령 사이의 진행을 조율하는 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:game_kit/errors/services/user_error_message.dart';
import 'package:game_kit/core/diagnostics/dev_error_log.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:game_liars_poker/game_copy.dart';
import 'package:game_liars_poker/shared/models/game_models.dart';
import 'package:game_liars_poker/shared/models/game_state.dart';
import 'package:game_liars_poker/shared/services/game_service.dart';
import 'package:game_liars_poker/shared/services/private_state_mapper.dart';
import 'package:game_liars_poker/shared/services/public_state_mapper.dart';
import 'package:game_liars_poker/shared/providers/penalty_coordinator.dart';
import 'package:game_kit/penalty/roulette.dart';
import 'package:game_kit/game_flow/game_finish.dart';
import 'package:game_kit/game_flow/game_flow_copy.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_liars_poker/game_assets.dart';
import 'package:game_kit/recovery/providers/game_session_controller.dart';
import 'package:game_kit/recovery/services/game_progress_command.dart';
import 'package:game_kit/services/game_query_service.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
export 'package:game_liars_poker/shared/models/game_models.dart'
    show PhoneGamePlayer, PhoneHandCard, PhonePenaltyResult, PublicLastPlay;

// ============================================================

// LiarsPokerController
// │
// ├─ ① build() → RTDB 공개 상태와 필요한 손패 구독
// ├─ ② applyPublicValue() → 서버 데이터를 게임 상태로 변환
// ├─ ③ handlePrivateEvent() → 휴대폰 손패 반영
// ├─ ④ 행동 메서드 → 카드 제출·LIAR·FOLD·룰렛 요청
// └─ ⑤ dispose → 타이머와 구독 정리

// ---------------------------------------------------------------------------
// Liar's Poker Riverpod 게임 컨트롤러
// ---------------------------------------------------------------------------
/// Final Call처럼 휴대폰과 태블릿이 함께 쓰는 단일 서버 미러 컨트롤러입니다.
///
/// 서버 상태는 불변 [LiarsPokerGameState]로 발행하고, 태블릿 전용 연출 상태
/// (stage, 카드 더미 버전, 제출 연출)는 태블릿 화면 State가 소유합니다.
/// Provider가 폐기되면 Realtime Database 구독도 종료됩니다.
class LiarsPokerController extends GameSessionController<LiarsPokerGameState> {
  static const int _cardsPerNewHand = 5;

  LiarsPokerController({
    required this.roomCode,
    required this.uid,
    required this.service,
    this.watchPrivateHand = true,
  });

  @override
  final String roomCode;
  @override
  final String uid;
  final LiarsPokerService service;

  // ---------------------------------------------------------------------------
  // 공용 뼈대에 넘겨 주는 것
  // ---------------------------------------------------------------------------
  @override
  GameQueryService get query => service.query;

  @override
  GameInterruptionCommandService get interruptionCommands =>
      service.interruption;

  @override
  String get commandCrashReason => '라이어스포커 서버 명령';

  /// 라이어스포커는 개인 상태 전체가 아니라 **손패만** 구독합니다.
  ///
  /// 받는 스냅샷이 `game/private/{uid}/hand` 자체라 [handlePrivateEvent]의
  /// 해석도 그 모양에 맞춰져 있습니다. 둘은 짝입니다.
  @override
  Stream<DatabaseEvent> watchPrivateStream() =>
      service.query.watchPrivatePlayer(roomCode: roomCode, uid: uid);

  /// 휴대폰은 true(내 손패 구독), 태블릿(진행 기기)은 false입니다.
  final bool watchPrivateHand;

  bool _hasPublicSnapshot = false;
  final _readyTurnCommand = GameProgressCommand();
  bool _hasHandSnapshot = false;
  final Completer<void> _initialDataCompleter = Completer<void>();
  String? _lastDealtHandSignature;

  /// 새로운 5장 손패가 실제로 도착할 때마다 증가합니다.
  ///
  /// 라운드 번호가 다시 1부터 시작하는 게임 재시작에서도 손패 위젯을 새로
  /// 만들 수 있도록 화면의 key에는 [round] 대신 이 값을 사용합니다.
  Timer? _liarVerdictDelayTimer;
  Timer? _liarVerdictTimer;
  Timer? _penaltyResultTimer;
  String? _activePenaltyResultKey;

  late LiarsPokerPenaltyCoordinator _penaltyCoordinator;

  /// [state]를 한 번에 바꿉니다. 화면이 사라진 뒤에는 아무 일도 하지 않습니다.
  ///
  /// 파이널콜·마피아와 같은 방식입니다. 스냅샷 하나를 해석하며 바뀌는 값은
  /// 모아서 **한 번의** `copyWith`로 발행합니다(알림 한 번). 예전에는 세터로
  /// 임시 사본에 적었다가 따로 발행했는데, 그 사본이 공용 뼈대가 [state]에
  /// 직접 쓴 값(방 삭제·명령 진행·오류)과 갈라지는 문제가 있었습니다.
  void _update(
    LiarsPokerGameState Function(LiarsPokerGameState current) change,
  ) {
    if (!ref.mounted) return;
    state = change(state);
  }

  @override
  LiarsPokerGameState build() {
    _penaltyCoordinator = LiarsPokerPenaltyCoordinator(
      roomCode: roomCode,
      commandService: service.command,
    );
    // 태블릿(진행 기기)은 첫 카드 제출과 라이어 함수의 콜드 스타트를 미리
    // 끝냅니다. 휴대폰은 명령을 보내는 시점이 제각각이라 준비하지 않습니다.
    if (!watchPrivateHand) {
      _scheduleGameplayWarmUp();
    }
    startSession(watchPrivate: watchPrivateHand);
    ref.onDispose(() {
      _readyTurnCommand.dispose();
      _liarVerdictDelayTimer?.cancel();
      _liarVerdictTimer?.cancel();
      _penaltyResultTimer?.cancel();
    });
    return LiarsPokerGameState.initial();
  }

  /// Provider [build] 스택을 빠져나온 다음 서버 함수를 예열합니다.
  ///
  /// 예열 요청은 통신 로그를 남기고 그 로그가 개발용 UI를 갱신합니다.
  /// 이를 [build] 안에서 동기적으로 시작하면 화면을 그리는 중에 조상
  /// Widget이 다시 빌드되어 디버그 실행이 예외 지점에 멈출 수 있습니다.
  void _scheduleGameplayWarmUp() {
    Timer.run(() {
      if (ref.mounted) unawaited(_warmUpGameplayCommands());
    });
  }

  // ---------------------------------------------------------------------------
  // 상태 읽기 전용 접근자 — 바꿀 때는 [_update]
  // ---------------------------------------------------------------------------
  String get status => state.status;
  String? get finishReason => state.finishReason;
  String get phase => state.phase;
  String get table => state.table;
  String? get turnUid => state.turnUid;
  String? get winnerUid => state.winnerUid;
  String? get penaltyTargetUid => state.penaltyTargetUid;
  String? get lastPlayPlayerUid => state.lastPlayPlayerUid;
  String? get lastPlayId => state.lastPlayId;
  bool get lastPlayRevealed => state.lastPlayRevealed;
  int get lastPlayCardCount => state.lastPlayCardCount;
  int get round => state.round;
  int get revision => state.revision;
  int? get turnDeadlineAt => state.turnDeadlineAt;
  Map<String, PhoneGamePlayer> get players => state.players;
  List<PublicLastPlay> get roundPlays => state.roundPlays;
  List<PhoneHandCard> get handCards => state.handCards;
  List<GameImage> get handCardAssets => state.handCardAssets;
  bool get commandInFlight => state.commandInFlight;
  bool get isMenuCommandInFlight => state.isMenuCommandInFlight;
  bool get isResolvingPenalty => state.isResolvingPenalty;
  int get rouletteRetry => state.rouletteRetry;
  bool get hasRevealedHand => state.hasRevealedHand;
  int get handDealVersion => state.handDealVersion;
  String? get errorMessage => state.errorMessage;
  String? get liarVerdictMessage => state.liarVerdictMessage;
  bool get liarVerdictIsFalse => state.liarVerdictIsFalse;
  bool get isLiarVerdictPending => state.isLiarVerdictPending;
  PhonePenaltyResult? get penaltyResult => state.penaltyResult;
  bool get isPenaltyResultVisible => state.isPenaltyResultVisible;
  @override
  GameInterruption? get interruption => state.interruption;

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

  bool get canSubmitCards => canSelectCards && isMyTurn && !commandInFlight;

  bool get canCallLiar =>
      status == 'playing' &&
      interruption == null &&
      (phase == 'playing' || phase == 'lastCardChallenge') &&
      isMyTurn &&
      !isEliminated &&
      lastPlayPlayerUid != null &&
      !commandInFlight;

  bool get canFoldLastCardChallenge =>
      status == 'playing' &&
      interruption == null &&
      phase == 'lastCardChallenge' &&
      isMyTurn &&
      !isEliminated &&
      isOnlyPlayerWithCards &&
      !commandInFlight;

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

  // ---------------------------------------------------------------------------
  // 태블릿 파생 상태
  // ---------------------------------------------------------------------------
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

  @override
  void applyPublicValue(Object? value) {
    // 빈 스냅샷 처리와 방 삭제 확인은 공용 뼈대가 먼저 합니다.
    if (value is! Map) return;

    final hadPublicSnapshot = _hasPublicSnapshot;
    final data = Map<Object?, Object?>.from(value);
    final nextStatus = liarsPokerString(data['status'], fallback: 'playing');
    final nextFinishReason = liarsPokerNullableString(data['finishReason']);
    final nextPhase = liarsPokerString(data['phase'], fallback: 'playing');
    final nextTable = liarsPokerString(
      data['table'],
      fallback: 'K',
    ).toUpperCase();
    final nextTurnUid = liarsPokerNullableString(data['turnUid']);
    final nextWinnerUid = liarsPokerNullableString(data['winnerUid']);
    final nextPenaltyTargetUid = liarsPokerNullableString(
      data['penaltyTargetUid'],
    );
    final nextRound = liarsPokerInteger(data['round']) ?? 1;
    final nextRevision = liarsPokerInteger(data['revision']) ?? revision;
    final nextTurnDeadlineAt = liarsPokerInteger(data['turnDeadlineAt']);
    final nextPenaltyResult = parseLiarsPokerPenaltyResult(
      data['penaltyResult'],
    );
    final rawInterruption = data['recovery'];
    final nextInterruption = rawInterruption is Map
        ? GameInterruption.fromMap(Map<Object?, Object?>.from(rawInterruption))
        : null;
    final Map<String, PhoneGamePlayer> nextPlayers = Map.unmodifiable(
      parseLiarsPokerPlayers(data['players']),
    );
    final nextRoundPlays = mergeRoundPlays(
      roundPlaysValue: data['roundPlays'],
      lastPlayValue: data['lastPlay'],
      round: nextRound,
    );

    final lastPlay = LiarsPokerLastPlaySnapshot.fromValue(data['lastPlay']);
    final nextLastPlayId = lastPlay.playId;
    final nextLastPlayPlayerUid = lastPlay.playerUid;
    final nextLastPlayRevealed = lastPlay.revealed;
    final nextLastPlayCardCount = lastPlay.cardCount;
    final nextActualCardValues = lastPlay.actualCardValues;

    final didRevealLiarCards =
        _hasPublicSnapshot &&
        nextPhase == 'penalty' &&
        nextLastPlayRevealed &&
        (lastPlayId != nextLastPlayId || !lastPlayRevealed);
    final declarationWasFalse = nextActualCardValues.any(
      (cardValue) => cardValue != nextTable && cardValue != 'JOKER',
    );
    // ---------------------------------------------------------------------------
    // 플레이어별 판정 문구
    // ---------------------------------------------------------------------------
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
    final playersChanged = !mapEquals(players, nextPlayers);
    final roundPlaysChanged = !listEquals(roundPlays, nextRoundPlays);
    final hasChanged =
        !_hasPublicSnapshot ||
        status != nextStatus ||
        finishReason != nextFinishReason ||
        phase != nextPhase ||
        table != nextTable ||
        turnUid != nextTurnUid ||
        winnerUid != nextWinnerUid ||
        penaltyTargetUid != nextPenaltyTargetUid ||
        penaltyResult != nextPenaltyResult ||
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

    if (didRevealLiarCards) {
      _liarVerdictDelayTimer?.cancel();
      _liarVerdictTimer?.cancel();
      final verdictPlayId = nextLastPlayId;

      // 태블릿 카드 공개 상태를 받은 뒤 정확히 1초 후 판정 문구를 표시합니다.
      _liarVerdictDelayTimer = Timer(const Duration(seconds: 1), () {
        if (phase != 'penalty' || lastPlayId != verdictPlayId) return;
        _update(
          (current) => current.copyWith(
            isLiarVerdictPending: false,
            liarVerdictMessage: delayedVerdictMessage,
            liarVerdictIsFalse: declarationWasFalse,
          ),
        );

        _liarVerdictTimer = Timer(const Duration(milliseconds: 2900), () {
          if (phase != 'penalty' || liarVerdictMessage == null) return;
          _update(
            (current) => current.copyWith(
              liarVerdictMessage: null,
              liarVerdictIsFalse: false,
            ),
          );
        });
      });
    } else if (nextPhase != 'penalty') {
      // 판정 대기 표시는 아래 발행에서 nextLiarVerdictPending(= false)으로 꺼집니다.
      _liarVerdictDelayTimer?.cancel();
      _liarVerdictDelayTimer = null;
      _liarVerdictTimer?.cancel();
      _liarVerdictTimer = null;
    }

    final nextPenaltyResultVisible = _syncPenaltyResultVisibility(
      nextPenaltyResult,
      showFullDuration: hadPublicSnapshot,
    );

    // 같은 스냅샷이 다시 온 경우(hasChanged == false)는 발행하지 않습니다.
    if (hasChanged) {
      _update(
        (current) => current.copyWith(
          status: nextStatus,
          finishReason: nextFinishReason,
          phase: nextPhase,
          table: nextTable,
          turnUid: nextTurnUid,
          winnerUid: nextWinnerUid,
          penaltyTargetUid: nextPenaltyTargetUid,
          penaltyResult: nextPenaltyResult,
          round: nextRound,
          revision: nextRevision,
          turnDeadlineAt: nextTurnDeadlineAt,
          // 내용이 같으면 기존 객체를 유지해 하위 위젯이 다시 그려지지 않게 합니다.
          players: playersChanged ? nextPlayers : null,
          roundPlays: roundPlaysChanged ? nextRoundPlays : null,
          lastPlayId: nextLastPlayId,
          lastPlayPlayerUid: nextLastPlayPlayerUid,
          lastPlayRevealed: nextLastPlayRevealed,
          lastPlayCardCount: nextLastPlayCardCount,
          liarVerdictMessage: nextLiarVerdictMessage,
          liarVerdictIsFalse: nextLiarVerdictIsFalse,
          isLiarVerdictPending: nextLiarVerdictPending,
          hasRevealedHand: nextHasRevealedHand,
          errorMessage: null,
          interruption: nextInterruption,
          isResolvingPenalty: false,
          isPenaltyResultVisible: nextPenaltyResultVisible,
        ),
      );
    }
    // 발행한 뒤에 검사해야 새 상태를 기준으로 판단합니다.
    _completeInitialDataIfReady();
  }

  @override
  void handlePrivateEvent(DatabaseEvent event) {
    final hadHandSnapshot = _hasHandSnapshot;
    _hasHandSnapshot = true;
    final parsedCards = parseLiarsPokerHand(
      event.snapshot.value is Map
          ? (event.snapshot.value as Map)['hand']
          : null,
    );

    // 카드 배분 단계와 개인 손패 이벤트의 도착 순서는 기기마다 달라질 수
    // 있습니다. 따라서 공개 상태는 phase가 아니라 실제 새 5장 카드 ID를
    // 기준으로 초기화합니다. 카드 제출로 4장 이하가 되는 변화에는 반응하지
    // 않으므로 펼친 상태가 유지됩니다.
    var dealVersionChanged = false;
    if (parsedCards.length == _cardsPerNewHand) {
      final dealtHandSignature = parsedCards.map((card) => card.id).join('|');
      if (dealtHandSignature != _lastDealtHandSignature) {
        _lastDealtHandSignature = dealtHandSignature;
        dealVersionChanged = true;
      }
    }

    final handChanged = !listEquals(handCards, parsedCards);

    // 연결 복구 과정에서 동일한 snapshot이 다시 도착하면 카드 위젯과 선택
    // 상태를 그대로 유지합니다. 최초 빈 손패 수신은 로딩 종료를 위해 알립니다.
    if (handChanged || dealVersionChanged || !hadHandSnapshot) {
      _update(
        (current) => current.copyWith(
          hasRevealedHand: dealVersionChanged ? false : null,
          handDealVersion: dealVersionChanged
              ? current.handDealVersion + 1
              : null,
          handCards: handChanged ? List.unmodifiable(parsedCards) : null,
          handCardAssets: handChanged
              ? List.unmodifiable(
                  parsedCards.map((card) => _cardAssetForValue(card.cardValue)),
                )
              : null,
        ),
      );
    }

    // 진입 대기 완료 신호는 화면 갱신 여부와 무관하게 항상 검사해야
    // waitForInitialData()가 영구 대기하지 않습니다. 발행한 뒤에 검사해야
    // 새 손패를 기준으로 판단합니다.
    _completeInitialDataIfReady();
  }

  void _completeInitialDataIfReady() {
    if (!isEntryDataReady || _initialDataCompleter.isCompleted) return;
    _initialDataCompleter.complete();
  }

  /// 룰렛 결과를 보여 줄지 정하고, 필요하면 숨김 타이머를 겁니다.
  ///
  /// 표시 여부는 돌려주기만 합니다. 호출한 쪽이 같은 발행에 담습니다.
  bool _syncPenaltyResultVisibility(
    PhonePenaltyResult? result, {
    required bool showFullDuration,
  }) {
    if (result == null) {
      _penaltyResultTimer?.cancel();
      _penaltyResultTimer = null;
      _activePenaltyResultKey = null;
      return false;
    }

    final resultKey = '${result.targetUid}-${result.resolvedAt}';
    if (_activePenaltyResultKey == resultKey) return isPenaltyResultVisible;
    _activePenaltyResultKey = resultKey;
    _penaltyResultTimer?.cancel();

    final elapsed = ServerClock.nowMillis() - result.resolvedAt;
    final remainingMilliseconds = showFullDuration
        ? 3000
        : (3000 - elapsed).clamp(0, 3000).toInt();
    if (remainingMilliseconds <= 0) return false;

    _penaltyResultTimer = Timer(
      Duration(milliseconds: remainingMilliseconds),
      () {
        _penaltyResultTimer = null;
        _update((current) => current.copyWith(isPenaltyResultVisible: false));
      },
    );
    return true;
  }

  // ---------------------------------------------------------------------------
  // 휴대폰 게임 명령
  // ---------------------------------------------------------------------------
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

    if (commandInFlight) return false;

    _update(
      (current) => current.copyWith(commandInFlight: true, errorMessage: null),
    );
    String? failureMessage;
    try {
      await service.command.submitCards(roomCode: roomCode, cardIds: cardIds);
      return true;
    } catch (_) {
      // Callable 응답만 유실됐을 수 있으므로 RTDB 개인 손패에서 제출 카드가
      // 제거됐는지 잠시 확인합니다. 서버 재시도와 상태 확인까지 모두 실패한
      // 경우에만 손패 위젯에 false를 반환해 카드 복귀를 실행합니다.
      if (await _waitForSubmittedCardsToDisappear(cardIds)) return true;
      failureMessage = '카드 제출 실패';
      return false;
    } finally {
      final message = failureMessage;
      // 실패 문구와 진행 종료를 한 번에 발행합니다.
      _update(
        (current) => message == null
            ? current.copyWith(commandInFlight: false)
            : current.copyWith(commandInFlight: false, errorMessage: message),
      );
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
  /// 서버가 success:false로 거절하므로 공용 run()이 false를 돌려줍니다.
  Future<bool> forceTurnTimeout() =>
      run(() => service.command.forceTimeout(roomCode: roomCode));

  Future<bool> callLiar() {
    if (!canCallLiar) return Future.value(_reject('현재 라이어를 선언할 수 없습니다.'));
    return run(() => service.command.callLiar(roomCode: roomCode));
  }

  Future<bool> foldLastCardChallenge() {
    if (!canFoldLastCardChallenge) {
      return Future.value(_reject('현재 마지막 카드 도전을 통과할 수 없습니다.'));
    }
    return run(() => service.command.foldLastCardChallenge(roomCode: roomCode));
  }

  // ---------------------------------------------------------------------------
  // 태블릿(진행 기기) 게임 명령
  // ---------------------------------------------------------------------------
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

  /// 태블릿 진행자가 끊긴 참가자를 제외하고 계속합니다.
  ///
  /// 공용 뼈대는 게임 조작 플래그로 처리하지만, 라이어스포커는 **메뉴 명령**
  /// 으로 돌립니다. 진행자가 이 버튼을 누르는 동안 다른 사람의 카드 제출이
  /// 막히면 안 되기 때문입니다. 실패는 태블릿 SnackBar로 알립니다.
  @override
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

  /// 태블릿의 카드 배분 애니메이션이 끝났음을 서버에 알립니다.
  Future<bool> completeDealing() async {
    // 이전 서버 버전이나 개발용 로컬 상태에서는 별도 완료 호출이 필요 없습니다.
    if (phase != 'dealing') return true;

    try {
      final result = await service.command.completeDealing(roomCode: roomCode);
      return result['success'] != false;
    } catch (error) {
      _reportError('카드 배분 완료 상태를 반영하지 못했습니다.', error);
      return false;
    }
  }

  /// 실제 결과는 회전 전에 서버가 추첨합니다. 클라이언트는 그 결과에 맞는 칸으로
  /// 원판을 움직일 뿐 확률이나 생존/탈락을 결정하지 않습니다.
  Future<RouletteResult?> prepareRoulette() async {
    if (isResolvingPenalty || penaltyTargetUid == null) return null;
    _update((current) => current.copyWith(isResolvingPenalty: true));

    try {
      return await _penaltyCoordinator.prepare();
    } catch (error) {
      _update(
        (current) => current.copyWith(
          isResolvingPenalty: false,
          rouletteRetry: current.rouletteRetry + 1,
        ),
      );
      _reportError('룰렛 결과를 추첨하지 못했습니다.', error);
      return null;
    }
  }

  /// 서버가 정한 결과대로 룰렛 연출이 끝났음을 알립니다.
  Future<void> resolveRoulette(RouletteResult _) async {
    if (!isResolvingPenalty || penaltyTargetUid == null) {
      return;
    }

    try {
      await _penaltyCoordinator.complete();
    } catch (error) {
      _penaltyCoordinator.reset();
      _update(
        (current) => current.copyWith(
          isResolvingPenalty: false,
          rouletteRetry: current.rouletteRetry + 1,
        ),
      );
      _reportError('룰렛 결과를 반영하지 못했습니다.', error);
    }
  }

  Future<bool> _runMenuCommand(
    Future<Object?> Function() command, {
    required String failureMessage,
  }) async {
    if (isMenuCommandInFlight) return false;

    _update((current) => current.copyWith(isMenuCommandInFlight: true));
    try {
      await command();
      return true;
    } catch (error) {
      _reportError(failureMessage, error);
      return false;
    } finally {
      _update((current) => current.copyWith(isMenuCommandInFlight: false));
    }
  }

  /// 실패를 [errorMessage]에 적습니다. 어떻게 보여 줄지는 화면이 정합니다
  /// (휴대폰은 화면 문구, 태블릿은 SnackBar).
  void _reportError(String message, Object error) {
    _logError(error);
    _update((current) => current.copyWith(errorMessage: message));
  }

  /// 오류 원문은 화면에 붙이지 않고 개발용 기록에만 남깁니다.
  void _logError(Object error) {
    DevErrorLog.instance.add(
      error: error,
      context: watchPrivateHand ? 'liars_poker/phone' : 'liars_poker/tablet',
      time: DateTime.now(),
    );
  }

  bool _reject(String message) {
    _update((current) => current.copyWith(errorMessage: message));
    return false;
  }

  /// 방향 전환 뒤에도 같은 라운드의 공개된 손패 상태를 유지합니다.
  void markHandRevealed() {
    // 공개 시작과 완료 콜백이 모두 이 메서드를 호출합니다.
    // 서버의 첫 턴 시작 명령은 같은 라운드에서 한 번만 보내야 합니다.
    final shouldReadyTurn = !hasRevealedHand && isMyTurn && phase == 'playing';
    _update((current) => current.copyWith(hasRevealedHand: true));
    if (shouldReadyTurn) {
      final key = (gameStartedAt, round);
      _readyTurnCommand.run(
        key: key,
        isCurrent: () =>
            ref.mounted &&
            !isFinished &&
            phase == 'playing' &&
            isMyTurn &&
            turnDeadlineAt == null &&
            (gameStartedAt, round) == key,
        send: () async {
          if (interruption != null) return false;
          try {
            final result = await service.command.readyTurn(roomCode: roomCode);
            return result['success'] != false;
          } catch (error) {
            _reportError('첫 턴 시작을 확인하고 있습니다.', error);
            return false;
          }
        },
      );
    }
  }

  @override
  void handleSubscriptionError(Object error) {
    // 정상 퇴장으로 권한이 사라진 경우와 연결 복구로 스스로 해결되는 네이티브
    // 오류는 사용자에게 표시하지 않습니다. 예전에는 예외 원문을 문구에 붙여
    // 정상 퇴장 중에도 permission-denied 영문 원문이 화면에 떴습니다.
    final message = userErrorMessage(
      error,
      context: UserErrorContext.gameSubscription,
    );

    // 태블릿(진행 기기)은 표시 여부와 별개로 초기 데이터 대기를 반드시 풀어 줍니다.
    if (!watchPrivateHand && !_initialDataCompleter.isCompleted) {
      _initialDataCompleter.completeError(error);
    }

    if (message == null) return;
    _logError(error);
    _update((current) => current.copyWith(errorMessage: message));
    if (!_initialDataCompleter.isCompleted) {
      _initialDataCompleter.completeError(error);
    }
  }

  GameImage _cardAssetForValue(String cardValue) {
    return switch (cardValue.toUpperCase()) {
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
