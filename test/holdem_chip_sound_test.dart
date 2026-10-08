import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/game_sounds.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_holdem/tablet/screens/table_screen.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/sound/providers/sound_provider.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../packages/game_holdem/test/support/fixtures.dart';

const _layout = PlayerLayoutModel(
  players: [
    PlayerLayoutPlayer(
      uid: 'me',
      nickname: '민지',
      characterId: 'frog',
      seatIndex: 0,
    ),
    PlayerLayoutPlayer(
      uid: 'rival',
      nickname: '하준',
      characterId: 'frog',
      seatIndex: 1,
    ),
  ],
);

class _RecordingSound extends SoundProvider {
  _RecordingSound() : super(preferences: _Preferences());

  final played = <String>[];
  final background = <String>[];
  int backgroundStops = 0;

  @override
  Future<void> playEffect(String assetPath) async {
    played.add(assetPath);
  }

  @override
  Future<void> playBgm(String assetPath) async {
    background.add(assetPath);
  }

  @override
  Future<void> stopBgm() async {
    backgroundStops += 1;
  }
}

class _Preferences implements SharedPreferencesAsync {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  testWidgets('홀덤 전용 배경음악 에셋이 앱에 포함된다', (tester) async {
    final bytes = await rootBundle.load(HoldemSounds.background);
    expect(bytes.lengthInBytes, greaterThan(1000000));
  });

  testWidgets('홀덤 배경음악은 진행 중 한 번 켜지고 게임 종료 시 멈춘다', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sound = _RecordingSound();
    addTearDown(sound.dispose);
    final initial = playingState(lastAction: null);

    Future<void> show(HoldemGameState game) => tester.pumpWidget(
      ChangeNotifierProvider<SoundProvider>.value(
        value: sound,
        child: MaterialApp(
          home: HoldemTableScreen(game: game, playerLayout: _layout),
        ),
      ),
    );

    await show(initial);
    expect(sound.background, [HoldemSounds.background]);
    expect(HoldemSounds.background, isNot(HoldemSounds.chipLanding));

    await show(initial.copyWith(revision: 10, phase: 'turn'));
    expect(sound.background, hasLength(1));

    await show(initial.copyWith(status: 'finished', finishReason: 'winner'));
    expect(sound.backgroundStops, 1);

    await show(initial.copyWith(revision: 11));
    expect(sound.background, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
    expect(sound.backgroundStops, 2);
  });

  testWidgets('홀덤 칩 착지에만 효과음이 행동당 한 번 재생된다', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sound = _RecordingSound();
    addTearDown(sound.dispose);
    final initial = playingState(lastAction: null);

    Future<void> show(HoldemLastActionModel? action, int revision) =>
        tester.pumpWidget(
          ChangeNotifierProvider<SoundProvider>.value(
            value: sound,
            child: MaterialApp(
              home: HoldemTableScreen(
                game: initial.copyWith(lastAction: action, revision: revision),
                playerLayout: _layout,
              ),
            ),
          ),
        );

    await show(null, 9);
    await show(
      const HoldemLastActionModel(
        uid: 'rival',
        kind: 'raise',
        amount: 400,
        createdAt: 1,
      ),
      10,
    );
    await tester.pump(const Duration(milliseconds: 700));
    expect(sound.played, isEmpty);
    await tester.pump(const Duration(milliseconds: 100));
    expect(sound.played, [HoldemSounds.chipLanding]);
    await tester.pump(const Duration(milliseconds: 800));
    expect(sound.played, hasLength(1));

    await show(
      const HoldemLastActionModel(
        uid: 'me',
        kind: 'check',
        amount: 0,
        createdAt: 2,
      ),
      11,
    );
    await tester.pump(const Duration(milliseconds: 1200));
    expect(sound.played, hasLength(1));

    await show(
      const HoldemLastActionModel(
        uid: 'rival',
        kind: 'fold',
        amount: 0,
        createdAt: 3,
      ),
      12,
    );
    await tester.pump(const Duration(milliseconds: 1150));
    expect(sound.played, hasLength(1));

    await show(
      const HoldemLastActionModel(
        uid: 'rival',
        kind: 'call',
        amount: 200,
        createdAt: 4,
      ),
      13,
    );
    await tester.pump(const Duration(milliseconds: 800));
    expect(sound.played, hasLength(2));
  });
}
