enum PieceType {
  victory,  // 승리말
  support,  // 지원말
}

class PieceModel {
  final String id;
  final String teamId; // e.g., 'A' or 'B'
  final PieceType type;
  
  // null이면 대기실에 있음. 완주했을 경우 특수 값(예: 99) 또는 별도 상태로 관리
  final int? currentNodeId; 
  
  // 자신이 업고 있는(합쳐진) 다른 말들의 ID 목록
  final List<String> carriedPieceIds;

  const PieceModel({
    required this.id,
    required this.teamId,
    required this.type,
    this.currentNodeId,
    this.carriedPieceIds = const [],
  });

  PieceModel copyWith({
    String? id,
    String? teamId,
    PieceType? type,
    int? currentNodeId,
    List<String>? carriedPieceIds,
    bool clearNode = false, // true로 설정하면 currentNodeId를 강제로 null로 만듦 (대기실 복귀)
  }) {
    return PieceModel(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      type: type ?? this.type,
      currentNodeId: clearNode ? null : (currentNodeId ?? this.currentNodeId),
      carriedPieceIds: carriedPieceIds ?? this.carriedPieceIds,
    );
  }

  @override
  String toString() {
    return 'Piece(id: $id, type: $type, node: $currentNodeId, carried: $carriedPieceIds)';
  }
}
