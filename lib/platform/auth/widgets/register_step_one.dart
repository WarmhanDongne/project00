import 'package:flutter/material.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class RegisterStepOne extends StatelessWidget {
  const RegisterStepOne({
    required this.emailController,
    required this.customDomainController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.emailDomain,
    required this.isCustomDomain,
    required this.isLoading,
    this.errorMessage,
    required this.verificationState,
    required this.onDomainChanged,
    required this.onProcessRegistration,
    required this.onResendVerification,
    super.key,
  });

  final TextEditingController emailController;
  final TextEditingController customDomainController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final String emailDomain;
  final bool isCustomDomain;
  final bool isLoading;
  final String? errorMessage;
  final VerificationState verificationState;
  final ValueChanged<String?> onDomainChanged;
  final VoidCallback onProcessRegistration;
  final VoidCallback onResendVerification;

  bool get isFieldsEnabled => verificationState == VerificationState.initial;

  String get buttonLabel {
    if (isLoading && verificationState == VerificationState.initial) {
      return '확인 중...';
    }
    switch (verificationState) {
      case VerificationState.initial:
        return '인증하기';
      case VerificationState.waiting:
        return '재전송';
      case VerificationState.verified:
        return '완료';
    }
  }

  VoidCallback? get onButtonPressed {
    if (isLoading) return null;
    switch (verificationState) {
      case VerificationState.initial:
        return onProcessRegistration;
      case VerificationState.waiting:
        return onResendVerification;
      case VerificationState.verified:
        return null;
    }
  }

  PlatformButtonStyle get buttonStyle {
    if (verificationState == VerificationState.verified) {
      return PlatformButtonStyle.secondary;
    }
    return PlatformButtonStyle.primary;
  }

  String get noticeMessage {
    if (errorMessage != null) return errorMessage!;
    switch (verificationState) {
      case VerificationState.initial:
        return '';
      case VerificationState.waiting:
        return '인증 메일을 보냈습니다. 메일함을 확인해 주세요.';
      case VerificationState.verified:
        return '인증이 완료되었습니다.';
    }
  }

  PlatformNoticeStyle get noticeStyle {
    if (errorMessage != null) return PlatformNoticeStyle.danger;
    switch (verificationState) {
      case VerificationState.initial:
        return PlatformNoticeStyle.warning;
      case VerificationState.waiting:
        return PlatformNoticeStyle.warning;
      case VerificationState.verified:
        return PlatformNoticeStyle.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '이메일',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              flex: 4,
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: emailController,
                      enabled: isFieldsEnabled,
                      keyboardType: TextInputType.emailAddress,
                      decoration: const InputDecoration(hintText: '이메일을 입력하세요'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: isCustomDomain
                        ? TextField(
                            controller: customDomainController,
                            enabled: isFieldsEnabled,
                            decoration: InputDecoration(
                              hintText: '직접 입력',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 10),
                              suffixIcon: isFieldsEnabled ? IconButton(
                                icon: const Icon(Icons.arrow_drop_down, size: 20),
                                onPressed: () => onDomainChanged('gmail.com'),
                              ) : null,
                            ),
                          )
                        : DropdownButtonFormField<String>(
                            isExpanded: true,
                            initialValue: emailDomain == 'custom' ? 'gmail.com' : emailDomain,
                            decoration: const InputDecoration(
                              contentPadding: EdgeInsets.symmetric(horizontal: 10),
                            ),
                            items: const [
                              DropdownMenuItem(
                                value: 'gmail.com',
                                child: Text('gmail.com', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'naver.com',
                                child: Text('naver.com', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'daum.net',
                                child: Text('daum.net', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'hanmail.net',
                                child: Text('hanmail.net', overflow: TextOverflow.ellipsis),
                              ),
                              DropdownMenuItem(
                                value: 'custom',
                                child: Text('직접 입력', overflow: TextOverflow.ellipsis),
                              ),
                            ],
                            onChanged: isFieldsEnabled ? onDomainChanged : null,
                          ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 96,
              child: PlatformButton(
                label: buttonLabel,
                style: buttonStyle,
                onPressed: onButtonPressed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        AnimatedSize(
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
          child: (verificationState == VerificationState.initial && errorMessage == null)
              ? const SizedBox.shrink()
              : PlatformNotice(
                  message: noticeMessage,
                  style: noticeStyle,
                  leading: (verificationState == VerificationState.waiting && errorMessage == null)
                      ? SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: context.platformColors.warning,
                          ),
                        )
                      : null,
                ),
        ),
        const SizedBox(height: 14),
        const Text(
          '비밀번호',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: passwordController,
          enabled: isFieldsEnabled,
          obscureText: true,
          decoration: const InputDecoration(hintText: ''),
        ),
        const SizedBox(height: 12),
        const Text(
          '비밀번호 재입력',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: confirmPasswordController,
          enabled: isFieldsEnabled,
          obscureText: true,
          decoration: const InputDecoration(hintText: ''),
        ),
      ],
    );
  }
}
