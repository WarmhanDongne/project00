import 'package:cloud_functions/cloud_functions.dart';

/// 게임 액션(쓰기)을 담당하는 Command 서비스 뼈대입니다.
///
/// `LiarsPokerCommandService`/`FinalCallCommandService`처럼 Cloud Function을
/// `httpsCallable`로 호출하는 메서드를 여기에 추가하세요.
class TemplateCommandService {
  TemplateCommandService({FirebaseFunctions? functions})
    : _functions =
          functions ?? FirebaseFunctions.instanceFor(region: 'asia-northeast3');

  final FirebaseFunctions _functions;

  Future<Map<String, dynamic>> startGame({required String roomCode}) {
    return _call('startTemplateGame', {'roomCode': roomCode});
  }

  Future<Map<String, dynamic>> _call(
    String functionName,
    Map<String, dynamic> data,
  ) async {
    final result = await _functions.httpsCallable(functionName).call(data);
    if (result.data is! Map) return const {};
    return Map<String, dynamic>.from(result.data as Map);
  }
}
