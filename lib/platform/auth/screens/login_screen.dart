import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/material.dart';
import 'package:project00/platform/auth/providers/auth_provider.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

enum _LoginAction { password, google }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _authProvider = AuthProvider();
  final _authService = FirebaseAuthService();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _customDomainController = TextEditingController();
  final _customDomainFocusNode = FocusNode();
  _LoginAction? _action;
  String? _errorMessage;
  bool _isCustomDomain = false;
  String _emailDomain = 'gmail.com';

  @override
  void dispose() {
    _authProvider.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _customDomainController.dispose();
    _customDomainFocusNode.dispose();
    super.dispose();
  }

  String _email() {
    final input = _emailController.text.trim().toLowerCase();
    if (input.contains('@')) return input;
    final domain = _isCustomDomain
        ? _customDomainController.text.trim().toLowerCase()
        : _emailDomain;
    return '$input@$domain';
  }

  Future<void> _signIn() async {
    if (_action != null) return;
    final email = _email();
    final password = _passwordController.text;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        password.isEmpty) {
      setState(() => _errorMessage = '이메일과 비밀번호를 확인해주세요.');
      return;
    }
    setState(() {
      _action = _LoginAction.password;
      _errorMessage = null;
    });
    try {
      await _authService.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      final user = FirebaseAuth.instance.currentUser;
      if (user != null && !user.emailVerified) {
        await FirebaseAuth.instance.signOut();
        throw const AuthServiceException(
          'email-not-verified',
          '이메일 링크 인증을 완료한 뒤 다시 로그인해주세요.',
        );
      }
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = switch (error.code) {
          'invalid-credential' => '이메일 또는 비밀번호가 올바르지 않습니다.',
          'invalid-email' => '이메일 형식이 올바르지 않습니다.',
          'network-request-failed' => '네트워크 연결을 확인해주세요.',
          _ => error.message,
        },
      );
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  Future<void> _signInWithGoogle() async {
    if (_action != null) return;
    setState(() {
      _action = _LoginAction.google;
      _errorMessage = null;
    });
    final credential = await _authProvider.signInWithGoogle();
    if (!mounted) return;
    setState(() {
      if (credential == null) {
        _errorMessage = _authProvider.errorMessage ?? '구글 로그인을 완료하지 못했습니다.';
      }
      _action = null;
    });
  }

  void _changeDomain(String? value) {
    if (value == null) return;
    setState(() {
      _isCustomDomain = value == 'custom';
      if (!_isCustomDomain) _emailDomain = value;
    });
    if (_isCustomDomain) _customDomainFocusNode.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final isBusy = _action != null;
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
            '모이면 시작하는 게임',
            style: TextStyle(color: colors.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _emailController,
                  enabled: !isBusy,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(hintText: '이메일'),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 112,
                child: _isCustomDomain
                    ? TextField(
                        controller: _customDomainController,
                        focusNode: _customDomainFocusNode,
                        enabled: !isBusy,
                        decoration: InputDecoration(
                          hintText: '직접 입력',
                          suffixIcon: IconButton(
                            onPressed: () => _changeDomain('gmail.com'),
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                          ),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        initialValue: _emailDomain,
                        isExpanded: true,
                        decoration: const InputDecoration(),
                        items: const [
                          DropdownMenuItem(
                            value: 'gmail.com',
                            child: Text('gmail.com'),
                          ),
                          DropdownMenuItem(
                            value: 'naver.com',
                            child: Text('naver.com'),
                          ),
                          DropdownMenuItem(
                            value: 'daum.net',
                            child: Text('daum.net'),
                          ),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text('직접 입력'),
                          ),
                        ],
                        onChanged: isBusy ? null : _changeDomain,
                      ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _passwordController,
            enabled: !isBusy,
            obscureText: true,
            onSubmitted: (_) => _signIn(),
            decoration: const InputDecoration(hintText: '비밀번호'),
          ),
          if (_errorMessage != null) ...[
            const SizedBox(height: 10),
            PlatformNotice(
              message: _errorMessage!,
              style: PlatformNoticeStyle.danger,
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: PlatformButton(
                  label: '회원가입',
                  style: PlatformButtonStyle.secondary,
                  onPressed: isBusy
                      ? null
                      : () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => const RegisterScreen(),
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: PlatformButton(
                  label: '로그인',
                  loading: _action == _LoginAction.password,
                  onPressed: isBusy ? null : _signIn,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: Divider(color: colors.border)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text('또는', style: TextStyle(color: colors.textMuted)),
              ),
              Expanded(child: Divider(color: colors.border)),
            ],
          ),
          const SizedBox(height: 20),
          PlatformButton(
            label: 'Google로 로그인',
            style: PlatformButtonStyle.secondary,
            loading: _action == _LoginAction.google,
            onPressed: isBusy ? null : _signInWithGoogle,
          ),
        ],
      ),
    );
  }
}
