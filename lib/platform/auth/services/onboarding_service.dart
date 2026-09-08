import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project00/platform/auth/models/onboarding_state.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/services/email_link_config.dart';

class OnboardingService {
  OnboardingService({
    FirebaseAuth? auth,
    FirebaseFirestore? firestore,
    FirebaseFunctions? functions,
    EmailLinkConfig? emailLinkConfig,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _firestore = firestore ?? FirebaseFirestore.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
       _emailLinkConfig = emailLinkConfig ?? EmailLinkConfig.fromEnvironment();

  final FirebaseAuth _auth;
  final FirebaseFirestore _firestore;
  final FirebaseFunctions _functions;
  final EmailLinkConfig _emailLinkConfig;

  Stream<UserOnboarding?> watch(String uid) async* {
    final reference = _firestore.collection('userOnboarding').doc(uid);
    const retryDelays = [
      Duration(milliseconds: 250),
      Duration(milliseconds: 500),
      Duration(seconds: 1),
    ];

    for (var attempt = 0; ; attempt++) {
      try {
        await for (final snapshot in reference.snapshots()) {
          yield UserOnboarding.fromSnapshot(snapshot);
        }
        return;
      } on FirebaseException catch (error) {
        final retryable =
            error.code == 'permission-denied' || error.code == 'unavailable';
        if (!retryable || attempt >= retryDelays.length) rethrow;
        await Future<void>.delayed(retryDelays[attempt]);
      }
    }
  }

  bool isEmailSignInLink(String link) => _auth.isSignInWithEmailLink(link);

  Future<void> sendEmailLink(String email) async {
    try {
      await _auth.sendSignInLinkToEmail(
        email: email,
        actionCodeSettings: _emailLinkConfig.toActionCodeSettings(),
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(
        error.code,
        error.message ?? '인증 메일을 보내지 못했습니다.',
      );
    }
  }

  Future<void> completeEmailLink({
    required String email,
    required String link,
  }) async {
    try {
      if (!_auth.isSignInWithEmailLink(link)) {
        throw const AuthServiceException(
          'invalid-action-code',
          '유효한 이메일 인증 링크가 아닙니다.',
        );
      }
      await _auth.signInWithEmailLink(email: email, emailLink: link);
      await _callAuthenticated('beginOnboarding');
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(
        error.code,
        error.message ?? '이메일 인증을 완료하지 못했습니다.',
      );
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(
        error.code,
        error.message ?? '회원가입을 시작하지 못했습니다.',
      );
    }
  }

  Future<void> setPasswordAndAdvance(String password) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException('unauthenticated', '로그인이 필요합니다.');
    }
    try {
      await user.updatePassword(password);
      await _callAuthenticated('advanceOnboarding');
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(
        error.code,
        error.message ?? '비밀번호를 설정하지 못했습니다.',
      );
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(
        error.code,
        error.message ?? '회원가입 단계를 진행하지 못했습니다.',
      );
    }
  }

  Future<OnboardingStatus> recoverLegacy() async {
    try {
      final result = await _callAuthenticated<Map<String, dynamic>>(
        'recoverLegacyOnboarding',
      );
      return OnboardingStatus.values.firstWhere(
        (item) => item.name == result.data['status'],
      );
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(
        error.code,
        error.message ?? '계정 진행 상태를 복구하지 못했습니다.',
      );
    }
  }

  Future<void> completeProfile({
    required String nickname,
    String? profileImageUrl,
  }) async {
    try {
      await _callAuthenticated('completeOnboardingProfile', {
        'nickname': nickname,
        'profileImageUrl': profileImageUrl,
      });
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(
        error.code,
        error.message ?? '프로필을 저장하지 못했습니다.',
      );
    }
  }

  Future<HttpsCallableResult<T>> _callAuthenticated<T>(
    String name, [
    Map<String, dynamic>? data,
  ]) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException('unauthenticated', '로그인이 필요합니다.');
    }

    for (var attempt = 0; ; attempt++) {
      try {
        if (attempt > 0) await user.getIdToken(true);
        return await _functions.httpsCallable(name).call<T>(data);
      } on FirebaseFunctionsException catch (error) {
        if (error.code != 'unauthenticated' || attempt > 0) rethrow;
      }
    }
  }
}
