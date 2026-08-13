import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/foundation.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';

class FinalCallController extends ChangeNotifier {
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
  bool loading = true;
  bool commandInFlight = false;
  String? errorMessage;
  String status = 'playing';
  String? finishReason;
  String phase = 'dealing';
  int round = 1;
  int revision = 0;
  String? turnUid;
  int? turnDeadlineAt;
  String? callerUid;
  int deckRemainingCount = 0;
  FinalCallCard? discardCard;
  String? pendingDrawUid;
  String? pendingDrawSource;
  List<String> finalTurnPendingUids = const [];
  String? winnerUid;
  Map<String, FinalCallPlayer> players = const {};
  List<FinalCallCard> hand = const [];
  FinalCallCard? pendingDraw;
  FinalCallRoundResult? roundResult;

  bool get isMyTurn => turnUid == uid;
  bool get isFinished => status == 'finished';
  bool get canAct =>
      status == 'playing' &&
      (phase == 'playing' ||
          phase == 'callerSubmit' ||
          phase == 'finalTurns') &&
      isMyTurn &&
      !commandInFlight;
  bool get canDraw => canAct && pendingDrawUid == null;
  bool get canCompleteTurn =>
      canAct && pendingDrawUid == uid && pendingDraw != null;
  bool get canCall => canAct && phase == 'playing' && pendingDrawUid == null;
  bool get canSubmitCallerHand =>
      canAct && phase == 'callerSubmit' && callerUid == uid;
  FinalCallPlayer? get turnPlayer => players[turnUid];
  String get actionErrorMessage =>
      errorMessage == null || errorMessage!.trim().isEmpty
      ? '요청을 처리하지 못했습니다. 잠시 후 다시 시도해주세요.'
      : errorMessage!;

  void initialize() {
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
  }

  void _handlePublic(DatabaseEvent event) {
    //=======================게임 노드 삭제 감지==============================
    // 태블릿이 홈으로 이동하며 `rooms/{code}/game`을 정리하면 공개 경로도
    // null이 됩니다. 휴대폰은 이를 수동 종료로 처리해 플랫폼으로 복귀합니다.
    if (!event.snapshot.exists || event.snapshot.value == null) {
      loading = false;
      status = 'finished';
      finishReason = 'manual';
      phase = 'finished';
      turnUid = null;
      turnDeadlineAt = null;
      pendingDrawUid = null;
      pendingDrawSource = null;
      notifyListeners();
      return;
    }
    if (event.snapshot.value is! Map) return;
    final map = Map<Object?, Object?>.from(event.snapshot.value as Map);
    status = map['status']?.toString() ?? status;
    finishReason = map['finishReason']?.toString();
    phase = map['phase']?.toString() ?? phase;
    round = (map['round'] as num?)?.toInt() ?? round;
    revision = (map['revision'] as num?)?.toInt() ?? revision;
    turnUid = map['turnUid']?.toString();
    turnDeadlineAt = (map['turnDeadlineAt'] as num?)?.toInt();
    callerUid = map['callerUid']?.toString();
    deckRemainingCount = (map['deckRemainingCount'] as num?)?.toInt() ?? 0;
    pendingDrawUid = map['pendingDrawUid']?.toString();
    pendingDrawSource = map['pendingDrawSource']?.toString();
    final rawFinalTurns = map['finalTurnPendingUids'];
    if (rawFinalTurns is List) {
      finalTurnPendingUids = rawFinalTurns.whereType<String>().toList(
        growable: false,
      );
    } else if (rawFinalTurns is Map) {
      finalTurnPendingUids = rawFinalTurns.values.whereType<String>().toList(
        growable: false,
      );
    } else {
      finalTurnPendingUids = const [];
    }
    winnerUid = map['winnerUid']?.toString();
    final rawDiscard = map['discardCard'];
    if (rawDiscard is Map) {
      discardCard = FinalCallCard.fromMap(
        Map<Object?, Object?>.from(rawDiscard),
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
    players = Map.unmodifiable(parsedPlayers);
    final rawResult = map['roundResult'];
    roundResult = rawResult is Map
        ? FinalCallRoundResult.fromMap(Map<Object?, Object?>.from(rawResult))
        : null;
    loading = false;
    errorMessage = null;
    notifyListeners();
  }

  void _handlePrivate(DatabaseEvent event) {
    final value = event.snapshot.value;
    final cards = <FinalCallCard>[];
    pendingDraw = null;
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
        pendingDraw = FinalCallCard.fromMap(
          Map<Object?, Object?>.from(rawPending),
        );
      }
    }
    cards.sort((a, b) => a.id.compareTo(b.id));
    hand = List.unmodifiable(cards);
    notifyListeners();
  }

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

  /// 제한 시간이 끝난 턴은 덱에서 한 장을 가져와 그대로 버립니다.
  ///
  /// 이미 카드를 가져온 상태라면 그 카드만 버립니다. 서버 명령은 멱등 키와
  /// 재시도를 사용하므로 화면에서 중복으로 호출되어도 한 번만 반영됩니다.
  Future<bool> completeTimedOutTurn() async {
    if (!canAct) return false;
    if (pendingDrawUid == uid) return completeTurn(null);
    final drawn = await draw('deck');
    if (!drawn) return false;
    return completeTurn(null);
  }

  Future<bool> _run(Future<Object?> Function() command) async {
    if (commandInFlight) return false;
    commandInFlight = true;
    errorMessage = null;
    notifyListeners();
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
      commandInFlight = false;
      notifyListeners();
    }
  }

  void _setError(String message) {
    errorMessage = message;
    notifyListeners();
  }

  void clearError() {
    errorMessage = null;
    notifyListeners();
  }

  @override
  void dispose() {
    _publicSubscription?.cancel();
    _privateSubscription?.cancel();
    super.dispose();
  }
}
