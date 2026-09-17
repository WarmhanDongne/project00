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
import 'package:game_kit/template_game.dart';
import 'package:project00/platform/widgets/platform_components.dart';

//==============================================================================
// Screen determine
//==============================================================================
/*
- 문제점: 파일 내 프라이빗 메서드로 인해 코드가 길다. 
- 리팩토링 요소: 다른 파이어베이스 구독 메서드와 통합해 외부로 뺄 것, 빌드 코드 부분 줄일 것
- 인증 상태 관찰: 파베 userChanges()를 구독해 로그인, 로그아웃을 화면에 반영한다.
- 온보딩 상태 관찰: 현재 UID의 온보딩 상태를 구독하고, 로그아웃하거나 UID가 바뀌면 기존 구독
을 정리한다.
- 이메일 링크 수신과 전달: 앱 최초 실행 및 실행 중 받은 링크를 처리 화면에 넘긴다. 가입 화면
이 별도 경로로 열려 있으면 루트로 돌아와 링크 처리 상태를 보여준다.
- 기존 계정 복구 연결: 온보딩 문서가 없으면 OnboardingService.recoverLegacy()를 호출한다.
- 대기, 오류 처리: 로그인 복원, 온보딩 조회, 계정 복구가 지연될 대 타임아웃과 복구 경로를
제공한다. 로그인 복원 타임아웃의 기본 동작은 로그아웃이다. 
*/

class AuthGate extends StatefulWidget {
  //==============================[ 외부에서 받을 설정 정의 ]======================
  const AuthGate({
    super.key,
    this.userChanges,
    this.emailLinks,
    this.initialEmailLink,
    this.onboardingService,
    this.onAuthRestoreTimeout,
    this.gameCatalog = const EmptyGameCatalog(),
  });

  final Stream<User?>? userChanges;
  final Stream<Uri>? emailLinks;
  final Uri? initialEmailLink;
  final OnboardingService? onboardingService;
  final GameCatalog gameCatalog;

  /// 저장된 로그인 정보를 제때 복원하지 못했을 때 할 일입니다.
  ///
  /// 기본값은 세션 비우기(로그아웃)입니다. 시험에서 갈아 끼웁니다.
  final VoidCallback? onAuthRestoreTimeout;

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  //=================================[ 정보 보관 및 관리 ]========================
  late final OnboardingService _onboardingService;

  // 리빌드마다 인증 스트림 구독이 교체되지 않도록
  // initState에서 한 번 초기화해 보관
  late final Stream<User?> _userChanges;

  StreamSubscription<Uri>? _emailLinkSubscription;
  Uri? _emailLink;
  String? _emailLinkError;
  String? _reauthenticationEmail;

  //=======================[ onboarding subscribe ]=======================================
  // 단일 구독 스트림을 중복 구독하지 않도록 State에서 구독을 관리합니다.
  // 수신한 최신 온보딩 상태를 보관해 화면 분기에 사용합니다.
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

  //[스트림 구독 관리] emailLinks 스트림 변경 시 새 스트림 구독
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
        // 로딩 화면
        if (authSnapshot.connectionState == ConnectionState.waiting) {
          return _AppInitializingView(
            step: '로그인 상태 확인',
            onTimeout: _handleAuthRestoreTimeout,
          );
        }
        final user = authSnapshot.data;
        //[로그인 화면 진입: 로그인된 사용자가 없는 경우]
        if (user == null) {
          _clearOnboardingWatch();
          final link = _emailLink;
          // 이메일 인증 화면 리턴
          if (link != null) {
            return RegisterScreen(
              initialEmailLink: link,
              onEmailLinkHandled: _handleEmailLink,
              onboardingService: _onboardingService,
            );
          }
          // 이메일 인증 실패 시 오류 내용 표시
          if (_emailLinkError != null) {
            //
            return RegisterScreen(
              initialStep: RegisterStep.emailLinkFailed,
              initialError: _emailLinkError,
              onCancel: () => setState(() => _emailLinkError = null),
              onboardingService: _onboardingService,
            );
          }
          // 이메일 재인증 링크 대기 화면
          if (_reauthenticationEmail != null) {
            return RegisterScreen(
              initialStep: RegisterStep.awaitingEmailLink,
              initialEmail: _reauthenticationEmail,
              onCancel: () => setState(() => _reauthenticationEmail = null),
              onboardingService: _onboardingService,
            );
          }
          // 처리할 인증 흐름 없을 시 로그인 화면 리턴
          return const LoginScreen();
        }
        // 이메일 링크 처리 대기
        if (_emailLink != null) {
          return const _AppInitializingView(step: '이메일 링크 처리');
        }

        // 현재 사용자의 온보딩 상태 구독
        _ensureOnboardingWatch(user.uid);
        if (_onboardingFailed) {
          return _GateErrorView(
            message: '회원가입 상태를 불러오지 못했습니다.',
            onRetry: _retryOnboardingWatch,
          );
        }
        // 오류 화면과 재시도 버튼 표시
        if (!_onboardingLoaded) {
          return _AppInitializingView(
            step: '회원가입 상태 확인',
            onTimeout: () {
              if (mounted) setState(() => _onboardingFailed = true);
            },
          );
        }
        final onboarding = _onboarding;
        // 계정 상태 복구 시도
        if (onboarding == null) {
          return _LegacyRecoveryView(service: _onboardingService);
        }
        // 온보딩 상태에 맞는 최종 화면 반환
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
          OnboardingStatus.complete => Home(gameCatalog: widget.gameCatalog),
        };
      },
    );
  }

  //===============================[ user sign state subscribe ]================
  // 해당 사용자의 가입 상태를 구독, 이미 구독 중이면 유지.
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

  // =============================[ call back or log out ]======================
  // 로그인 복원이 지연되면 지정된 콜백을 실행하거나 로그아웃한다.
  void _handleAuthRestoreTimeout() {
    debugPrint('[auth_gate] 로그인 상태 복원이 지연됩니다. 저장된 세션을 비웁니다.');
    final onTimeout = widget.onAuthRestoreTimeout;
    if (onTimeout != null) {
      onTimeout();
      return;
    }
    unawaited(FirebaseAuth.instance.signOut());
  }

  //=============================[ re-subscribe ]===============================
  // 기존 가입 상태 구독 정리 후 재구독.
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

  //===========================[ subscribe cancel ]=============================
  // 가입 상태 구독을 취소하고 관련 정보를 초기화한다.
  void _clearOnboardingWatch() {
    unawaited(_onboardingSubscription?.cancel());
    _onboardingSubscription = null;
    _watchedOnboardingUid = null;
    _onboarding = null;
    _onboardingLoaded = false;
    _onboardingFailed = false;
  }

  //============================[ email link subscribe ]========================
  // 앱 실행 중 이메일 인증 링크 구독.
  void _subscribeToEmailLinks() {
    _emailLinkSubscription = widget.emailLinks?.listen(
      _handleIncomingEmailLink,
      onError: (Object error) {
        debugPrint('이메일 링크 수신 오류: $error');
      },
    );
  }

  //============================[ back to gate ]================================
  // 유효한 이메일 인증 링크를 저장하고 인증 게이트로 돌아옵니다.
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

  //============================[ result ]======================================
  // 이메일 링크 처리가 끝나면 링크를 비우고 처리 결과를 반영한다.
  void _handleEmailLink(String? error) {
    if (!mounted) return;
    setState(() {
      _emailLink = null;
      _emailLinkError = error;
      if (error == null) _reauthenticationEmail = null;
    });
  }
}

//==========================[ recovery screen ]=================================
// 가입 상태 정보가 없는 기존 계정의 복구 화면
class _LegacyRecoveryView extends StatefulWidget {
  const _LegacyRecoveryView({required this.service});

  final OnboardingService service;

  @override
  State<_LegacyRecoveryView> createState() => _LegacyRecoveryViewState();
}

//==========================[ manage recovery request ]=========================
// 기존 계정의 복구 요청과 실패, 시간 초과, 재시도를 관리한다.
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

//=========================[ show error message ]===============================
// 오류 메세지와 다시 시도, 로그아웃 버튼을 보여준다.
// 로그인 실패 시 빈 화면에 로그아웃 버튼 하나만 딱 보일 때 코드
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

//========================[ loading view ]======================================
// 앱 진입에 필요한 처리를 기다리는 동안 보여주는 로딩 화면
// 추후 수정 요소: 파일 분리. 로딩 뷰에 대한 코드가 한 파일에 작성되어야 하나?
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

//========================[ call back ]=========================================
// 대기 시간을 관리하고 지연 안내와 시간 초과 콜백을 처리합니다.
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
