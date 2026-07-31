import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project00/platform/auth/services/firebase_auth_service.dart';
import 'package:project00/platform/auth/widgets/register_step_one.dart';
import 'package:project00/platform/auth/widgets/register_step_two.dart';
import 'package:project00/platform/hub/screens/home.dart';

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
  int? resendToken;
  XFile? profileImage;
  Uint8List? profileImageBytes;

  @override
  void initState() {
    super.initState();
    pageNumber = widget.isGoogleSignIn ? 1 : 0; // 구글 로그인 여부 설정
  }

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

  Future<void> sendPhoneCode() async {
    if (!authService.hasEmailAccount) {
      showMessage('이메일 계정을 먼저 생성해주세요.');
      return;
    }

    final phone = phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');

    if (!RegExp(r'^01[016789]\d{7,8}$').hasMatch(phone)) {
      showMessage('올바른 휴대폰 번호를 입력해주세요.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      await authService.sendPhoneCode(
        phoneNumber: '+82${phone.substring(1)}',
        forceResendingToken: resendToken,

        verificationCompleted: () async {
          handlePhoneVerificationCompleted();
        },

        verificationFailed: (error) {
          if (!mounted) return;

          setState(() {
            isLoading = false;
          });

          debugPrint(
            'Phone verification failed: ${error.code} / ${error.message}',
          );

          final message = switch (error.code) {
            'invalid-phone-number' => '휴대폰 번호 형식이 올바르지 않습니다.',
            'too-many-requests' => '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.',
            'quota-exceeded' => 'SMS 인증 한도를 초과했습니다.',
            'operation-not-allowed' =>
              '휴대폰 인증 요청이 허용되지 않았습니다. Firebase SMS 설정을 확인해주세요.',
            _ => error.message,
          };

          showMessage('$message\n[${error.code}] ${error.message}');
        },

        codeSent: (id, token) {
          if (!mounted) return;

          setState(() {
            verificationId = id;
            resendToken = token;
            isCodeSent = true;
            isLoading = false;
          });

          showMessage('인증번호가 발송되었습니다.');
        },

        codeAutoRetrievalTimeout: (id) {
          verificationId = id;

          if (!mounted) return;

          setState(() {
            isLoading = false;
          });
        },

        timeout: const Duration(seconds: 60),
      );
    } on AuthServiceException catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      showMessage(error.message);
    }
  }

  Future<void> confirmPhoneCode() async {
    final id = verificationId;
    final code = verificationCodeController.text.trim();

    if (id == null) {
      showMessage('먼저 인증번호를 발송해주세요.');
      return;
    }

    if (!RegExp(r'^\d{6}$').hasMatch(code)) {
      showMessage('6자리 인증번호를 입력해주세요.');
      return;
    }

    setState(() {
      isLoading = true;
    });

    await verifyPhoneCredential(verificationId: id, smsCode: code);
  }

  Future<void> verifyPhoneCredential({
    required String verificationId,
    required String smsCode,
  }) async {
    if (!authService.hasEmailAccount) {
      if (mounted) {
        setState(() => isLoading = false);
        showMessage('이메일 계정 정보를 찾을 수 없습니다. 다시 가입해주세요.');
      }
      return;
    }

    try {
      await authService.confirmAndLinkPhoneCode(
        verificationId: verificationId,
        smsCode: smsCode,
      );

      handlePhoneVerificationCompleted();
    } on AuthServiceException catch (error) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });

      final message = switch (error.code) {
        'invalid-verification-code' => '인증번호가 올바르지 않습니다.',
        'credential-already-in-use' => '이미 다른 계정에서 사용 중인 휴대폰 번호입니다.',
        'provider-already-linked' => '이미 휴대폰 인증이 연결된 계정입니다.',
        'session-expired' => '인증번호가 만료되었습니다. 다시 전송해주세요.',
        'too-many-requests' => '요청이 너무 많습니다. 잠시 후 다시 시도해주세요.',
        _ => error.message,
      };

      showMessage(message);
    }
  }

  void handlePhoneVerificationCompleted() {
    if (!mounted) return;

    setState(() {
      isPhoneVerified = true;
      isLoading = false;
    });

    showMessage('휴대폰 인증이 완료되었습니다.');
  }

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

  Future<void> completeRegistration() async {
    if (!isPhoneVerified) {
      showMessage('휴대폰 인증을 완료해주세요.');
      return;
    }

    if (!authService.hasEmailAndPhoneAccount) {
      showMessage('회원가입 정보를 확인할 수 없습니다. 다시 시도해주세요.');
      return;
    }

    setState(() => isLoading = true);
    try {
      final image = profileImage;
      final imageBytes = profileImageBytes;
      if (image != null && imageBytes != null) {
        await authService.uploadProfileImage(
          imageBytes: imageBytes,
          fileName: image.name,
          contentType: image.mimeType,
        );
      }
      await authService.updateDisplayName(nicknameController.text.trim());

      if (!mounted) return;
      showMessage('가입이 완료되었습니다.');
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const Home()),
        (route) => false,
      );
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      showMessage(error.message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

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
                    onPickProfileImage: pickProfileImage,
                    onCheckNickname: checkNickname,
                    onSendPhoneCode: sendPhoneCode,
                    onConfirmPhoneCode: confirmPhoneCode,
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
