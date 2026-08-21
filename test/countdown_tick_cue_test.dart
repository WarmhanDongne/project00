import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/sound/app_sounds.dart';
import 'package:project00/core/sound/providers/sound_provider.dart';
import 'package:project00/core/time/server_clock.dart';
import 'package:project00/games/shared/sound/countdown_tick_cue.dart';
import 'package:provider/provider.dart';
// SoundProvider가 SharedPreferences를 직접 만들기 때문에, 테스트에서는 메모리
// 구현으로 바꿔 끼웁니다. shared_preferences가 함께 가져오는 패키지입니다.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// 실제 오디오 플레이어를 건드리지 않고 재생·정지 요청만 기록합니다.
class _RecordingSoundProvider extends SoundProvider {
  final played = <String>[];
  int stopCount = 0;

  @override
  Future<void> playSustainedEffect(String assetPath, {Duration? window}) async {
    played.add(assetPath);
  }

  @override
  Future<void> stopSustainedEffect() async {
    stopCount += 1;
  }
}

/// 초읽기 소리는 마감 5초 전에 정확히 시작해야 화면의 남은 초와 맞습니다.
/// 1초 주기 갱신에 기대면 최대 1초까지 밀리므로 그 회귀를 막습니다.
void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    // 기기 시계를 그대로 서버 시각으로 씁니다(보정 0).
    ServerClock.debugSetOffset(0);
  });
  tearDown(() async {
    await ServerClock.stop();
  });

  /// 큐를 붙인 빈 화면을 띄우고 큐를 돌려줍니다.
  Future<CountdownTickCue> pumpCue(
    WidgetTester tester,
    SoundProvider sound,
  ) async {
    final cue = CountdownTickCue();
    await tester.pumpWidget(
      ChangeNotifierProvider<SoundProvider>.value(
        value: sound,
        child: MaterialApp(
          home: Builder(
            builder: (context) {
              cue.attach(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      ),
    );
    return cue;
  }

  int deadlineIn(Duration remaining) =>
      ServerClock.nowMillis() + remaining.inMilliseconds;

  //=======================시작 시점==============================
  testWidgets('마감 5초 전에 초읽기를 시작한다', (tester) async {
    final sound = _RecordingSoundProvider();
    final cue = await pumpCue(tester, sound);

    cue.schedule(deadlineIn(const Duration(seconds: 30)));

    // 5초를 남기기 직전까지는 아무 소리도 나지 않습니다.
    await tester.pump(const Duration(seconds: 24, milliseconds: 900));
    expect(sound.played, isEmpty);

    // 정확히 5초를 남긴 순간 한 번 재생합니다.
    await tester.pump(const Duration(milliseconds: 200));
    expect(sound.played, [AppSounds.timer]);

    // 남은 시간이 흘러도 다시 재생하지 않습니다.
    await tester.pump(const Duration(seconds: 5));
    expect(sound.played, [AppSounds.timer]);

    cue.stop();
  });

  //=======================같은 마감 재호출==============================
  testWidgets('마감이 그대로면 예약을 유지해 초읽기가 끊기지 않는다', (tester) async {
    final sound = _RecordingSoundProvider();
    final cue = await pumpCue(tester, sound);
    final deadline = deadlineIn(const Duration(seconds: 30));

    cue.schedule(deadline);
    await tester.pump(const Duration(seconds: 26));
    expect(sound.played, [AppSounds.timer]);

    // 서버 상태 갱신마다 같은 마감으로 다시 불러도 멈추거나 겹치지 않습니다.
    cue.schedule(deadline);
    cue.schedule(deadline);
    await tester.pump(const Duration(milliseconds: 100));
    expect(sound.played, [AppSounds.timer]);
    expect(sound.stopCount, 0);

    cue.stop();
  });

  //=======================턴 종료==============================
  testWidgets('마감이 사라지면 재생 중인 초읽기를 멈춘다', (tester) async {
    final sound = _RecordingSoundProvider();
    final cue = await pumpCue(tester, sound);

    cue.schedule(deadlineIn(const Duration(seconds: 30)));
    await tester.pump(const Duration(seconds: 26));
    expect(sound.played, [AppSounds.timer]);

    // 제한시간 전에 행동을 마치면 마감이 null이 되고 소리도 끊깁니다.
    cue.schedule(null);
    expect(sound.stopCount, 1);
  });

  testWidgets('마감 전에 화면을 떠나면 초읽기를 멈춘다', (tester) async {
    final sound = _RecordingSoundProvider();
    final cue = await pumpCue(tester, sound);

    cue.schedule(deadlineIn(const Duration(seconds: 30)));
    await tester.pump(const Duration(seconds: 26));

    cue.stop();
    expect(sound.stopCount, 1);
  });

  //=======================재접속==============================
  testWidgets('이미 초읽기 구간 안이면 중간부터 울리지 않는다', (tester) async {
    final sound = _RecordingSoundProvider();
    final cue = await pumpCue(tester, sound);

    // 재접속으로 3초만 남은 상태에서 예약되는 경우입니다.
    cue.schedule(deadlineIn(const Duration(seconds: 3)));

    await tester.pump(const Duration(seconds: 4));
    expect(sound.played, isEmpty);

    cue.stop();
  });

  //=======================다음 턴==============================
  testWidgets('마감이 바뀌면 새 마감 기준으로 다시 예약한다', (tester) async {
    final sound = _RecordingSoundProvider();
    final cue = await pumpCue(tester, sound);

    cue.schedule(deadlineIn(const Duration(seconds: 10)));
    await tester.pump(const Duration(seconds: 1));
    expect(sound.played, isEmpty);

    // 다음 턴이 시작되며 마감이 30초로 갱신됩니다.
    cue.schedule(deadlineIn(const Duration(seconds: 30)));

    // 이전 마감(9초 뒤)에는 울리지 않습니다.
    await tester.pump(const Duration(seconds: 10));
    expect(sound.played, isEmpty);

    // 새 마감의 5초 전에 울립니다.
    await tester.pump(const Duration(seconds: 15, milliseconds: 100));
    expect(sound.played, [AppSounds.timer]);

    cue.stop();
  });
}
