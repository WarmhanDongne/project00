import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:project00/games/final_call/screens/phone/phone_game_controller.dart';
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

//=======================Final Call 단일 구독 Provider==============================
/// 같은 방·사용자·기기 역할에는 컨트롤러를 하나만 생성합니다.
///
/// 화면이 사라지면 autoDispose가 Firebase 공개 상태와 개인 손패 구독을
/// 함께 정리합니다. 카드·버튼 AnimationController는 화면의 State에 남겨
/// 서버 갱신으로 애니메이션 인스턴스가 재생성되지 않게 합니다.
final finalCallSessionProvider = ChangeNotifierProvider.autoDispose
    .family<PhoneGameController, FinalCallSessionArgs>((ref, args) {
      return PhoneGameController(
        roomCode: args.roomCode,
        uid: args.uid,
        gameService: args.service,
        watchPrivateHand: args.watchPrivateHand,
      )..initialize();
    });
