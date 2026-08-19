import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/sound/app_sounds.dart';
import 'package:project00/core/sound/providers/sound_provider.dart';
import 'package:project00/games/penalty/roulette.dart';
import 'package:provider/provider.dart';
// SoundProvider가 SharedPreferences를 직접 만들기 때문에, 테스트에서는 메모리
// 구현으로 바꿔 끼웁니다. shared_preferences가 함께 가져오는 패키지입니다.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// 실제 오디오 플레이어를 건드리지 않고 재생 요청만 기록합니다.
class _RecordingSoundProvider extends SoundProvider {
  final playedEffects = <String>[];

  @override
  Future<void> playEffect(String assetPath) async {
    playedEffects.add(assetPath);
  }

  @override
  Future<void> playSustainedEffect(String assetPath, {Duration? window}) async {
    playedEffects.add(assetPath);
  }

  @override
  Future<void> stopSustainedEffect() async {}
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  /// 레버 좌표 판정은 1300 × 900 디자인 캔버스를 기준으로 합니다. 화면을 같은
  /// 크기로 맞춰 FittedBox 배율을 1로 만들면 드래그 거리가 그대로 전달됩니다.
  Future<void> pumpRoulette(WidgetTester tester, SoundProvider? sound) async {
    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const roulette = MaterialApp(
      home: Scaffold(
        body: PenaltyRoulette(attemptCount: 0, onResult: _ignoreResult),
      ),
    );

    await tester.pumpWidget(
      sound == null
          ? roulette
          : ChangeNotifierProvider<SoundProvider>.value(
              value: sound,
              child: roulette,
            ),
    );
    await tester.pump();
  }

  /// 레버 터치 영역은 디자인 캔버스 Stack의 마지막 자식입니다.
  Finder leverArea() => find.byType(GestureDetector).last;

  //=======================레버를 내렸을 때==============================
  testWidgets('레버를 끝까지 내리면 레버 효과음을 재생한다', (tester) async {
    final sound = _RecordingSoundProvider();

    await pumpRoulette(tester, sound);

    // 임계값은 0.75이고 드래그 400px이 1.0입니다. 320px이면 0.8로 잠깁니다.
    await tester.drag(leverArea(), const Offset(0, 320));
    await tester.pump();

    expect(sound.playedEffects, contains(AppSounds.lever));

    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('임계점에 못 미치면 레버 효과음을 재생하지 않는다', (tester) async {
    final sound = _RecordingSoundProvider();

    await pumpRoulette(tester, sound);

    // 0.3까지만 내렸다 놓으면 레버가 제자리로 돌아가고 회전도 하지 않습니다.
    await tester.drag(leverArea(), const Offset(0, 120));
    await tester.pumpAndSettle();

    expect(sound.playedEffects, isNot(contains(AppSounds.lever)));
    expect(tester.takeException(), isNull);
  });

  //=======================사운드는 연출을 막지 않는다==============================
  // 사운드는 보조 기능입니다. SoundProvider가 없어도 레버와 회전은 그대로
  // 동작해야 벌칙 진행이 막히지 않습니다.
  testWidgets('SoundProvider가 없어도 레버를 내리면 룰렛이 돌아간다', (tester) async {
    RouletteResult? result;

    tester.view.physicalSize = const Size(1300, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PenaltyRoulette(
            attemptCount: 0,
            onResult: (value) => result = value,
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.drag(leverArea(), const Offset(0, 320));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(result, isNotNull);
  });
}

void _ignoreResult(RouletteResult result) {}
