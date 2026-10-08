import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_holdem/shared/providers/game_controller.dart';
import 'package:game_holdem/shared/services/game_service.dart';

@immutable
class HoldemSessionArgs {
  const HoldemSessionArgs({
    required this.roomCode,
    required this.uid,
    required this.service,
    required this.watchPrivate,
  });
  final String roomCode;
  final String uid;
  final HoldemService service;
  final bool watchPrivate;

  @override
  bool operator ==(Object other) =>
      other is HoldemSessionArgs &&
      roomCode == other.roomCode &&
      uid == other.uid &&
      identical(service, other.service) &&
      watchPrivate == other.watchPrivate;
  @override
  int get hashCode =>
      Object.hash(roomCode, uid, identityHashCode(service), watchPrivate);
}

final holdemSessionProvider = NotifierProvider.autoDispose
    .family<HoldemController, HoldemGameState, HoldemSessionArgs>(
      (args) => HoldemController(
        roomCode: args.roomCode,
        uid: args.uid,
        service: args.service,
        watchPrivate: args.watchPrivate,
      ),
    );
