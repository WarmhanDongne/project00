// [penalty_coordinator.dart] 룰렛 결과를 서버에서 미리 준비하고,
// 태블릿 연출 종료 후 해당 결과를 확정하는 벌칙 진행 파일이다.

// ========================[ import ]==========================
import 'package:game_liars_poker/shared/services/command_service.dart';
import 'package:game_kit/penalty/roulette.dart';
// ============================================================

/// 서버 추첨과 태블릿 애니메이션 완료 사이의 2단계 벌칙 프로토콜을 소유합니다.
class LiarsPokerPenaltyCoordinator {
  LiarsPokerPenaltyCoordinator({
    required this.roomCode,
    required this.commandService,
  });

  final String roomCode;
  final LiarsPokerCommandService commandService;
  String? _resolutionId;

  Future<RouletteResult> prepare() async {
    final response = await commandService.preparePenalty(roomCode: roomCode);
    final resolutionId = response['resolutionId'];
    final result = response['result'];
    if (resolutionId is! String ||
        (result != RouletteResult.safe.name &&
            result != RouletteResult.eliminated.name)) {
      throw StateError('서버 벌칙 추첨 응답이 올바르지 않습니다.');
    }
    _resolutionId = resolutionId;
    return result == RouletteResult.eliminated.name
        ? RouletteResult.eliminated
        : RouletteResult.safe;
  }

  Future<void> complete() async {
    final resolutionId = _resolutionId;
    if (resolutionId == null) {
      throw StateError('완료할 서버 벌칙 추첨값이 없습니다.');
    }
    await commandService.resolvePenalty(
      roomCode: roomCode,
      resolutionId: resolutionId,
    );
    _resolutionId = null;
  }

  void reset() => _resolutionId = null;
}
