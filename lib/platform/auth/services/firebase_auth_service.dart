import 'dart:typed_data';

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
  }) : _auth = auth ?? FirebaseAuth.instance,
       _functions =
           functions ??
           FirebaseFunctions.instanceFor(region: 'asia-northeast3'),
       _storage = storage ?? FirebaseStorage.instance;

  final FirebaseAuth _auth;
  final FirebaseFunctions _functions;
  final FirebaseStorage _storage;

  bool get hasEmailAccount => _auth.currentUser?.email != null;

  bool get hasEmailAndPhoneAccount {
    final user = _auth.currentUser;
    return user?.email != null && user?.phoneNumber != null;
  }

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

  Future<void> sendPhoneCode({
    required String phoneNumber,
    required Future<void> Function() verificationCompleted,
    required void Function(AuthServiceException error) verificationFailed,
    required void Function(String verificationId, int? resendToken) codeSent,
    required void Function(String verificationId) codeAutoRetrievalTimeout,
    int? forceResendingToken,
    Duration timeout = const Duration(seconds: 60),
  }) async {
    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: phoneNumber,
        verificationCompleted: (credential) async {
          try {
            await _linkPhoneCredential(credential);
            await verificationCompleted();
          } on AuthServiceException catch (error) {
            verificationFailed(error);
          }
        },
        verificationFailed: (error) {
          verificationFailed(_toServiceException(error));
        },
        codeSent: codeSent,
        codeAutoRetrievalTimeout: codeAutoRetrievalTimeout,
        forceResendingToken: forceResendingToken,
        timeout: timeout,
      );
    } on FirebaseAuthException catch (error) {
      throw _toServiceException(error);
    }
  }

  Future<void> confirmAndLinkPhoneCode({
    required String verificationId,
    required String smsCode,
  }) {
    final credential = PhoneAuthProvider.credential(
      verificationId: verificationId,
      smsCode: smsCode,
    );
    return _linkPhoneCredential(credential);
  }

  Future<void> _linkPhoneCredential(PhoneAuthCredential credential) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw const AuthServiceException('user-not-found', '로그인된 이메일 계정이 없습니다.');
    }
    try {
      await user.linkWithCredential(credential);
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

  Future<String> uploadProfileImage({
    required Uint8List imageBytes,
    required String fileName,
    String? contentType,
  }) async {
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
    final reference = _storage.ref(
      'profile_images/${user.uid}/profile.$safeExtension',
    );

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

  AuthServiceException _toServiceException(FirebaseAuthException error) {
    return AuthServiceException(
      error.code,
      error.message ?? 'Firebase 인증에 실패했습니다.',
    );
  }
}
