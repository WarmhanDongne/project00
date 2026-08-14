class BoardNodeModel {
  final int id;
  final int nextNodeId; // 기본 직진 경로의 다음 칸 ID (완주시 특수 ID, 예: 99)
  final int? shortcutNodeId; // 교차로(모서리)에 도착했을 때 꺾어지는 경로의 다음 칸 ID
  final bool isCenter; // 정중앙(방) 칸인지 여부. (정중앙 칸은 진입 방향에 따라 출구가 달라지므로 특수 처리 필요)

  const BoardNodeModel({
    required this.id,
    required this.nextNodeId,
    this.shortcutNodeId,
    this.isCenter = false,
  });

  @override
  String toString() {
    return 'Node(id: $id, next: $nextNodeId, shortcut: $shortcutNodeId)';
  }
}

// 윷판 전체 노드 맵을 상수로 제공
class YutBoardMap {
  static const int outNodeId = 99; // 완주 처리용 가상 노드

  static final Map<int, BoardNodeModel> nodes = {
    // === 외곽 경로 (0 ~ 19) ===
    0: const BoardNodeModel(id: 0, nextNodeId: 1), // 시작점 우측 하단
    1: const BoardNodeModel(id: 1, nextNodeId: 2),
    2: const BoardNodeModel(id: 2, nextNodeId: 3),
    3: const BoardNodeModel(id: 3, nextNodeId: 4),
    4: const BoardNodeModel(id: 4, nextNodeId: 5),
    
    // 모서리 1 (우측 상단) - 지름길(20번) 존재
    5: const BoardNodeModel(id: 5, nextNodeId: 6, shortcutNodeId: 20),
    6: const BoardNodeModel(id: 6, nextNodeId: 7),
    7: const BoardNodeModel(id: 7, nextNodeId: 8),
    8: const BoardNodeModel(id: 8, nextNodeId: 9),
    9: const BoardNodeModel(id: 9, nextNodeId: 10),
    
    // 모서리 2 (좌측 상단) - 지름길(25번) 존재
    10: const BoardNodeModel(id: 10, nextNodeId: 11, shortcutNodeId: 25),
    11: const BoardNodeModel(id: 11, nextNodeId: 12),
    12: const BoardNodeModel(id: 12, nextNodeId: 13),
    13: const BoardNodeModel(id: 13, nextNodeId: 14),
    14: const BoardNodeModel(id: 14, nextNodeId: 15),
    
    // 모서리 3 (좌측 하단)
    15: const BoardNodeModel(id: 15, nextNodeId: 16),
    16: const BoardNodeModel(id: 16, nextNodeId: 17),
    17: const BoardNodeModel(id: 17, nextNodeId: 18),
    18: const BoardNodeModel(id: 18, nextNodeId: 19),
    19: const BoardNodeModel(id: 19, nextNodeId: outNodeId), // 출구로 나감

    // === 대각선 경로 1 (우측 상단 -> 좌측 하단) ===
    20: const BoardNodeModel(id: 20, nextNodeId: 21),
    21: const BoardNodeModel(id: 21, nextNodeId: 22),
    
    // 방 (정중앙) - 특수 처리 교차로
    // 21에서 왔으면 23으로, 26에서 왔으면 27로 가야 함
    // 여기서는 기본값을 23으로 두고 서비스 로직에서 isCenter일 때 분기 처리
    22: const BoardNodeModel(id: 22, nextNodeId: 23, isCenter: true), 
    
    23: const BoardNodeModel(id: 23, nextNodeId: 24),
    24: const BoardNodeModel(id: 24, nextNodeId: 15), // 좌하단 합류

    // === 대각선 경로 2 (좌측 상단 -> 우측 하단 출구) ===
    25: const BoardNodeModel(id: 25, nextNodeId: 26),
    26: const BoardNodeModel(id: 26, nextNodeId: 22),
    
    27: const BoardNodeModel(id: 27, nextNodeId: 28),
    28: const BoardNodeModel(id: 28, nextNodeId: outNodeId), // 바로 출구로 나감
  };
}
