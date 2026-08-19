import 'package:project00/platform/auth/services/auth_service.dart';

abstract final class EmailLinkErrorMessage {
  static String from(AuthServiceException error) => switch (error.code) {
    'invalid-email' => '이메일 형식이 올바르지 않습니다.',
    'invalid-action-code' =>
      '이미 사용했거나 유효하지 않은 인증 링크입니다. '
          '아래 재전송 버튼으로 새 링크를 받아주세요.',
    'expired-action-code' =>
      '인증 링크가 만료되었습니다. '
          '아래 재전송 버튼으로 새 링크를 받아주세요.',
    'too-many-requests' =>
      '요청이 너무 많습니다. 잠시 후 인증 메일을 다시 요청해 주세요.',
    'network-request-failed' => '네트워크 연결을 확인해주세요.',
    _ => error.message,
  };
}
