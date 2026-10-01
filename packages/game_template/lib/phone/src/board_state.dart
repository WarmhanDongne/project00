// 세션 수명·구독 해제·재접속·타이머를 관리하는 내부 구현입니다.
// 화면 연출 설정은 ../phone_board.dart에서 수정합니다.
// board와 같은 Dart library의 part로 유지해 private 상태를 외부에 노출하지 않습니다.
//
// 서버 상태를 붙일 때는 shared/providers/session_provider.dart의 사용 예를
// 따라 이 클래스를 ConsumerState로 바꾸고, 아래 가짜 게터들을 컨트롤러 값으로
// 교체하세요(휴대폰은 watchPrivate: true).
part of '../phone_board.dart';

class _TemplatePhoneGameState extends State<TemplatePhoneGame> {
  bool _introDone = false;
  int _announcedRound = 0;

  int get _round => 1;
  bool get _isLoading => false;
  bool get _isFinished => false;
  bool get _isClosing => false;
  bool get _handReady => true;
  bool get _handRevealed => true;

  // ============================================================================
  // 서버 상태 → 공용 휴대폰 화면 단계
  // ============================================================================
  //
  // 새 게임의 기본 순서는 다음과 같습니다.
  // 연결 → GAME START → ROUND N → 플레이 → 결과 또는 비정상 종료
  //
  // 서버 문자열을 Widget 곳곳에서 비교하지 말고 이 함수 한곳에서만 번역합니다.
  // 각 단계의 문구·Duration·Animation·입력·Scrim 설정은
  // `../phone_board.dart`에서 확인할 수 있습니다.
  @override
  Widget build(BuildContext context) {
    final stage = resolveTemplatePhoneStage(
      isLoading: _isLoading,
      isClosing: _isClosing,
      introDone: _introDone,
      roundIntroDone: _announcedRound == _round,
      isFinished: _isFinished,
    );
    final flowConfig = buildTemplatePhoneFlowConfig(roundNumber: _round);
    return PhoneGameShell<TemplatePhoneStage>(
      stage: stage,
      stageRole: stage.shellRole,
      flowConfig: flowConfig,
      roundNumber: _round,
      background: const ColoredBox(color: Colors.black),
      contentReady: _handReady,
      contentRevealed: _handRevealed,
      onIntroCompleted: () => setState(() => _introDone = true),
      onRoundIntroCompleted: () => setState(() => _announcedRound = _round),

      // 셸이 표시 시점만 제어하므로, 여기서 상태에 따라 감추지 마세요.
      topBar: const SizedBox(height: 52),

      result: const SizedBox.shrink(),
      content: Center(
        child: Text(
          'TODO: 휴대폰 진행 화면 (${widget.roomCode})',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
