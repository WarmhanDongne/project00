import 'package:flutter/material.dart';
import '../widgets/board_widget.dart';

class YutnoriTestScreen extends StatelessWidget {
  const YutnoriTestScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: const Text('전략 윷놀이 - 2-1 보드 테스트'),
        backgroundColor: Colors.blueGrey,
      ),
      body: const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: BoardWidget(),
        ),
      ),
    );
  }
}
