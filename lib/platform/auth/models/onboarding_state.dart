import 'package:cloud_firestore/cloud_firestore.dart';

enum OnboardingStatus { settingPassword, settingProfile, complete }

/// 회원가입을 시작한 경로입니다.
///
/// ⚠️ **서버 `ONBOARDING_PROVIDERS`와 이름이 같아야 합니다**
/// (`functions/src/auth/onboarding-types.ts`). 여기 없는 값이 문서에 있으면
/// [UserOnboarding.fromSnapshot]이 null을 돌려주고, 게이트는 복구 화면과
/// 스피너를 오가며 멈춥니다. 실제로 `apple`이 빠져 애플 로그인 뒤 앱이 무한
/// 로딩에 갇혔습니다(2026-08-22). `auth/onboarding_parity_test.dart`가 두 목록을
/// 대조합니다.
enum OnboardingProvider { emailLink, google, apple, legacyPassword }

class UserOnboarding {
  const UserOnboarding({
    required this.uid,
    required this.status,
    required this.provider,
  });

  final String uid;
  final OnboardingStatus status;
  final OnboardingProvider provider;

  static UserOnboarding? fromSnapshot(
    DocumentSnapshot<Map<String, dynamic>> snapshot,
  ) {
    final data = snapshot.data();
    if (!snapshot.exists || data == null) return null;
    final status = OnboardingStatus.values
        .where((item) => item.name == data['status'])
        .firstOrNull;
    final provider = OnboardingProvider.values
        .where((item) => item.name == data['provider'])
        .firstOrNull;
    if (status == null || provider == null) return null;
    return UserOnboarding(uid: snapshot.id, status: status, provider: provider);
  }
}
