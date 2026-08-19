import 'package:flutter/material.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:project00/platform/theme/platform_theme.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class RegisterStepOne extends StatelessWidget {
  const RegisterStepOne({
    required this.emailController,
    required this.customDomainController,
    required this.customDomainFocusNode,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.emailDomain,
    required this.isCustomDomain,
    required this.step,
    required this.action,
    required this.cooldownSeconds,
    required this.onDomainChanged,
    required this.onSendEmail,
    required this.onResendEmail,
    required this.onSetPassword,
    this.errorMessage,
    super.key,
  });

  final TextEditingController emailController;
  final TextEditingController customDomainController;
  final FocusNode customDomainFocusNode;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final String emailDomain;
  final bool isCustomDomain;
  final RegisterStep step;
  final RegisterAction? action;
  final int cooldownSeconds;
  final String? errorMessage;
  final ValueChanged<String?> onDomainChanged;
  final VoidCallback onSendEmail;
  final VoidCallback onResendEmail;
  final VoidCallback onSetPassword;

  bool get _emailEditable =>
      step == RegisterStep.emailInput ||
      (step == RegisterStep.emailLinkFailed &&
          emailController.text.trim().isEmpty);
  bool get _isWaiting => step == RegisterStep.awaitingEmailLink;
  bool get _isFailed => step == RegisterStep.emailLinkFailed;
  bool get _isSettingPassword => step == RegisterStep.settingPassword;

  @override
  Widget build(BuildContext context) {
    final isBusy = action != null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('이메일', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 7),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: emailController,
                enabled: _emailEditable && !isBusy,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: '이메일'),
              ),
            ),
            if (_emailEditable) ...[
              const SizedBox(width: 8),
              SizedBox(
                width: 112,
                child: isCustomDomain
                    ? TextField(
                        controller: customDomainController,
                        focusNode: customDomainFocusNode,
                        enabled: !isBusy,
                        decoration: InputDecoration(
                          hintText: '직접 입력',
                          suffixIcon: IconButton(
                            onPressed: () => onDomainChanged('gmail.com'),
                            icon: const Icon(Icons.arrow_drop_down, size: 20),
                          ),
                        ),
                      )
                    : DropdownButtonFormField<String>(
                        isExpanded: true,
                        initialValue: emailDomain,
                        decoration: const InputDecoration(),
                        items: const [
                          DropdownMenuItem(
                            value: 'gmail.com',
                            child: Text('gmail.com'),
                          ),
                          DropdownMenuItem(
                            value: 'naver.com',
                            child: Text('naver.com'),
                          ),
                          DropdownMenuItem(
                            value: 'daum.net',
                            child: Text('daum.net'),
                          ),
                          DropdownMenuItem(
                            value: 'custom',
                            child: Text('직접 입력'),
                          ),
                        ],
                        onChanged: isBusy ? null : onDomainChanged,
                      ),
              ),
            ],
            const SizedBox(width: 8),
            SizedBox(
              width: 72,
              child: PlatformButton(
                label: action == RegisterAction.resendEmail
                    ? '재전송 중…'
                    : _emailEditable
                    ? '인증'
                    : (_isSettingPassword ? '완료' : '재시도'),
                height: 48,
                loading: action == RegisterAction.sendEmail,
                onPressed: switch (step) {
                  RegisterStep.emailInput => isBusy ? null : onSendEmail,
                  RegisterStep.awaitingEmailLink ||
                  RegisterStep.emailLinkFailed =>
                    isBusy || cooldownSeconds > 0 ? null : onResendEmail,
                  RegisterStep.settingPassword => null,
                },
                style: _isSettingPassword
                    ? PlatformButtonStyle.secondary
                    : PlatformButtonStyle.primary,
              ),
            ),
          ],
        ),
        if (!_emailEditable || errorMessage != null) ...[
          const SizedBox(height: 10),
          PlatformNotice(
            message:
                errorMessage ??
                (_isSettingPassword
                    ? '인증이 완료되었습니다.'
                    : _isFailed
                    ? '인증에 실패했습니다. 메일 주소와 링크를 확인해 주세요.'
                    : '인증 메일을 보냈습니다. 메일함을 확인해 주세요. '
                          '(${_formatCooldown(cooldownSeconds)})'),
            style: errorMessage != null || _isFailed
                ? PlatformNoticeStyle.danger
                : _isSettingPassword
                ? PlatformNoticeStyle.success
                : PlatformNoticeStyle.warning,
            leading: _isWaiting
                ? SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: context.platformColors.warning,
                    ),
                  )
                : null,
          ),
        ],
        if (_isSettingPassword) ...[
          const SizedBox(height: 18),
          const Text('비밀번호', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 7),
          TextField(
            controller: passwordController,
            enabled: !isBusy,
            obscureText: true,
            onChanged: (_) {},
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.visibility_outlined, size: 18),
            ),
          ),
          const SizedBox(height: 14),
          const Text('비밀번호 재입력', style: TextStyle(fontSize: 13)),
          const SizedBox(height: 7),
          TextField(
            controller: confirmPasswordController,
            enabled: !isBusy,
            obscureText: true,
            decoration: const InputDecoration(
              suffixIcon: Icon(Icons.visibility_outlined, size: 18),
            ),
          ),
        ],
        const SizedBox(height: 24),
        PlatformButton(
          label: _isSettingPassword ? '다음' : '다음',
          loading: action == RegisterAction.setPassword,
          onPressed: _isSettingPassword && !isBusy ? onSetPassword : null,
        ),
      ],
    );
  }

  String _formatCooldown(int totalSeconds) {
    final seconds = totalSeconds.clamp(0, 5999);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }
}
