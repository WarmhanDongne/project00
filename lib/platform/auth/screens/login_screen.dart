import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/auth/providers/auth_provider.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';

enum _LoginAction { password, google, apple }

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
  bool _isRegistering = false;

  @override
  void dispose() {
    _authProvider.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _customDomainController.dispose();
    _customDomainFocusNode.dispose();
    super.dispose();
  }

  //===========================[ 기본 로그인 ]======================
  Future<void> _signIn() async {
    if (_action != null) return;
    final email = _email();
    final password = _passwordController.text;
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email) ||
        password.isEmpty) {
      setState(() => _errorMessage = context.l10n.checkCredentials);
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
          'invalid-credential' => context.l10n.invalidCredentials,
          'invalid-email' => context.l10n.invalidEmail,
          'network-request-failed' => context.l10n.checkNetwork,
          _ => error.message,
        },
      );
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  // _sign()에서 사용
  String _email() {
    final input = _emailController.text.trim().toLowerCase();
    if (input.contains('@')) return input;
    final domain = _isCustomDomain
        ? _customDomainController.text.trim().toLowerCase()
        : _emailDomain;
    return '$input@$domain';
  }

  //===========================[ 구글 로그인 ]======================
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

  // Apple 로그인은 애플 플랫폼에서만 네이티브로 동작합니다. Android/웹에서 쓰려면
  // sign_in_with_apple의 webAuthenticationOptions 설정이 추가로 필요합니다.

  //==========================[ 애플 로그인 ]======================
  Future<void> _signInWithApple() async {
    if (_action != null) return;
    setState(() {
      _action = _LoginAction.apple;
      _errorMessage = null;
    });
    final credential = await _authProvider.signInWithApple();
    if (!mounted) return;
    setState(() {
      // 사용자가 창을 닫은 경우에는 errorMessage가 비어 있어 문구를 띄우지 않습니다.
      if (credential == null && _authProvider.errorMessage != null) {
        _errorMessage = _authProvider.errorMessage;
      }
      _action = null;
    });
  }

  // 도메인 선택 시 드롭다운 또는 직접 입력 실행
  void _changeDomain(String? value) {
    if (value == null) return;
    setState(() {
      _isCustomDomain = value == 'custom';
      if (!_isCustomDomain) _emailDomain = value;
    });
    if (_isCustomDomain) _customDomainFocusNode.requestFocus();
  }

  // Apple 로그인 버튼을 표시할지 결정할 때 사용
  bool get _isAppleSignInAvailable =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  @override
  Widget build(BuildContext context) {
    return MosiAuthScaffold(
      child: MosiAuthTransition(
        child: _isRegistering
            ? RegisterScreen(
                key: const ValueKey('register'),
                onCancel: () => setState(() => _isRegistering = false),
              )
            : KeyedSubtree(
                key: const ValueKey('login'),
                child: _buildLogin(context),
              ),
      ),
    );
  }

  Widget _buildLogin(BuildContext context) {
    final isBusy = _action != null;
    final titleSize = isTabletLayout(context) ? 30.0 : 26.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.l10n.login,
          style: MosiFonts.sans(
            locale: Localizations.maybeLocaleOf(context),
            size: titleSize,
            weight: FontWeight.w700,
            color: MosiColors.navy,
            letterSpacing: -1,
          ),
        ),
        const SizedBox(height: 14),
        MosiLabeledField(
          label: context.l10n.email,
          child: MosiEmailField(
            emailController: _emailController,
            customDomainController: _customDomainController,
            customDomainFocusNode: _customDomainFocusNode,
            emailDomain: _emailDomain,
            isCustomDomain: _isCustomDomain,
            enabled: !isBusy,
            onDomainChanged: _changeDomain,
          ),
        ),
        const SizedBox(height: 14),
        MosiLabeledField(
          label: context.l10n.password,
          child: TextField(
            controller: _passwordController,
            enabled: !isBusy,
            obscureText: true,
            onSubmitted: (_) => _signIn(),
            style: mosiFieldTextStyle(),
            decoration: mosiInputDecoration(hintText: context.l10n.password),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          MosiNotice(message: _errorMessage!),
        ],
        const SizedBox(height: 18),
        Row(
          children: [
            Expanded(
              flex: 10,
              child: MosiButton(
                label: context.l10n.signUp,
                background: MosiColors.white,
                height: 54,
                expand: true,
                onPressed: isBusy
                    ? null
                    : () {
                        FocusScope.of(context).unfocus();
                        setState(() => _isRegistering = true);
                      },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              flex: 14,
              child: MosiButton(
                label: context.l10n.login,
                height: 54,
                expand: true,
                loading: _action == _LoginAction.password,
                onPressed: isBusy ? null : _signIn,
              ),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const MosiOrDivider(),
        const SizedBox(height: 14),
        SocialLoginButton(
          key: const Key('login-google-button'),
          label: context.l10n.googleLogin,
          icon: Assets.images.logo.googleG.svg(width: 22, height: 22),
          enabled: !isBusy,
          onPressed: _signInWithGoogle,
        ),
        if (_isAppleSignInAvailable) ...[
          const SizedBox(height: 10),
          SocialLoginButton(
            key: const Key('login-apple-button'),
            label: context.l10n.appleLogin,
            dark: true,
            // Apple 로고는 시각 중심이 살짝 위라 아래로 조금 내려 글자와 맞춥니다.
            icon: const Padding(
              padding: EdgeInsets.only(bottom: 2),
              child: Icon(Icons.apple, size: 24, color: MosiColors.white),
            ),
            enabled: !isBusy,
            onPressed: _signInWithApple,
          ),
        ],
      ],
    );
  }
}

// 구글, 애플 로그인 버튼
class SocialLoginButton extends StatelessWidget {
  const SocialLoginButton({
    super.key,
    required this.label,
    required this.icon,
    required this.enabled,
    required this.onPressed,
    this.dark = false,
  });

  final String label;
  final Widget icon;
  final bool enabled;
  final VoidCallback onPressed;

  /// Apple 버튼처럼 검은 바탕에 흰 글자로 그립니다.
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final background = dark ? MosiColors.ink : MosiColors.white;
    final foreground = dark ? MosiColors.white : MosiColors.navy;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      excludeSemantics: true,
      onTap: enabled ? onPressed : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Material(
          color: background,
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            onTap: enabled ? onPressed : null,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border.all(
                  color: dark ? MosiColors.ink : MosiColors.navy,
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  icon,
                  const SizedBox(width: 10),
                  Text(
                    label,
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 15,
                      weight: FontWeight.w700,
                      color: foreground,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
