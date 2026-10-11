import 'package:project00/platform/localization/platform_localizations.dart';
import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/core/time/server_clock.dart';
import 'package:project00/platform/auth/models/email_link_error_message.dart';
import 'package:project00/platform/auth/models/password_policy.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/legal/signup_terms.dart';
import 'package:project00/platform/auth/services/pending_email_store.dart';
import 'package:project00/platform/auth/widgets/signup_terms_view.dart';
import 'package:project00/platform/auth/widgets/register_step_one.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';

enum RegisterStep {
  /// 약관 동의입니다. 새로 가입을 시작할 때 이메일 입력 전에 한 번 거칩니다.
  terms,
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
    this.consentStore,
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

  /// 가입을 마칠 때까지 약관 동의를 보관하는 곳입니다.
  final SignupConsentStore? consentStore;

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen>
    with WidgetsBindingObserver {
  static const _resendCooldown = Duration(minutes: 5);

  late final OnboardingService _onboardingService;
  late final PendingEmailStore _pendingEmailStore;
  late final SignupConsentStore _consentStore;

  /// 이미 동의했는지 확인하는 동안에는 이메일 단계를 그리지 않습니다.
  bool _checkingConsent = false;
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
  Uri? _queuedEmailLink;
  String? _lastHandledEmailLink;
  bool _canPop = false;
  bool _isLeaving = false;

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
    WidgetsBinding.instance.addObserver(this);
    _onboardingService = widget.onboardingService ?? OnboardingService();
    _pendingEmailStore = widget.pendingEmailStore ?? PendingEmailStore();
    _consentStore = widget.consentStore ?? SignupConsentStore();
    _step = widget.initialStep;
    // 새로 가입을 시작하면 약관 동의부터 받습니다. 이미 동의하고 메일 단계로
    // 넘어갔다가 돌아온 경우에는 다시 묻지 않습니다.
    if (_step == RegisterStep.emailInput && widget.initialEmailLink == null) {
      _checkingConsent = true;
      unawaited(_checkConsent());
    }
    _errorMessage = widget.initialError;
    _setInitialEmail(widget.initialEmail);
    if (widget.initialEmailLink != null) {
      _queueIncomingLink(widget.initialEmailLink!);
    } else if (_step == RegisterStep.awaitingEmailLink ||
        _step == RegisterStep.emailLinkFailed) {
      unawaited(_restorePendingEmail());
    }
  }

  @override
  void didUpdateWidget(covariant RegisterScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    final incomingLink = widget.initialEmailLink;
    if (incomingLink != null &&
        incomingLink.toString() != oldWidget.initialEmailLink?.toString()) {
      _queueIncomingLink(incomingLink);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    setState(() {});
    if (_cooldownSeconds > 0) _startCooldownTicker();
  }

  Future<void> _checkConsent() async {
    final consents = await _consentStore.read();
    if (!mounted) return;
    setState(() {
      _checkingConsent = false;
      if (consents == null && _step == RegisterStep.emailInput) {
        _step = RegisterStep.terms;
      }
    });
  }

  Future<void> _agreeToTerms(SignupConsents consents) async {
    await _consentStore.save(consents);
    if (!mounted) return;
    setState(() {
      _step = RegisterStep.emailInput;
      _errorMessage = null;
    });
  }

  void _setInitialEmail(String? email) {
    final value = email?.trim();
    if (value == null || value.isEmpty) return;
    _emailController.text = value;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _cooldownTimer?.cancel();
    _emailController.dispose();
    _customDomainController.dispose();
    _customDomainFocusNode.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _queueIncomingLink(Uri link) {
    final value = link.toString();
    if (value == _lastHandledEmailLink ||
        value == _queuedEmailLink?.toString()) {
      return;
    }
    _queuedEmailLink = link;
    // addPostFrameCallback을 기다리는 첫 프레임부터 로딩 UI를 보여줍니다.
    if (_action == null) {
      _step = RegisterStep.awaitingEmailLink;
      _action = RegisterAction.completeLink;
      _errorMessage = null;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_processQueuedIncomingLink());
    });
  }

  Future<void> _processQueuedIncomingLink() async {
    if (!mounted ||
        (_action != null && _action != RegisterAction.completeLink)) {
      return;
    }
    final link = _queuedEmailLink;
    if (link == null) return;
    _queuedEmailLink = null;
    _lastHandledEmailLink = link.toString();
    await _completeIncomingLink(link);
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
      setState(() => _errorMessage = context.l10n.invalidEmail);
      return;
    }
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
        _errorMessage = EmailLinkErrorMessage.from(error);
        if (resend) _step = RegisterStep.emailLinkFailed;
      });
    } finally {
      if (mounted) {
        setState(() => _action = null);
        unawaited(_processQueuedIncomingLink());
      }
    }
  }

  Future<void> _completeIncomingLink(Uri link) async {
    if (_action != null && _action != RegisterAction.completeLink) {
      _queuedEmailLink = link;
      return;
    }
    if (_action != RegisterAction.completeLink) {
      setState(() {
        _step = RegisterStep.awaitingEmailLink;
        _action = RegisterAction.completeLink;
        _errorMessage = null;
      });
    }
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
      final message = EmailLinkErrorMessage.from(error);
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
    if (!PasswordPolicy.isValid(password)) {
      setState(() => _errorMessage = PasswordPolicy.requirementsMessage);
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
      // AuthGate가 서버 온보딩 상태에 따라 카드 내용만 교체합니다.
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
    if (_action != null || _isLeaving) return;
    final shouldLeave = await showMosiLeaveDialog(
      context,
      title: '회원가입을 중단할까요?',
      message: _step == RegisterStep.emailInput || _step == RegisterStep.terms
          ? '입력한 이메일은 저장되지 않아요.'
          : '다음에 로그인하면 여기서부터 이어서 할 수 있어요.',
    );
    if (shouldLeave != true || !mounted) return;
    _isLeaving = true;
    // 가입을 그만두면 이 기기에 남긴 약관 동의도 지웁니다. 다음에 같은 기기로
    // 다른 사람이 가입할 때 동의 없이 넘어가지 않게 합니다.
    await _consentStore.clear();
    if (_step != RegisterStep.emailInput && _step != RegisterStep.terms) {
      await _pendingEmailStore.clear();
      await FirebaseAuth.instance.signOut();
    }
    if (!mounted) return;
    final onCancel = widget.onCancel;
    if (onCancel != null) {
      onCancel();
      return;
    }
    if (!mounted) return;
    setState(() => _canPop = true);
    final navigator = Navigator.of(context);
    if (navigator.canPop()) navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) unawaited(_requestBack());
      },
      child: MosiAuthScaffold(
        showTagline: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MosiAuthHeader(
              title: context.l10n.signUp,
              onBack: () => unawaited(_requestBack()),
              steps: signupSteps,
              stepIndex: switch (_step) {
                RegisterStep.terms => 0,
                RegisterStep.settingPassword => 2,
                _ => 1,
              },
            ),
            const SizedBox(height: 16),
            MosiAuthTransition(
              child: _checkingConsent
                  ? const SizedBox(key: ValueKey('checking-consent'))
                  : _step == RegisterStep.terms
                  ? SignupTermsView(
                      key: const ValueKey(RegisterStep.terms),
                      onAgreed: (consents) =>
                          unawaited(_agreeToTerms(consents)),
                    )
                  : RegisterStepOne(
                      key: ValueKey(_step),
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
            ),
          ],
        ),
      ),
    );
  }
}
