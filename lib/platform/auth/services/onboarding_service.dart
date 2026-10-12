import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:project00/platform/auth/legal/signup_terms.dart';
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

  Future<void> completeGuest(SignupConsents consents) async {
    try {
      await _callAuthenticated('completeGuestOnboarding', {
        'consents': consents.toJson(),
      });
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(
        error.code,
        '게스트 이용 준비를 완료하지 못했습니다. 다시 시도해주세요.',
      );
    }
  }

  Stream<UserOnboarding?> watch(String uid) async* {
    final reference = _firestore.collection('userOnboarding').doc(uid);
    const retryDelays = [
      Duration(milliseconds: 250),
      Duration(milliseconds: 500),
      Duration(seconds: 1),
    ];

    for (var attempt = 0; ; attempt++) {
      try {
        await for (final snapshot in reference.snapshots(
          includeMetadataChanges: true,
        )) {
          if (!snapshot.exists && snapshot.metadata.isFromCache) continue;
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

  /// 새 가입은 비밀번호 계정을 먼저 만듭니다. 인증 메일은 AuthGate의
  /// 대기 화면에서 서버 가입 준비가 끝난 뒤 보내므로 실패 시 재시도할 수 있습니다.
  Future<void> createPasswordAccount(String email, String password) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(error.code, switch (error.code) {
        'email-already-in-use' => '이미 가입된 이메일입니다. 로그인해주세요.',
        'weak-password' => '더 안전한 비밀번호를 입력해주세요.',
        'network-request-failed' => '네트워크 연결을 확인해주세요.',
        _ => '계정을 만들지 못했습니다. 잠시 후 다시 시도해주세요.',
      });
    }
  }

  Future<void> preparePasswordVerification() async {
    try {
      await _callAuthenticated('beginOnboarding', {
        'provider': 'legacyPassword',
      });
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(error.code, '가입 준비를 완료하지 못했습니다. 다시 시도해주세요.');
    }
  }

  Future<void> sendPasswordVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException('unauthenticated', '다시 로그인해주세요.');
    }
    try {
      // 기본 웹 인증 링크입니다. 앱 딥링크로 로그인하는 메일을 보내지 않습니다.
      await user.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(
        error.code,
        error.code == 'too-many-requests'
            ? '메일 요청이 많습니다. 잠시 후 다시 보내주세요.'
            : '인증 메일을 보내지 못했습니다. 연결을 확인하고 다시 시도해주세요.',
      );
    }
  }

  Future<bool> refreshEmailVerification() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException('unauthenticated', '다시 로그인해주세요.');
    }
    try {
      await user.reload();
      final refreshed = _auth.currentUser;
      if (refreshed == null || refreshed.uid != user.uid) {
        throw const AuthServiceException('unauthenticated', '로그인 상태가 변경되었습니다.');
      }
      if (!refreshed.emailVerified) return false;
      await refreshed.getIdToken(true);
      return true;
    } on FirebaseAuthException catch (error) {
      throw AuthServiceException(error.code, '인증 상태를 확인하지 못했습니다. 다시 시도해주세요.');
    }
  }

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

  /// 프로필을 저장하고 가입을 마칩니다.
  ///
  /// [consents]는 처음 가입을 마칠 때 서버가 요구하는 약관 동의입니다.
  /// 서버가 동의 시각과 약관 버전을 기록합니다.
  Future<void> completeProfile({
    required String nickname,
    String? profileImageUrl,
    SignupConsents? consents,
  }) async {
    try {
      await _callAuthenticated('completeOnboardingProfile', {
        'nickname': nickname,
        'profileImageUrl': profileImageUrl,
        if (consents != null) 'consents': consents.toJson(),
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
