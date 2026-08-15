import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/board_node_model.dart';
import '../models/piece_model.dart';
import '../models/yutnori_state.dart';
import '../providers/yutnori_provider.dart';
import '../services/yutnori_query_service.dart';
import 'board_painter.dart';
import 'piece_widget.dart';

class BoardWidget extends ConsumerStatefulWidget {
  const BoardWidget({super.key});

  @override
  ConsumerState<BoardWidget> createState() => _BoardWidgetState();
}

class _BoardWidgetState extends ConsumerState<BoardWidget> {
  // 현재 선택된 말의 ID
  String? _selectedPieceId;

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
    
    // 완주(OUT) 가상 노드 (시작점 0번의 우측 바깥쪽)
    YutBoardMap.outNodeId: Offset(1.15, 1.0),
  };

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(yutnoriProvider);
    final currentTeamId = state.currentTurnTeamId;
    
    // 선택된 말이 현재 갈 수 있는 도착지 계산
    Map<int, YutResult> highlightedNodes = {};
    if (_selectedPieceId != null && state.availableMoves.isNotEmpty) {
      final pieceIndex = state.pieces.indexWhere((p) => p.id == _selectedPieceId);
      if (pieceIndex != -1) {
        final piece = state.pieces[pieceIndex];
        // 내 팀의 말일 경우에만 하이라이트 계산
        if (piece.teamId == currentTeamId) {
          for (var result in state.availableMoves) {
            final destNodeIds = YutnoriQueryService.getDestinationNodeIds(piece, result);
            for (var destNodeId in destNodeIds) {
              highlightedNodes[destNodeId] = result;
            }
          }
        }
      }
    }

    return AspectRatio(
      aspectRatio: 1.15, // 가로 여백을 주어 OUT 노드 터치(hit test)가 가능하도록 함
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width = constraints.maxWidth;
          final size = constraints.maxHeight; // 윷판은 정사각형을 유지하므로 height 기준
          final nodeRadius = size * 0.035; 
          final pieceRadius = size * 0.05;
          final boardSize = size - pieceRadius * 4; // 상하좌우 여백(pieceRadius*2)을 뺀 실제 보드 크기

          final paddingOffset = pieceRadius * 2;

          return SizedBox(
            width: width,
            height: size,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                // 1. 바닥선 그리기
                Positioned(
                  left: paddingOffset,
                  top: paddingOffset,
                  width: boardSize,
                  height: boardSize,
                  child: CustomPaint(painter: BoardPainter()),
                ),

                // 2. 모든 노드(빈 칸 + OUT 노드) + 하이라이트 렌더링
                ...(YutBoardMap.nodes.keys.toList()..add(YutBoardMap.outNodeId)).map((id) {
                  final offset = _nodeOffsets[id]!;
                  final x = paddingOffset + offset.dx * boardSize;
                  final y = paddingOffset + offset.dy * boardSize;
                  
                  final isMajorNode = [0, 5, 10, 15, 22].contains(id);
                  final isOutNode = id == YutBoardMap.outNodeId;
                  final isHighlighted = highlightedNodes.containsKey(id);
                  
                  // OUT 노드는 크기를 3배로
                  final currentRadius = isOutNode ? nodeRadius * 2.5 : nodeRadius;

                  return Positioned(
                    left: x - currentRadius,
                    top: y - currentRadius,
                    child: GestureDetector(
                      onTap: () {
                        // 하이라이트된 칸을 누르면 이동 처리 (다중 도착지 중 선택한 곳 전달)
                        if (isHighlighted && _selectedPieceId != null) {
                          ref.read(yutnoriProvider.notifier).movePiece(_selectedPieceId!, highlightedNodes[id]!, id);
                          setState(() { _selectedPieceId = null; });
                        }
                      },
                      child: Container(
                        width: currentRadius * 2,
                        height: currentRadius * 2,
                        decoration: BoxDecoration(
                          color: isHighlighted 
                              ? Colors.amber.shade300 
                              : (isOutNode ? Colors.transparent : (isMajorNode ? Colors.grey.shade800 : Colors.grey.shade300)),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: isHighlighted ? Colors.redAccent : (isOutNode ? Colors.grey.shade400 : (isMajorNode ? Colors.black : Colors.grey.shade500)), 
                            width: isHighlighted ? 3.0 : 2.0
                          ),
                          boxShadow: isHighlighted 
                              ? [const BoxShadow(color: Colors.amber, blurRadius: 10, spreadRadius: 2)] 
                              : null,
                        ),
                        child: isHighlighted || isOutNode
                            ? Center(
                                child: Text(
                                  isOutNode ? 'OUT' : _getYutName(highlightedNodes[id]!),
                                  style: TextStyle(
                                    fontWeight: FontWeight.w900, 
                                    fontSize: isOutNode ? 14 : 11, 
                                    color: isOutNode && !isHighlighted ? Colors.grey.shade600 : Colors.black
                                  ),
                                ),
                              )
                            : null,
                      ),
                    ),
                  );
                }),

                // 3. 윷판 위에 올라와 있는 말들 렌더링
                ..._buildPiecesOnBoard(state.pieces, boardSize, pieceRadius, paddingOffset, currentTeamId, highlightedNodes),

                // 4. 대기실 영역 렌더링 (보드 바깥 모서리)
                ..._buildWaitingRoom(state.pieces, boardSize, pieceRadius, paddingOffset, currentTeamId, 'A'),
                ..._buildWaitingRoom(state.pieces, boardSize, pieceRadius, paddingOffset, currentTeamId, 'B'),
              ],
            ),
          );
        },
      ),
    );
  }

  String _getYutName(YutResult result) {
    switch (result) {
      case YutResult.backDo: return '도';
      case YutResult.gae: return '개';
      case YutResult.geol: return '걸';
      case YutResult.yut: return '윷';
      case YutResult.mo: return '모';
    }
  }

  List<Widget> _buildPiecesOnBoard(List<PieceModel> pieces, double boardSize, double pieceRadius, double paddingOffset, String currentTeamId, Map<int, YutResult> highlightedNodes) {
    final activePieces = pieces.where((p) => p.currentNodeId != null && p.currentNodeId != YutBoardMap.outNodeId).toList();
    final groupedPieces = <String, List<PieceModel>>{};
    
    for (var piece in activePieces) {
      final key = '${piece.currentNodeId}_${piece.teamId}';
      if (!groupedPieces.containsKey(key)) groupedPieces[key] = [];
      groupedPieces[key]!.add(piece);
    }

    final widgets = <Widget>[];

    for (var group in groupedPieces.values) {
      final representativePiece = group.first; 
      final badgeCount = group.length - 1; 
      
      final nodeId = representativePiece.currentNodeId!;
      final offset = _nodeOffsets[nodeId]!;
      
      final x = paddingOffset + offset.dx * boardSize;
      final y = paddingOffset + offset.dy * boardSize;

      final isSelected = _selectedPieceId == representativePiece.id;
      final isSelectable = representativePiece.teamId == currentTeamId;
      final isHighlightedNode = highlightedNodes.containsKey(nodeId);

      widgets.add(
        Positioned(
          left: x - pieceRadius,
          top: y - pieceRadius,
          child: GestureDetector(
            onTap: () {
              if (isHighlightedNode && _selectedPieceId != null) {
                // 말이 있는 칸이 하이라이트된 목적지라면, 말 선택 대신 이동 처리 수행 (잡기/업기)
                ref.read(yutnoriProvider.notifier).movePiece(_selectedPieceId!, highlightedNodes[nodeId]!, nodeId);
                setState(() { _selectedPieceId = null; });
              } else if (isSelectable) {
                // 내 턴의 내 말이라면 평범하게 선택/해제 처리
                setState(() {
                  _selectedPieceId = isSelected ? null : representativePiece.id;
                });
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.amberAccent, blurRadius: 12, spreadRadius: 6)],
                      ),
                    ),
                  ),
                PieceWidget(
                  piece: representativePiece,
                  size: pieceRadius * 2,
                  badgeCount: badgeCount,
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }

  /// 대기실의 말들을 보드 바깥에 그립니다.
  List<Widget> _buildWaitingRoom(List<PieceModel> pieces, double boardSize, double pieceRadius, double paddingOffset, String currentTeamId, String targetTeamId) {
    // 대기실에 있는 해당 팀의 말들
    final waitingPieces = pieces.where((p) => p.teamId == targetTeamId && p.currentNodeId == null).toList();
    if (waitingPieces.isEmpty) return [];

    // 팀 A는 좌측 하단 바깥쪽, 팀 B는 우측 상단 바깥쪽으로 배치
    final isTeamA = targetTeamId == 'A';
    final baseX = paddingOffset + (isTeamA ? -pieceRadius * 1.5 : boardSize + pieceRadius * 0.5);
    final baseY = paddingOffset + (isTeamA ? boardSize + pieceRadius * 1.5 : -pieceRadius * 1.5);

    final widgets = <Widget>[];
    
    // 승리말과 지원말을 시각적으로 구분해서 가로로 나열
    for (int i = 0; i < waitingPieces.length; i++) {
      final piece = waitingPieces[i];
      final isSelected = _selectedPieceId == piece.id;
      final isSelectable = piece.teamId == currentTeamId;

      widgets.add(
        Positioned(
          left: baseX + (i * pieceRadius * 1.5), // 가로로 조금씩 띄워서 배치
          top: baseY,
          child: GestureDetector(
            onTap: () {
              if (isSelectable) {
                setState(() {
                  _selectedPieceId = isSelected ? null : piece.id;
                });
              }
            },
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                if (isSelected)
                  Positioned.fill(
                    child: Container(
                      decoration: const BoxDecoration(
                        color: Colors.transparent,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.amberAccent, blurRadius: 12, spreadRadius: 6)],
                      ),
                    ),
                  ),
                PieceWidget(
                  piece: piece,
                  size: pieceRadius * 1.5, // 대기실 말은 약간 작게
                ),
              ],
            ),
          ),
        ),
      );
    }

    return widgets;
  }
}
