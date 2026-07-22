import 'package:flutter/material.dart';

class AuthFormField extends StatelessWidget {
  const AuthFormField({
    required this.label,
    this.obscureText = false,
    super.key,
  });
  final String label;
  final bool obscureText;
  @override
  Widget build(BuildContext context) => TextField(
    obscureText: obscureText,
    decoration: InputDecoration(labelText: label),
  );
}
