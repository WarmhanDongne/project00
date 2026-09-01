import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/auth/services/apple_auth_utils.dart';

void main() {
  test('Apple provider 연결 여부를 provider ID로 판정한다', () {
    expect(hasAppleProvider(const ['password', 'apple.com']), isTrue);
    expect(hasAppleProvider(const ['password', 'google.com']), isFalse);
  });

  test('Apple nonce는 요청 길이와 허용 문자만 사용한다', () {
    final nonce = generateAppleNonce(64);
    expect(nonce, hasLength(64));
    expect(nonce, matches(RegExp(r'^[A-Za-z0-9._-]+$')));
  });

  test('Apple nonce SHA-256은 알려진 값과 일치한다', () {
    expect(
      sha256AppleNonce('mosigame'),
      '2d1c3c9b2b63380e224a2019d55ca0acc7b3fdbc54825bcd9383fece0e9add14',
    );
  });
}
