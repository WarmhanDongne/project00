import 'package:flutter/material.dart';

class LiarsBarResultScreen extends StatelessWidget {
  const LiarsBarResultScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('게임 결과')),
    body: const Center(child: Text('결과가 여기에 표시됩니다.')),
  );
}
