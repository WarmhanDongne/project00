import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/strategic_yutnori/models/yutnori_state.dart';
import 'package:project00/games/strategic_yutnori/models/piece_model.dart';
import 'package:project00/games/strategic_yutnori/models/board_node_model.dart';
import 'package:project00/games/strategic_yutnori/services/yutnori_command_service.dart';
import 'package:project00/games/strategic_yutnori/services/yutnori_query_service.dart';

void main() {
  group('전략 윷놀이 1단계 핵심 로직 테스트', () {
    late YutnoriState initialState;

    setUp(() {
      initialState = YutnoriState(
        phase: GamePhase.throwing,
        currentTurnTeamId: 'A',
        pieces: [
          const PieceModel(id: 'A1', teamId: 'A', type: PieceType.victory),
          const PieceModel(id: 'B1', teamId: 'B', type: PieceType.victory),
        ],
      );
    });

    test('대기실의 말은 백도를 사용할 수 없다 (이동 불가)', () {
      final state = YutnoriCommandService.throwYut(initialState, YutResult.backDo);
      final newState = YutnoriCommandService.movePiece(state, 'A1', YutResult.backDo);
      
      expect(newState.pieces[0].currentNodeId, isNull); // 변화 없음
    });

    test('대기실에서 "걸(3칸)"이 나오면 2번 노드로 이동해야 한다', () {
      // 0(시작점)부터 시작해서 걸(3)이면 0 -> 1 -> 2
      final state = YutnoriCommandService.throwYut(initialState, YutResult.geol);
      final newState = YutnoriCommandService.movePiece(state, 'A1', YutResult.geol);
      
      expect(newState.pieces[0].currentNodeId, 2);
    });

    test('상대 말을 잡았을 경우 대기실로 돌아가고 던지기 페이즈(추가 턴)가 되어야 한다', () {
      // B1을 미리 2번 노드에 배치
      var state = initialState.copyWith(
        pieces: [
          const PieceModel(id: 'A1', teamId: 'A', type: PieceType.victory, currentNodeId: null),
          const PieceModel(id: 'B1', teamId: 'B', type: PieceType.victory, currentNodeId: 2),
        ],
      );

      // A1이 걸(3)을 던져 2번 노드로 이동
      state = YutnoriCommandService.throwYut(state, YutResult.geol);
      final newState = YutnoriCommandService.movePiece(state, 'A1', YutResult.geol);
      
      // A1은 2번 칸에, B1은 잡혀서 대기실(null)로
      expect(newState.pieces[0].currentNodeId, 2);
      expect(newState.pieces[1].currentNodeId, isNull);
      
      // 잡았으므로 던지기 페이즈로 전환
      expect(newState.phase, GamePhase.throwing);
    });

    test('거꾸로 완주(역주행 완주) 특수 규칙 테스트', () {
      // A1을 0(출발선 바로 앞)에 배치, A2는 대기실에 배치 (총 2개의 승리말)
      var state = initialState.copyWith(
        pieces: [
          const PieceModel(id: 'A1', teamId: 'A', type: PieceType.victory, currentNodeId: 0),
          const PieceModel(id: 'A2', teamId: 'A', type: PieceType.victory, currentNodeId: null),
        ]
      );

      state = YutnoriCommandService.throwYut(state, YutResult.backDo);
      final newState = YutnoriCommandService.movePiece(state, 'A1', YutResult.backDo);
      
      // 백도로 0번 칸을 뒤로 넘어갔으므로 즉시 완주 처리 (99)
      expect(newState.pieces[0].currentNodeId, YutBoardMap.outNodeId);
      
      // 승리말 1개가 완주했으나, 테스트용 기본 승리조건(2개) 미달로 아직 finished는 아님.
      // 1개만 있어도 승리인지 확인하려면 승리 조건을 1개 완주로 체크
      expect(YutnoriQueryService.checkWinCondition(newState, 'A'), isFalse);
    });
  });
}
