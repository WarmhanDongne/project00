import 'package:cloud_functions/cloud_functions.dart';
import 'package:mosigame_core/core/diagnostics/dev_error_log.dart';
import 'package:mosigame_core/core/error/user_error_message.dart';
import 'package:mosigame_platform/platform/home/room/services/room_common.dart';

/// 방 명령의 예외 분류와 사용자 문구 변환을 담당합니다.
///
/// [RoomProvider]는 방 상태와 구독만 소유하고, Firebase/도메인 예외를 화면 문구로
/// 바꾸는 책임은 이 실행기로 분리합니다.
class RoomCommandExecutor {
  const RoomCommandExecutor();

  Future<RoomCommandOutcome<T>> run<T>(Future<T> Function() command) async {
    try {
      return RoomCommandOutcome.success(await command());
    } on RoomCommandException catch (error) {
      return RoomCommandOutcome.failure(error.message);
    } on FirebaseFunctionsException catch (error) {
      return RoomCommandOutcome.failure(error.message ?? '서버 요청을 처리하지 못했습니다.');
    } catch (error) {
      DevErrorLog.instance.add(
        error: error,
        context: 'room/command',
        time: DateTime.now(),
      );
      return RoomCommandOutcome.failure(
        userErrorMessage(error, context: UserErrorContext.roomCommand) ??
            UserErrorCopy.requestFailed,
      );
    }
  }
}

class RoomCommandOutcome<T> {
  const RoomCommandOutcome._({this.value, this.errorMessage});

  const RoomCommandOutcome.success(T value) : this._(value: value);

  const RoomCommandOutcome.failure(String message)
    : this._(errorMessage: message);

  final T? value;
  final String? errorMessage;
  bool get succeeded => errorMessage == null;
}
