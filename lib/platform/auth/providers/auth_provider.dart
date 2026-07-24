import 'package:flutter/foundation.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthProvider extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  /// Google OAuth 2.0 인증 및 Firebase 세션 초기화 (최신 API 방식)
  Future<UserCredential?> signInWithGoogle() async {
    if (_isLoading) return null;

    try {
      _isLoading = true;
      notifyListeners();

      // 1. Google 계정 팝업 호출 (싱글톤 instance 및 authenticate() 사용)
      // 최신 API에서는 사용자가 취소하면 null을 반환하지 않고 Exception을 던지므로 try-catch에서 잡힙니다.
      final GoogleSignInAccount googleUser = await GoogleSignIn.instance
          .authenticate();

      // 2. 인증 객체 획득 (최신 API에서는 Future가 아닌 일반 getter이므로 await 제거)
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // 3. Firebase 크레덴셜 생성
      // 최신 구글 정책에 따라 accessToken은 제외되었으며, idToken만으로 Firebase 인증이 가능합니다.
      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      // 4. Firebase 인증 시스템에 로그인 요청 및 세션 할당
      final UserCredential userCredential = await FirebaseAuth.instance
          .signInWithCredential(credential);

      return userCredential;
    } on GoogleSignInException catch (e) {
      // 사용자가 로그인 팝업을 닫았거나 취소한 경우
      debugPrint('Google Sign-In Canceled or Failed: ${e.code}');
      return null;
    } catch (e) {
      debugPrint('Firebase Auth Exception: $e');
      return null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// 로그아웃 처리
  Future<void> signOut() async {
    // 로그아웃 역시 instance를 사용합니다.
    await GoogleSignIn.instance.signOut();
    await FirebaseAuth.instance.signOut();
  }
}
