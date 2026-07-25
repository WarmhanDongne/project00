import 'package:flutter/material.dart';
import 'package:project00/platform/auth/providers/auth_provider.dart';

import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/firebase_auth_service.dart';
import 'package:project00/platform/hub/screens/home_tablet.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  // 상태 관리 객체 인스턴스화
  final AuthProvider _authProvider = AuthProvider();
  final authService = FirebaseAuthService();
  //이메일+비밀번호 불러오기
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;

  @override
  void dispose() {
    // 위젯 트리가 파괴될 때 Provider 메모리 할당 해제
    _authProvider.dispose();
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  Future<void> signIn() async {
    //아이디+비밀번호 .text처리
    //trim()? 공백 제거
    final email = emailController.text.trim();
    final password = passwordController.text;

    //비여있는지 확인
    if (email.isEmpty || password.isEmpty) {
      showMessage('이메일과 비밀번호를 입력해주세요.');
      return;
    }

    //로딩중
    setState(() {
      isLoading = true;
    });

    //ui로딩으로 바꾼후 서버 접속,
    try {
      await authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      //사용자가 화면에 머물러 있는지 확인
      if (!mounted) return;
      showMessage('환영합니다');
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const HomeTablet()),
      );
    } on AuthServiceException catch (error) {
      if (!mounted) return;

      //error코드에서 메시지 전환시켜 showMessage로 출력
      final message = switch (error.code) {
        'invalid-credential' => '이메일 또는 비밀번호가 올바르지 않습니다.',
        'invalid-email' => '이메일 형식이 올바르지 않습니다.',
        'weak-password' => '비밀번호는 6자 이상 입력해주세요.',
        'network-request-failed' => '네트워크 연결을 확인해주세요.',
        _ => error.message,
      };

      showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void gotoRegister() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const RegisterScreen()),
    );
  }

  void showMessage(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            // color: const Color.fromARGB(255, 255, 255, 255),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'ID/EMAIL:',
                  filled: true,
                  fillColor: Color(0xFFD4D4D4),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  hintText: 'PW:',
                  filled: true,
                  fillColor: Color(0xFFD4D4D4),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                          ),
                        ),
                        onPressed: gotoRegister,
                        child: Text('회원가입'),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(0),
                          ),
                        ),
                        onPressed: isLoading ? null : signIn,
                        child: isLoading
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Text('로그인'),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: 16),
              GestureDetector(
                onTap: () async {
                  // 로딩 중이 아닐 때만 실행되도록 처리
                  if (isLoading) return;

                  // 상태를 로딩 중으로 변경
                  setState(() {
                    isLoading = true;
                  });

                  // AuthProvider의 구글 로그인 로직 호출
                  final credential = await _authProvider.signInWithGoogle();

                  if (mounted) {
                    setState(() {
                      setState(() {
                        isLoading = false;
                      });

                      if (credential != null) {
                        showMessage('구글 로그인에 성공했습니다.');
                      } else {
                        showMessage('구글 로그인에 실패했습니다.');
                      }
                    });
                  }
                },
                child: SizedBox(
                  width: double.infinity,
                  child: Image.asset(
                    'assets/images/button/googleLoginButton.png',
                    fit: BoxFit.fitWidth,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
