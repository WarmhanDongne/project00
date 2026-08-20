import 'package:flutter/material.dart';
import 'package:project00/games/shared/game_flow/game_screen_phase.dart';
import 'package:project00/games/shared/game_flow/phone_game_flow_config.dart';
import 'package:project00/games/shared/game_flow/phone_game_shell.dart';

/// 휴대폰 진행 화면 뼈대입니다.
///
/// 화면 분기를 직접 짜지 말고 [PhoneGameShell]에 맡기세요. 셸이 진입 매트
/// 연출, `GAME START`/`ROUND N` 문구, 상단바 등장, **퇴장 접근 보장**, 결과·종료
/// 안내를 모두 처리합니다. 이 화면이 할 일은 두 가지뿐입니다.
///
/// 1. 서버 상태를 [GameScreenPhase]로 번역 (`_resolvePhase`)
/// 2. 자기 게임의 상단바·진행 화면·결과 위젯을 넘기기
///
/// 실제 게임에서는 Riverpod 세션 컨트롤러(`NotifierProvider.autoDispose.family`)를

class TemplatePhoneGame extends StatefulWidget {
  const TemplatePhoneGame({
    super.key,
    required this.roomCode,
    required this.onExitRoom,
  });

  final String roomCode;
  final Future<bool> Function() onExitRoom;

  @override
  State<TemplatePhoneGame> createState() => _TemplatePhoneGameState();
}

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
  // `shared/game_flow/phone_game_flow_config.dart`에서 확인할 수 있습니다.
  GameScreenPhase _resolvePhase() {
    if (_isLoading) return GameScreenPhase.connecting;
    if (_isClosing) return GameScreenPhase.closing;
    if (!_introDone) return GameScreenPhase.intro;
    if (_announcedRound != _round) return GameScreenPhase.roundIntro;
    if (_isFinished) return GameScreenPhase.result;
    return GameScreenPhase.playing;
  }

  @override
  Widget build(BuildContext context) {
    final flowConfig = buildPhoneGameFlowConfig(roundNumber: _round);
    return PhoneGameShell(
      phase: _resolvePhase(),
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
