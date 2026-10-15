import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/gen/assets.gen.dart';
import 'package:project00/platform/auth/providers/auth_provider.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';

enum _LoginAction { password, passwordReset, google, apple, guest }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.authService});

  final FirebaseAuthService? authService;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  late final FirebaseAuthService _authService;
  late final AuthProvider _authProvider;
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _customDomainController = TextEditingController();
  final _customDomainFocusNode = FocusNode();
  _LoginAction? _action;
  String? _errorMessage;
  bool _isCustomDomain = false;
  String _emailDomain = 'gmail.com';
  bool _isRegistering = false;
  bool _isResettingPassword = false;
  bool _passwordResetSent = false;
  String? _resetTargetEmail;

  @override
  void initState() {
    super.initState();
    _authService = widget.authService ?? FirebaseAuthService();
    _authProvider = AuthProvider(authService: _authService);
  }

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
      // 미인증 계정도 AuthGate의 이메일 확인 화면에서 가입을 이어갑니다.
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

  Future<void> _signInAsGuest() async {
    if (_action != null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _action = _LoginAction.guest;
      _errorMessage = null;
    });
    try {
      await _authService.signInAsGuest();
    } on AuthServiceException catch (error) {
      if (mounted) setState(() => _errorMessage = error.message);
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  void _openPasswordReset() {
    if (_action != null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isResettingPassword = true;
      _passwordResetSent = false;
      _resetTargetEmail = null;
      _errorMessage = null;
    });
  }

  void _closePasswordReset() {
    if (_action != null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _isResettingPassword = false;
      _passwordResetSent = false;
      _resetTargetEmail = null;
      _errorMessage = null;
    });
  }

  Future<void> _sendPasswordResetEmail() async {
    if (_action != null) return;
    final email = _email();
    if (!RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email)) {
      setState(() => _errorMessage = context.l10n.invalidEmail);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _action = _LoginAction.passwordReset;
      _errorMessage = null;
    });
    try {
      await _authService.sendPasswordResetEmail(email: email);
      if (!mounted) return;
      setState(() {
        _passwordResetSent = true;
        _resetTargetEmail = email;
      });
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(
        () => _errorMessage = switch (error.code) {
          'invalid-email' => context.l10n.invalidEmail,
          'network-request-failed' => context.l10n.checkNetwork,
          'too-many-requests' => context.l10n.tooManyRequests,
          _ => context.l10n.passwordResetFailed,
        },
      );
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  // _signIn에서 사용
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
        _errorMessage =
            _authProvider.errorMessage?.localized ??
            GameLocale.select(
              ko: '구글 로그인을 완료하지 못했습니다.',
              en: 'Google sign-in could not be completed.',
              zhHans: '无法完成 Google 登录。',
              zhHant: '無法完成 Google 登入。',
            );
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
            : _isResettingPassword
            ? KeyedSubtree(
                key: ValueKey(
                  _passwordResetSent
                      ? 'password-reset-sent'
                      : 'password-reset-request',
                ),
                child: _buildPasswordReset(context),
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
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const Key('forgot-password-button'),
            onPressed: isBusy ? null : _openPasswordReset,
            style: TextButton.styleFrom(
              foregroundColor: MosiColors.navy,
              padding: const EdgeInsets.fromLTRB(8, 8, 0, 4),
              minimumSize: const Size(0, 36),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              textStyle: MosiFonts.sans(
                locale: Localizations.maybeLocaleOf(context),
                size: 13,
                weight: FontWeight.w700,
              ),
            ),
            child: Text(context.l10n.forgotPassword),
          ),
        ),
        if (_errorMessage != null) ...[
          const SizedBox(height: 10),
          MosiNotice(message: _errorMessage!),
        ],
        const SizedBox(height: 14),
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
        MosiButton(
          key: const Key('login-guest-button'),
          label: context.l10n.guestLogin,
          background: MosiColors.white,
          height: 50,
          expand: true,
          loading: _action == _LoginAction.guest,
          onPressed: isBusy ? null : _signInAsGuest,
        ),
        const SizedBox(height: 10),
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

  Widget _buildPasswordReset(BuildContext context) {
    final isBusy = _action != null;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MosiAuthHeader(
          title: _passwordResetSent
              ? context.l10n.resetEmailSentTitle
              : context.l10n.resetPasswordTitle,
          onBack: _closePasswordReset,
        ),
        const SizedBox(height: 18),
        if (_passwordResetSent) ...[
          Center(
            child: Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MosiColors.lime,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: MosiColors.ink, width: 3),
                boxShadow: const [
                  BoxShadow(color: MosiColors.navy, offset: Offset(5, 5)),
                ],
              ),
              child: const Icon(
                Icons.mark_email_read_outlined,
                size: 36,
                color: MosiColors.navy,
              ),
            ),
          ),
          const SizedBox(height: 18),
          MosiNotice(
            tone: MosiNoticeTone.success,
            message: context.l10n.resetEmailSentDescription,
          ),
          const SizedBox(height: 12),
          Text(
            _resetTargetEmail ?? _email(),
            key: const Key('password-reset-target-email'),
            textAlign: TextAlign.center,
            style: MosiFonts.sans(
              locale: Localizations.maybeLocaleOf(context),
              size: 15,
              weight: FontWeight.w700,
              color: MosiColors.navy,
            ),
          ),
        ] else ...[
          Text(
            context.l10n.resetPasswordDescription,
            style: MosiFonts.sans(
              locale: Localizations.maybeLocaleOf(context),
              size: 14,
              weight: FontWeight.w500,
              color: MosiColors.navyDim,
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
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
        ],
        if (_errorMessage != null) ...[
          const SizedBox(height: 14),
          MosiNotice(message: _errorMessage!),
        ],
        const SizedBox(height: 20),
        MosiButton(
          key: const Key('send-password-reset-button'),
          label: _passwordResetSent
              ? context.l10n.resendResetEmail
              : context.l10n.sendResetEmail,
          height: 54,
          expand: true,
          loading: _action == _LoginAction.passwordReset,
          onPressed: isBusy ? null : _sendPasswordResetEmail,
        ),
        const SizedBox(height: 12),
        MosiButton(
          key: const Key('back-to-login-button'),
          label: context.l10n.backToLogin,
          background: MosiColors.white,
          height: 50,
          expand: true,
          onPressed: isBusy ? null : _closePasswordReset,
        ),
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
