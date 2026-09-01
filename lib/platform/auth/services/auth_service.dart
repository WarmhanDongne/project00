import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:project00/platform/auth/services/apple_auth_utils.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthServiceException implements Exception {
  const AuthServiceException(this.code, this.message);

  final String code;
  final String message;
}

class FirebaseAuthService {
  FirebaseAuthService({
    FirebaseAuth? auth,
    FirebaseFunctions? functions,
    FirebaseStorage? storage,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
       _storage = storage ?? FirebaseStorage.instance;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  //이메일 중복확인
  Future<bool> isEmailDuplicate(String email) async {
    try {
      final callable = _functions.httpsCallable('checkEmailDuplicate');
      final result = await callable.call<Map<String, dynamic>>({
        'email': email,
      });
      return result.data['isDuplicate'] == true;
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(
        error.code,
        error.message ?? '이메일 중복확인에 실패했습니다.',
      );
    }
  }

  //회원가입
  Future<void> createEmailAccount({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (error) {
      throw _toServiceException(error);
    }
  }

  //인증 메일 발송
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (error) {
      throw _toServiceException(error);
    }
  }

  //로그인
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    try {
      await _auth.signInWithEmailAndPassword(email: email, password: password);
    } on FirebaseAuthException catch (error) {
      throw _toServiceException(error);
    }
  }

  Future<void> updateDisplayName(String displayName) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException('user-not-found', '로그인된 사용자가 없습니다.');
    }
    try {
      await user.updateDisplayName(displayName);
    } on FirebaseAuthException catch (error) {
      throw _toServiceException(error);
    }
  }

  //프로필사진 업로드
  Future<String> uploadProfileImage({
    required Uint8List imageBytes,
    required String fileName,
    String? contentType,
  }) async {
    //현재 로그인되어있는 유저
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException('user-not-found', '로그인된 사용자가 없습니다.');
    }

    final extension = fileName.contains('.')
        ? fileName.split('.').last.toLowerCase()
        : 'jpg';
    final safeExtension = RegExp(r'^[a-z0-9]+$').hasMatch(extension)
        ? extension
        : 'jpg';
    //업로드 위치
    final reference = _storage.ref('users/${user.uid}/profile.$safeExtension');

    try {
      for (var attempt = 0; ; attempt++) {
        try {
          if (attempt > 0) await user.getIdToken(true);
          await reference.putData(
            imageBytes,
            SettableMetadata(contentType: contentType ?? 'image/jpeg'),
          );
          final downloadUrl = await reference.getDownloadURL();
          await user.updatePhotoURL(downloadUrl);
          return downloadUrl;
        } on FirebaseException catch (error) {
          if (error.code != 'unauthenticated' || attempt > 0) rethrow;
        }
      }
    } on FirebaseException catch (error) {
      throw AuthServiceException(
        error.code,
        error.code == 'unauthenticated'
            ? '로그인 정보가 만료되었습니다. 다시 로그인해주세요.'
            : error.message ?? '프로필 사진 업로드에 실패했습니다.',
      );
    }
  }

  //=======================회원탈퇴==============================
  /// 계정과 계정에 딸린 데이터를 삭제하고 로컬 세션을 정리합니다.
  ///
  /// 클라이언트의 User.delete()는 최근 로그인을 요구해 재인증 없이 실패할 수
  /// 있으므로, 관리자 권한을 가진 Cloud Function이 Firestore 문서·프로필
  /// 사진·대기방 정리까지 함께 처리합니다.
  Future<void> deleteAccount() async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException('user-not-found', '로그인된 사용자가 없습니다.');
    }

    try {
      await _revokeAppleAuthorizationIfNeeded(user);
      await _functions.httpsCallable('deleteAccount').call();
    } on SignInWithAppleAuthorizationException catch (error) {
      throw AuthServiceException(
        error.code.name,
        error.code == AuthorizationErrorCode.canceled
            ? 'Apple 계정 확인이 취소되어 회원탈퇴를 중단했습니다.'
            : 'Apple 계정 확인에 실패했습니다. 잠시 후 다시 시도해주세요.',
      );
    } on FirebaseAuthException catch (error) {
      throw _toServiceException(error);
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(error.code, error.message ?? '회원탈퇴에 실패했습니다.');
    }

    // 계정이 사라진 뒤에도 로컬 인증 상태는 남아 있어 직접 정리합니다.
    await _auth.signOut();
  }

  /// Apple 연결 계정은 Apple이 요구하는 재확인을 거쳐 authorization token을
  /// 먼저 폐기합니다. 폐기 실패 시 서버 데이터도 지우지 않아 다시 시도할 수
  /// 있도록 순서를 고정합니다.
  Future<void> _revokeAppleAuthorizationIfNeeded(User user) async {
    final usesApple = hasAppleProvider(
      user.providerData.map((provider) => provider.providerId),
    );
    if (!usesApple) return;
    if (kIsWeb ||
        (defaultTargetPlatform != TargetPlatform.iOS &&
            defaultTargetPlatform != TargetPlatform.macOS)) {
      throw const AuthServiceException(
        'apple-platform-required',
        'Apple로 가입한 계정은 iPhone 또는 iPad에서 회원탈퇴해주세요.',
      );
    }

    final rawNonce = generateAppleNonce();
    final appleCredential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
      nonce: sha256AppleNonce(rawNonce),
    );
    final authorizationCode = appleCredential.authorizationCode.trim();
    if (authorizationCode.isEmpty) {
      throw const AuthServiceException(
        'missing-apple-authorization-code',
        'Apple 계정 확인 정보를 가져오지 못했습니다. 다시 시도해주세요.',
      );
    }
    await _auth.revokeTokenWithAuthorizationCode(authorizationCode);
  }

  //=======================프로필 정보를 Firestore에 동기화==============================
  Future<void> createUserDocument() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw const AuthServiceException('user-not-found', '로그인된 사용자가 없습니다.');
    }

    await syncGoogleUserProfile(user);
  }

  /// 현재 계정의 닉네임과 프로필 사진을 Cloud Function으로 저장합니다.
  ///
  /// Firestore의 users 쓰기는 클라이언트에 허용되지 않으므로 인증된 서버가
  /// 기존 사용자 문서에 필요한 필드만 병합합니다.
  Future<void> syncGoogleUserProfile(User user) async {
    await _syncSocialUserProfile(
      user,
      callable: 'syncGoogleUserProfile',
      failureMessage: 'Google 프로필을 저장하지 못했습니다.',
    );
  }

  /// 현재 Apple 계정의 닉네임과 프로필 사진을 Cloud Function으로 저장합니다.
  ///
  /// Apple은 이름을 최초 승인 때만 내려주고 사진은 주지 않으므로 값이 비어
  /// 있는 것이 정상입니다. 서버가 빈 값으로 기존 프로필을 덮지 않습니다.
  Future<void> syncAppleUserProfile(User user) async {
    await _syncSocialUserProfile(
      user,
      callable: 'syncAppleUserProfile',
      failureMessage: 'Apple 프로필을 저장하지 못했습니다.',
    );
  }

  Future<void> _syncSocialUserProfile(
    User user, {
    required String callable,
    required String failureMessage,
  }) async {
    try {
      await _functions.httpsCallable(callable).call({
        'nickname': user.displayName,
        'profileImageUrl': user.photoURL,
      });
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(error.code, error.message ?? failureMessage);
    }
  }

  //예외 변경해주는
  AuthServiceException _toServiceException(FirebaseAuthException error) {
    return AuthServiceException(
      error.code,
      error.message ?? 'Firebase 인증에 실패했습니다.',
    );
  }
}
