/// 사용자에게 보여 줄 오류와 내부 예외 변환을 모은 공개 진입점입니다.
///
/// 연결 복구와 재시도는 `recovery/`에서 담당하고, 이 폴더는 오류의 형태와 문구,
/// 오류 전용 화면만 담당합니다.
library;

export 'models/app_exception.dart';
export 'models/room_command_exception.dart';
export 'services/user_error_message.dart';
export 'widgets/leave_failure_notice.dart';
