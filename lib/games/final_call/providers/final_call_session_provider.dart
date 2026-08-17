import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/games/final_call/providers/final_call_game_state.dart';
import 'package:project00/games/final_call/controllers/final_call_controller.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';

//=======================Final Call 세션 식별자==============================
@immutable
class FinalCallSessionArgs {
  const FinalCallSessionArgs({
    required this.roomCode,
    required this.uid,
    required this.service,
    required this.watchPrivateHand,
  });

  final String roomCode;
  final String uid;
  final FinalCallService service;
  final bool watchPrivateHand;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FinalCallSessionArgs &&
          roomCode == other.roomCode &&
          uid == other.uid &&
          identical(service, other.service) &&
          watchPrivateHand == other.watchPrivateHand;

  @override
  int get hashCode =>
      Object.hash(roomCode, uid, identityHashCode(service), watchPrivateHand);
}

//=======================Final Call 불변 세션 Provider==============================
/// 같은 방·사용자·기기 역할에는 Riverpod Notifier를 하나만 생성합니다.
///
/// 상태는 매 갱신마다 새로운 [FinalCallGameState]로 발행됩니다. 화면이
/// 사라지면 autoDispose가 공개 상태와 개인 손패 구독을 함께 정리합니다.
final finalCallSessionProvider = NotifierProvider.autoDispose
    .family<FinalCallController, FinalCallGameState, FinalCallSessionArgs>((
      args,
    ) {
      return FinalCallController(
        roomCode: args.roomCode,
        uid: args.uid,
        service: args.service,
        watchPrivateHand: args.watchPrivateHand,
      );
    });
