import 'package:game_kit/localization/game_locale.dart';
import 'package:google_sign_in/google_sign_in.dart';

/// 구글 로그인 실패를 사용자에게 보여 줄 문구로 바꿉니다.
///
/// 사용자가 직접 취소한 경우([GoogleSignInExceptionCode.canceled])는
/// 오류가 아니므로 여기서 다루지 않고 호출한 쪽에서 조용히 넘깁니다.
/// 설정 오류처럼 원인을 알아야 하는 경우에는 문구 끝에 코드를 붙여
/// 테스트하는 사람이 원인을 바로 전달할 수 있게 합니다.
abstract final class GoogleSignInErrorMessage {
  static String fromGoogle(GoogleSignInExceptionCode code) => switch (code) {
    GoogleSignInExceptionCode.clientConfigurationError ||
    GoogleSignInExceptionCode.providerConfigurationError => _withCode(
      GameLocale.select(
        ko: '구글 로그인 설정에 문제가 있어 로그인하지 못했습니다. 다른 방법으로 로그인하거나 잠시 후 다시 시도해 주세요.',
        en: 'Google sign-in is not set up correctly. Try another sign-in method or try again later.',
        zhHans: 'Google 登录设置有问题，无法登录。请使用其他方式登录或稍后重试。',
        zhHant: 'Google 登入設定有問題，無法登入。請使用其他方式登入或稍後再試。',
      ),
      code.name,
    ),
    GoogleSignInExceptionCode.interrupted => GameLocale.select(
      ko: '구글 로그인이 중간에 끊겼습니다. 다시 시도해 주세요.',
      en: 'Google sign-in was interrupted. Please try again.',
      zhHans: 'Google 登录中断，请重试。',
      zhHant: 'Google 登入中斷，請再試一次。',
    ),
    GoogleSignInExceptionCode.uiUnavailable => GameLocale.select(
      ko: '구글 로그인 창을 열지 못했습니다. 앱을 다시 열고 시도해 주세요.',
      en: 'Could not open Google sign-in. Reopen the app and try again.',
      zhHans: '无法打开 Google 登录窗口，请重新打开应用后再试。',
      zhHant: '無法開啟 Google 登入視窗，請重新開啟 App 後再試。',
    ),
    _ => _withCode(_generic, code.name),
  };

  static String fromFirebase(String code) => switch (code) {
    'network-request-failed' => GameLocale.select(
      ko: '네트워크 연결을 확인한 뒤 다시 시도해 주세요.',
      en: 'Check your network connection and try again.',
      zhHans: '请检查网络连接后重试。',
      zhHant: '請檢查網路連線後再試。',
    ),
    'user-disabled' => GameLocale.select(
      ko: '사용이 중지된 계정입니다. 문의처로 연락해 주세요.',
      en: 'This account has been disabled. Please contact support.',
      zhHans: '此账号已被停用，请联系客服。',
      zhHant: '此帳號已停用，請聯絡客服。',
    ),
    'account-exists-with-different-credential' => GameLocale.select(
      ko: '이 이메일은 다른 로그인 방법으로 가입되어 있습니다. 처음 가입한 방법으로 로그인해 주세요.',
      en: 'This email is registered with another sign-in method. Please use the method you signed up with.',
      zhHans: '此邮箱已通过其他登录方式注册，请使用注册时的方式登录。',
      zhHant: '此電子郵件已透過其他登入方式註冊，請使用註冊時的方式登入。',
    ),
    _ => _withCode(_generic, code),
  };

  static String get generic => _generic;

  static String get _generic => GameLocale.select(
    ko: '구글 로그인을 완료하지 못했습니다. 잠시 후 다시 시도해 주세요.',
    en: 'Google sign-in could not be completed. Please try again later.',
    zhHans: '无法完成 Google 登录，请稍后重试。',
    zhHant: '無法完成 Google 登入，請稍後再試。',
  );

  static String _withCode(String message, String code) => '$message ($code)';
}
