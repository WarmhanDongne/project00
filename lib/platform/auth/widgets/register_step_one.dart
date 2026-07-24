import 'package:flutter/material.dart';

class RegisterStepOne extends StatelessWidget {
  const RegisterStepOne({
    required this.emailController,
    required this.passwordController,
    required this.confirmPasswordController,
    required this.isLoading,
    required this.isEmailChecked,
    required this.onCheckEmail,
    super.key,
  });

  final TextEditingController emailController;
  final TextEditingController passwordController;
  final TextEditingController confirmPasswordController;
  final bool isLoading;
  final bool isEmailChecked;
  final VoidCallback onCheckEmail;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: emailController,
                enabled: !isEmailChecked,
                keyboardType: TextInputType.emailAddress,
                decoration: const InputDecoration(
                  hintText: 'ID/EMAIL:',
                  filled: true,
                  fillColor: Color(0xFFD4D4D4),
                ),
              ),
            ),
            const SizedBox(width: 16),
            SizedBox(
              width: 110,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  shape: const RoundedRectangleBorder(),
                ),
                onPressed: isLoading || isEmailChecked ? null : onCheckEmail,
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(isEmailChecked ? '확인완료' : '중복확인'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                children: [
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'PW',
                      filled: true,
                      fillColor: Color(0xFFD4D4D4),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: confirmPasswordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      hintText: 'PW 재입력',
                      filled: true,
                      fillColor: Color(0xFFD4D4D4),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 16),
            Container(
              width: 110,
              height: 110,
              color: Colors.grey,
              alignment: Alignment.center,
              child: const Text(
                '영문 / 숫자로\n구성된 6자\n이상의 PW',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
