import 'package:flutter/material.dart';
import 'package:project00/games/shared/widgets/game_reconnect_screen.dart';

//=======================재접속 화면 미리보기 (개발 전용)==============================
/// [GameReconnectScreen] 한 장만 띄우는 작은 앱입니다.
///
/// 디자인을 확인하려고 진행 중인 게임을 끊거나 로그인을 다시 할 필요가 없게,
/// Firebase도 로그인도 없이 화면만 그립니다.
///
/// 실행:
///
/// ```bash
/// flutter run -t lib/dev/reconnect_preview.dart -d "iPhone 17 Pro"
/// ```
///
/// 문구를 바꿔 보려면 아래 [GameReconnectScreen]에 값을 넣고 핫 리로드하세요.
void main() {
  runApp(const _ReconnectPreviewApp());
}

class _ReconnectPreviewApp extends StatelessWidget {
  const _ReconnectPreviewApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      title: '재접속 화면 미리보기',
      home: GameReconnectScreen(),
    );
  }
}
