import 'package:game_kit/games/shared/services/game_command_service.dart';

class LiarsPokerCommandService extends GameCommandService {
  LiarsPokerCommandService({super.functions, super.retryPolicy});

  /// 태블릿 딜링 중 첫 카드 제출과 라이어 함수의 콜드 스타트를 미리 끝냅니다.
  Future<void> warmUpGameplayCommands() => warmUpCommands(const [
    'game_liars_poker_submit_cards',
    'game_liars_poker_call_liar',
  ]);

  /// 카드가 제출된 직후 라이어 선언 함수가 바로 응답하도록 준비합니다.
  Future<void> warmUpLiarCommand() =>
      warmUpCommands(const ['game_liars_poker_call_liar']);

  // 게임 시작
  Future<Map<String, dynamic>> startGame({required String roomCode}) {
    return invoke('game_liars_poker_start_game', {'roomCode': roomCode});
  }

  // 방과 플레이어는 유지하고 게임만 처음부터 다시 시작
  Future<Map<String, dynamic>> restartGame({required String roomCode}) {
    return invoke('game_liars_poker_start_game', {
      'roomCode': roomCode,
      'restart': true,
    });
  }

  // 방은 유지하고 현재 게임만 종료
  Future<Map<String, dynamic>> endGame({required String roomCode}) {
    return invoke('game_liars_poker_end_game', {'roomCode': roomCode});
  }

  // 태블릿의 카드 배분 애니메이션 완료
  Future<Map<String, dynamic>> completeDealing({required String roomCode}) {
    return invoke('game_liars_poker_complete_dealing', {'roomCode': roomCode});
  }

  // 카드 제출
  Future<Map<String, dynamic>> submitCards({
    required String roomCode,
    required List<String> cardIds,
  }) {
    return invoke('game_liars_poker_submit_cards', {
      'roomCode': roomCode,
      'commandId': commandId('cards'),
      'cardIds': cardIds,
    }, retryTransientFailure: true);
  }

  // 라이어 선언
  Future<Map<String, dynamic>> callLiar({required String roomCode}) {
    return invoke('game_liars_poker_call_liar', {
      'roomCode': roomCode,
      'commandId': commandId('liar'),
    }, retryTransientFailure: true);
  }

  // 마감이 지난 턴을 태블릿(컨트롤러)이 강제로 해결합니다.
  //
  // 평소 타임아웃은 턴 플레이어 휴대폰이 처리하지만, 그 기기가 화면 잠금·
  // 백그라운드로 멈추면 아무도 턴을 넘기지 못합니다. 이 명령이 그 백스톱입니다.
  // 마감 전 호출은 서버가 {success: false, reason: notExpired}로 거절합니다.
  Future<Map<String, dynamic>> forceTimeout({required String roomCode}) {
    return invoke('game_liars_poker_force_timeout', {'roomCode': roomCode});
  }

  // 카드를 펼쳐 최초 턴 타이머 시작
  Future<Map<String, dynamic>> readyTurn({required String roomCode}) {
    return invoke('game_liars_poker_ready_turn', {
      'roomCode': roomCode,
      'commandId': commandId('ready'),
    }, retryTransientFailure: true);
  }

  // 마지막 카드 도전 포기(FOLD)
  //
  // 서버 함수는 `game_liars_poker_pass_challenge`입니다. 배포된 callable 이름을
  // 바꿀 때는 이 호출부를 같은 커밋에서 함께 고치고 함께 배포해야 구버전 앱이
  // 함수를 찾지 못하는 일을 막을 수 있습니다.
  Future<Map<String, dynamic>> foldLastCardChallenge({
    required String roomCode,
  }) {
    return invoke('game_liars_poker_pass_challenge', {
      'roomCode': roomCode,
      'commandId': commandId('fold'),
    }, retryTransientFailure: true);
  }

  // 서버가 결과를 먼저 추첨합니다. 같은 벌칙의 재호출은 서버가 보관한 결과를
  // 반환하므로 클라이언트가 원하는 값이 나올 때까지 다시 뽑을 수 없습니다.
  Future<Map<String, dynamic>> preparePenalty({required String roomCode}) {
    final resolutionId = commandId('roulette');
    return invoke('game_liars_poker_prepare_penalty', {
      'roomCode': roomCode,
      'commandId': resolutionId,
    }, retryTransientFailure: true);
  }

  // 서버 추첨값에 맞춘 룰렛 연출이 끝났음을 전달합니다.
  Future<Map<String, dynamic>> resolvePenalty({
    required String roomCode,
    required String resolutionId,
  }) {
    return invoke('game_liars_poker_resolve_penalty', {
      'roomCode': roomCode,
      'commandId': resolutionId,
      'resolutionId': resolutionId,
    }, retryTransientFailure: true);
  }
}
