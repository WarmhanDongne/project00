import 'package:flutter/material.dart';
import 'package:project00/platform/auth/widgets/auth_form_field.dart';
import 'package:project00/platform/auth/widgets/social_login_button.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('로그인')),
    body: const Padding(
      padding: EdgeInsets.all(24),
      child: Column(
        children: [
          AuthFormField(label: '이메일'),
          SizedBox(height: 12),
          AuthFormField(label: '비밀번호', obscureText: true),
          SizedBox(height: 24),
          SocialLoginButton(label: '소셜 계정으로 계속하기'),
        ],
      ),
    ),
  );
}
