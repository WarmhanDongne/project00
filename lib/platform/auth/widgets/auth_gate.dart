import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:project00/platform/auth/models/onboarding_state.dart';
import 'package:project00/platform/auth/screens/login_screen.dart';
import 'package:project00/platform/auth/screens/profile_setup_screen.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/home/home.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({
    super.key,
    this.userChanges,
    this.emailLinks,
    this.initialEmailLink,
    this.onboardingService,
  });

  final Stream<User?>? userChanges;
  final Stream<Uri>? emailLinks;
  final Uri? initialEmailLink;
  final OnboardingService? onboardingService;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final OnboardingService _onboardingService;
  StreamSubscription<Uri>? _emailLinkSubscription;
  Uri? _emailLink;
  String? _emailLinkError;
  String? _reauthenticationEmail;
  String? _watchedOnboardingUid;
  Stream<UserOnboarding?>? _onboardingStream;

  @override
  void initState() {
    super.initState();
    _onboardingService = widget.onboardingService ?? OnboardingService();
    final initialLink = widget.initialEmailLink;
    if (initialLink != null &&
        _onboardingService.isEmailSignInLink(initialLink.toString())) {
      _emailLink = initialLink;
    }
    _emailLinkSubscription = widget.emailLinks?.listen(
      (link) {
        if (!mounted ||
            !_onboardingService.isEmailSignInLink(link.toString())) {
          return;
        }
        setState(() => _emailLink = link);
      },
      onError: (Object error) {
        debugPrint('이메일 링크 수신 오류: $error');
      },
    );
  }

  @override
  void dispose() {
    _emailLinkSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: widget.userChanges ?? FirebaseAuth.instance.userChanges(),
      builder: (context, authSnapshot) {
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return const _AppInitializingView();
        }
        final user = authSnapshot.data;
        if (user == null) {
          _clearOnboardingWatch();
          final link = _emailLink;
          if (link != null) {
            return RegisterScreen(
              initialEmailLink: link,
              onEmailLinkHandled: _handleEmailLink,
            );
          }
          if (_emailLinkError != null) {
            return RegisterScreen(
              initialStep: RegisterStep.emailLinkFailed,
              initialError: _emailLinkError,
              onCancel: () => setState(() => _emailLinkError = null),
            );
          }
          if (_reauthenticationEmail != null) {
            return RegisterScreen(
              initialStep: RegisterStep.awaitingEmailLink,
              initialEmail: _reauthenticationEmail,
              onCancel: () => setState(() => _reauthenticationEmail = null),
            );
          }
          return const LoginScreen();
        }
        if (_emailLink != null) return const _AppInitializingView();

        return StreamBuilder<UserOnboarding?>(
          stream: _watchOnboarding(user.uid),
          builder: (context, onboardingSnapshot) {
            if (onboardingSnapshot.connectionState == ConnectionState.waiting) {
              return const _AppInitializingView();
            }
            if (onboardingSnapshot.hasError) {
              return _GateErrorView(
                message: '회원가입 상태를 불러오지 못했습니다.',
                onRetry: () => setState(() {}),
              );
            }
            final onboarding = onboardingSnapshot.data;
            if (onboarding == null) {
              return _LegacyRecoveryView(service: _onboardingService);
            }
            return switch (onboarding.status) {
              OnboardingStatus.settingPassword => RegisterScreen(
                initialStep: RegisterStep.settingPassword,
                initialEmail: user.email,
                onReauthenticationStarted: (email) {
                  setState(() => _reauthenticationEmail = email);
                },
              ),
              OnboardingStatus.settingProfile => const ProfileSetupScreen(),
              OnboardingStatus.complete => const Home(),
            };
          },
        );
      },
    );
  }

  Stream<UserOnboarding?> _watchOnboarding(String uid) {
    if (_watchedOnboardingUid != uid || _onboardingStream == null) {
      _watchedOnboardingUid = uid;
      _onboardingStream = _onboardingService.watch(uid);
    }
    return _onboardingStream!;
  }

  void _clearOnboardingWatch() {
    _watchedOnboardingUid = null;
    _onboardingStream = null;
  }

  void _handleEmailLink(String? error) {
    if (!mounted) return;
    setState(() {
      _emailLink = null;
      _emailLinkError = error;
      if (error == null) _reauthenticationEmail = null;
    });
  }
}

class _LegacyRecoveryView extends StatefulWidget {
  const _LegacyRecoveryView({required this.service});

  final OnboardingService service;

  @override
  State<_LegacyRecoveryView> createState() => _LegacyRecoveryViewState();
}

class _LegacyRecoveryViewState extends State<_LegacyRecoveryView> {
  Object? _error;

  @override
  void initState() {
    super.initState();
    unawaited(_recover());
  }

  Future<void> _recover() async {
    try {
      await widget.service.recoverLegacy();
    } on Object catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error == null) return const _AppInitializingView();
    final message = _error is AuthServiceException
        ? (_error! as AuthServiceException).message
        : '계정 진행 상태를 복구하지 못했습니다.';
    return _GateErrorView(
      message: message,
      onRetry: () {
        setState(() => _error = null);
        unawaited(_recover());
      },
    );
  }
}

class _GateErrorView extends StatelessWidget {
  const _GateErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return PlatformAuthShell(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PlatformNotice(message: message, style: PlatformNoticeStyle.danger),
          const SizedBox(height: 12),
          PlatformButton(label: '다시 시도', onPressed: onRetry),
          const SizedBox(height: 8),
          TextButton(
            onPressed: FirebaseAuth.instance.signOut,
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}

class _AppInitializingView extends StatelessWidget {
  const _AppInitializingView();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
