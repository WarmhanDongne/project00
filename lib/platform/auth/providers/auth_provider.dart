import 'package:game_kit/core/diagnostics/crash_reporting.dart';
import 'package:game_kit/firebase/firebase_backend.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:project00/platform/auth/models/google_sign_in_error_message.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/services/apple_auth_utils.dart';
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

  User? get currentUser => FirebaseBackend.auth.currentUser;

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
    if (FirebaseBackend.isLocal) {
      _errorMessage = '로컬 환경에서는 테스트 이메일 계정 또는 게스트 로그인을 사용해주세요.';
      notifyListeners();
      return null;
    }

    _setLoading(true);

    try {
      _errorMessage = null;

      final googleUser = await GoogleSignIn.instance.authenticate();

      final googleAuth = googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      final userCredential = await FirebaseBackend.auth.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user != null) {
        await _authService.syncGoogleUserProfile(user);
      }

      notifyListeners();

      return userCredential;
    } on GoogleSignInException catch (error, stack) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        // 사용자가 계정 선택 창을 닫은 경우라 화면에는 아무것도 띄우지
        // 않습니다. 다만 Android는 앱 서명 지문(SHA) 미등록 같은 설정 오류도
        // 취소로 알려 주는 경우가 있어, 원인을 찾을 수 있게 기록만 남깁니다.
        CrashReporting.log('구글 로그인 취소: ${error.description ?? '-'}');
        return null;
      }
      CrashReporting.recordError(
        error,
        stack,
        reason: '구글 로그인 실패 (${error.code.name})',
      );
      _errorMessage = GoogleSignInErrorMessage.fromGoogle(error.code);
      notifyListeners();

      return null;
    } on FirebaseAuthException catch (error, stack) {
      CrashReporting.recordError(
        error,
        stack,
        reason: '구글 로그인 Firebase 인증 실패 (${error.code})',
      );
      _errorMessage = GoogleSignInErrorMessage.fromFirebase(error.code);
      notifyListeners();

      return null;
    } on AuthServiceException catch (e) {
      // 인증은 끝났지만 프로필 동기화가 실패한 경우입니다. AuthGate가 온보딩을
      // 복구하므로 치명적이지 않지만, 원인은 그대로 보여줍니다.
      _errorMessage = e.message;
      notifyListeners();

      return null;
    } catch (error, stack) {
      CrashReporting.recordError(error, stack, reason: '구글 로그인 실패');
      _errorMessage = GoogleSignInErrorMessage.generic;
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
    if (FirebaseBackend.isLocal) {
      _errorMessage = '로컬 환경에서는 테스트 이메일 계정 또는 게스트 로그인을 사용해주세요.';
      notifyListeners();
      return null;
    }

    _setLoading(true);

    try {
      _errorMessage = null;

      // Firebase가 Apple의 ID Token을 검증할 때 사용할 원본 nonce입니다.
      final rawNonce = generateAppleNonce();

      // Apple 로그인 요청에는 SHA-256 처리된 nonce를 전달합니다.
      final hashedNonce = sha256AppleNonce(rawNonce);

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

      final userCredential = await FirebaseBackend.auth.signInWithCredential(
        credential,
      );

      final user = userCredential.user;

      if (user != null) {
        // 구글과 같은 경로입니다. 이 호출이 users/userOnboarding 문서를 만들어
        // AuthGate가 프로필 설정 단계로 이어갑니다. 빠지면 온보딩 문서가 없어
        // 소셜 계정인데도 비밀번호 설정 화면으로 떨어집니다.
        await _authService.syncAppleUserProfile(user);
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
    } on AuthServiceException catch (e) {
      // 인증은 끝났지만 프로필 동기화가 실패한 경우입니다. AuthGate가 온보딩을
      // 복구하므로 치명적이지 않지만, 원인은 그대로 보여줍니다.
      _errorMessage = e.message;
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
  ///
  /// 구글 로그아웃이 실패해도(로컬 환경처럼 구글 SDK를 초기화하지 않은 경우
  /// 포함) Firebase 로그아웃은 반드시 진행해야 사용자가 실제로 로그아웃됩니다.
  Future<void> signOut() async {
    try {
      await GoogleSignIn.instance.signOut();
    } catch (error, stack) {
      CrashReporting.recordError(error, stack, reason: '구글 로그아웃 실패');
    }
    await FirebaseBackend.auth.signOut();

    notifyListeners();
  }
}
