import 'package:flutter/material.dart';

class FilterBar extends StatelessWidget {
  const FilterBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 678,
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      alignment: Alignment.centerLeft,
      decoration: BoxDecoration(color: Colors.grey.shade300),
      child: const Text(
        '장르 필터 : 재미 / 추리 / 액션 / 심리 / 전략 / 수학 / 공간 / 협동',
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
