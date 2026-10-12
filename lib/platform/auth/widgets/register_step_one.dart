import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:flutter/material.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:project00/platform/auth/models/password_policy.dart';
import 'package:project00/platform/auth/screens/register_screen.dart';
import 'package:game_kit/mosi_ui/mosi_design.dart';
import 'package:project00/platform/auth/widgets/auth_design.dart';

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
      step == RegisterStep.passwordAccount ||
      step == RegisterStep.emailInput ||
      (step == RegisterStep.emailLinkFailed &&
          emailController.text.trim().isEmpty);
  bool get _isWaiting => step == RegisterStep.awaitingEmailLink;
  bool get _isFailed => step == RegisterStep.emailLinkFailed;
  bool get _isSettingPassword => step == RegisterStep.settingPassword;

  @override
  Widget build(BuildContext context) {
    final isBusy = action != null;
    final email = emailController.text.trim();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_isSettingPassword) ...[
          MosiNotice(
            message:
                errorMessage ??
                GameLocale.select(
                  ko: email.isEmpty ? '이메일 인증이 완료되었어요' : '$email 인증이 완료되었어요',
                  en: email.isEmpty ? 'Email verified' : '$email verified',
                  zhHans: email.isEmpty ? '邮箱验证完成' : '$email 验证完成',
                  zhHant: email.isEmpty ? '電子郵件驗證完成' : '$email 驗證完成',
                ),
            tone: errorMessage != null
                ? MosiNoticeTone.error
                : MosiNoticeTone.success,
          ),
          const SizedBox(height: 12),
          _PasswordFields(
            passwordController: passwordController,
            controller: confirmPasswordController,
            isBusy: isBusy,
            isSaving: action == RegisterAction.setPassword,
            onSetPassword: onSetPassword,
          ),
        ] else ...[
          MosiLabeledField(
            label: context.l10n.email,
            child: MosiEmailField(
              emailController: emailController,
              customDomainController: customDomainController,
              customDomainFocusNode: customDomainFocusNode,
              emailDomain: emailDomain,
              isCustomDomain: isCustomDomain,
              enabled: _emailEditable && !isBusy,
              showDomain: _emailEditable,
              onDomainChanged: onDomainChanged,
            ),
          ),
          if (_isWaiting) ...[
            const SizedBox(height: 14),
            _MailSentBox(
              email: email,
              cooldownText: GameLocale.select(
                ko: '메일이 오지 않았다면 다시 보내 주세요',
                en: 'Resend if the email does not arrive',
                zhHans: '若未收到邮件，请重新发送',
                zhHant: '若未收到郵件，請重新傳送',
              ),
              completing: action == RegisterAction.completeLink,
            ),
          ],
          if (_isFailed && errorMessage == null) ...[
            const SizedBox(height: 14),
            MosiNotice(
              message: GameLocale.select(
                ko: '인증에 실패했습니다. 메일 주소와 링크를 확인해 주세요.',
                en: 'Verification failed. Check the email address and link.',
                zhHans: '验证失败。请检查邮箱地址和链接。',
                zhHant: '驗證失敗。請檢查電子郵件地址和連結。',
              ),
            ),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            MosiNotice(message: errorMessage!),
          ],
          const SizedBox(height: 14),
          if (step == RegisterStep.passwordAccount)
            _PasswordFields(
              passwordController: passwordController,
              controller: confirmPasswordController,
              isBusy: isBusy,
              isSaving: action == RegisterAction.setPassword,
              onSetPassword: onSetPassword,
              buttonLabel: GameLocale.select(
                ko: '계정 만들고 인증하기',
                en: 'Create account and verify',
                zhHans: '创建账号并验证',
                zhHant: '建立帳號並驗證',
              ),
            )
          else
            MosiButton(
              key: const Key('register-send-email-button'),
              label: _emailEditable && !_isFailed
                  ? GameLocale.select(
                      ko: '인증 메일 보내기',
                      en: 'Send verification email',
                      zhHans: '发送验证邮件',
                      zhHant: '傳送驗證郵件',
                    )
                  : action == RegisterAction.resendEmail
                  ? GameLocale.select(
                      ko: '다시 보내는 중…',
                      en: 'Resending…',
                      zhHans: '正在重新发送…',
                      zhHant: '正在重新傳送…',
                    )
                  : GameLocale.select(
                      ko: '인증 메일 다시 보내기',
                      en: 'Resend verification email',
                      zhHans: '重新发送验证邮件',
                      zhHant: '重新傳送驗證郵件',
                    ),
              background: _emailEditable && !_isFailed
                  ? MosiColors.lime
                  : MosiColors.white,
              height: 54,
              expand: true,
              loading: action == RegisterAction.sendEmail,
              onPressed: isBusy
                  ? null
                  : step == RegisterStep.emailInput
                  ? onSendEmail
                  : onResendEmail,
            ),
        ],
      ],
    );
  }
}

class _PasswordFields extends StatefulWidget {
  const _PasswordFields({
    required this.passwordController,
    required this.controller,
    required this.isBusy,
    required this.isSaving,
    required this.onSetPassword,
    this.buttonLabel,
  });

  final TextEditingController passwordController;
  final TextEditingController controller;
  final bool isBusy;
  final bool isSaving;
  final VoidCallback onSetPassword;
  final String? buttonLabel;

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
        final passwordsMatch = confirmationStarted && password == confirmation;
        final canSetPassword =
            PasswordPolicy.isValid(password) && passwordsMatch;

        Widget eye(
          bool obscure,
          String show,
          String hide,
          VoidCallback toggle,
        ) => IconButton(
          tooltip: obscure ? show : hide,
          onPressed: widget.isBusy ? null : toggle,
          icon: Icon(
            obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
            size: 18,
            color: MosiColors.navy,
          ),
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MosiLabeledField(
              label: context.l10n.password,
              child: TextField(
                controller: widget.passwordController,
                enabled: !widget.isBusy,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.next,
                style: mosiFieldTextStyle(),
                decoration: mosiInputDecoration(
                  hintText: context.l10n.password,
                  suffix: eye(
                    _obscurePassword,
                    GameLocale.select(
                      ko: '비밀번호 보기',
                      en: 'Show password',
                      zhHans: '显示密码',
                      zhHant: '顯示密碼',
                    ),
                    GameLocale.select(
                      ko: '비밀번호 숨기기',
                      en: 'Hide password',
                      zhHans: '隐藏密码',
                      zhHant: '隱藏密碼',
                    ),
                    () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              runSpacing: 6,
              children: [
                for (final (label, met) in [
                  (
                    GameLocale.select(
                      ko: '6자 이상',
                      en: '6+ characters',
                      zhHans: '至少 6 个字符',
                      zhHant: '至少 6 個字元',
                    ),
                    PasswordPolicy.hasMinimumLength(password),
                  ),
                  (
                    GameLocale.select(
                      ko: '영문 1개 이상',
                      en: 'At least 1 letter',
                      zhHans: '至少 1 个英文字母',
                      zhHant: '至少 1 個英文字母',
                    ),
                    PasswordPolicy.hasLetter(password),
                  ),
                  (
                    GameLocale.select(
                      ko: '숫자 1개 이상',
                      en: 'At least 1 number',
                      zhHans: '至少 1 个数字',
                      zhHant: '至少 1 個數字',
                    ),
                    PasswordPolicy.hasNumber(password),
                  ),
                  (
                    GameLocale.select(
                      ko: '특수문자 1개 이상',
                      en: 'At least 1 symbol',
                      zhHans: '至少 1 个特殊字符',
                      zhHant: '至少 1 個特殊字元',
                    ),
                    PasswordPolicy.hasSpecialCharacter(password),
                  ),
                ])
                  FractionallySizedBox(
                    widthFactor: 0.5,
                    child: _PasswordRequirement(
                      label: label,
                      met: met,
                      evaluated: passwordStarted,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            MosiLabeledField(
              label: context.l10n.passwordAgain,
              child: TextField(
                controller: widget.controller,
                enabled: !widget.isBusy,
                obscureText: _obscureConfirmation,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) {
                  if (canSetPassword && !widget.isBusy) widget.onSetPassword();
                },
                style: mosiFieldTextStyle(),
                decoration: mosiInputDecoration(
                  hintText: context.l10n.passwordAgain,
                  suffix: eye(
                    _obscureConfirmation,
                    GameLocale.select(
                      ko: '비밀번호 확인 보기',
                      en: 'Show password confirmation',
                      zhHans: '显示确认密码',
                      zhHant: '顯示確認密碼',
                    ),
                    GameLocale.select(
                      ko: '비밀번호 확인 숨기기',
                      en: 'Hide password confirmation',
                      zhHans: '隐藏确认密码',
                      zhHant: '隱藏確認密碼',
                    ),
                    () => setState(
                      () => _obscureConfirmation = !_obscureConfirmation,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              !confirmationStarted
                  ? ' '
                  : passwordsMatch
                  ? GameLocale.select(
                      ko: '비밀번호가 일치합니다.',
                      en: 'Passwords match.',
                      zhHans: '密码一致。',
                      zhHant: '密碼一致。',
                    )
                  : GameLocale.select(
                      ko: '비밀번호가 일치해야 합니다.',
                      en: 'Passwords must match.',
                      zhHans: '两次密码必须一致。',
                      zhHant: '兩次密碼必須一致。',
                    ),
              style: MosiFonts.sans(
                locale: Localizations.maybeLocaleOf(context),
                size: 12,
                weight: FontWeight.w600,
                color: passwordsMatch
                    ? const Color(0xFF2F7A1A)
                    : const Color(0xFFA82E40),
              ),
            ),
            const SizedBox(height: 12),
            MosiButton(
              label: widget.buttonLabel ?? context.l10n.next,
              height: 54,
              expand: true,
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

class _MailSentBox extends StatelessWidget {
  const _MailSentBox({
    required this.email,
    required this.cooldownText,
    required this.completing,
  });

  final String email;
  final String cooldownText;
  final bool completing;

  @override
  Widget build(BuildContext context) {
    return MosiDashedBorder(
      radius: 10,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: MosiColors.cream,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            completing
                ? const SizedBox(
                    width: 56,
                    height: 44,
                    child: Center(
                      child: SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(strokeWidth: 3),
                      ),
                    ),
                  )
                : const CustomPaint(
                    size: Size(56, 44),
                    painter: _MailPainter(),
                  ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    completing
                        ? GameLocale.select(
                            ko: '인증을 확인하는 중이에요',
                            en: 'Checking verification',
                            zhHans: '正在确认验证',
                            zhHant: '正在確認驗證',
                          )
                        : GameLocale.select(
                            ko: '인증 메일을 보냈어요',
                            en: 'Verification email sent',
                            zhHans: '验证邮件已发送',
                            zhHant: '驗證郵件已傳送',
                          ),
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 14,
                      weight: FontWeight.w700,
                      color: MosiColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    GameLocale.select(
                      ko: '$email 메일함에서 링크를 눌러 주세요.',
                      en: 'Open the link in the email sent to $email.',
                      zhHans: '请打开发送到 $email 的邮件链接。',
                      zhHant: '請開啟傳送到 $email 的郵件連結。',
                    ),
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 13,
                      color: MosiColors.navy,
                      height: 1.5,
                    ),
                  ),
                  Text(
                    cooldownText,
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 13,
                      color: MosiColors.muted,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MailPainter extends CustomPainter {
  const _MailPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final stroke = Paint()
      ..color = MosiColors.ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeJoin = StrokeJoin.round;
    RRect r(double x, double y) => RRect.fromRectAndRadius(
      Rect.fromLTWH(x, y, 48, 34),
      const Radius.circular(4),
    );
    canvas.drawRRect(r(5, 7), Paint()..color = MosiColors.navy);
    canvas.drawRRect(r(2, 4), Paint()..color = MosiColors.sun);
    canvas.drawRRect(r(2, 4), stroke);
    canvas.drawPath(
      Path()
        ..moveTo(4, 7)
        ..lineTo(26, 24)
        ..lineTo(48, 7),
      stroke,
    );
    canvas.drawCircle(const Offset(46, 8), 6, Paint()..color = MosiColors.red);
    canvas.drawCircle(const Offset(46, 8), 6, stroke..strokeWidth = 2);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
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
    final color = met
        ? const Color(0xFF2F7A1A)
        : evaluated
        ? const Color(0xFFA82E40)
        : const Color(0xFF8C8AA8);
    return Row(
      children: [
        Container(
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: met ? const Color(0xFF4C8A1E) : MosiColors.white,
            border: Border.all(color: color, width: 2),
          ),
          child: met
              ? const Icon(
                  Icons.check_rounded,
                  size: 10,
                  color: MosiColors.white,
                )
              : null,
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            label,
            style: MosiFonts.sans(
              locale: Localizations.maybeLocaleOf(context),
              size: 12,
              weight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }
}
