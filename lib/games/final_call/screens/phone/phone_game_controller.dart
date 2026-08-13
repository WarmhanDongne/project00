import 'package:project00/games/final_call/controllers/final_call_controller.dart';
import 'package:project00/games/final_call/services/final_call_service.dart';

/// Final Call 휴대폰 화면에서 사용하는 단일 Firebase 구독 컨트롤러입니다.
class PhoneGameController extends FinalCallController {
  PhoneGameController({
    required super.roomCode,
    required super.uid,
    required FinalCallService gameService,
    super.watchPrivateHand = true,
  }) : super(service: gameService);
}
