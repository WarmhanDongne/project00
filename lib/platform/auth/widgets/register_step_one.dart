import 'package:flutter/material.dart';
import 'package:project00/platform/auth/models/password_policy.dart';
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
                    : (_isSettingPassword ? '완료' : '재전송'),
                height: 48,
                loading: action == RegisterAction.sendEmail,
                onPressed: switch (step) {
                  RegisterStep.emailInput => isBusy ? null : onSendEmail,
                  RegisterStep.awaitingEmailLink ||
                  RegisterStep.emailLinkFailed =>
                    isBusy ? null : onResendEmail,
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
                    : cooldownSeconds > 0
                    ? '인증 메일을 보냈습니다. 메일함을 확인해 주세요. '
                          '(${_formatCooldown(cooldownSeconds)}, 재전송 가능)'
                    : '메일이 오지 않았다면 인증 메일을 다시 전송해 주세요.'),
            style: errorMessage != null || _isFailed
                ? PlatformNoticeStyle.danger
                : _isSettingPassword
                ? PlatformNoticeStyle.success
                : PlatformNoticeStyle.warning,
            leading:
                _isWaiting && action == RegisterAction.completeLink
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
          _PasswordFields(
            passwordController: passwordController,
            controller: confirmPasswordController,
            isBusy: isBusy,
            isSaving: action == RegisterAction.setPassword,
            onSetPassword: onSetPassword,
          ),
        ] else ...[
          const SizedBox(height: 24),
          const PlatformButton(label: '다음', onPressed: null),
        ],
      ],
    );
  }

  String _formatCooldown(int totalSeconds) {
    final seconds = totalSeconds.clamp(0, 5999);
    return '${(seconds ~/ 60).toString().padLeft(2, '0')}:'
        '${(seconds % 60).toString().padLeft(2, '0')}';
  }
}

class _PasswordFields extends StatefulWidget {
  const _PasswordFields({
    required this.passwordController,
    required this.controller,
    required this.isBusy,
    required this.isSaving,
    required this.onSetPassword,
  });

  final TextEditingController passwordController;
  final TextEditingController controller;
  final bool isBusy;
  final bool isSaving;
  final VoidCallback onSetPassword;

  @override
  State<_PasswordFields> createState() => _PasswordFieldsState();
}

class _PasswordFieldsState extends State<_PasswordFields> {
  bool _obscurePassword = true;
  bool _obscureConfirmation = true;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([
        widget.passwordController,
        widget.controller,
      ]),
      builder: (context, child) {
        final password = widget.passwordController.text;
        final confirmation = widget.controller.text;
        final passwordStarted = password.isNotEmpty;
        final confirmationStarted = confirmation.isNotEmpty;
        final passwordsMatch =
            confirmationStarted && password == confirmation;
        final canSetPassword =
            PasswordPolicy.isValid(password) && passwordsMatch;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('비밀번호', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 7),
            TextField(
              controller: widget.passwordController,
              enabled: !widget.isBusy,
              obscureText: _obscurePassword,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  tooltip: _obscurePassword ? '비밀번호 보기' : '비밀번호 숨기기',
                  onPressed: widget.isBusy
                      ? null
                      : () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _PasswordRequirement(
              label: '6자 이상입니다.',
              met: PasswordPolicy.hasMinimumLength(password),
              evaluated: passwordStarted,
            ),
            _PasswordRequirement(
              label: '영문이 1개 이상 포함되었습니다.',
              met: PasswordPolicy.hasLetter(password),
              evaluated: passwordStarted,
            ),
            _PasswordRequirement(
              label: '숫자가 1개 이상 포함되었습니다.',
              met: PasswordPolicy.hasNumber(password),
              evaluated: passwordStarted,
            ),
            _PasswordRequirement(
              label: '특수문자가 1개 이상 포함되었습니다.',
              met: PasswordPolicy.hasSpecialCharacter(password),
              evaluated: passwordStarted,
            ),
            const SizedBox(height: 14),
            const Text('비밀번호 재입력', style: TextStyle(fontSize: 13)),
            const SizedBox(height: 7),
            TextField(
              controller: widget.controller,
              enabled: !widget.isBusy,
              obscureText: _obscureConfirmation,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) {
                if (canSetPassword && !widget.isBusy) widget.onSetPassword();
              },
              decoration: InputDecoration(
                suffixIcon: IconButton(
                  tooltip: _obscureConfirmation
                      ? '비밀번호 확인 보기'
                      : '비밀번호 확인 숨기기',
                  onPressed: widget.isBusy
                      ? null
                      : () => setState(
                          () => _obscureConfirmation =
                              !_obscureConfirmation,
                        ),
                  icon: Icon(
                    _obscureConfirmation
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    size: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _PasswordRequirement(
              label: passwordsMatch
                  ? '비밀번호가 일치합니다.'
                  : '비밀번호가 일치해야 합니다.',
              met: passwordsMatch,
              evaluated: confirmationStarted,
            ),
            const SizedBox(height: 24),
            PlatformButton(
              label: '다음',
              loading: widget.isSaving,
              onPressed: !widget.isBusy && canSetPassword
                  ? widget.onSetPassword
                  : null,
            ),
          ],
        );
      },
    );
  }
}

class _PasswordRequirement extends StatelessWidget {
  const _PasswordRequirement({
    required this.label,
    required this.met,
    required this.evaluated,
  });

  final String label;
  final bool met;
  final bool evaluated;

  @override
  Widget build(BuildContext context) {
    final colors = context.platformColors;
    final color = met
        ? colors.success
        : evaluated
        ? colors.danger
        : colors.textMuted;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            met ? Icons.check_rounded : Icons.close_rounded,
            size: 14,
            color: color,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: Text(label, style: TextStyle(color: color, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
