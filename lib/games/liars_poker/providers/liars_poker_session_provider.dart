import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:project00/games/liars_poker/providers/liars_poker_game_state.dart';
import 'package:project00/games/liars_poker/controllers/liars_poker_controller.dart';
import 'package:project00/games/liars_poker/services/liars_poker_service.dart';

//=======================Liar's Poker 세션 식별자==============================
@immutable
class LiarsPokerSessionArgs {
  const LiarsPokerSessionArgs({
    required this.roomCode,
    required this.uid,
    required this.service,
    required this.watchPrivateHand,
    this.onError,
  });

  final String roomCode;
  final String uid;
  final LiarsPokerService service;

  /// 휴대폰은 true(내 손패 구독), 태블릿(진행 기기)은 false입니다.
  final bool watchPrivateHand;

  /// 태블릿이 명령 실패를 SnackBar로 알릴 때 전달합니다. initState에서 만든
  /// args를 재사용해야 family 캐시가 유지됩니다.
  final LiarsPokerErrorHandler? onError;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiarsPokerSessionArgs &&
          roomCode == other.roomCode &&
          uid == other.uid &&
          identical(service, other.service) &&
          watchPrivateHand == other.watchPrivateHand &&
          identical(onError, other.onError);

  @override
  int get hashCode => Object.hash(
    roomCode,
    uid,
    identityHashCode(service),
    watchPrivateHand,
    identityHashCode(onError),
  );
}

//=======================Liar's Poker 불변 세션 Provider==============================
/// 같은 방·사용자·기기 역할에는 Riverpod Notifier를 하나만 생성합니다.
///
/// 상태는 매 갱신마다 새로운 [LiarsPokerGameState]로 발행됩니다. 화면이
/// 사라지면 autoDispose가 공개 상태와 개인 손패 구독을 함께 정리합니다.
final liarsPokerSessionProvider = NotifierProvider.autoDispose
    .family<LiarsPokerController, LiarsPokerGameState, LiarsPokerSessionArgs>((
      args,
    ) {
      return LiarsPokerController(
        roomCode: args.roomCode,
        uid: args.uid,
        service: args.service,
        watchPrivateHand: args.watchPrivateHand,
        onError: args.onError,
      );
    });
