import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/auth/legal/signup_terms.dart';
import 'package:project00/platform/auth/services/auth_service.dart';
import 'package:project00/platform/auth/services/onboarding_service.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';

/// 비밀번호 계정의 웹 이메일 인증을 기다립니다. 인증 링크 자체로 로그인하지
/// 않으며, 앱 복귀/확인 버튼에서 Firebase의 최신 인증 여부를 다시 읽습니다.
class EmailVerificationScreen extends StatefulWidget {
  const EmailVerificationScreen({
    super.key,
    required this.email,
    required this.service,
  });

  final String email;
  final OnboardingService service;

  @override
  State<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState extends State<EmailVerificationScreen>
    with WidgetsBindingObserver {
  bool _busy = true;
  bool _sent = false;
  bool _prepared = false;
  String? _message;
  bool _error = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_prepareAndSend());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && !_busy && _prepared) {
      unawaited(_check());
    }
  }

  Future<void> _prepareAndSend() async {
    try {
      await widget.service.preparePasswordVerification();
      if (!mounted) return;
      _prepared = true;
      if (await widget.service.refreshEmailVerification() || !mounted) return;
      await widget.service.sendPasswordVerification();
      if (mounted) setState(() => _sent = true);
    } on AuthServiceException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _resend() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    await _prepareAndSend();
  }

  Future<void> _check() async {
    if (_busy || !_prepared) return;
    setState(() {
      _busy = true;
      _message = null;
      _error = false;
    });
    try {
      final verified = await widget.service.refreshEmailVerification();
      if (!mounted) return;
      setState(
        () => _message = verified
            ? GameLocale.select(
                ko: '인증을 확인했어요. 가입을 이어갑니다.',
                en: 'Email verified. Continuing sign-up.',
                zhHans: '邮箱验证成功，继续注册。',
                zhHant: '電子郵件驗證成功，繼續註冊。',
              )
            : GameLocale.select(
                ko: '아직 인증이 확인되지 않았어요. 메일의 인증 링크를 누른 뒤 다시 확인해주세요.',
                en: 'Email is not verified yet. Open the verification link, then check again.',
                zhHans: '邮箱尚未验证，请打开验证链接后再次确认。',
                zhHant: '電子郵件尚未驗證，請開啟驗證連結後再次確認。',
              ),
      );
    } on AuthServiceException catch (error) {
      if (mounted) {
        setState(() {
          _message = error.message;
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leave() async {
    if (_busy) return;
    final leave = await showMosiLeaveDialog(
      context,
      title: GameLocale.select(
        ko: '인증을 나중에 할까요?',
        en: 'Verify later?',
        zhHans: '稍后验证？',
        zhHant: '稍後驗證？',
      ),
      message: GameLocale.select(
        ko: '계정은 만들어졌어요. 이메일과 비밀번호로 로그인하면 이어서 인증할 수 있어요.',
        en: 'Your account was created. Sign in with email and password to continue verification later.',
        zhHans: '账号已创建，之后可使用邮箱和密码登录并继续验证。',
        zhHant: '帳號已建立，之後可使用電子郵件和密碼登入並繼續驗證。',
      ),
    );
    if (leave != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await FirebaseAuth.instance.signOut();
      await SignupConsentStore().clear();
    } on FirebaseAuthException catch (_) {
      if (mounted) {
        setState(() {
          _message = GameLocale.select(
            ko: '로그아웃하지 못했습니다. 다시 시도해주세요.',
            en: 'Could not log out. Try again.',
            zhHans: '无法退出登录，请重试。',
            zhHant: '無法登出，請重試。',
          );
          _error = true;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop) unawaited(_leave());
    },
    child: MosiAuthScaffold(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MosiAuthHeader(
            title: GameLocale.select(
              ko: '이메일 인증',
              en: 'Verify email',
              zhHans: '验证邮箱',
              zhHant: '驗證電子郵件',
            ),
            steps: passwordSignupSteps,
            stepIndex: 2,
            onBack: _busy ? null : () => unawaited(_leave()),
          ),
          const SizedBox(height: 20),
          const Icon(
            Icons.mark_email_read_outlined,
            size: 52,
            color: MosiColors.violet,
          ),
          const SizedBox(height: 16),
          Text(
            widget.email,
            textAlign: TextAlign.center,
            style: MosiFonts.sans(
              size: 17,
              weight: FontWeight.w700,
              color: MosiColors.navy,
            ),
          ),
          const SizedBox(height: 12),
          MosiNotice(
            message:
                _message ??
                (_sent
                    ? GameLocale.select(
                        ko: '인증 메일을 보냈어요. 메일의 링크를 눌러 인증한 뒤 앱으로 돌아와 주세요.',
                        en: 'Verification email sent. Open its link, then return to the app.',
                        zhHans: '验证邮件已发送，请打开链接验证后返回应用。',
                        zhHant: '驗證郵件已傳送，請開啟連結驗證後返回 App。',
                      )
                    : GameLocale.select(
                        ko: '인증 메일을 준비하고 있어요.',
                        en: 'Preparing verification email.',
                        zhHans: '正在准备验证邮件。',
                        zhHant: '正在準備驗證郵件。',
                      )),
            tone: _error ? MosiNoticeTone.error : MosiNoticeTone.info,
          ),
          const SizedBox(height: 18),
          MosiButton(
            label: GameLocale.select(
              ko: '인증했어요',
              en: 'I verified',
              zhHans: '已完成验证',
              zhHant: '已完成驗證',
            ),
            height: 54,
            expand: true,
            loading: _busy,
            onPressed: _busy || !_prepared ? null : _check,
          ),
          const SizedBox(height: 12),
          MosiButton(
            label: GameLocale.select(
              ko: '인증 메일 다시 보내기',
              en: 'Resend verification email',
              zhHans: '重新发送验证邮件',
              zhHant: '重新傳送驗證郵件',
            ),
            background: MosiColors.white,
            height: 50,
            expand: true,
            onPressed: _busy ? null : _resend,
          ),
        ],
      ),
    ),
  );
}
