import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';

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
    FirebaseFirestore? firestore,
  }) : _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
       _storage = storage ?? FirebaseStorage.instance,
       _firestore = firestore ?? FirebaseFirestore.instance;
  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;
  final FirebaseFirestore _firestore;

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
      await reference.putData(
        imageBytes,
        SettableMetadata(contentType: contentType ?? 'image/jpeg'),
      );
      final downloadUrl = await reference.getDownloadURL();
      await user.updatePhotoURL(downloadUrl);
      return downloadUrl;
    } on FirebaseException catch (error) {
      throw AuthServiceException(
        error.code,
        error.message ?? '프로필 사진 업로드에 실패했습니다.',
      );
    }
  }

  //프로필사진+닉네임+UID 묶어서 firestore에 저장하기
  Future<void> createUserDocument() async {
    final user = _auth.currentUser;

    if (user == null) {
      throw const AuthServiceException('user-not-found', '로그인된 사용자가 없습니다.');
    }

    //유저 구조
    await _firestore.collection('users').doc(user.uid).set({
      'uid': user.uid,
      'email': user.email,
      'nickname': user.displayName,
      'profileImageUrl': user.photoURL,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Google 계정의 닉네임과 프로필 사진을 Cloud Function으로 저장합니다.
  ///
  /// Firestore의 users 쓰기는 클라이언트에 허용되지 않으므로 인증된 서버가
  /// 기존 사용자 문서에 필요한 필드만 병합합니다.
  Future<void> syncGoogleUserProfile(User user) async {
    try {
      await _functions.httpsCallable('syncGoogleUserProfile').call({
        'nickname': user.displayName,
        'profileImageUrl': user.photoURL,
      });
    } on FirebaseFunctionsException catch (error) {
      throw AuthServiceException(
        error.code,
        error.message ?? 'Google 프로필을 저장하지 못했습니다.',
      );
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
