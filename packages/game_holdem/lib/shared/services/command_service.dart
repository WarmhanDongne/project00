import 'package:game_kit/services/game_command_service.dart';

class HoldemCommandService extends GameCommandService {
  HoldemCommandService({super.functions, super.retryPolicy});

  Future<void> warmUpGameplayCommands() => warmUpCommands(const [
    'game_holdem_act',
    'game_holdem_complete_dealing',
    'game_holdem_timeout_turn',
  ]);

  Future<Map<String, dynamic>> startGame({
    required String roomCode,
    bool restart = false,
  }) => invoke('game_holdem_start_game', {
    'roomCode': roomCode,
    'restart': restart,
  });
  Future<Map<String, dynamic>> completeDealing({required String roomCode}) =>
      invoke('game_holdem_complete_dealing', {'roomCode': roomCode});
  Future<Map<String, dynamic>> act({
    required String roomCode,
    required String action,
    required int stateVersion,
    int? amount,
  }) {
    final payload = <String, dynamic>{
      'roomCode': roomCode,
      'commandId': commandId('act'),
      'action': action,
      'stateVersion': stateVersion,
    };
    if (amount != null) {
      payload['amount'] = amount;
    }
    return invoke('game_holdem_act', payload, retryTransientFailure: true);
  }

  Future<Map<String, dynamic>> timeoutTurn({required String roomCode}) =>
      invoke('game_holdem_timeout_turn', {'roomCode': roomCode});
  Future<Map<String, dynamic>> completeResult({required String roomCode}) =>
      invoke('game_holdem_complete_result', {'roomCode': roomCode});
  Future<Map<String, dynamic>> endGame({required String roomCode}) =>
      invoke('game_holdem_end_game', {'roomCode': roomCode});
}
