// [game_controller.dart] 는 파이널콜에서 사용하는 서버 상태 구독과 사용자 명령 흐름을 조정하는 파일이다.
//
// - [Package] : 파이널콜
// - [Controller] : 서버 상태 구독과 사용자 명령 흐름을 조정함
//
// 즉, 화면과 서버 사이의 게임 진행을 한곳에서 관리하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:async';
import 'package:firebase_database/firebase_database.dart';
import 'package:game_final_call/shared/models/game_models.dart';
import 'package:game_final_call/shared/models/game_state.dart';
import 'package:game_final_call/shared/services/game_service.dart';
import 'package:game_final_call/shared/services/private_state_mapper.dart';
import 'package:game_final_call/shared/services/public_state_mapper.dart';
import 'package:game_kit/game_flow/game_finish.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/providers/game_session_controller.dart';
import 'package:game_kit/services/game_query_service.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';

// ============================================================

// ---------------------------------------------------------------------------
// Final Call Riverpod 게임 컨트롤러
// ---------------------------------------------------------------------------
/// 서버 상태는 불변 [FinalCallGameState]로 발행하고, 화면 애니메이션 상태는
/// 위젯에 남깁니다. Provider가 폐기되면 Realtime Database 구독도 종료됩니다.
class FinalCallController extends GameSessionController<FinalCallGameState> {
  FinalCallController({
    required this.roomCode,
    required this.uid,
    required this.service,
    this.watchPrivateHand = true,
  });

  @override
  final String roomCode;
  @override
  final String uid;
  final FinalCallService service;
  final bool watchPrivateHand;

  // ---------------------------------------------------------------------------
  // 공용 뼈대에 넘겨 주는 것
  // ---------------------------------------------------------------------------
  @override
  GameQueryService get query => service.query;

  @override
  GameInterruptionCommandService get interruptionCommands =>
      service.interruption;

  @override
  String get commandCrashReason => '파이널콜 서버 명령';

  int _discardEventVersion = 0;

  @override
  FinalCallGameState build() {
    final initialState = FinalCallGameState.initial();
    // 태블릿(진행 기기)이 첫 카드 뽑기·CALL 함수의 콜드스타트를 미리 끝냅니다.
    // 휴대폰은 명령을 보내는 시점이 제각각이라 준비하지 않습니다(LP와 같은 규칙).
    if (!watchPrivateHand) {
      _scheduleGameplayWarmUp();
    }

    startSession(watchPrivate: watchPrivateHand);
    return initialState;
  }

  /// Provider [build] 중 통신 로그가 UI를 갱신하지 않도록 예열을 다음
  /// event-loop turn에 시작합니다. 라이어스포커와 같은 진입 규칙입니다.
  void _scheduleGameplayWarmUp() {
    Timer.run(() {
      if (ref.mounted) unawaited(_warmUpGameplayCommands());
    });
  }

  /// 첫 조작 함수를 미리 깨웁니다. 실패는 무시합니다(실제 명령이 재시도합니다).
  Future<void> _warmUpGameplayCommands() async {
    try {
      await service.command.warmUpGameplayCommands();
    } catch (_) {
      // 예열은 보조 기능이라 실패해도 게임 진행을 막지 않습니다.
    }
  }

  // ---------------------------------------------------------------------------
  // 화면 호환용 상태 접근자
  // ---------------------------------------------------------------------------
  bool get loading => state.loading;
  bool get commandInFlight => state.commandInFlight;
  String? get errorMessage => state.errorMessage;
  String get status => state.status;
  String? get finishReason => state.finishReason;
  String get phase => state.phase;
  int get round => state.round;
  int get revision => state.revision;
  String? get turnUid => state.turnUid;
  int? get turnDeadlineAt => state.turnDeadlineAt;
  String? get callerUid => state.callerUid;
  int get deckRemainingCount => state.deckRemainingCount;
  FinalCallCard? get discardCard => state.discardCard;
  String? get pendingDrawUid => state.pendingDrawUid;
  String? get pendingDrawSource => state.pendingDrawSource;
  List<String> get finalTurnPendingUids => state.finalTurnPendingUids;
  String? get winnerUid => state.winnerUid;
  List<String> get winnerUids => state.winnerUids;
  FinalCallTeam? get winningTeam => state.winningTeam;
  int? get resultRevealCompletedAt => state.resultRevealCompletedAt;
  Map<String, FinalCallPlayer> get players => state.players;
  List<FinalCallCard> get hand => state.hand;
  FinalCallCard? get pendingDraw => state.pendingDraw;
  FinalCallRoundResult? get roundResult => state.roundResult;
  FinalCallDiscardEvent? get discardEvent => state.discardEvent;
  @override
  GameInterruption? get interruption => state.interruption;

  // ---------------------------------------------------------------------------
  // 파생 게임 상태
  // ---------------------------------------------------------------------------
  bool get isMyTurn => turnUid == uid;
  bool get isEliminated => players[uid]?.status == 'eliminated';
  int get remainingTeamCount => players.values
      .where((player) => player.status == 'alive')
      .map((player) => player.team)
      .toSet()
      .length;
  bool get isFinished => status == 'finished';

  /// 마지막 생존자가 정해져 정상적으로 끝났는지 여부입니다.
  ///
  /// 휴대폰은 이 값이 false인 종료를 모두 '나가야 하는 종료'로 봅니다.
  /// 자세한 근거는 [isNaturalGameResult] 문서를 보세요.
  bool get isNaturalResult =>
      (isFinished && finishReason == 'draw') ||
      isNaturalGameResult(
        isFinished: isFinished,
        winnerUid: winnerUid,
        finishReason: finishReason,
      );
  List<FinalCallPlayer> get winners =>
      (winnerUids.isNotEmpty
              ? winnerUids
              : winnerUid == null
              ? const <String>[]
              : <String>[winnerUid!])
          .map((winningUid) => players[winningUid])
          .whereType<FinalCallPlayer>()
          .toList(growable: false);
  FinalCallTeam? get myTeam => players[uid]?.team;
  bool get canAct =>
      status == 'playing' &&
      interruption == null &&
      (phase == 'playing' ||
          phase == 'callerSubmit' ||
          phase == 'finalTurns' ||
          phase == 'finalSubmit') &&
      isMyTurn &&
      !commandInFlight;
  bool get canDraw =>
      canAct &&
      (phase == 'playing' || phase == 'finalTurns') &&
      pendingDrawUid == null;
  bool get canCompleteTurn =>
      canAct && pendingDrawUid == uid && pendingDraw != null;
  bool get canCall => canAct && phase == 'playing' && pendingDrawUid == null;
  bool get isFinalSubmitPhase =>
      status == 'playing' &&
      (phase == 'callerSubmit' || phase == 'finalSubmit') &&
      turnUid == uid;
  bool get canSubmitFinalHand => isFinalSubmitPhase && !commandInFlight;
  FinalCallPlayer? get turnPlayer => players[turnUid];
  String get actionErrorMessage =>
      errorMessage == null || errorMessage!.trim().isEmpty
      ? '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.'
      : errorMessage!;
  @override
  void applyPublicValue(Object? value) {
    if (!ref.mounted || value is! Map) return;

    final current = state;
    final map = Map<Object?, Object?>.from(value);
    final nextRevision = (map['revision'] as num?)?.toInt() ?? current.revision;
    final nextPendingDrawUid = map['pendingDrawUid']?.toString();
    final nextPhase = map['phase']?.toString() ?? current.phase;
    final nextRound = (map['round'] as num?)?.toInt() ?? current.round;
    final enteredNewDealing =
        nextPhase == 'dealing' &&
        (current.loading ||
            current.phase != 'dealing' ||
            current.round != nextRound);
    final nextDiscardCard =
        parseFinalCallCard(map['discardCard']) ?? current.discardCard;

    var nextDiscardEvent = current.discardEvent;
    if (!current.loading &&
        current.pendingDrawUid != null &&
        nextPendingDrawUid == null &&
        nextPhase != 'roundResult' &&
        nextPhase != 'finished' &&
        nextDiscardCard != null) {
      _discardEventVersion += 1;
      nextDiscardEvent = FinalCallDiscardEvent(
        version: _discardEventVersion,
        playerUid: current.pendingDrawUid!,
        card: nextDiscardCard,
        previousCard: current.discardCard,
        drawSource: current.pendingDrawSource,
      );
    }

    final parsedPlayers = parseFinalCallPlayers(map['players']);
    final finalTurnUids = parseFinalCallStringCollection(
      map['finalTurnPendingUids'],
    );
    final winnerUids = parseFinalCallStringCollection(map['winnerUids']);

    state = current.copyWith(
      loading: false,
      errorMessage: null,
      status: map['status']?.toString() ?? current.status,
      finishReason: map['finishReason']?.toString(),
      phase: nextPhase,
      round: nextRound,
      revision: nextRevision,
      turnUid: map['turnUid']?.toString(),
      turnDeadlineAt: (map['turnDeadlineAt'] as num?)?.toInt(),
      callerUid: map['callerUid']?.toString(),
      deckRemainingCount: (map['deckRemainingCount'] as num?)?.toInt() ?? 0,
      discardCard: nextDiscardCard,
      pendingDrawUid: nextPendingDrawUid,
      pendingDrawSource: map['pendingDrawSource']?.toString(),
      finalTurnPendingUids: finalTurnUids,
      winnerUid: map['winnerUid']?.toString(),
      winnerUids: winnerUids,
      winningTeam: parseFinalCallWinningTeam(map['winningTeam']),
      resultRevealCompletedAt: (map['resultRevealCompletedAt'] as num?)
          ?.toInt(),
      players: parsedPlayers,
      // 새 라운드 트랜잭션은 public phase와 private={}를 함께 기록하지만
      // RTDB 리스너의 이벤트 도착 순서는 보장되지 않습니다. private null이
      // public dealing보다 먼저 오면 재접속 보호 로직이 이전 손패를 보존할 수
      // 있으므로, 공개 상태가 dealing에 진입한 순간 이전 손패를 확실히 지웁니다.
      // 이 초기화가 없으면 이전 카드팩을 한 번 보여준 뒤 실제 새 손패로 카드팩을
      // 다시 만드는 이중 분배 현상이 발생합니다.
      hand: enteredNewDealing ? const <FinalCallCard>[] : current.hand,
      pendingDraw: enteredNewDealing ? null : current.pendingDraw,
      roundResult: parseFinalCallRoundResult(map['roundResult']),
      discardEvent: nextDiscardEvent,
      interruption: parseFinalCallInterruption(map['recovery']),
    );
  }

  // ---------------------------------------------------------------------------
  // Realtime Database 개인 손패 수신
  // ---------------------------------------------------------------------------
  @override
  void handlePrivateEvent(DatabaseEvent event) {
    if (!ref.mounted) return;
    final value = event.snapshot.value;
    if (value == null &&
        phase != 'dealing' &&
        (hand.isNotEmpty || pendingDraw != null)) {
      // 연결 복구 중의 일시적인 null로 손패와 이미 받은 새 카드를 지우지 않습니다.
      return;
    }
    final privateSnapshot = FinalCallPrivateSnapshot.fromValue(value);
    state = state.copyWith(
      hand: _preserveHandSlots(privateSnapshot.hand),
      pendingDraw: privateSnapshot.pendingDraw,
    );
  }

  // ---------------------------------------------------------------------------
  // 손패 표시 순서
  // ---------------------------------------------------------------------------
  /// 교체된 카드만 기존 슬롯에 넣어 나머지 카드가 임의로 이동하지 않게 합니다.
  List<FinalCallCard> _preserveHandSlots(List<FinalCallCard> incomingCards) {
    if (hand.isEmpty) return incomingCards;

    final incomingById = <String, FinalCallCard>{
      for (final card in incomingCards) card.id: card,
    };
    final newCards = incomingCards
        .where((card) => !hand.any((current) => current.id == card.id))
        .toList();
    final ordered = <FinalCallCard>[];

    for (final current in hand) {
      final retained = incomingById.remove(current.id);
      if (retained != null) {
        ordered.add(retained);
      } else if (newCards.isNotEmpty) {
        final replacement = newCards.removeAt(0);
        incomingById.remove(replacement.id);
        ordered.add(replacement);
      }
    }
    ordered.addAll(incomingById.values);
    return ordered;
  }

  /// 길게 눌러 옮긴 손패 순서를 이후 Firebase 갱신에서도 유지합니다.
  void reorderHand(String draggedCardId, String targetCardId) {
    final fromIndex = hand.indexWhere((card) => card.id == draggedCardId);
    final targetIndex = hand.indexWhere((card) => card.id == targetCardId);
    if (fromIndex < 0 || targetIndex < 0 || fromIndex == targetIndex) return;

    final reordered = List<FinalCallCard>.from(hand);
    final draggedCard = reordered.removeAt(fromIndex);
    reordered.insert(targetIndex.clamp(0, reordered.length), draggedCard);
    state = state.copyWith(hand: reordered);
  }

  void acknowledgeDiscardEvent(int version) {
    if (discardEvent?.version != version) return;
    state = state.copyWith(discardEvent: null);
  }

  // ---------------------------------------------------------------------------
  // Cloud Function 게임 명령
  // ---------------------------------------------------------------------------
  Future<bool> draw(String source) =>
      run(() => service.command.drawCard(roomCode: roomCode, source: source));
  Future<bool> completeTurn(String? replaceCardId) => run(
    () => service.command.completeTurn(
      roomCode: roomCode,
      replaceCardId: replaceCardId,
    ),
  );
  Future<bool> call() => run(() => service.command.call(roomCode: roomCode));
  Future<bool> submitFinalHand(List<String> cardIds) => run(
    () => service.command.submitFinalHand(roomCode: roomCode, cardIds: cardIds),
  );
  Future<bool> completeDealing() =>
      run(() => service.command.completeDealing(roomCode: roomCode));
  Future<bool> nextRound() =>
      run(() => service.command.startNextRound(roomCode: roomCode));
  Future<bool> restartGame() =>
      run(() => service.command.restartGame(roomCode: roomCode));
  Future<bool> endGame() =>
      run(() => service.command.endGame(roomCode: roomCode));
  Future<bool> clearGame() =>
      run(() => service.command.clearGame(roomCode: roomCode));
  Future<bool> timeoutTurn() =>
      run(() => service.command.timeoutTurn(roomCode: roomCode));
  Future<bool> completeResultReveal() =>
      run(() => service.command.completeResultReveal(roomCode: roomCode));

  /// 제한 시간이 끝난 턴은 덱에서 한 장을 가져와 그대로 버립니다.
  Future<bool> completeTimedOutTurn() async {
    if (!canAct) return false;
    if (isFinalSubmitPhase) return timeoutTurn();
    if (pendingDrawUid == uid) return completeTurn(null);
    final drawn = await draw('deck');
    if (!drawn) return false;
    return completeTurn(null);
  }
}
