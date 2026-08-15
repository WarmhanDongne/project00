import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../widgets/board_widget.dart';
import '../widgets/yut_control_panel.dart';
import '../providers/yutnori_provider.dart';
import '../models/yutnori_state.dart';

class YutnoriTestScreen extends ConsumerWidget {
  const YutnoriTestScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 게임 상태 구독
    final availableMoves = ref.watch(yutnoriProvider.select((state) => state.availableMoves));
    final currentTeamId = ref.watch(yutnoriProvider.select((state) => state.currentTurnTeamId));
    final currentPhase = ref.watch(yutnoriProvider.select((state) => state.phase));

    // 턴 표시용 변수
    final isTeamA = currentTeamId == 'A';
    final teamColor = isTeamA ? Colors.blue.shade600 : Colors.red.shade600;
    final teamName = isTeamA ? '팀 A (파란색)' : '팀 B (빨간색)';
    
    String phaseText;
    switch (currentPhase) {
      case GamePhase.throwing: phaseText = '윷 던지기 단계'; break;
      case GamePhase.moving: phaseText = '말 이동 단계'; break;
      case GamePhase.finished: phaseText = '게임 종료'; break;
      case GamePhase.setup: phaseText = '준비'; break;
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade200,
      appBar: AppBar(
        title: const Text('전략 윷놀이 - 2-3 말 이동 조작 및 턴 제어'),
        backgroundColor: Colors.blueGrey,
      ),
      body: Column(
        children: [
          // 0. 턴 표시기 UI
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
            color: teamColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${isTeamA ? '🟦' : '🟥'} $teamName 차례',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
                ),
                const SizedBox(width: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    phaseText,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),

          // 1. 상단 보드 영역 (가능한 최대 크기)
          const Expanded(
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: BoardWidget(),
              ),
            ),
          ),
          
          // 2. 던진 결과 표시 영역
          Container(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('사용 가능한 이동: ', style: TextStyle(fontWeight: FontWeight.bold)),
                if (availableMoves.isEmpty)
                  const Text('없음 (윷을 던지세요)', style: TextStyle(color: Colors.grey)),
                ...availableMoves.map((move) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4.0),
                    child: Chip(
                      label: Text(move.name.toUpperCase()),
                      backgroundColor: Colors.amber.shade200,
                    ),
                  );
                }),
              ],
            ),
          ),
          
          // 3. 하단 윷 컨트롤 패널
          const YutControlPanel(),
        ],
      ),
    );
  }
}
