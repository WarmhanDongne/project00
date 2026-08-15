import '../models/board_node_model.dart';
import '../models/piece_model.dart';
import '../models/yutnori_state.dart';

class YutnoriQueryService {
  
  /// 특정 팀이 승리조건을 달성했는지 체크
  /// 승리말 2개가 모두 완주(currentNodeId == YutBoardMap.outNodeId)하면 true
  static bool checkWinCondition(YutnoriState state, String teamId) {
    final teamVictoryPieces = state.pieces.where((p) => 
      p.teamId == teamId && p.type == PieceType.victory
    ).toList();
    
    if (teamVictoryPieces.isEmpty) return false;

    return teamVictoryPieces.every((p) => p.currentNodeId == YutBoardMap.outNodeId);
  }

  /// 특정 말이 윷 결과에 따라 도달할 최종 노드 ID 목록 계산 (다중 경로 지원)
  /// 이동 불가(예: 대기실에서 백도)인 경우 빈 리스트 반환
  static List<int> getDestinationNodeIds(PieceModel piece, YutResult result) {
    int? current = piece.currentNodeId;

    // 대기실에 있는 경우
    if (current == null) {
      if (result == YutResult.backDo) {
        return []; // 대기실에서는 뒷도 사용 불가
      }
      current = 0; // 시작점 진입
      return _moveForward(current, result.steps - 1); 
    }

    // 윷판 위에 있는 경우
    if (result == YutResult.backDo) {
      int backwardDest = _moveBackward(current);
      return [backwardDest];
    } else {
      return _moveForward(current, result.steps);
    }
  }

  // 앞방향으로 steps 칸 만큼 이동하여 가능한 도착지 리스트 반환
  static List<int> _moveForward(int startNodeId, int steps) {
    // 이동 경로 탐색을 위한 BFS 큐
    List<int> currentNodes = [startNodeId];
    
    for (int i = 0; i < steps; i++) {
      List<int> nextNodes = [];
      
      for (int currentId in currentNodes) {
        if (currentId == YutBoardMap.outNodeId) {
          if (!nextNodes.contains(YutBoardMap.outNodeId)) {
            nextNodes.add(YutBoardMap.outNodeId);
          }
          continue;
        }

        final node = YutBoardMap.nodes[currentId]!;
        
        // 방금 출발한 칸이 모서리(교차로)인 경우 지름길과 직진길 모두 탐색 (첫 스텝에서만 분기)
        if (i == 0 && node.shortcutNodeId != null) {
          nextNodes.add(node.shortcutNodeId!);
          nextNodes.add(node.nextNodeId);
        } else {
          // 모서리가 아니거나, 이미 이동 중이라면 직진
          nextNodes.add(node.nextNodeId);
        }
      }
      currentNodes = nextNodes;
    }
    
    // 중복 제거 후 반환
    return currentNodes.toSet().toList();
  }

  // 뒤방향(백도)으로 1칸 이동
  static int _moveBackward(int currentId) {
    if (currentId == 0) return YutBoardMap.outNodeId; // 출발선을 거꾸로 지나가면 즉시 완주 처리! (역주행 완주)
    if (currentId == 20) return 5; // 우상단 교차로로 빽
    if (currentId == 25) return 10; // 좌상단 교차로로 빽
    if (currentId == 23) return 22; // 중앙에서 빽
    if (currentId == 27) return 22; // 중앙에서 빽
    
    // 그 외 일반적인 경로는 nextNodeId가 현재 노드인 곳을 찾음
    for (var entry in YutBoardMap.nodes.entries) {
      // 꺾이는 교차로가 아닌 직진 경로에서만 탐색 (shortcut이 아닌 nextNodeId 기준)
      if (entry.value.nextNodeId == currentId && !entry.value.isCenter) {
        return entry.key;
      }
    }
    
    // 중앙 노드(22)에서 빽하는 경우, 이전 노드는 21 또는 26인데 기본으로 21로 처리 (간소화)
    if (currentId == 22) return 21;
    
    return 0; // Fallback
  }
}
