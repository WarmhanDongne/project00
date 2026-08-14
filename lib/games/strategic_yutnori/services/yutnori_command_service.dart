import '../models/yutnori_state.dart';
import '../models/piece_model.dart';
import 'yutnori_query_service.dart';

class YutnoriCommandService {
  
  /// 윷 던지기 판정 후 상태 업데이트
  static YutnoriState throwYut(YutnoriState state, YutResult result) {
    List<YutResult> newMoves = List.from(state.availableMoves)..add(result);
    
    // 윷이나 모가 나오면 추가 턴 (던지기 페이즈 유지), 그 외에는 이동 페이즈로 전환
    GamePhase nextPhase = (result == YutResult.yut || result == YutResult.mo)
        ? GamePhase.throwing
        : GamePhase.moving;
    
    return state.copyWith(
      availableMoves: newMoves,
      phase: nextPhase,
    );
  }

  /// 말 이동 및 부수 효과(업기, 잡기) 처리 후 상태 업데이트
  static YutnoriState movePiece(YutnoriState state, String pieceId, YutResult resultToUse) {
    final piece = state.pieces.firstWhere((p) => p.id == pieceId);
    final destNodeId = YutnoriQueryService.getDestinationNodeId(piece, resultToUse);
    
    // 이동 불가능한 경우 상태 변경 없음
    if (destNodeId == null) return state;

    final teamId = piece.teamId;

    // 1. 업기 판정: 현재 이동하려는 말과 같은 위치에 있는 '우리 팀' 말들을 모두 찾음 (자동 합치기)
    final piggybackedPieces = state.pieces.where((p) => 
      p.teamId == teamId && p.currentNodeId == piece.currentNodeId
    ).toList();

    // 2. 잡기 판정: 도착지에 있는 '적 팀' 말들을 찾음
    final enemyPieces = state.pieces.where((p) => 
      p.teamId != teamId && p.currentNodeId == destNodeId
    ).toList();

    bool isCaptured = enemyPieces.isNotEmpty;
    
    // 3. 상태 업데이트를 위한 새로운 말 리스트 구성
    List<PieceModel> newPieces = [];
    for (var p in state.pieces) {
      if (piggybackedPieces.any((piggy) => piggy.id == p.id)) {
        // 우리 팀 말 이동 (업혀서 다 같이 도착지로 이동)
        newPieces.add(p.copyWith(currentNodeId: destNodeId));
      } else if (enemyPieces.any((enemy) => enemy.id == p.id)) {
        // 적 말 잡힘 (currentNodeId를 강제로 null로 만들어 대기실로 원상복귀)
        newPieces.add(p.copyWith(clearNode: true)); 
      } else {
        newPieces.add(p);
      }
    }

    // 4. 사용한 윷 결과 제거
    List<YutResult> newMoves = List.from(state.availableMoves);
    newMoves.remove(resultToUse); // 사용한 결과 1개 소진

    // 5. 다음 페이즈 및 턴 결정 로직
    GamePhase nextPhase;
    String nextTurnTeamId = state.currentTurnTeamId;

    if (isCaptured) {
      // 상대방 말을 잡았으면 윷을 한 번 더 던질 기회를 얻음
      nextPhase = GamePhase.throwing;
    } else if (newMoves.isEmpty) {
      // 사용할 윷 결과가 없으면 턴이 종료됨 (다음 팀으로 교체 로직 필요. 일단 윷 던지기 페이즈로 전환)
      nextPhase = GamePhase.setup; 
      // 실제로는 A->B->B->A 순서 로직이 들어가야 하나, 1단계에선 우선 상태 구조만 잡음
      nextTurnTeamId = state.currentTurnTeamId == 'A' ? 'B' : 'A';
    } else {
      // 아직 남은 이동 횟수가 있으면 계속 이동 페이즈
      nextPhase = GamePhase.moving;
    }

    // 6. 승리 조건 체크
    String? winnerId = state.winnerTeamId;
    // 임시로 상태를 만들어서 쿼리 서비스에 전달
    final tempState = state.copyWith(pieces: newPieces);
    if (YutnoriQueryService.checkWinCondition(tempState, teamId)) {
      nextPhase = GamePhase.finished;
      winnerId = teamId;
    }

    return state.copyWith(
      pieces: newPieces,
      availableMoves: newMoves,
      phase: nextPhase,
      currentTurnTeamId: nextTurnTeamId,
      winnerTeamId: winnerId,
    );
  }
}
