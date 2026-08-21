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

  /// 로그인 상태 스트림입니다. **반드시 한 번만 만들어 보관합니다.**
  ///
  /// 빌드마다 `userChanges()`를 새로 만들면 회전 같은 평범한 리빌드에도
  /// StreamBuilder가 구독을 갈아 끼우며 `waiting`으로 돌아가, 화면 전체가
  /// 스피너로 접혔다 펴집니다. 그 과정에서 아래 온보딩 구독이 다시 마운트되어
  /// `Bad state: Stream has already been listened to.`로 터졌습니다(회전 크래시).
  late final Stream<User?> _userChanges;

  StreamSubscription<Uri>? _emailLinkSubscription;
  Uri? _emailLink;
  String? _emailLinkError;
  String? _reauthenticationEmail;

  //=======================온보딩 구독==============================
  // 온보딩 스트림(`async*`)은 **한 번만 들을 수 있습니다.** StreamBuilder에
  // 캐시된 스트림을 넘기면 위젯이 다시 마운트되는 순간 두 번째 listen이 되어
  // 터집니다. 그래서 StreamBuilder 대신 여기서 직접 한 번 구독하고, 최근 값을
  // 상태로 들고 있다가 그립니다. 다시 마운트돼도 구독은 그대로입니다.
  String? _watchedOnboardingUid;
  StreamSubscription<UserOnboarding?>? _onboardingSubscription;
  UserOnboarding? _onboarding;
  bool _onboardingLoaded = false;
  bool _onboardingFailed = false;

  @override
  void initState() {
    super.initState();
    _onboardingService = widget.onboardingService ?? OnboardingService();
    _userChanges = widget.userChanges ?? FirebaseAuth.instance.userChanges();
    final initialLink = widget.initialEmailLink;
    if (initialLink != null &&
        _onboardingService.isEmailSignInLink(initialLink.toString())) {
      _emailLink = initialLink;
    }
    _subscribeToEmailLinks();
  }

  @override
  void didUpdateWidget(covariant AuthGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (identical(oldWidget.emailLinks, widget.emailLinks)) return;
    unawaited(_emailLinkSubscription?.cancel());
    _subscribeToEmailLinks();
  }

  @override
  void dispose() {
    _emailLinkSubscription?.cancel();
    _onboardingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _userChanges,
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
              onboardingService: _onboardingService,
            );
          }
          if (_emailLinkError != null) {
            return RegisterScreen(
              initialStep: RegisterStep.emailLinkFailed,
              initialError: _emailLinkError,
              onCancel: () => setState(() => _emailLinkError = null),
              onboardingService: _onboardingService,
            );
          }
          if (_reauthenticationEmail != null) {
            return RegisterScreen(
              initialStep: RegisterStep.awaitingEmailLink,
              initialEmail: _reauthenticationEmail,
              onCancel: () => setState(() => _reauthenticationEmail = null),
              onboardingService: _onboardingService,
            );
          }
          return const LoginScreen();
        }
        if (_emailLink != null) return const _AppInitializingView();

        _ensureOnboardingWatch(user.uid);
        if (_onboardingFailed) {
          return _GateErrorView(
            message: '회원가입 상태를 불러오지 못했습니다.',
            onRetry: _retryOnboardingWatch,
          );
        }
        if (!_onboardingLoaded) return const _AppInitializingView();
        final onboarding = _onboarding;
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
            onboardingService: _onboardingService,
          ),
          OnboardingStatus.settingProfile => const ProfileSetupScreen(),
          OnboardingStatus.complete => const Home(),
        };
      },
    );
  }

  /// 이 uid의 온보딩 상태를 구독합니다. 이미 같은 uid를 듣고 있으면
  /// 아무것도 하지 않습니다. 빌드 중에 불러도 안전합니다 — listen 자체는
  /// 콜백을 즉시 부르지 않고, 값은 다음 이벤트 루프에서 setState로 반영됩니다.
  void _ensureOnboardingWatch(String uid) {
    if (_watchedOnboardingUid == uid && _onboardingSubscription != null) {
      return;
    }
    unawaited(_onboardingSubscription?.cancel());
    _watchedOnboardingUid = uid;
    _onboarding = null;
    _onboardingLoaded = false;
    _onboardingFailed = false;
    // 스트림은 매번 새로 만듭니다(async*는 한 번만 들을 수 있습니다).
    _onboardingSubscription = _onboardingService
        .watch(uid)
        .listen(
          (onboarding) {
            if (!mounted) return;
            setState(() {
              _onboarding = onboarding;
              _onboardingLoaded = true;
            });
          },
          onError: (Object error) {
            debugPrint('온보딩 상태 수신 오류: $error');
            if (!mounted) return;
            setState(() => _onboardingFailed = true);
          },
        );
  }

  void _retryOnboardingWatch() {
    final uid = _watchedOnboardingUid;
    // 구독 자체를 새로 만들어야 다시 시도가 됩니다. uid를 지워 두면
    // 다음 빌드의 _ensureOnboardingWatch가 처음부터 다시 구독합니다.
    unawaited(_onboardingSubscription?.cancel());
    _onboardingSubscription = null;
    _watchedOnboardingUid = null;
    setState(() {});
    if (uid != null) _ensureOnboardingWatch(uid);
  }

  void _clearOnboardingWatch() {
    unawaited(_onboardingSubscription?.cancel());
    _onboardingSubscription = null;
    _watchedOnboardingUid = null;
    _onboarding = null;
    _onboardingLoaded = false;
    _onboardingFailed = false;
  }

  void _subscribeToEmailLinks() {
    _emailLinkSubscription = widget.emailLinks?.listen(
      _handleIncomingEmailLink,
      onError: (Object error) {
        debugPrint('이메일 링크 수신 오류: $error');
      },
    );
  }

  void _handleIncomingEmailLink(Uri link) {
    if (!mounted) return;
    final value = link.toString();
    if (!_onboardingService.isEmailSignInLink(value)) {
      debugPrint(
        '이메일 인증이 아닌 링크를 무시했습니다: '
        '${link.scheme}://${link.host}${link.path}',
      );
      return;
    }
    if (_emailLink?.toString() == value) return;

    // LoginScreen에서 push한 RegisterScreen이 루트 AuthGate를 가리고
    // 있을 수 있습니다. 인증 링크의 단일 소유자인 AuthGate로 복귀해
    // 새 상태가 즉시 보이게 합니다.
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() {
      _emailLink = link;
      _emailLinkError = null;
    });
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
