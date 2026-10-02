import 'package:flutter/material.dart';

/// 중간 단계 안내. 배경과 상단바는 board에 남기고 내용만 바꿉니다.
class MafiaPhonePhaseNotice extends StatelessWidget {
  const MafiaPhonePhaseNotice({super.key, required this.message, this.detail});
  final String message;
  final String? detail;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: Colors.black,
            ),
          ),
          if (detail != null) ...[
            const SizedBox(height: 16),
            Text(
              detail!,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 16, color: Colors.black87),
            ),
          ],
        ],
      ),
    ),
  );
}
