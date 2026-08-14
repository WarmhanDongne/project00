import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_node_model.dart';
import '../providers/yutnori_provider.dart';
import 'board_painter.dart';
import 'piece_widget.dart';

class BoardWidget extends ConsumerWidget {
  const BoardWidget({super.key});

  // 0.0 ~ 1.0 비율로 29개 노드의 좌표 정의
  static const Map<int, Offset> _nodeOffsets = {
    // 우측 모서리 라인 (아래 -> 위)
    0: Offset(1.0, 1.0), 1: Offset(1.0, 0.8), 2: Offset(1.0, 0.6), 3: Offset(1.0, 0.4), 4: Offset(1.0, 0.2),
    // 상단 모서리 라인 (우측 -> 좌측)
    5: Offset(1.0, 0.0), 6: Offset(0.8, 0.0), 7: Offset(0.6, 0.0), 8: Offset(0.4, 0.0), 9: Offset(0.2, 0.0),
    // 좌측 모서리 라인 (위 -> 아래)
    10: Offset(0.0, 0.0), 11: Offset(0.0, 0.2), 12: Offset(0.0, 0.4), 13: Offset(0.0, 0.6), 14: Offset(0.0, 0.8),
    // 하단 모서리 라인 (좌측 -> 우측)
    15: Offset(0.0, 1.0), 16: Offset(0.2, 1.0), 17: Offset(0.4, 1.0), 18: Offset(0.6, 1.0), 19: Offset(0.8, 1.0),
    
    // 대각선 1 (우측 상단 5번 -> 좌측 하단 15번)
    20: Offset(5/6, 1/6), 21: Offset(4/6, 2/6), 
    22: Offset(0.5, 0.5), // 정중앙 (방)
    23: Offset(2/6, 4/6), 24: Offset(1/6, 5/6),
    
    // 대각선 2 (좌측 상단 10번 -> 우측 하단 0번)
    25: Offset(1/6, 1/6), 26: Offset(2/6, 2/6), 
    // 22번은 공유됨
    27: Offset(4/6, 4/6), 28: Offset(5/6, 5/6),
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 게임 상태 구독
    final state = ref.watch(yutnoriProvider);
    
    return AspectRatio(
      aspectRatio: 1.0, // 윷판은 항상 정사각형
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = constraints.maxWidth;
          // 위젯이 위치할 때 중심점이 맞춰지도록 패딩/오프셋 계산용 반지름
          final nodeRadius = size * 0.035; 
          final pieceRadius = size * 0.05;

          return Padding(
            // 윷판 외곽선이 잘리지 않도록 화면 가장자리에 여백 확보
            padding: EdgeInsets.all(pieceRadius),
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. 바닥선 그리기 (CustomPaint)
                SizedBox.expand(
                  child: CustomPaint(
                    painter: BoardPainter(),
                  ),
                ),

                // 2. 29개의 노드(빈 칸) 그리기
                ...YutBoardMap.nodes.keys.map((id) {
                  final offset = _nodeOffsets[id]!;
                  final x = offset.dx * (size - pieceRadius * 2);
                  final y = offset.dy * (size - pieceRadius * 2);
                  
                  // 모서리(0, 5, 10, 15)와 중앙(22)은 크고 짙게 표현
                  final isMajorNode = [0, 5, 10, 15, 22].contains(id);

                  return Positioned(
                    left: x - nodeRadius,
                    top: y - nodeRadius,
                    child: Container(
                      width: nodeRadius * 2,
                      height: nodeRadius * 2,
                      decoration: BoxDecoration(
                        color: isMajorNode ? Colors.grey.shade800 : Colors.grey.shade300,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isMajorNode ? Colors.black : Colors.grey.shade500, 
                          width: 2.0
                        ),
                      ),
                    ),
                  );
                }),

                // 3. 윷판 위에 올라와 있는 말(Piece)들 그리기
                // 위치가 같은 말들을 묶어서(그룹핑) 배지(badge) 형태의 UI로 렌더링
                ..._buildPiecesOnBoard(state.pieces, size - pieceRadius * 2, pieceRadius),
              ],
            ),
          );
        },
      ),
    );
  }

  /// 윷판 위의 말들을 렌더링하고 위치가 겹치는 경우 badgeCount로 합쳐주는 헬퍼 메서드
  List<Widget> _buildPiecesOnBoard(List pieces, double boardSize, double pieceRadius) {
    // 윷판 위에 있는 말만 필터링 (currentNodeId != null && != 99)
    final activePieces = pieces.where((p) => p.currentNodeId != null && p.currentNodeId != YutBoardMap.outNodeId).toList();
    
    // 위치(currentNodeId)와 팀(teamId)을 기준으로 그룹핑
    final groupedPieces = <String, List>{};
    for (var piece in activePieces) {
      final key = '${piece.currentNodeId}_${piece.teamId}';
      if (!groupedPieces.containsKey(key)) groupedPieces[key] = [];
      groupedPieces[key]!.add(piece);
    }

    final widgets = <Widget>[];

    for (var group in groupedPieces.values) {
      final representativePiece = group.first; // 그룹의 대표 말 하나만 그림
      final badgeCount = group.length - 1; // 업힌 말의 개수
      
      final nodeId = representativePiece.currentNodeId!;
      final offset = _nodeOffsets[nodeId]!;
      
      final x = offset.dx * boardSize;
      final y = offset.dy * boardSize;

      // 만약 서로 다른 팀의 말이 같은 칸에 있다면? (규칙상 발생 불가, 잡기 처리됨)
      // 그래도 시각적으로 겹치지 않게 하기 위해 약간의 오프셋을 줄 수 있으나 현재는 무시

      widgets.add(
        Positioned(
          left: x - pieceRadius,
          top: y - pieceRadius,
          child: PieceWidget(
            piece: representativePiece,
            size: pieceRadius * 2,
            badgeCount: badgeCount, // 인터뷰에서 결정한 대로 '+N' 배지로 표시
          ),
        ),
      );
    }

    return widgets;
  }
}
