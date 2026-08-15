import 'package:flutter/material.dart';

/// 휴대폰 진행 화면 뼈대입니다.
///
/// 실제 게임에서는 여기서 Riverpod 세션 컨트롤러(예:
/// `liarsPokerPhoneSessionProvider`처럼 `NotifierProvider.autoDispose.family`)를
/// 만들어 [TemplateQueryService]의 스트림을 구독하세요.
class TemplatePhoneGame extends StatelessWidget {
  const TemplatePhoneGame({
    super.key,
    required this.roomCode,
    required this.onExitRoom,
  });

  final String roomCode;
  final Future<bool> Function() onExitRoom;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: Text(
          'TODO: 휴대폰 진행 화면 ($roomCode)',
          style: const TextStyle(color: Colors.white),
        ),
      ),
    );
  }
}
