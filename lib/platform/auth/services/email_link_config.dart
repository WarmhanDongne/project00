import 'package:firebase_auth/firebase_auth.dart';

class EmailLinkConfig {
  const EmailLinkConfig({
    required this.continueUrl,
    required this.androidPackageName,
    required this.iOSBundleId,
    this.linkDomain,
  });

  factory EmailLinkConfig.fromEnvironment() {
    const linkDomain = String.fromEnvironment('EMAIL_LINK_DOMAIN');
    return const EmailLinkConfig(
      continueUrl: String.fromEnvironment(
        'EMAIL_LINK_CONTINUE_URL',
        defaultValue:
            'https://project0000-ec01e.firebaseapp.com/auth/email-link',
      ),
      androidPackageName: String.fromEnvironment(
        'ANDROID_APPLICATION_ID',
        defaultValue: 'com.example.project00',
      ),
      // iOS는 유료 개발자 계정으로 옮기면서 실제 번들 ID로 바꿨습니다
      // (2026-08). Android는 아직 com.example.project00입니다.
      iOSBundleId: String.fromEnvironment(
        'IOS_BUNDLE_ID',
        defaultValue: 'com.warmhandong.msg',
      ),
      linkDomain: linkDomain == '' ? null : linkDomain,
    );
  }

  final String continueUrl;
  final String androidPackageName;
  final String iOSBundleId;
  final String? linkDomain;

  ActionCodeSettings toActionCodeSettings() => ActionCodeSettings(
    url: continueUrl,
    handleCodeInApp: true,
    androidPackageName: androidPackageName,
    androidInstallApp: true,
    iOSBundleId: iOSBundleId,
    linkDomain: linkDomain,
  );
}
