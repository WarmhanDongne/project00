// [lobby_connection_band.dart] 는 로비 화면에 서버 연결 띠를 언어에 맞춰 붙이는 파일이다.
//
// - [Platform] : 로비(태블릿 선반·휴대폰 홈·대기실)
// - [Widget] : 공용 연결 띠에 번역 문구를 넘김
//
// 즉, 로비 어디서든 같은 모양·같은 말로 연결 상태를 알리기 위해 필요한 파일이다.

import 'package:flutter/widgets.dart';
import 'package:game_kit/mosi_ui/mosi_connection_band.dart';
import 'package:project00/platform/localization/platform_localizations.dart';

/// 로비 화면 맨 아래 서버 연결 띠입니다(시안 '서버 연결 알림' 2안 · 가장자리 띠).
///
/// 게임 화면에는 쓰지 않습니다. 게임은 각자의 복구·중단 안내가 있습니다.
class LobbyConnectionBand extends StatelessWidget {
  const LobbyConnectionBand({
    super.key,
    required this.connectionChanges,
    required this.child,
  });

  /// 서버 연결 여부입니다. 화면이 다시 그려져도 같은 스트림을 넘겨야 합니다.
  final Stream<bool>? connectionChanges;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return MosiConnectionBandHost(
      connectionChanges: connectionChanges,
      labels: MosiConnectionBandLabels(
        lost: l10n.connectionBandLost,
        reconnecting: l10n.connectionBandReconnecting,
        restored: l10n.connectionBandRestored,
      ),
      child: child,
    );
  }
}
