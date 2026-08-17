import 'package:flutter/material.dart';
import 'package:project00/platform/auth/providers/auth_provider.dart';

import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

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
  String emailDomain = 'gmail.com';

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
    final localEmail = emailController.text.trim();
    final email = localEmail.contains('@')
        ? localEmail
        : '$localEmail@$emailDomain';
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
    final colors = context.platformColors;
    return PlatformAuthShell(
      maxWidth: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            '모시겜',
            style: TextStyle(
              color: colors.primary,
              fontSize: 28,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '모이면 시작되는 게임',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: '이메일'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  initialValue: emailDomain,
                  decoration: const InputDecoration(
                    contentPadding: EdgeInsets.symmetric(horizontal: 10),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'gmail.com',
                      child: Text('gmail.com', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'naver.com',
                      child: Text('naver.com', overflow: TextOverflow.ellipsis),
                    ),
                    DropdownMenuItem(
                      value: 'handong.ac.kr',
                      child: Text(
                        'handong.ac.kr',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (value) =>
                      setState(() => emailDomain = value ?? emailDomain),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: passwordController,
            obscureText: true,
            decoration: const InputDecoration(hintText: '비밀번호'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PlatformButton(
                  label: '회원가입',
                  style: PlatformButtonStyle.secondary,
                  onPressed: isLoading ? null : gotoRegister,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PlatformButton(
                  label: isLoading ? '로그인 중...' : '로그인',
                  onPressed: isLoading ? null : signIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Divider(color: colors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  '또는',
                  style: TextStyle(color: colors.textMuted, fontSize: 11),
                ),
              ),
              Expanded(child: Divider(color: colors.border)),
            ],
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: isLoading
                ? null
                : () async {
                    setState(() => isLoading = true);
                    final credential = await _authProvider.signInWithGoogle();
                    if (!mounted) return;
                    setState(() => isLoading = false);
                    showMessage(
                      credential == null
                          ? '구글 로그인에 실패했습니다.'
                          : '구글 로그인에 성공했습니다.',
                    );
                  },
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 44,
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border.all(color: colors.border),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.circle_outlined, size: 17),
                  const SizedBox(width: 8),
                  Text(
                    '구글로 로그인',
                    style: TextStyle(
                      color: colors.text,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
