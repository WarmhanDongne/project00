import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/widgets/register_step_one.dart';
import 'package:project00/platform/auth/widgets/register_step_two.dart';
import 'package:project00/platform/home/home.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.isGoogleSignIn = false});

  final bool isGoogleSignIn; // 구글 로그인 여부

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final authService = FirebaseAuthService();
  final imagePicker = ImagePicker();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final phoneController = TextEditingController();
  final verificationCodeController = TextEditingController();
  final nicknameController = TextEditingController();

  bool isLoading = false;
  bool isEmailChecked = false;
  bool isCodeSent = false;
  bool isPhoneVerified = false;

  late int pageNumber; // late로 선언해 나중에 초기화
  String? verificationId;
  String? googlePhotoURL;
  int? resendToken;
  XFile? profileImage;
  Uint8List? profileImageBytes;

  @override
  void initState() {
    super.initState();
    pageNumber = widget.isGoogleSignIn ? 1 : 0; // 구글 로그인 여부 설정

    // 구글 로그인 객체 바탕으로 기본 정보 채우기
    // 구글 로그인으로 접근이 아닌 경우 종료
    if (!widget.isGoogleSignIn) return;

    // 구글 로그인 계정 객체 생성
    final user = FirebaseAuth.instance.currentUser;

    if (user == null) return; // 실패

    // 성공 시 닉네임과 photoURL 갱신
    nicknameController.text = user.displayName ?? '';
    googlePhotoURL = user.photoURL;
  }

  //이메일 중복확인
  Future<void> checkEmailDuplicate() async {
    final email = emailController.text.trim();

    if (email.isEmpty) {
      showMessage('이메일을 입력해주세요.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      showMessage('이메일 형식이 올바르지 않습니다.');
      return;
    }
    try {
      final isDuplicate = await authService.isEmailDuplicate(email);

      if (!mounted) return;
      if (isDuplicate) {
        showMessage('이미 사용 중인 이메일입니다.');
        return;
      }
      setState(() => isEmailChecked = true);
      showMessage('사용 가능한 이메일입니다.');
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      showMessage(error.message);
    } finally {}
  }

  //회원가입
  Future<void> createEmailAccount() async {
    if (!isEmailChecked) {
      showMessage('이메일 중복확인을 완료해주세요.');
      return;
    }

    final password = passwordController.text;
    if (password.isEmpty) {
      showMessage('비밀번호를 입력해주세요.');
      return;
    }
    if (password != confirmPasswordController.text) {
      showMessage('비밀번호가 일치하지 않습니다.');
      return;
    }
    setState(() => isLoading = true);
    try {
      await authService.createEmailAccount(
        email: emailController.text.trim(),
        password: password,
      );

      if (!mounted) return;
      setState(() => pageNumber = 1);
      showMessage('이메일 계정이 생성되었습니다. 휴대폰 인증을 진행해주세요.');
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'email-already-in-use' => '방금 다른 사용자가 가입한 이메일입니다.',
        'weak-password' => '비밀번호는 6자 이상 입력해주세요.',
        _ => error.message,
      };
      showMessage(message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  //닉네임 형식 확인
  void checkNickname() {
    final nickname = nicknameController.text.trim();
    showMessage(nickname.length >= 2 ? '사용 가능한 형식입니다.' : '닉네임을 2자 이상 입력해주세요.');
  }

  Future<void> pickProfileImage() async {
    try {
      final image = await imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        imageQuality: 85,
      );

      if (image == null) return;

      final bytes = await image.readAsBytes();

      if (!mounted) return;

      setState(() {
        profileImage = image;
        profileImageBytes = bytes;
      });
    } catch (error, stackTrace) {
      debugPrint('프로필 이미지 선택 오류: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      showMessage('프로필 사진을 불러오지 못했습니다.\n$error');
    }
  }

  //제출하기
  Future<void> completeRegistration() async {
    setState(() => isLoading = true);
    try {
      final image = profileImage;
      final imageBytes = profileImageBytes;
      //닉네임 저장
      await authService.updateDisplayName(nicknameController.text.trim());
      if (image != null && imageBytes != null) {
        //프로필 이미지 저장
        await authService.uploadProfileImage(
          imageBytes: imageBytes,
          fileName: image.name,
          contentType: image.mimeType,
        );
      }
      //(프로필 이미지+ 닉네임)을 계정정보를 firestore에 저장
      await authService.createUserDocument();
      if (!mounted) return;
      showMessage('가입이 완료되었습니다.');
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const Home()));
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      showMessage(error.message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  //메시지 보여주기
  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  //객체 정리
  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    phoneController.dispose();
    verificationCodeController.dispose();
    nicknameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          child: Container(
            width: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (pageNumber == 0)
                  RegisterStepOne(
                    emailController: emailController,
                    passwordController: passwordController,
                    confirmPasswordController: confirmPasswordController,
                    isEmailChecked: isEmailChecked,
                    onCheckEmail: checkEmailDuplicate,
                  )
                else
                  RegisterStepTwo(
                    nicknameController: nicknameController,
                    phoneController: phoneController,
                    verificationCodeController: verificationCodeController,
                    isLoading: isLoading,
                    isCodeSent: isCodeSent,
                    isPhoneVerified: isPhoneVerified,
                    profileImageBytes: profileImageBytes,
                    googlePhotoURL: googlePhotoURL,
                    onPickProfileImage: pickProfileImage,
                    onCheckNickname: checkNickname,
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  style: FilledButton.styleFrom(
                    shape: const RoundedRectangleBorder(),
                  ),
                  onPressed: isLoading
                      ? null
                      : pageNumber == 0
                      ? createEmailAccount
                      : completeRegistration,
                  child: isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Text(pageNumber == 0 ? '다음' : '가입 완료'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
