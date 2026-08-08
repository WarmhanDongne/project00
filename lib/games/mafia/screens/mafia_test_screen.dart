import 'package:flutter/material.dart';

/// 방 생성과 플레이어 자리 배치 없이 Mafia UI를 바로 확인하는 개발 화면입니다.
///
/// 실제 게임 연동 전까지 Mafia 화면 작업은 이 위젯의 본문에서 진행합니다.
class MafiaTestScreen extends StatelessWidget {
  const MafiaTestScreen({super.key, this.testPlayerCount = 6});

  final int testPlayerCount;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // Mafia 게임 UI 테스트 영역입니다.
            Positioned.fill(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'MAFIA',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 56,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 8,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'UI TEST · 플레이어 $testPlayerCount명',
                      style: const TextStyle(
                        color: Colors.white54,
                        fontSize: 16,
                        letterSpacing: 1.5,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Positioned(
              left: 12,
              top: 12,
              child: IconButton(
                tooltip: '게임 목록으로 돌아가기',
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(
                  Icons.arrow_back_rounded,
                  color: Colors.white,
                  size: 32,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
