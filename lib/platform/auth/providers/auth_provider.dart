import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  bool _isSignedIn = false;
  bool get isSignedIn => _isSignedIn;

  /// Google Identity Provider를 통한 로그인 및 Firebase 세션 생성
  Future<UserCredential?> signInWithGoogle() async {
    try {
      _isLoading = true;
      notifyListeners();

      // 1. Google 계정 선택 팝업 호출
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) {
        // 사용자가 인증 프로세스를 취소한 경우
        _isLoading = false;
        notifyListeners();
        return null;
      }

      // 2. 인증 객체로부터 Access Token 및 ID Token 비동기 획득
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // 3. 획득한 Token을 기반으로 Firebase 인증 크레덴셜 생성
      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // 4. Firebase Auth 시스템에 로그인 요청 및 세션 생성
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      _isSignedIn = true;
      return userCredential;
    } catch (e) {
      debugPrint('Google Sign-In Exception: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 로그아웃 처리 (Google 및 Firebase 세션 모두 파기)
  Future<void> signOut() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    _isSignedIn = false;
    notifyListeners();
  }
}
