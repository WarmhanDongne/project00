import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/services/pending_email_store.dart';
import 'package:project00/platform/auth/widgets/register_step_one.dart';
import 'package:project00/platform/widgets/platform_components.dart';

enum RegisterStep {
  emailInput,
  awaitingEmailLink,
  emailLinkFailed,
  settingPassword,
}

enum RegisterAction { sendEmail, resendEmail, completeLink, setPassword }

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({
    super.key,
    this.initialStep = RegisterStep.emailInput,
    this.initialEmail,
    this.initialEmailLink,
    this.initialError,
    this.onEmailLinkHandled,
    this.onCancel,
    this.onReauthenticationStarted,
    this.onboardingService,
    this.pendingEmailStore,
  });

  final RegisterStep initialStep;
  final String? initialEmail;
  final Uri? initialEmailLink;
  final String? initialError;
  final ValueChanged<String?>? onEmailLinkHandled;
  final VoidCallback? onCancel;
  final ValueChanged<String>? onReauthenticationStarted;
  final OnboardingService? onboardingService;
  final PendingEmailStore? pendingEmailStore;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const _resendCooldown = Duration(minutes: 5);

  late final OnboardingService _onboardingService;
  late final PendingEmailStore _pendingEmailStore;
  final _emailController = TextEditingController();
  final _customDomainController = TextEditingController();
  final _customDomainFocusNode = FocusNode();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  late RegisterStep _step;
  RegisterAction? _action;
  String _emailDomain = 'gmail.com';
  bool _isCustomDomain = false;
  String? _errorMessage;
  DateTime? _cooldownUntil;
  Timer? _cooldownTimer;

  int get _cooldownSeconds {
    final until = _cooldownUntil;
    if (until == null) return 0;
    final seconds =
        (until.millisecondsSinceEpoch - ServerClock.nowMillis()) ~/ 1000;
    return seconds.clamp(0, _resendCooldown.inSeconds);
  }

  @override
  void initState() {
    super.initState();
    _onboardingService = widget.onboardingService ?? OnboardingService();
    _pendingEmailStore = widget.pendingEmailStore ?? PendingEmailStore();
    _step = widget.initialStep;
    _errorMessage = widget.initialError;
    _setInitialEmail(widget.initialEmail);
    if (widget.initialEmailLink != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_completeIncomingLink(widget.initialEmailLink!));
      });
    } else if (_step == RegisterStep.awaitingEmailLink ||
        _step == RegisterStep.emailLinkFailed) {
      unawaited(_restorePendingEmail());
    }
  }

  void _setInitialEmail(String? email) {
    final value = email?.trim();
    if (value == null || value.isEmpty) return;
    _emailController.text = value;
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _customDomainController.dispose();
    _customDomainFocusNode.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _restorePendingEmail() async {
    final pending = await _pendingEmailStore.read();
    if (!mounted || pending == null) return;
    setState(() {
      _emailController.text = pending.email;
      _cooldownUntil = pending.cooldownUntil;
    });
    _startCooldownTicker();
  }

  String? _normalizedEmail() {
    final input = _emailController.text.trim().toLowerCase();
    if (input.contains('@')) return input;
    final domain = _isCustomDomain
        ? _customDomainController.text.trim().toLowerCase()
        : _emailDomain;
    return '$input@$domain';
  }

  bool _isValidEmail(String email) =>
      RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);

  Future<void> _sendEmail({bool resend = false}) async {
    if (_action != null) return;
    final email = _normalizedEmail()!;
    if (!_isValidEmail(email)) {
      setState(() => _errorMessage = '이메일 형식이 올바르지 않습니다.');
      return;
    }
    if (resend && _cooldownSeconds > 0) return;

    setState(() {
      _action = resend ? RegisterAction.resendEmail : RegisterAction.sendEmail;
      _errorMessage = null;
    });
    try {
      await _onboardingService.sendEmailLink(email);
      final cooldownUntil = DateTime.fromMillisecondsSinceEpoch(
        ServerClock.nowMillis() + _resendCooldown.inMilliseconds,
      );
      await _pendingEmailStore.save(email: email, cooldownUntil: cooldownUntil);
      if (!mounted) return;
      setState(() {
        _emailController.text = email;
        _cooldownUntil = cooldownUntil;
        _step = RegisterStep.awaitingEmailLink;
      });
      _startCooldownTicker();
    } on AuthServiceException catch (error) {
      if (!mounted) return;
      setState(() {
        _errorMessage = _emailErrorMessage(error);
        if (resend) _step = RegisterStep.emailLinkFailed;
      });
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  Future<void> _completeIncomingLink(Uri link) async {
    if (_action != null) return;
    setState(() {
      _step = RegisterStep.awaitingEmailLink;
      _action = RegisterAction.completeLink;
      _errorMessage = null;
    });
    try {
      final pending = await _pendingEmailStore.read();
      if (pending == null) {
        throw const AuthServiceException(
          'missing-email',
          '인증을 요청한 기기에서 다시 시도해주세요.',
        );
      }
      _emailController.text = pending.email;
      await _onboardingService.completeEmailLink(
        email: pending.email,
        link: link.toString(),
      );
      await _pendingEmailStore.clear();
      widget.onEmailLinkHandled?.call(null);
      if (!mounted) return;
      setState(() => _step = RegisterStep.settingPassword);
    } on AuthServiceException catch (error) {
      await FirebaseAuth.instance.signOut();
      final message = _emailErrorMessage(error);
      widget.onEmailLinkHandled?.call(message);
      if (!mounted) return;
      setState(() {
        _step = RegisterStep.emailLinkFailed;
        _errorMessage = message;
      });
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  Future<void> _setPassword() async {
    if (_action != null) return;
    final password = _passwordController.text;
    if (password.length < 6 ||
        !RegExp('[A-Za-z]').hasMatch(password) ||
        !RegExp('[0-9]').hasMatch(password)) {
      setState(() => _errorMessage = '비밀번호는 영문과 숫자를 포함해 6자 이상이어야 합니다.');
      return;
    }
    if (password != _confirmPasswordController.text) {
      setState(() => _errorMessage = '비밀번호가 일치하지 않습니다.');
      return;
    }

    setState(() {
      _action = RegisterAction.setPassword;
      _errorMessage = null;
    });
    try {
      await _onboardingService.setPasswordAndAdvance(password);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
    } on AuthServiceException catch (error) {
      if (error.code == 'requires-recent-login') {
        await _restartEmailVerification();
      } else if (mounted) {
        setState(() => _errorMessage = error.message);
      }
    } finally {
      if (mounted) setState(() => _action = null);
    }
  }

  Future<void> _restartEmailVerification() async {
    final email = _emailController.text.trim();
    try {
      await _onboardingService.sendEmailLink(email);
      final cooldownUntil = DateTime.fromMillisecondsSinceEpoch(
        ServerClock.nowMillis() + _resendCooldown.inMilliseconds,
      );
      await _pendingEmailStore.save(email: email, cooldownUntil: cooldownUntil);
      widget.onReauthenticationStarted?.call(email);
      if (mounted) {
        setState(() {
          _cooldownUntil = cooldownUntil;
          _step = RegisterStep.awaitingEmailLink;
          _errorMessage = null;
        });
        _startCooldownTicker();
      }
      await FirebaseAuth.instance.signOut();
    } on AuthServiceException catch (error) {
      if (mounted) {
        setState(() {
          _errorMessage = '보안을 위해 이메일 인증이 다시 필요합니다. ${error.message}';
        });
      }
    }
  }

  void _startCooldownTicker() {
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() {});
      if (_cooldownSeconds <= 0) timer.cancel();
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

  Future<void> _requestBack() async {
    if (_action != null) return;
    if (_step == RegisterStep.emailInput) {
      Navigator.of(context).maybePop();
      return;
    }
    final shouldLeave = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('회원가입을 중단할까요?'),
        content: const Text('다시 로그인하면 완료하지 못한 단계부터 이어집니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('계속하기'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('중단하기'),
          ),
        ],
      ),
    );
    if (shouldLeave != true || !mounted) return;
    await _pendingEmailStore.clear();
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    widget.onCancel?.call();
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _emailErrorMessage(AuthServiceException error) => switch (error.code) {
    'invalid-email' => '이메일 형식이 올바르지 않습니다.',
    'invalid-action-code' ||
    'expired-action-code' => '인증 링크가 만료되었거나 이미 사용되었습니다.',
    'network-request-failed' => '네트워크 연결을 확인해주세요.',
    _ => error.message,
  };

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestBack());
      },
      child: PlatformAuthShell(
        maxWidth: 390,
        showBack: true,
        onBackPressed: () => unawaited(_requestBack()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '회원가입',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            RegisterStepOne(
              emailController: _emailController,
              customDomainController: _customDomainController,
              customDomainFocusNode: _customDomainFocusNode,
              passwordController: _passwordController,
              confirmPasswordController: _confirmPasswordController,
              emailDomain: _emailDomain,
              isCustomDomain: _isCustomDomain,
              step: _step,
              action: _action,
              cooldownSeconds: _cooldownSeconds,
              errorMessage: _errorMessage,
              onDomainChanged: _changeDomain,
              onSendEmail: _sendEmail,
              onResendEmail: () => _sendEmail(resend: true),
              onSetPassword: _setPassword,
            ),
          ],
        ),
      ),
    );
  }
}
