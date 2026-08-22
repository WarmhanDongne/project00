import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/sound/providers/sound_provider.dart';
import 'package:project00/games/mafia/sound/mafia_bgm_plan.dart';
import 'package:project00/games/mafia/sound/mafia_sounds.dart';
import 'package:project00/games/shared/sound/game_background_music.dart';
import 'package:provider/provider.dart';
// SoundProvider가 SharedPreferences를 직접 만들기 때문에, 테스트에서는 메모리
// 구현으로 바꿔 끼웁니다. shared_preferences가 함께 가져오는 패키지입니다.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// 재생 요청만 적어 두는 가짜 사운드입니다(실제 소리는 내지 않습니다).
class _RecordingSoundProvider extends SoundProvider {
  final played = <String>[];
  int stopCount = 0;
  final fadeOuts = <Duration>[];

  @override
  Future<void> playBgm(String assetPath) async {
    played.add(assetPath);
  }

  @override
  Future<void> stopBgm() async {
    stopCount += 1;
  }

  @override
  Future<void> fadeOutBgm({
    Duration duration = const Duration(milliseconds: 1200),
  }) async {
    fadeOuts.add(duration);
  }
}

//=======================마피아 배경음악==============================
// 확정(2026-08): **밤에만** 곡이 깔립니다. 아침이 되면 뚝 끊지 않고 서서히
// 작아지며 사라집니다.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  group('단계별 곡', () {
    test('밤에만 곡을 깐다', () {
      expect(
        mafiaBackgroundMusicFor(isNight: true, isFinished: false),
        MafiaSounds.nightBackground,
      );
      // 신분 확인·아침·낮·투표·개표는 모두 조용합니다.
      expect(
        mafiaBackgroundMusicFor(isNight: false, isFinished: false),
        isNull,
      );
    });

    test('게임이 끝나면 곡을 내린다', () {
      // 밤에 끝나도 결과 화면에는 곡이 깔리지 않습니다.
      expect(mafiaBackgroundMusicFor(isNight: true, isFinished: true), isNull);
    });
  });

  group('곡을 갈아 끼우는 방식', () {
    /// 가짜 사운드를 붙인 배경음악 관리자를 돌려줍니다.
    Future<GameBackgroundMusic> pumpBgm(
      WidgetTester tester,
      SoundProvider sound,
    ) async {
      final bgm = GameBackgroundMusic();
      await tester.pumpWidget(
        ChangeNotifierProvider<SoundProvider>.value(
          value: sound,
          child: MaterialApp(
            home: Builder(
              builder: (context) {
                bgm.attach(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      return bgm;
    }

    testWidgets('아침이 되면 서서히 줄이며 멈춘다', (tester) async {
      final sound = _RecordingSoundProvider();
      final bgm = await pumpBgm(tester, sound);

      // 밤: 곡이 깔립니다.
      bgm.start(MafiaSounds.nightBackground);
      expect(sound.played, [MafiaSounds.nightBackground]);

      // 아침: 뚝 끊지 않고 서서히 사라집니다.
      bgm.fadeOut(duration: mafiaBgmFadeOut);
      expect(sound.fadeOuts, [mafiaBgmFadeOut]);
      expect(sound.stopCount, 0, reason: '갑자기 끊으면 안 됩니다');
      expect(bgm.isPlaying, isFalse);
    });

    testWidgets('사라진 뒤 다음 밤에 다시 깔린다', (tester) async {
      final sound = _RecordingSoundProvider();
      final bgm = await pumpBgm(tester, sound);

      bgm.start(MafiaSounds.nightBackground);
      bgm.fadeOut(duration: mafiaBgmFadeOut);
      bgm.start(MafiaSounds.nightBackground);

      expect(sound.played, [
        MafiaSounds.nightBackground,
        MafiaSounds.nightBackground,
      ]);
    });

    testWidgets('깔린 곡이 없으면 서서히 줄일 것도 없다', (tester) async {
      // 낮에 화면이 여러 번 다시 그려져도 페이드 요청이 쌓이지 않습니다.
      final sound = _RecordingSoundProvider();
      final bgm = await pumpBgm(tester, sound);

      bgm.fadeOut(duration: mafiaBgmFadeOut);
      bgm.fadeOut(duration: mafiaBgmFadeOut);
      expect(sound.fadeOuts, isEmpty);
    });
  });
}
