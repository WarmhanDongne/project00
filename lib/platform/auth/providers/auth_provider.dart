import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({FirebaseAuthService? authService})
    : _authService = authService ?? FirebaseAuthService();

  final FirebaseAuthService _authService;

  bool _isDisposed = false;
  bool _isLoading = false;

  String? _errorMessage;

  // ============================================================
  // Getters
  // ============================================================

  bool get isLoading => _isLoading;

  String? get errorMessage => _errorMessage;

  User? get currentUser => FirebaseAuth.instance.currentUser;

  bool get isSignedIn => currentUser != null;

  // ============================================================
  // Lifecycle
  // ============================================================

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  // ============================================================
  // Email
  // ============================================================

  /// 이메일 중복 확인
  Future<bool> isEmailDuplicate(String email) async {
    try {
      return await _authService.isEmailDuplicate(email);
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    }
  }

  /// 이메일 회원가입
  Future<void> createEmailAccount({
    required String email,
    required String password,
  }) async {
    _setLoading(true);

    try {
      _errorMessage = null;

      await _authService.createEmailAccount(email: email, password: password);

      notifyListeners();
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// 이메일 로그인
  Future<void> signInWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    _setLoading(true);

    try {
      _errorMessage = null;

      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      notifyListeners();
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // Profile
  // ============================================================

  /// 닉네임 변경
  Future<void> updateDisplayName(String displayName) async {
    _setLoading(true);

    try {
      _errorMessage = null;

      await _authService.updateDisplayName(displayName);

      notifyListeners();
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  /// 프로필 사진 업로드
  Future<String> uploadProfileImage({
    required Uint8List imageBytes,
    required String fileName,
    String? contentType,
  }) async {
    _setLoading(true);

    try {
      _errorMessage = null;

      final url = await _authService.uploadProfileImage(
        imageBytes: imageBytes,
        fileName: fileName,
        contentType: contentType,
      );

      notifyListeners();

      return url;
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // Google
  // ============================================================

  /// Google 로그인
  Future<UserCredential?> signInWithGoogle() async {
    if (_isLoading) return null;

    _setLoading(true);

    try {
      _errorMessage = null;

      final googleUser = await GoogleSignIn.instance.authenticate();

      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user != null) {
        await _authService.syncGoogleUserProfile(user);
      }

      notifyListeners();

      return userCredential;
    } on GoogleSignInException {
      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();

      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // Apple
  // ============================================================

  /// Apple 로그인
  Future<UserCredential?> signInWithApple() async {
    if (_isLoading) return null;

    _setLoading(true);

    try {
      _errorMessage = null;

      // Firebase가 Apple의 ID Token을 검증할 때 사용할 원본 nonce입니다.
      final rawNonce = _generateNonce();

      // Apple 로그인 요청에는 SHA-256 처리된 nonce를 전달합니다.
      final hashedNonce = _sha256OfString(rawNonce);

      final appleCredential = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final identityToken = appleCredential.identityToken;

      if (identityToken == null) {
        _errorMessage = 'Apple 인증 토큰을 가져오지 못했습니다.';
        notifyListeners();

        return null;
      }

      // 현재 firebase_auth의 credentialWithIDToken은
      // idToken, rawNonce, AppleFullPersonName을 요구합니다.
      final credential = AppleAuthProvider.credentialWithIDToken(
        identityToken,
        rawNonce,
        AppleFullPersonName(
          givenName: appleCredential.givenName,
          familyName: appleCredential.familyName,
        ),
      );

      final userCredential = await FirebaseAuth.instance.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user != null) {
        // Apple은 이름 정보를 최초 승인 시에만 제공할 수 있으므로
        // 필요하면 여기에서 별도의 프로필 동기화를 수행하세요.
        //
        // await _authService.syncAppleUserProfile(user);
      }

      notifyListeners();

      return userCredential;
    } on SignInWithAppleAuthorizationException catch (e) {
      // 사용자가 Apple 로그인 창을 취소한 경우
      if (e.code == AuthorizationErrorCode.canceled) {
        return null;
      }

      _errorMessage = e.message;
      notifyListeners();

      return null;
    } on FirebaseAuthException catch (e) {
      _errorMessage = e.message ?? e.code;
      notifyListeners();

      return null;
    } catch (e) {
      _errorMessage = e.toString();
      notifyListeners();

      return null;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // User Document
  // ============================================================

  Future<void> createUserDocument() async {
    _setLoading(true);

    try {
      _errorMessage = null;

      await _authService.createUserDocument();

      notifyListeners();
    } on AuthServiceException catch (e) {
      _errorMessage = e.message;
      notifyListeners();
      rethrow;
    } finally {
      _setLoading(false);
    }
  }

  // ============================================================
  // Sign Out
  // ============================================================

  /// 로그아웃
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();

    notifyListeners();
  }

  // ============================================================
  // Apple Utils
  // ============================================================

  /// Apple 로그인에 사용할 랜덤 nonce를 생성합니다.
  String _generateNonce([int length = 32]) {
    const charset =
        '0123456789ABCDEFGHIJKLMNOPQRSTUVXYZ'
        'abcdefghijklmnopqrstuvwxyz-._';

    final random = Random.secure();

    return List.generate(
      length,
      (_) => charset[random.nextInt(charset.length)],
    ).join();
  }

  /// 문자열을 SHA-256으로 변환합니다.
  String _sha256OfString(String input) {
    final bytes = utf8.encode(input);

    return sha256.convert(bytes).toString();
  }
}
