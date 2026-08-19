import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/models/email_link_error_message.dart';
import 'package:project00/platform/auth/services/auth_service.dart';

void main() {
  test('이미 사용한 링크는 Firebase 원문 대신 새 링크 안내를 표시한다', () {
    const rawMessage = 'The action code is invalid.';
    final message = EmailLinkErrorMessage.from(
      const AuthServiceException('invalid-action-code', rawMessage),
    );

    expect(message, isNot(contains(rawMessage)));
    expect(message, contains('이미 사용'));
    expect(message, contains('재전송'));
  });

  test('만료된 링크는 새 링크 재전송을 안내한다', () {
    final message = EmailLinkErrorMessage.from(
      const AuthServiceException('expired-action-code', 'expired'),
    );

    expect(message, contains('만료'));
    expect(message, contains('재전송'));
  });
}
