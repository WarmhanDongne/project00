import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_phone_state.dart';
import 'package:project00/games/liars_poker/screens/phone/phone_game_controller.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';

//=======================Liar's Poker 휴대폰 세션 식별자==============================
@immutable
class LiarsPokerPhoneSessionArgs {
  const LiarsPokerPhoneSessionArgs({
    required this.roomCode,
    required this.uid,
    required this.service,
  });

  final String roomCode;
  final String uid;
  final LiarsPokerService service;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiarsPokerPhoneSessionArgs &&
          roomCode == other.roomCode &&
          uid == other.uid &&
          identical(service, other.service);

  @override
  int get hashCode => Object.hash(roomCode, uid, identityHashCode(service));
}

//=======================Liar's Poker 휴대폰 세션 Provider==============================
final liarsPokerPhoneSessionProvider = NotifierProvider.autoDispose
    .family<
      PhoneGameController,
      LiarsPokerPhoneState,
      LiarsPokerPhoneSessionArgs
    >((args) {
      return PhoneGameController(
        roomCode: args.roomCode,
        uid: args.uid,
        gameService: args.service,
      );
    });
