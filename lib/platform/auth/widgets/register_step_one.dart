import 'package:flutter/material.dart';
import 'package:project00/platform/widgets/platform_components.dart';

class RegisterStepOne extends StatelessWidget {
  const RegisterStepOne({
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isEmailChecked,
    required this.onCheckEmail,
    super.key,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isEmailChecked;
  final VoidCallback onCheckEmail;

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
              child: TextField(
                controller: emailController,
                enabled: !isEmailChecked,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(hintText: 'mosi@gmail.com'),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 82,
              child: PlatformButton(
                label: isEmailChecked ? '완료' : '중복확인',
                style: isEmailChecked
                    ? PlatformButtonStyle.secondary
                    : PlatformButtonStyle.primary,
                onPressed: isEmailChecked ? null : onCheckEmail,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        PlatformNotice(
          message: isEmailChecked
              ? '사용 가능한 이메일입니다.'
              : '중복 확인 후 다음 단계로 이동할 수 있습니다.',
          style: isEmailChecked
              ? PlatformNoticeStyle.success
              : PlatformNoticeStyle.warning,
        ),
        const SizedBox(height: 14),
        const Text(
          '비밀번호',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: passwordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: '••••••••'),
        ),
        const SizedBox(height: 12),
        const Text(
          '비밀번호 재입력',
          style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        TextField(
          controller: confirmPasswordController,
          obscureText: true,
          decoration: const InputDecoration(hintText: '••••••••'),
        ),
      ],
    );
  }
}
