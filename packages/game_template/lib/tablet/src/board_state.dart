// 서버 상태 → 태블릿 단계 번역과 화면 조립을 맡는 내부 구현입니다.
// 단계별 연출 설정은 ../tablet_board.dart에서 수정합니다.
// board와 같은 Dart library의 part로 유지해 private 상태를 외부에 노출하지 않습니다.
//
// 서버 상태를 붙일 때는 shared/providers/session_provider.dart의 사용 예를
// 따라 이 클래스를 ConsumerState로 바꾸고, 아래 가짜 게터들을 컨트롤러 값으로
// 교체하세요(태블릿은 watchPrivate: false).
part of '../tablet_board.dart';

class _TemplateTabletGameState extends State<TemplateTabletGame> {
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
                  'TODO: 게임 진행 (${widget.roomCode}, ${widget.playerLayout.playerCount}명)',
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
