// [session_provider.dart] 방·사용자·기기 역할별로
// 라이어스 포커 세션 Controller와 상태의 생명주기를 관리하는 파일이다.

// ========================[ import ]==========================
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_liars_poker/shared/models/game_state.dart';
import 'package:game_liars_poker/shared/providers/game_controller.dart';
import 'package:game_liars_poker/shared/services/game_service.dart';
// ============================================================

// ---------------------------------------------------------------------------
// Liar's Poker 세션 식별자
// ---------------------------------------------------------------------------
@immutable
class LiarsPokerSessionArgs {
  const LiarsPokerSessionArgs({
    required this.roomCode,
    required this.uid,
    required this.service,
    required this.watchPrivateHand,
  });

  final String roomCode;
  final String uid;
  final LiarsPokerService service;

  /// 휴대폰은 true(내 손패 구독), 태블릿(진행 기기)은 false입니다.
  final bool watchPrivateHand;


  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LiarsPokerSessionArgs &&
          roomCode == other.roomCode &&
          uid == other.uid &&
          identical(service, other.service) &&
          watchPrivateHand == other.watchPrivateHand;

  @override
  int get hashCode => Object.hash(
    roomCode,
    uid,
    identityHashCode(service),
    watchPrivateHand,
  );
}

// ---------------------------------------------------------------------------
// Liar's Poker 불변 세션 Provider
// ---------------------------------------------------------------------------
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
      );
    });
