import 'package:flutter/material.dart';

class AppTextField extends StatelessWidget {
  const AppTextField({required this.label, this.controller, super.key});
  final String label;
  final TextEditingController? controller;
  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    decoration: InputDecoration(labelText: label),
  );
}
