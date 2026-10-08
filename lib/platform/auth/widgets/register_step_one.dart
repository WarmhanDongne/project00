import 'package:project00/platform/localization/platform_localizations.dart';
import 'package:flutter/material.dart';
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
                (email.isEmpty ? '이메일 인증이 완료되었어요' : '$email 인증이 완료되었어요'),
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
              cooldownText: '메일이 오지 않았다면 다시 보내 주세요',
              completing: action == RegisterAction.completeLink,
            ),
          ],
          if (_isFailed && errorMessage == null) ...[
            const SizedBox(height: 14),
            const MosiNotice(message: '인증에 실패했습니다. 메일 주소와 링크를 확인해 주세요.'),
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 14),
            MosiNotice(message: errorMessage!),
          ],
          const SizedBox(height: 14),
          MosiButton(
            key: const Key('register-send-email-button'),
            label: _emailEditable && !_isFailed
                ? '인증 메일 보내기'
                : action == RegisterAction.resendEmail
                ? '다시 보내는 중…'
                : '인증 메일 다시 보내기',
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
                    '비밀번호 보기',
                    '비밀번호 숨기기',
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
                  ('6자 이상', PasswordPolicy.hasMinimumLength(password)),
                  ('영문 1개 이상', PasswordPolicy.hasLetter(password)),
                  ('숫자 1개 이상', PasswordPolicy.hasNumber(password)),
                  ('특수문자 1개 이상', PasswordPolicy.hasSpecialCharacter(password)),
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
                    '비밀번호 확인 보기',
                    '비밀번호 확인 숨기기',
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
                  ? '비밀번호가 일치합니다.'
                  : '비밀번호가 일치해야 합니다.',
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
              label: context.l10n.next,
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
                    completing ? '인증을 확인하는 중이에요' : '인증 메일을 보냈어요',
                    style: MosiFonts.sans(
                      locale: Localizations.maybeLocaleOf(context),
                      size: 14,
                      weight: FontWeight.w700,
                      color: MosiColors.navy,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$email 메일함에서 링크를 눌러 주세요.',
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
