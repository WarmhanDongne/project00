import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/models/game_room_context.dart';
import 'package:game_kit/phone/widgets/rule_dialog.dart';
import 'package:game_kit/recovery/widgets/game_reconnect_screen.dart';
import 'package:game_kit/recovery/widgets/network_unavailable_modal.dart';
import 'package:game_kit/sound/providers/sound_provider.dart';
import 'package:game_kit/tablet/widgets/game_settings_dialog.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/overflow_sweep.dart';

// 실제 규칙처럼 제목과 긴 문단이 여러 개인 규칙입니다.
final _rules = [
  for (var i = 1; i <= 6; i++)
    '# $i. 단계별 규칙 제목이 조금 긴 경우\n'
        '차례가 오면 카드를 고르고, 다른 사람의 말이 거짓이라고 생각되면 버튼을 눌러요. '
        '남은 시간이 지나면 자동으로 넘어가며, 벌칙 룰렛은 갈수록 불리해져요.',
].join('\n\n');

const _games = ['라이어스 포커', '마피아', '파이널콜', '텍사스 홀덤'];

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 250));
  }
}

void main() {
  testWidgets('공용 휴대폰 게임 화면(규칙·연결)은 모든 휴대폰 크기·방향에서 넘치지 않는다', (tester) async {
    await loadSweepFonts(tester);
    addTearDown(tester.view.reset);
    final sweep = OverflowSweep()..start();
    addTearDown(sweep.stop);
    for (final device in [...sweepPhones, ...sweepPhonesLandscape]) {
      applySweepDevice(tester, device);
      for (final game in _games) {
        sweep.where = '휴대폰 $device 규칙 $game';
        await tester.pumpWidget(
          MaterialApp(
            theme: sweepTheme(),
            home: Scaffold(
              body: PhoneGameRuleDialog(
                title: game,
                rules: _rules,
                surfaceColor: Colors.white,
                foregroundColor: Colors.black,
              ),
            ),
          ),
        );
        await _settle(tester);
        sweep.scanText(tester);
      }
      sweep.where = '휴대폰 $device 인터넷 끊김';
      await tester.pumpWidget(
        MaterialApp(
          theme: sweepTheme(),
          home: Scaffold(
            body: NetworkUnavailableModal(onRetry: () {}, onExit: () {}),
          ),
        ),
      );
      await _settle(tester);
      sweep.scanText(tester);
      sweep.where = '휴대폰 $device 다시 접속';
      await tester.pumpWidget(
        MaterialApp(
          theme: sweepTheme(),
          home: GameReconnectScreen(
            homeButtonDelay: Duration.zero,
            onHome: () {},
          ),
        ),
      );
      await _settle(tester);
      sweep.scanText(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    sweep.stop();
    expect(sweep.problems.toList()..sort(), isEmpty);
  });

  testWidgets('공용 태블릿 게임 화면(설정·연결)은 모든 태블릿 크기에서 넘치지 않는다', (tester) async {
    await loadSweepFonts(tester);
    addTearDown(tester.view.reset);
    final sweep = OverflowSweep()..start();
    addTearDown(sweep.stop);
    final sound = SoundProvider(preferences: _Preferences());
    for (final device in sweepTablets) {
      applySweepDevice(tester, device);
      for (final game in _games) {
        sweep.where = '태블릿 $device 설정 $game';
        await tester.pumpWidget(
          ChangeNotifierProvider<SoundProvider>.value(
            value: sound,
            child: MaterialApp(
              theme: sweepTheme(),
              home: Scaffold(
                body: Center(
                  child: TabletGameSettingsDialog(
                    provider: _Room(game),
                    onRestartGame: () {},
                    onEndGame: () {},
                  ),
                ),
              ),
            ),
          ),
        );
        await _settle(tester);
        sweep.scanText(tester);
      }
      sweep.where = '태블릿 $device 인터넷 끊김';
      await tester.pumpWidget(
        MaterialApp(
          theme: sweepTheme(),
          home: Scaffold(
            body: NetworkUnavailableModal(onRetry: () {}, onExit: () {}),
          ),
        ),
      );
      await _settle(tester);
      sweep.scanText(tester);
      sweep.where = '태블릿 $device 다시 접속';
      await tester.pumpWidget(
        MaterialApp(
          theme: sweepTheme(),
          home: GameReconnectScreen(
            homeButtonDelay: Duration.zero,
            onHome: () {},
          ),
        ),
      );
      await _settle(tester);
      sweep.scanText(tester);
      await tester.pumpWidget(const SizedBox.shrink());
    }
    sweep.stop();
    expect(sweep.problems.toList()..sort(), isEmpty);
  });
}

class _Game implements GameRoomMetadata {
  const _Game(this.name);
  @override
  final String name;
  @override
  String get imageUrl => '';
  @override
  String get ruleVideoUrl => '';
}

class _Room extends GameRoomContext {
  _Room(this.game);
  final String game;
  @override
  String? get roomCode => 'ABCDE';
  @override
  GameRoomMetadata? get selectedGame => _Game(game);
  @override
  List<GameRoomPlayer> get players => const [];
  @override
  bool get isLeaving => false;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Preferences implements SharedPreferencesAsync {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
