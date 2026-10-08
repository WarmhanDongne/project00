import 'dart:async';

import 'package:firebase_database/firebase_database.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_holdem/shared/services/game_service.dart';
import 'package:game_holdem/shared/services/public_state_mapper.dart';
import 'package:game_kit/recovery/models/game_interruption.dart';
import 'package:game_kit/recovery/providers/game_session_controller.dart';
import 'package:game_kit/recovery/services/game_interruption_command_service.dart';
import 'package:game_kit/services/game_query_service.dart';

class HoldemController extends GameSessionController<HoldemGameState> {
  HoldemController({
    required this.roomCode,
    required this.uid,
    required this.service,
    required this.watchPrivate,
  });

  @override
  final String roomCode;
  @override
  final String uid;
  final HoldemService service;
  final bool watchPrivate;

  @override
  GameQueryService get query => service.query;
  @override
  GameInterruptionCommandService get interruptionCommands =>
      service.interruption;
  @override
  GameInterruption? get interruption => state.interruption;
  @override
  String get commandCrashReason => '홀덤 서버 명령';

  @override
  HoldemGameState build() {
    if (!watchPrivate) {
      Timer.run(() {
        if (ref.mounted) {
          unawaited(
            service.command.warmUpGameplayCommands().catchError((_) {}),
          );
        }
      });
    }
    startSession(watchPrivate: watchPrivate);
    return HoldemGameState.initial();
  }

  @override
  void applyPublicValue(Object? value) {
    if (value is! Map) return;
    final snapshot = HoldemPublicSnapshot.fromValue(value);
    state = state.copyWith(
      loading: false,
      status: snapshot.status,
      phase: snapshot.phase,
      handNumber: snapshot.handNumber,
      revision: snapshot.revision,
      dealerUid: snapshot.dealerUid,
      smallBlindUid: snapshot.smallBlindUid,
      bigBlindUid: snapshot.bigBlindUid,
      smallBlind: snapshot.smallBlind,
      bigBlind: snapshot.bigBlind,
      communityCards: snapshot.communityCards,
      potTotal: snapshot.potTotal,
      turnUid: snapshot.turnUid,
      turnDeadlineAt: snapshot.turnDeadlineAt,
      currentBet: snapshot.currentBet,
      minimumRaise: snapshot.minimumRaise,
      lastAction: snapshot.lastAction,
      players: snapshot.players,
      result: snapshot.result,
      winnerUid: snapshot.winnerUid,
      finishReason: snapshot.finishReason,
      interruption: snapshot.interruption,
    );
  }

  @override
  void handlePrivateEvent(DatabaseEvent event) {
    final value = event.snapshot.value;
    if (value is! Map) {
      state = state.copyWith(
        hand: const [],
        legalActions: null,
        handRank: null,
      );
      return;
    }
    final map = Map<Object?, Object?>.from(value);
    final rawHand = map['hand'];
    state = state.copyWith(
      hand: rawHand is List
          ? rawHand.map(HoldemCardModel.fromValue).toList(growable: false)
          : const [],
      legalActions: map['legalActions'] is Map
          ? HoldemLegalActionsModel.fromValue(map['legalActions'])
          : null,
      handRank: HoldemHandRankModel.fromValue(map['handRank']),
    );
  }

  Future<bool> act(String action, {int? amount}) {
    final stateVersion = state.revision;
    return run(
      () => service.command.act(
        roomCode: roomCode,
        action: action,
        stateVersion: stateVersion,
        amount: amount,
      ),
    );
  }

  Future<bool> completeDealing() =>
      run(() => service.command.completeDealing(roomCode: roomCode));
  Future<bool> timeoutTurn() =>
      run(() => service.command.timeoutTurn(roomCode: roomCode));
  Future<bool> completeResult() =>
      run(() => service.command.completeResult(roomCode: roomCode));
  Future<bool> restartGame() =>
      run(() => service.command.startGame(roomCode: roomCode, restart: true));
  Future<bool> endGame() =>
      run(() => service.command.endGame(roomCode: roomCode));
}
