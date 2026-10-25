import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:project00/platform/auth/models/google_sign_in_error_message.dart';

void main() {
  test('설정 오류는 안내 문구 끝에 원인 코드를 붙인다', () {
    final message = GoogleSignInErrorMessage.fromGoogle(
      GoogleSignInExceptionCode.clientConfigurationError,
    );

    expect(message, contains('설정'));
    expect(message, endsWith('(clientConfigurationError)'));
  });

  test('알 수 없는 구글 오류도 코드를 함께 보여 준다', () {
    final message = GoogleSignInErrorMessage.fromGoogle(
      GoogleSignInExceptionCode.unknownError,
    );

    expect(message, startsWith(GoogleSignInErrorMessage.generic));
    expect(message, endsWith('(unknownError)'));
  });

  test('Firebase 오류는 아는 코드만 따로 안내하고 나머지는 코드를 붙인다', () {
    expect(
      GoogleSignInErrorMessage.fromFirebase('network-request-failed'),
      contains('네트워크'),
    );
    expect(
      GoogleSignInErrorMessage.fromFirebase('invalid-credential'),
      endsWith('(invalid-credential)'),
    );
  });

  test('현재 언어를 따른다', () {
    final original = GameLocale.current;
    addTearDown(() => GameLocale.current = original);

    GameLocale.current = const Locale('en');
    expect(
      GoogleSignInErrorMessage.fromGoogle(
        GoogleSignInExceptionCode.interrupted,
      ),
      'Google sign-in was interrupted. Please try again.',
    );
  });
}
