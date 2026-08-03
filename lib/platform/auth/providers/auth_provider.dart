import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:project00/platform/auth/services/auth_service.dart';

class AuthProvider extends ChangeNotifier {
  AuthProvider({FirebaseAuthService? authService})
    : _authService = authService ?? FirebaseAuthService();

  final FirebaseAuthService _authService;

  bool _isLoading = false;
  bool get isLoading => _isLoading;
  String? _errorMessage;
  String? get errorMessage => _errorMessage;
  User? get currentUser => FirebaseAuth.instance.currentUser;
  bool get isSignedIn => currentUser != null;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /////////////////////// 이메일 /////////////////////////////
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

  /////////////////////// 닉네임 /////////////////////////////
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

  /////////////////////// 구글 /////////////////////////////
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

  /////////////////////// 기타 /////////////////////////////
  /// 로그아웃
  Future<void> signOut() async {
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();

    notifyListeners();
  }
}
