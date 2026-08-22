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
    this.onAuthRestoreTimeout,
  });

  final Stream<User?>? userChanges;
  final Stream<Uri>? emailLinks;
  final Uri? initialEmailLink;
  final OnboardingService? onboardingService;

  /// 저장된 로그인 정보를 제때 복원하지 못했을 때 할 일입니다.
  ///
  /// 기본값은 세션 비우기(로그아웃)입니다. 시험에서 갈아 끼웁니다.
  final VoidCallback? onAuthRestoreTimeout;

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
          // 기기에 저장된 로그인 정보를 복원하는 중입니다. 여기서 멈추면
          // 저장된 세션을 읽지 못하는 상태이므로, 다시 로그인할 길을 엽니다.
          return _AppInitializingView(
            step: '로그인 상태 확인',
            onTimeout: _handleAuthRestoreTimeout,
          );
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
        if (_emailLink != null) {
          return const _AppInitializingView(step: '이메일 링크 처리');
        }

        _ensureOnboardingWatch(user.uid);
        if (_onboardingFailed) {
          return _GateErrorView(
            message: '회원가입 상태를 불러오지 못했습니다.',
            onRetry: _retryOnboardingWatch,
          );
        }
        if (!_onboardingLoaded) {
          // 확정(2026-08): **끝나지 않는 스피너를 만들지 않습니다.** 회원가입
          // 상태가 제때 오지 않으면(규칙 거부·오프라인·문서 없음) 그대로 굳는
          // 대신 다시 시도할 화면을 보여 줍니다.
          return _AppInitializingView(
            step: '회원가입 상태 확인',
            onTimeout: () {
              if (mounted) setState(() => _onboardingFailed = true);
            },
          );
        }
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

  /// 저장된 로그인 정보를 복원하지 못하고 멈춘 경우입니다.
  ///
  /// 기기 키체인에 남은 세션을 읽을 수 없을 때(앱 번들 id·서명 팀이 바뀐 뒤에
  /// 일어납니다) 스트림이 아무 값도 주지 않고 멈춥니다. 그대로 두면 영원히
  /// 스피너라, 세션을 비워 로그인 화면으로 되돌립니다.
  void _handleAuthRestoreTimeout() {
    debugPrint('[auth_gate] 로그인 상태 복원이 지연됩니다. 저장된 세션을 비웁니다.');
    final onTimeout = widget.onAuthRestoreTimeout;
    if (onTimeout != null) {
      onTimeout();
      return;
    }
    unawaited(FirebaseAuth.instance.signOut());
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

  /// 복구를 부르고도 상태가 바뀌지 않으면(문서를 앱이 못 읽는 값으로 쓰는 등)
  /// 여기서 멈춥니다. 그래서 시간 제한을 두고 다시 시도 화면으로 넘깁니다.
  bool _timedOut = false;

  @override
  Widget build(BuildContext context) {
    if (_error == null && !_timedOut) {
      return _AppInitializingView(
        step: '계정 상태 복구',
        onTimeout: () {
          if (mounted) setState(() => _timedOut = true);
        },
      );
    }
    final message = _error is AuthServiceException
        ? (_error! as AuthServiceException).message
        : '계정 진행 상태를 복구하지 못했습니다.';
    return _GateErrorView(
      message: _timedOut && _error == null
          ? '계정 진행 상태를 확인하지 못했습니다. 다시 시도하거나 로그아웃해 주세요.'
          : message,
      onRetry: () {
        setState(() {
          _error = null;
          _timedOut = false;
        });
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
            // 누를 때 찾습니다. 빌드할 때 찾으면 Firebase 준비가 늦거나 실패한
            // 상황에서 **이 오류 화면 자체가 다시 터집니다.**
            onPressed: () => unawaited(FirebaseAuth.instance.signOut()),
            child: const Text('로그아웃'),
          ),
        ],
      ),
    );
  }
}

/// 앱을 준비하는 동안 보여 주는 화면입니다.
///
/// [onTimeout]을 주면 [timeout] 뒤에 한 번 알려 줍니다. **스피너가 영원히 도는
/// 상태를 남기지 않기 위한 장치입니다** — 무엇을 기다리다 멈췄는지는 [step]으로
/// 화면에 적어, 기기에서 바로 원인을 알 수 있게 합니다.
class _AppInitializingView extends StatefulWidget {
  const _AppInitializingView({required this.step, this.onTimeout});

  /// 지금 기다리는 일입니다(예: `회원가입 상태 확인`).
  final String step;

  final VoidCallback? onTimeout;

  /// 이 시간이 지나면 기다리기를 멈춥니다.
  static const Duration timeout = Duration(seconds: 8);

  @override
  State<_AppInitializingView> createState() => _AppInitializingViewState();
}

class _AppInitializingViewState extends State<_AppInitializingView> {
  Timer? _timer;
  Timer? _slowTimer;

  /// 오래 걸리는 중임을 알리는 문구를 띄울지입니다.
  bool _isSlow = false;

  /// 문구를 띄우기까지 기다리는 시간입니다.
  static const Duration _slowAfter = Duration(seconds: 3);

  @override
  void initState() {
    super.initState();
    _startWaiting();
  }

  /// 기다리는 일이 바뀌면 **시계를 처음부터 다시 셉니다.**
  ///
  /// 같은 자리에 이 화면이 연달아 나오면(로그인 확인 → 회원가입 확인) Flutter가
  /// 같은 State를 그대로 씁니다. 그때 시계를 새로 세지 않으면 앞 단계에서 켠
  /// 시계가 다음 단계에서 터지고, 앞 단계의 할 일(세션 비우기)이 엉뚱하게
  /// 실행됩니다. 실제로 회원가입 상태를 기다리던 중에 로그아웃이 됐습니다.
  @override
  void didUpdateWidget(covariant _AppInitializingView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.step == oldWidget.step) return;
    _timer?.cancel();
    _slowTimer?.cancel();
    _isSlow = false;
    _startWaiting();
  }

  void _startWaiting() {
    _slowTimer = Timer(_slowAfter, () {
      if (mounted) setState(() => _isSlow = true);
    });
    _timer = null;
    final onTimeout = widget.onTimeout;
    if (onTimeout == null) return;
    // 시계가 터지는 순간의 할 일을 씁니다(위젯이 갈아 끼워질 수 있습니다).
    _timer = Timer(
      _AppInitializingView.timeout,
      () => widget.onTimeout?.call(),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    _slowTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            if (_isSlow) ...[
              const SizedBox(height: 16),
              Text(
                '${widget.step} 중…',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
