import 'package:cloud_firestore/cloud_firestore.dart';

enum OnboardingStatus { settingPassword, settingProfile, complete }

enum OnboardingProvider { emailLink, google, legacyPassword }

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
