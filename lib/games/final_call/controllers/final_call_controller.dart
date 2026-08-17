import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/providers/final_call_game_state.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';
import 'package:project00/games/shared/game_flow/game_finish.dart';
import 'package:project00/games/shared/game_flow/game_interruption.dart';

//=======================Final Call Riverpod 게임 컨트롤러==============================
/// 서버 상태는 불변 [FinalCallGameState]로 발행하고, 화면 애니메이션 상태는
/// 위젯에 남깁니다. Provider가 폐기되면 Realtime Database 구독도 종료됩니다.
class FinalCallController extends Notifier<FinalCallGameState> {
  FinalCallController({
    required this.roomCode,
    required this.uid,
    required this.service,
    this.watchPrivateHand = true,
  });

  final String roomCode;
  final String uid;
  final FinalCallService service;
  final bool watchPrivateHand;

  StreamSubscription<DatabaseEvent>? _publicSubscription;
  StreamSubscription<DatabaseEvent>? _privateSubscription;
  int _discardEventVersion = 0;

  @override
  FinalCallGameState build() {
    final initialState = FinalCallGameState.initial();
    _publicSubscription = service.query
        .watchPublicGame(roomCode)
        .listen(
          _handlePublic,
          onError: (Object error) => _setError('게임 연결이 불안정합니다: $error'),
        );
    if (watchPrivateHand) {
      _privateSubscription = service.query
          .watchPrivatePlayer(roomCode: roomCode, uid: uid)
          .listen(
            _handlePrivate,
            onError: (Object error) => _setError('손패 연결이 불안정합니다: $error'),
          );
    }
    ref.onDispose(() {
      unawaited(_publicSubscription?.cancel());
      unawaited(_privateSubscription?.cancel());
    });
    return initialState;
  }

  //=======================화면 호환용 상태 접근자==============================
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
  GameInterruption? get interruption => state.interruption;

  //=======================파생 게임 상태==============================
  bool get isMyTurn => turnUid == uid;
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

  //=======================Realtime Database 공개 상태 수신==============================
  void _handlePublic(DatabaseEvent event) {
    if (!ref.mounted) return;

    // 태블릿이 게임 노드를 정리하면 휴대폰도 수동 종료 상태로 전환합니다.
    if (!event.snapshot.exists || event.snapshot.value == null) {
      state = state.copyWith(
        loading: false,
        status: 'finished',
        finishReason: 'manual',
        phase: 'finished',
        turnUid: null,
        turnDeadlineAt: null,
        pendingDrawUid: null,
        pendingDrawSource: null,
      );
      return;
    }
    if (event.snapshot.value is! Map) return;

    final current = state;
    final map = Map<Object?, Object?>.from(event.snapshot.value as Map);
    final nextRevision = (map['revision'] as num?)?.toInt() ?? current.revision;
    final nextPendingDrawUid = map['pendingDrawUid']?.toString();
    final nextPhase = map['phase']?.toString() ?? current.phase;
    final rawDiscard = map['discardCard'];
    final nextDiscardCard = rawDiscard is Map
        ? FinalCallCard.fromMap(Map<Object?, Object?>.from(rawDiscard))
        : current.discardCard;

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

    final parsedPlayers = <String, FinalCallPlayer>{};
    final rawPlayers = map['players'];
    if (rawPlayers is Map) {
      for (final entry in rawPlayers.entries) {
        if (entry.value is Map) {
          parsedPlayers[entry.key.toString()] = FinalCallPlayer.fromMap(
            entry.key.toString(),
            Map<Object?, Object?>.from(entry.value as Map),
          );
        }
      }
    }

    final rawFinalTurns = map['finalTurnPendingUids'];
    final finalTurnUids = rawFinalTurns is List
        ? rawFinalTurns.whereType<String>().toList(growable: false)
        : rawFinalTurns is Map
        ? rawFinalTurns.values.whereType<String>().toList(growable: false)
        : const <String>[];
    final rawResult = map['roundResult'];
    final rawInterruption = map['interruption'];
    final rawWinnerUids = map['winnerUids'];
    final winnerUids = rawWinnerUids is List
        ? rawWinnerUids.map((value) => value.toString()).toList(growable: false)
        : rawWinnerUids is Map
        ? rawWinnerUids.values
              .map((value) => value.toString())
              .toList(growable: false)
        : const <String>[];
    final winningTeamValue = map['winningTeam'];
    final winningTeam = winningTeamValue == null
        ? null
        : FinalCallTeam.fromWire(winningTeamValue, seatIndex: 0);

    state = current.copyWith(
      loading: false,
      errorMessage: null,
      status: map['status']?.toString() ?? current.status,
      finishReason: map['finishReason']?.toString(),
      phase: nextPhase,
      round: (map['round'] as num?)?.toInt() ?? current.round,
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
      winningTeam: winningTeam,
      resultRevealCompletedAt: (map['resultRevealCompletedAt'] as num?)
          ?.toInt(),
      players: parsedPlayers,
      roundResult: rawResult is Map
          ? FinalCallRoundResult.fromMap(Map<Object?, Object?>.from(rawResult))
          : null,
      discardEvent: nextDiscardEvent,
      interruption: rawInterruption is Map
          ? GameInterruption.fromMap(
              Map<Object?, Object?>.from(rawInterruption),
            )
          : null,
    );
  }

  //=======================Realtime Database 개인 손패 수신==============================
  void _handlePrivate(DatabaseEvent event) {
    if (!ref.mounted) return;
    final value = event.snapshot.value;
    final cards = <FinalCallCard>[];
    FinalCallCard? nextPendingDraw;
    if (value is Map) {
      final map = Map<Object?, Object?>.from(value);
      final rawHand = map['hand'];
      if (rawHand is Map) {
        for (final raw in rawHand.values) {
          if (raw is Map) {
            cards.add(FinalCallCard.fromMap(Map<Object?, Object?>.from(raw)));
          }
        }
      }
      final rawPending = map['pendingDraw'];
      if (rawPending is Map) {
        nextPendingDraw = FinalCallCard.fromMap(
          Map<Object?, Object?>.from(rawPending),
        );
      }
    }
    state = state.copyWith(
      hand: _preserveHandSlots(cards),
      pendingDraw: nextPendingDraw,
    );
  }

  //=======================손패 표시 순서==============================
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

  //=======================Cloud Function 게임 명령==============================
  Future<bool> draw(String source) =>
      _run(() => service.command.drawCard(roomCode: roomCode, source: source));
  Future<bool> completeTurn(String? replaceCardId) => _run(
    () => service.command.completeTurn(
      roomCode: roomCode,
      replaceCardId: replaceCardId,
    ),
  );
  Future<bool> call() => _run(() => service.command.call(roomCode: roomCode));
  Future<bool> submitFinalHand(List<String> cardIds) => _run(
    () => service.command.submitFinalHand(roomCode: roomCode, cardIds: cardIds),
  );
  Future<bool> completeDealing() =>
      _run(() => service.command.completeDealing(roomCode: roomCode));
  Future<bool> nextRound() =>
      _run(() => service.command.startNextRound(roomCode: roomCode));
  Future<bool> restartGame() =>
      _run(() => service.command.restartGame(roomCode: roomCode));
  Future<bool> endGame() =>
      _run(() => service.command.endGame(roomCode: roomCode));
  Future<bool> clearGame() =>
      _run(() => service.command.clearGame(roomCode: roomCode));
  Future<bool> timeoutTurn() =>
      _run(() => service.command.timeoutTurn(roomCode: roomCode));
  Future<bool> completeResultReveal() =>
      _run(() => service.command.completeResultReveal(roomCode: roomCode));
  Future<bool> voteToContinueInterruption() {
    final current = interruption;
    if (current == null) return Future.value(false);
    return _run(
      () => service.interruption.voteToContinue(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }

  Future<bool> expireInterruption() {
    final current = interruption;
    if (current == null) return Future.value(false);
    return _run(
      () => service.interruption.expire(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }

  Future<bool> excludeInterruptedPlayerAndContinue() {
    final current = interruption;
    if (current == null || !current.canContinue) return Future.value(false);
    return _run(
      () => service.interruption.excludeAndContinue(
        roomCode: roomCode,
        interruptionId: current.id,
      ),
    );
  }

  /// 제한 시간이 끝난 턴은 덱에서 한 장을 가져와 그대로 버립니다.
  Future<bool> completeTimedOutTurn() async {
    if (!canAct) return false;
    if (isFinalSubmitPhase) return timeoutTurn();
    if (pendingDrawUid == uid) return completeTurn(null);
    final drawn = await draw('deck');
    if (!drawn) return false;
    return completeTurn(null);
  }

  Future<bool> _run(Future<Object?> Function() command) async {
    if (commandInFlight) return false;
    state = state.copyWith(commandInFlight: true, errorMessage: null);
    try {
      await command();
      return true;
    } catch (error) {
      _setError(
        error is FirebaseFunctionsException
            ? (error.message ?? '요청을 처리하지 못했습니다.')
            : '서버 연결이 불안정합니다. 잠시 후 다시 시도해주세요.',
      );
      return false;
    } finally {
      if (ref.mounted) {
        state = state.copyWith(commandInFlight: false);
      }
    }
  }

  void _setError(String message) {
    if (!ref.mounted) return;
    state = state.copyWith(errorMessage: message);
  }

  void clearError() {
    state = state.copyWith(errorMessage: null);
  }
}
