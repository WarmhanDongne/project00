import 'package:flutter/material.dart';
import 'package:game_kit/core/layout/app_orientation.dart';
import 'package:game_kit/localization/game_locale.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/recovery/widgets/critical_network_guard.dart';
import 'package:game_kit/template_game.dart';
import 'package:game_yut/src/phone.dart';
import 'package:game_yut/src/tablet.dart';
import 'package:game_yut/src/service.dart';

class YutGame extends TemplateGame {
  const YutGame();
  @override
  String get id => 'yut';
  @override
  String get title => GameLocale.select(
    ko: '윷놀이',
    en: 'Yut Nori',
    zhHans: '掷柶游戏',
    zhHant: '擲柶遊戲',
  );
  // 일반 윷놀이는 Firestore 카탈로그의 min/max 범위를 따릅니다 (2~4인).
  @override
  int? get fixedPlayerCount => null;
  @override
  String get leaveFunctionName => 'game_yut_leave_game';
  @override
  PhoneGameOrientation get phoneOrientation =>
      PhoneGameOrientation.portraitOnly;
  @override
  Color get tableColor => const Color(0xFFC98A4B);
  @override
  ImageProvider? get tableBackgroundImage => null;

  /// 자리 배치 뒤 한지 창호문이 닫혔다 열리며 판을 공개합니다(디자인 입장 연출).
  @override
  bool get usesDoorEntrance => true;
  @override
  Future<void> startGame(
    String roomCode, {
    Map<String, Object?>? options,
  }) async {
    await YutService().command.startGame(roomCode, id);
  }

  @override
  Stream<String?> watchStatus(String roomCode) => YutService().query
      .watchStatus(roomCode)
      .map((event) => event.snapshot.value as String?);
  @override
  Widget buildPhoneScreen({
    required String roomCode,
    required GameRoomContext provider,
    required Future<bool> Function() onExitRoom,
  }) => Builder(
    builder: (context) => CriticalNetworkGuard(
      provider: provider,
      onExit: () => Navigator.of(context).maybePop(),
      child: YutPhoneScreen(
        roomCode: roomCode,
        provider: provider,
        gameId: id,
        onExitRoom: onExitRoom,
      ),
    ),
  );
  @override
  Widget buildTabletScreen({
    required PlayerLayoutModel playerLayout,
    required GameRoomContext provider,
    required String roomCode,
  }) => Builder(
    builder: (context) => CriticalNetworkGuard(
      provider: provider,
      exitLabel: GameLocale.select(
        ko: '대기실로',
        en: 'To lobby',
        zhHans: '返回大厅',
        zhHant: '返回大廳',
      ),
      onExit: () => Navigator.of(context).maybePop(),
      child: YutTabletScreen(
        roomCode: roomCode,
        provider: provider,
        gameId: id,
      ),
    ),
  );
}

class StrategyYutGame extends YutGame {
  const StrategyYutGame();
  @override
  String get id => 'strategy_yut';
  @override
  int? get fixedPlayerCount => 4;
  @override
  String get title => GameLocale.select(
    ko: '전략 윷놀이',
    en: 'Strategy Yut',
    zhHans: '策略掷柶',
    zhHant: '策略擲柶',
  );
}

class StrategyYutEditionGame extends StrategyYutGame {
  const StrategyYutEditionGame();
  @override
  String get id => 'strategy_yut_edition';
  @override
  String get title => GameLocale.select(
    ko: '전략 윷놀이 에디션',
    en: 'Strategy Yut Edition',
    zhHans: '策略掷柶·典藏版',
    zhHant: '策略擲柶·典藏版',
  );
}
