import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/yutnori_state.dart';
import '../models/piece_model.dart';
import '../models/player_model.dart';
import '../services/yutnori_command_service.dart';

class YutnoriNotifier extends Notifier<YutnoriState> {
  @override
  YutnoriState build() {
    // 1단계 기본 초기화 (테스트용)
    // 각 팀별 승리말 2개, 지원말 2개 셋팅
    return const YutnoriState(
      phase: GamePhase.throwing,
      currentTurnTeamId: 'A',
      pieces: [
        PieceModel(id: 'A_V1', teamId: 'A', type: PieceType.victory),
        PieceModel(id: 'A_V2', teamId: 'A', type: PieceType.victory),
        PieceModel(id: 'A_S1', teamId: 'A', type: PieceType.support),
        PieceModel(id: 'A_S2', teamId: 'A', type: PieceType.support),
        
        PieceModel(id: 'B_V1', teamId: 'B', type: PieceType.victory),
        PieceModel(id: 'B_V2', teamId: 'B', type: PieceType.victory),
        PieceModel(id: 'B_S1', teamId: 'B', type: PieceType.support),
        PieceModel(id: 'B_S2', teamId: 'B', type: PieceType.support),
      ],
      players: [
        PlayerModel(id: 'P1', teamId: 'A', name: '팀A 메인', role: PlayerRole.main),
        PlayerModel(id: 'P2', teamId: 'A', name: '팀A 파트너', role: PlayerRole.partner),
        PlayerModel(id: 'P3', teamId: 'B', name: '팀B 메인', role: PlayerRole.main),
        PlayerModel(id: 'P4', teamId: 'B', name: '팀B 파트너', role: PlayerRole.partner),
      ],
    );
  }

  /// 윷 던지기 액션 (View에서 호출)
  void throwYut(YutResult result) {
    if (state.phase != GamePhase.throwing) return;
    state = YutnoriCommandService.throwYut(state, result);
  }

  /// 말 이동 액션 (View에서 호출)
  void movePiece(String pieceId, YutResult result) {
    if (state.phase != GamePhase.moving) return;
    state = YutnoriCommandService.movePiece(state, pieceId, result);
  }
}

// 전역으로 접근 가능한 Provider 생성
final yutnoriProvider = NotifierProvider<YutnoriNotifier, YutnoriState>(() {
  return YutnoriNotifier();
});
