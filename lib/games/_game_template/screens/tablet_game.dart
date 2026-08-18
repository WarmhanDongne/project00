import 'package:flutter/material.dart';
import 'package:project00/games/_game_template/screens/tablet/tablet_game_stage.dart';
import 'package:project00/games/_game_template/template_flow_config.dart';
import 'package:project00/games/shared/player_layouts/player_layout_model.dart';
import 'package:project00/games/shared/widgets/game_announcement_layer.dart';

/// 태블릿 진행 화면 뼈대입니다.
///
/// 화면이 여러 형제 위젯 파일로 쪼개질 만큼 복잡해지면(라이어스포커 사례),
/// `lib/games/template_game.dart`의 문서 주석에 적힌 기준에 따라 이 화면 전용
/// 오케스트레이션 Provider를 별도로 추가하세요. 그 전까지는 파이널콜처럼
/// 이 위젯의 로컬 상태(`StatefulWidget`)만으로 충분합니다.
class TemplateTabletGame extends StatelessWidget {
  const TemplateTabletGame({
    super.key,
    required this.playerLayout,
    required this.roomCode,
  });

  final PlayerLayoutModel playerLayout;
  final String roomCode;

  // TODO: 실제 세션 Controller의 불변 상태 접근자로 교체하세요.
  bool get _isLoading => false;
  bool get _isFinished => false;
  bool get _isClosing => false;
  String get _serverPhase => 'playing';
  int get _round => 1;

  // ============================================================================
  // 서버 상태 → 태블릿 화면 단계
  // ============================================================================
  // 서버 status/phase 문자열은 이 함수에서만 해석합니다. 하위 레이어는 반드시
  // TemplateTabletStage를 exhaustive switch로 처리해야 합니다.
  TemplateTabletStage _resolveStage() {
    if (_isLoading) return TemplateTabletStage.connecting;
    if (_isClosing) return TemplateTabletStage.closing;
    if (_isFinished) return TemplateTabletStage.result;
    return switch (_serverPhase) {
      'dealing' => TemplateTabletStage.dealing,
      'roundResult' => TemplateTabletStage.roundResult,
      'penalty' => TemplateTabletStage.penalty,
      _ => TemplateTabletStage.playing,
    };
  }

  @override
  Widget build(BuildContext context) {
    final stage = _resolveStage();
    final flowConfig = buildTemplateTabletFlowConfig(roundNumber: _round);
    final flowStep = flowConfig.stepFor(stage);
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const ColoredBox(color: Colors.black),
          if (flowStep.showScreen)
            switch (stage) {
              TemplateTabletStage.connecting ||
              TemplateTabletStage.closing => const SizedBox.shrink(),
              TemplateTabletStage.dealing => const Center(
                child: Text('TODO: CardDealAnimation'),
              ),
              TemplateTabletStage.playing => Center(
                child: Text(
                  'TODO: 게임 진행 ($roomCode, ${playerLayout.playerCount}명)',
                  style: const TextStyle(color: Colors.white),
                ),
              ),
              TemplateTabletStage.roundResult => const Center(
                child: Text('TODO: 라운드 판정 화면'),
              ),
              TemplateTabletStage.penalty => const Center(
                child: Text('TODO: 벌칙 화면'),
              ),
              TemplateTabletStage.result => const Center(
                child: Text('TODO: 최종 결과 화면'),
              ),
            },
          Positioned.fill(
            child: GameAnnouncementLayer(
              announcement: flowStep.buildAnnouncement(),
              style: const GameAnnouncementStyle.tablet(),
            ),
          ),
        ],
      ),
    );
  }
}
