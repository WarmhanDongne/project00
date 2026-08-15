import '../models/yutnori_state.dart';
import '../models/piece_model.dart';
import 'yutnori_query_service.dart';

class YutnoriCommandService {
  
  /// 윷 던지기 판정 후 상태 업데이트
  static YutnoriState throwYut(YutnoriState state, YutResult result) {
    List<YutResult> newMoves = List.from(state.availableMoves)..add(result);
    
    int newRemainingThrows = state.remainingThrows - 1;
    if (result == YutResult.yut || result == YutResult.mo) {
      newRemainingThrows += 1; // 윷이나 모가 나오면 던질 기회 +1
    }
    
    GamePhase nextPhase = newRemainingThrows > 0 ? GamePhase.throwing : GamePhase.moving;
    String nextTurnTeamId = state.currentTurnTeamId;
    
    // 만약 이동 페이즈로 넘어갔는데, 어떤 말로도 이동할 수 없는 상황(예: 판에 말이 없는데 빽도만 나옴)이면 턴 강제 종료
    if (nextPhase == GamePhase.moving) {
      bool hasValidMove = false;
      final myPieces = state.pieces.where((p) => p.teamId == state.currentTurnTeamId).toList();
      for (var piece in myPieces) {
        for (var move in newMoves) {
          if (YutnoriQueryService.getDestinationNodeIds(piece, move).isNotEmpty) {
            hasValidMove = true;
            break;
          }
        }
        if (hasValidMove) break;
      }
      
      if (!hasValidMove) {
        // 사용할 수 있는 이동이 없으므로 전부 소거하고 다음 턴으로 넘김
        newMoves.clear();
        nextPhase = GamePhase.throwing;
        nextTurnTeamId = state.currentTurnTeamId == 'A' ? 'B' : 'A';
        newRemainingThrows = 1;
      }
    }
    
    return state.copyWith(
      availableMoves: newMoves,
      phase: nextPhase,
      remainingThrows: newRemainingThrows,
      currentTurnTeamId: nextTurnTeamId,
    );
  }

  /// 말 이동 및 부수 효과(업기, 잡기) 처리 후 상태 업데이트
  static YutnoriState movePiece(YutnoriState state, String pieceId, YutResult resultToUse, int destNodeId) {
    final piece = state.pieces.firstWhere((p) => p.id == pieceId);
    final teamId = piece.teamId;

    // 1. 업기 판정: 현재 이동하려는 말과 '보드 위에서' 같은 위치에 있는 '우리 팀' 말들을 모두 찾음 (자동 합치기)
    // 대기실에서 출발하는 경우(null)는 자기 자신만 포함
    final piggybackedPieces = piece.currentNodeId == null 
        ? [piece] 
        : state.pieces.where((p) => 
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

    int newRemainingThrows = state.remainingThrows;
    if (isCaptured) {
      newRemainingThrows += 1; // 상대방 말을 잡았으면 윷을 한 번 더 던질 기회를 얻음
    }

    // 5. 다음 페이즈 및 턴 결정 로직
    GamePhase nextPhase;
    String nextTurnTeamId = state.currentTurnTeamId;

    if (newRemainingThrows > 0) {
      // 던질 기회가 남아있으면 언제든 던질 수 있도록 throwing 상태 유지
      nextPhase = GamePhase.throwing;
    } else if (newMoves.isNotEmpty) {
      // 던질 기회는 없지만 이동할 칸이 남아있으면 moving 상태 유지
      nextPhase = GamePhase.moving;
    } else {
      // 던질 기회도 없고 이동할 칸도 없으면 턴 종료
      nextPhase = GamePhase.throwing; 
      nextTurnTeamId = state.currentTurnTeamId == 'A' ? 'B' : 'A';
      newRemainingThrows = 1; // 다음 팀에게 기본 던지기 기회 1회 부여
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
      remainingThrows: newRemainingThrows,
    );
  }
}
