import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/auth/widgets/register_step_one.dart';
import 'package:project00/platform/auth/widgets/register_step_two.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
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
  int pageNumber = 0;
  String? verificationId;

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

    setState(() => isLoading = true);
    try {
      final callable = FirebaseFunctions.instanceFor(
        region: 'asia-northeast3',
      ).httpsCallable('checkEmailDuplicate');
      final result = await callable.call<Map<String, dynamic>>({
        'email': email,
      });
      final isDuplicate = result.data['isDuplicate'] == true;

      if (!mounted) return;
      if (isDuplicate) {
        showMessage('이미 사용 중인 이메일입니다.');
        return;
      }

      setState(() => isEmailChecked = true);
      showMessage('사용 가능한 이메일입니다.');
    } on FirebaseFunctionsException catch (error) {
      if (!mounted) return;
      showMessage(error.message ?? '이메일 중복확인에 실패했습니다.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> goToNextStep() async {
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
      await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: emailController.text.trim(),
        password: password,
      );
      if (!mounted) return;
      setState(() => pageNumber = 1);
      showMessage('이메일 계정이 생성되었습니다.');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      final message = switch (error.code) {
        'email-already-in-use' => '방금 다른 사용자가 가입한 이메일입니다.',
        'weak-password' => '비밀번호는 6자 이상 입력해주세요.',
        _ => error.message ?? '회원가입에 실패했습니다.',
      };
      showMessage(message);
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> sendPhoneCode() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      showMessage('먼저 이메일 계정을 생성해주세요.');
      return;
    }

    final phone = phoneController.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (!RegExp(r'^01[016789]\d{7,8}$').hasMatch(phone)) {
      showMessage('올바른 휴대폰 번호를 입력해주세요.');
      return;
    }

    setState(() => isLoading = true);
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: '+82${phone.substring(1)}',
        verificationCompleted: linkPhoneCredential,
        verificationFailed: (error) {
          if (!mounted) return;
          setState(() => isLoading = false);
          showMessage(error.message ?? '인증번호 발송에 실패했습니다.');
        },
        codeSent: (id, resendToken) {
          if (!mounted) return;
          setState(() {
            verificationId = id;
            isCodeSent = true;
            isLoading = false;
          });
          showMessage('인증번호가 발송되었습니다.');
        },
        codeAutoRetrievalTimeout: (id) {
          verificationId = id;
          if (mounted) setState(() => isLoading = false);
        },
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showMessage('전화 인증 설정을 확인해주세요.');
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

    setState(() => isLoading = true);
    await linkPhoneCredential(
      PhoneAuthProvider.credential(verificationId: id, smsCode: code),
    );
  }

  Future<void> linkPhoneCredential(PhoneAuthCredential credential) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() => isLoading = false);
        showMessage('로그인이 필요합니다.');
      }
      return;
    }

    try {
      final result = await user.linkWithCredential(credential);
      final linkedUser = result.user;
      if (linkedUser == null) throw StateError('사용자 정보를 찾을 수 없습니다.');

      await FirebaseFirestore.instance
          .collection('users')
          .doc(linkedUser.uid)
          .set({
            'uid': linkedUser.uid,
            'email': linkedUser.email,
            'nickname': nicknameController.text.trim(),
            'phoneNumber': linkedUser.phoneNumber,
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));

      if (!mounted) return;
      setState(() {
        isPhoneVerified = true;
        isLoading = false;
      });
      showMessage('휴대폰 인증이 완료되었습니다.');
    } on FirebaseAuthException catch (error) {
      if (!mounted) return;
      setState(() => isLoading = false);
      final message = switch (error.code) {
        'invalid-verification-code' => '인증번호가 올바르지 않습니다.',
        'credential-already-in-use' => '이미 다른 계정에서 사용하는 번호입니다.',
        'session-expired' => '인증번호가 만료되었습니다.',
        _ => error.message ?? '전화번호 연결에 실패했습니다.',
      };
      showMessage(message);
    } on FirebaseException catch (error) {
      if (!mounted) return;
      setState(() => isLoading = false);
      showMessage(error.message ?? '사용자 정보 저장에 실패했습니다.');
    }
  }

  void checkNickname() {
    final nickname = nicknameController.text.trim();
    showMessage(nickname.length >= 2 ? '사용 가능한 형식입니다.' : '닉네임을 2자 이상 입력해주세요.');
  }

  void completeRegistration() {
    if (!isPhoneVerified) {
      showMessage('휴대폰 인증을 완료해주세요.');
      return;
    }
    showMessage('가입이 완료되었습니다.');
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
                    isLoading: isLoading,
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
                      ? goToNextStep
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
