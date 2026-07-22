import 'package:flutter/material.dart';

class CardHandWidget extends StatelessWidget {
  const CardHandWidget({required this.cardCount, super.key});
  final int cardCount;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: List.generate(
      cardCount,
      (_) => const Padding(
        padding: EdgeInsets.all(3),
        child: Icon(Icons.style, size: 42),
      ),
    ),
  );
}
