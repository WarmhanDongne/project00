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
      iOSBundleId: String.fromEnvironment(
        'IOS_BUNDLE_ID',
        defaultValue: 'com.example.project00',
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
