import 'package:game_kit/services/game_command_service.dart';

/// 게임 액션(쓰기)을 담당하는 Command 서비스 뼈대입니다.
///
/// [GameCommandService]를 상속하면 리전, `controllerCommandData` 첨부,
/// 재전송 정책, 응답 Map 변환, `commandId` 생성, 콜드스타트 예열을 그대로
/// 물려받습니다. 이 클래스에는 **이 게임의 명령만** 추가하세요.
///
/// 규칙 두 가지:
/// - 서버가 `commandId`로 멱등 처리하는 명령에만 `retryTransientFailure: true`.
///   commandId 없이 재전송하면 게임이 두 번 진행될 수 있습니다.
/// - callable 이름은 `functions/src/<game>/`와 정확히 같아야 합니다. 배포된
///   이름을 바꾸면 구버전 앱이 함수를 찾지 못합니다.
class TemplateCommandService extends GameCommandService {
  TemplateCommandService({super.functions, super.retryPolicy});

  /// 게임 진입 때 첫 조작 함수를 미리 깨웁니다. 없으면 지우세요.
  Future<void> warmUpGameplayCommands() =>
      warmUpCommands(const ['game_template_play']);

  Future<Map<String, dynamic>> startGame({required String roomCode}) {
    return invoke('game_template_start_game', {'roomCode': roomCode});
  }

  /// 멱등 명령의 표준 모양입니다. `commandId`를 payload에 담고 재전송을 켭니다.
  Future<Map<String, dynamic>> play({
    required String roomCode,
    required String choice,
  }) {
    return invoke('game_template_play', {
      'roomCode': roomCode,
      'commandId': commandId('play'),
      'choice': choice,
    }, retryTransientFailure: true);
  }
}
