import 'dart:async';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/widgets/register_step_one.dart';
import 'package:project00/platform/auth/widgets/register_step_two.dart';
import 'package:project00/platform/home/home.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key, this.isGoogleSignIn = false});

  final bool isGoogleSignIn; // 구글 로그인 여부

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

enum VerificationState {
  initial,
  waiting,
  verified,
}

class _RegisterScreenState extends State<RegisterScreen> with WidgetsBindingObserver {
  final authService = FirebaseAuthService();
  final imagePicker = ImagePicker();
  final emailController = TextEditingController();
  final customDomainController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();
  final nicknameController = TextEditingController();

  bool isLoading = false;
  String emailDomain = 'gmail.com';
  bool isCustomDomain = false;
  String? errorMessage;
  VerificationState verificationState = VerificationState.initial;
  Timer? _pollingTimer;

  late int pageNumber; // late로 선언해 나중에 초기화
  String? verificationId;
  String? googlePhotoURL;
  int? resendToken;
  XFile? profileImage;
  Uint8List? profileImageBytes;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollingTimer?.cancel();
    emailController.dispose();
    customDomainController.dispose();
    passwordController.dispose();
    confirmPasswordController.dispose();
    nicknameController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        verificationState == VerificationState.waiting) {
      checkEmailVerification(silent: true);
    }
  }

  void _startPolling() {
    _pollingTimer?.cancel();
    _pollingTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (verificationState == VerificationState.waiting) {
        checkEmailVerification(silent: true);
      } else {
        timer.cancel();
      }
    });
  }

  String get fullEmail {
    final localPart = emailController.text.trim();
    if (localPart.isEmpty) return '';
    final domain = isCustomDomain ? customDomainController.text.trim() : emailDomain;
    return '$localPart@$domain';
  }

  //회원가입 원스텝 (중복확인 -> 계정가생성 -> 메일발송)
  Future<void> processRegistration() async {
    final email = fullEmail;

    if (emailController.text.trim().isEmpty || (isCustomDomain && customDomainController.text.trim().isEmpty)) {
      setState(() => errorMessage = '이메일을 완전히 입력해주세요.');
      return;
    }
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => errorMessage = '이메일 형식이 올바르지 않습니다.');
      return;
    }

    final password = passwordController.text;
    if (password.isEmpty) {
      setState(() => errorMessage = '비밀번호를 입력해주세요.');
      return;
    }
    if (password != confirmPasswordController.text) {
      setState(() => errorMessage = '비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() {
      isLoading = true;
      errorMessage = null; // 에러 초기화
    });

    try {
      // 1. 중복 확인
      final isDuplicate = await authService.isEmailDuplicate(email);
      if (!mounted) return;
      if (isDuplicate) {
        setState(() => errorMessage = '이미 사용 중인 이메일입니다.');
        return;
      }

      // 2. 계정 생성
      await authService.createEmailAccount(
        email: email,
        password: password,
      );
      if (!mounted) return;

      // 3. 인증 메일 발송
      await authService.sendEmailVerification();
      if (!mounted) return;

      setState(() {
        verificationState = VerificationState.waiting;
        errorMessage = null;
      });
      _startPolling();

    } on AuthServiceException catch (error) {
      if (!mounted) return;
      final msg = switch (error.code) {
        'weak-password' => '비밀번호는 6자 이상 입력해주세요.',
        _ => error.message,
      };
      setState(() => errorMessage = msg);
    } catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = '네트워크 통신 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  //재전송
  Future<void> resendVerificationEmail() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });
    try {
      await authService.sendEmailVerification();
      if (!mounted) return;
      setState(() => verificationState = VerificationState.waiting);
      showMessage('인증 메일이 재발송되었습니다. 메일함을 확인해주세요.');
      _startPolling();
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() => errorMessage = error.message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  //이메일 인증 확인
  Future<void> checkEmailVerification({bool silent = false}) async {
    if (isLoading && !silent) return;
    if (!silent) setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      await user?.reload();
      if (!mounted) return;
      if (user?.emailVerified == true) {
        _pollingTimer?.cancel();
        setState(() => verificationState = VerificationState.verified);
        showMessage('이메일 인증이 완료되었습니다. 하단의 다음 버튼을 눌러주세요.');
      } else if (!silent) {
        showMessage('아직 이메일 인증이 완료되지 않았습니다. 메일함의 링크를 클릭해주세요.');
      }
    } finally {
      if (mounted && !silent) setState(() => isLoading = false);
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
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      showMessage(error.message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  //메시지 보여주기
  void showMessage(String message) {
    if (message.isEmpty) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }


  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    return PlatformAuthShell(
      showBack: true,
      maxWidth: pageNumber == 0 ? 440 : 400,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            pageNumber == 0 ? '회원가입' : '프로필 설정',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          if (pageNumber == 0)
            Text(
              '사용할 이메일과 비밀번호를 입력해 주세요.',
              style: TextStyle(color: colors.textMuted, fontSize: 11),
            ),
          const SizedBox(height: 20),
          if (pageNumber == 0)
            RegisterStepOne(
              emailController: emailController,
              customDomainController: customDomainController,
              passwordController: passwordController,
              confirmPasswordController: confirmPasswordController,
              emailDomain: emailDomain,
              isCustomDomain: isCustomDomain,
              isLoading: isLoading,
              errorMessage: errorMessage,
              verificationState: verificationState,
              onDomainChanged: (val) {
                if (val != null) {
                  setState(() {
                    emailDomain = val;
                    isCustomDomain = val == '직접 입력';
                  });
                }
              },
              onProcessRegistration: processRegistration,
              onResendVerification: resendVerificationEmail,
            )
          else
            RegisterStepTwo(
              nicknameController: nicknameController,
              isLoading: isLoading,
              profileImageBytes: profileImageBytes,
              googlePhotoURL: googlePhotoURL,
              onPickProfileImage: pickProfileImage,
              onCheckNickname: checkNickname,
            ),
          const SizedBox(height: 20),
          PlatformButton(
            label: pageNumber == 0
                ? (verificationState == VerificationState.waiting
                    ? (isLoading ? '확인 중...' : '인증 확인')
                    : '다음')
                : (isLoading ? '처리 중...' : '가입 완료'),
            onPressed: pageNumber == 0
                ? (verificationState == VerificationState.waiting
                    ? (isLoading ? null : checkEmailVerification)
                    : (verificationState == VerificationState.verified
                        ? () => setState(() => pageNumber = 1)
                        : null)) // initial 상태에서는 다음 버튼 비활성화 (전송하기로 진행)
                : (isLoading ? null : completeRegistration),
          ),
        ],
      ),
    );
  }
}
