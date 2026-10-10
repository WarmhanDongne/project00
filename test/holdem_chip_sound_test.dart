import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/game_sounds.dart';
import 'package:game_holdem/phone/screens/game_screen.dart';
import 'package:game_holdem/shared/models/game_models.dart';
import 'package:game_holdem/shared/models/game_state.dart';
import 'package:game_holdem/tablet/screens/table_screen.dart';
import 'package:game_kit/player_layouts/models/player_layout.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
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
  late GameAssetStore previousStore;
  setUp(() {
    previousStore = GameAssetStore.instance;
    GameAssetStore.instance = FakeHoldemAssetStore();
  });
  tearDown(() => GameAssetStore.instance = previousStore);

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

  testWidgets('베팅·체크·폴드는 해당 효과음이 행동당 한 번 재생된다', (tester) async {
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
    expect(sound.played, [HoldemSounds.chipLanding, HoldemSounds.check]);

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
    expect(sound.played, [
      HoldemSounds.chipLanding,
      HoldemSounds.check,
      HoldemSounds.cardTable,
    ]);

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
    expect(sound.played, [
      HoldemSounds.chipLanding,
      HoldemSounds.check,
      HoldemSounds.cardTable,
      HoldemSounds.chipLanding,
    ]);
  });

  testWidgets('새 효과음이 번들에 있고 체크음은 첫 타격만 남긴 짧은 WAV다', (tester) async {
    for (final path in HoldemSounds.preloadTargets) {
      expect((await rootBundle.load(path)).lengthInBytes, greaterThan(100));
    }
    final wav = await rootBundle.load(HoldemSounds.check);
    // PCM WAV 헤더의 sample rate, byte rate, data size로 길이를 검증합니다.
    final seconds =
        wav.getUint32(40, Endian.little) / wav.getUint32(28, Endian.little);
    expect(seconds, closeTo(.195, .001));
    final shared = await rootBundle.load(HoldemSounds.cardTable);
    final original = await rootBundle.load(
      'packages/game_liars_poker/assets/games/liars_poker/sounds/submit.mp3',
    );
    expect(shared.buffer.asUint8List(), original.buffer.asUint8List());
  });

  testWidgets('배분은 카드별 착지에, 공용 카드 공개는 첫 뒤집기 착지에 재생된다', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sound = _RecordingSound();
    addTearDown(sound.dispose);
    Future<void> show(HoldemGameState game) => tester.pumpWidget(
      ChangeNotifierProvider<SoundProvider>.value(
        value: sound,
        child: MaterialApp(
          home: HoldemTableScreen(game: game, playerLayout: _layout),
        ),
      ),
    );
    final initial = playingState(phase: 'dealing').copyWith(communityCards: []);
    await show(initial);
    await tester.pump(const Duration(milliseconds: 890));
    expect(sound.played, isEmpty);
    await tester.pump(const Duration(milliseconds: 30));
    expect(sound.played, [HoldemSounds.dealing]);
    await tester.pump(const Duration(milliseconds: 2100));
    expect(sound.played, List.filled(4, HoldemSounds.dealing));
    sound.played.clear();
    await show(initial.copyWith(phase: 'preflop'));
    await show(
      initial.copyWith(
        phase: 'flop',
        communityCards: playingState().communityCards,
      ),
    );
    await tester.pump(const Duration(milliseconds: 630));
    expect(sound.played, isEmpty);
    await tester.pump(const Duration(milliseconds: 30));
    expect(sound.played, [HoldemSounds.cardTable]);
    await tester.pump(const Duration(milliseconds: 400));
    final turn = initial.copyWith(
      phase: 'turn',
      communityCards: [...playingState().communityCards, card('2', 'hearts')],
    );
    await show(turn);
    await tester.pump(const Duration(milliseconds: 660));
    expect(sound.played, List.filled(2, HoldemSounds.cardTable));
    await show(turn.copyWith(revision: 20));
    await tester.pump(const Duration(seconds: 1));
    expect(sound.played, hasLength(2));
    final river = turn.copyWith(
      phase: 'river',
      communityCards: [...turn.communityCards, card('3', 'hearts')],
    );
    await show(river);
    await tester.pump(const Duration(milliseconds: 660));
    expect(sound.played, List.filled(3, HoldemSounds.cardTable));
    await tester.pumpWidget(const SizedBox.shrink());
    sound.played.clear();
    await show(river); // 재접속으로 이미 공개된 보드를 복원하면 소리 없음.
    await tester.pump(const Duration(seconds: 1));
    expect(sound.played, isEmpty);
  });

  testWidgets('올인 강조와 칩 착지, 팟 지급이 각각 한 번 재생된다', (tester) async {
    tester.view.physicalSize = const Size(1366, 1024);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final sound = _RecordingSound();
    addTearDown(sound.dispose);
    Future<void> show(HoldemGameState game) => tester.pumpWidget(
      ChangeNotifierProvider<SoundProvider>.value(
        value: sound,
        child: MaterialApp(
          home: HoldemTableScreen(game: game, playerLayout: _layout),
        ),
      ),
    );
    final initial = playingState();
    await show(initial);
    final allIn = initial.copyWith(
      lastAction: const HoldemLastActionModel(
        uid: 'me',
        kind: 'allIn',
        amount: 4900,
        createdAt: 10,
      ),
    );
    await show(allIn);
    await tester.pump(const Duration(milliseconds: 50));
    expect(sound.played, [HoldemSounds.allIn]);
    await tester.pump(const Duration(milliseconds: 800));
    expect(sound.played, [HoldemSounds.allIn, HoldemSounds.chipLanding]);
    await show(allIn.copyWith(revision: 11));
    await tester.pump(const Duration(seconds: 1));
    expect(sound.played, hasLength(2));
    final result = allIn.copyWith(
      phase: 'handResult',
      result: const HoldemHandResultModel(
        reason: 'fold',
        winnerUids: ['me'],
        awards: {'me': 1800},
        revealedHands: {},
        handCategories: {},
      ),
    );
    await show(result);
    await tester.pump(const Duration(milliseconds: 1050));
    expect(sound.played, hasLength(2));
    await tester.pump(const Duration(milliseconds: 200));
    expect(sound.played.last, HoldemSounds.potAward);
    await show(result.copyWith(revision: 12));
    await tester.pump(const Duration(seconds: 2));
    expect(sound.played.where((s) => s == HoldemSounds.potAward), hasLength(1));
    await tester.pumpWidget(const SizedBox.shrink());
    sound.played.clear();
    await show(result);
    await tester.pump(const Duration(milliseconds: 1050));
    await tester.pump(const Duration(seconds: 2));
    expect(sound.played, isEmpty);
  });

  testWidgets('내 턴 진동은 개인 권한 도착 뒤 한 번, 다음 턴에는 다시 울린다', (tester) async {
    final haptics = <Object?>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          haptics.add(call.arguments);
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    Future<void> show(HoldemGameState game) => tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: HoldemPhoneGameScreen(
            game: game,
            uid: 'me',
            onAction: (_, {amount}) async => true,
          ),
        ),
      ),
    );
    final initial = playingState(turnUid: 'rival');
    await show(initial);
    expect(haptics, isEmpty);
    final pending = initial.copyWith(turnUid: 'me');
    await show(pending);
    expect(haptics, isEmpty);
    final ready = pending.copyWith(legalActions: callOrRaise);
    await show(ready);
    expect(haptics, ['HapticFeedbackType.mediumImpact']);
    await show(ready.copyWith(revision: 20));
    await show(ready.copyWith(legalActions: null));
    await show(ready);
    expect(haptics, hasLength(1));
    await show(ready.copyWith(turnUid: 'rival'));
    await show(ready.copyWith(turnDeadlineAt: ready.turnDeadlineAt! + 20000));
    expect(haptics, hasLength(2));
    await show(ready.copyWith(turnDeadlineAt: 1));
    expect(haptics, hasLength(2));
    await show(ready.copyWith(status: 'finished'));
    expect(haptics, hasLength(2));
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
