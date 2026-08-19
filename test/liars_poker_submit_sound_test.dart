import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/sound/providers/sound_provider.dart';
import 'package:project00/games/liars_poker/animations/tablet_card_play_animation.dart';
import 'package:project00/games/liars_poker/sound/liars_poker_sounds.dart';
import 'package:project00/gen/assets.gen.dart';
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
}

void main() {
  setUp(() {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
  });

  final cardAssets = [Assets.games.liarsPoker.images.cards.values.first];

  Future<void> pumpPlay(
    WidgetTester tester,
    SoundProvider sound, {
    required bool revealCards,
    required bool autoplay,
    GlobalKey<CardPlayAnimationState>? animationKey,
  }) async {
    await tester.pumpWidget(
      ChangeNotifierProvider<SoundProvider>.value(
        value: sound,
        child: MaterialApp(
          home: Scaffold(
            body: CardPlayAnimation(
              key: animationKey,
              frontCardAssets: cardAssets,
              autoplay: autoplay,
              revealCards: revealCards,
            ),
          ),
        ),
      ),
    );
    await tester.pump();
  }

  int countOf(_RecordingSoundProvider sound) => sound.playedEffects
      .where((path) => path == LiarsPokerSounds.submit)
      .length;

  //=======================제출==============================
  testWidgets('좌석에서 중앙으로 패를 던질 때 submit 효과음을 재생한다', (tester) async {
    final sound = _RecordingSoundProvider();

    await pumpPlay(tester, sound, revealCards: false, autoplay: true);
    await tester.pumpAndSettle();

    expect(countOf(sound), 1);
    expect(tester.takeException(), isNull);
  });

  //=======================공개==============================
  // 라이어가 선언되면 revealCards가 false에서 true로 바뀌고, 그때 던져진 패가
  // 뒤집힙니다. 던질 때와 공개할 때 각각 한 번씩 소리가 나야 합니다.
  testWidgets('던진 패를 공개할 때 submit 효과음을 한 번 더 재생한다', (tester) async {
    final sound = _RecordingSoundProvider();
    final key = GlobalKey<CardPlayAnimationState>();

    await pumpPlay(
      tester,
      sound,
      revealCards: false,
      autoplay: true,
      animationKey: key,
    );
    await tester.pumpAndSettle();
    expect(countOf(sound), 1);

    unawaited(key.currentState!.reveal());
    await tester.pumpAndSettle();

    expect(countOf(sound), 2);
    expect(tester.takeException(), isNull);
  });

  //=======================공개 효과음은 착지에 맞춘다==============================
  // 카드는 뒤집히는 동안 살짝 떠 있다가 뒤집기가 끝나며 바닥에 놓입니다.
  // 소리는 그 내려앉는 순간에 나야 합니다. 연출 시작에 재생하면 기본 900ms
  // 기준으로 약 650ms 먼저 들려 화면과 어긋납니다.
  testWidgets('공개 효과음은 연출 시작이 아니라 카드가 내려앉을 때 재생한다', (tester) async {
    final sound = _RecordingSoundProvider();
    final key = GlobalKey<CardPlayAnimationState>();

    await pumpPlay(
      tester,
      sound,
      revealCards: false,
      autoplay: true,
      animationKey: key,
    );
    await tester.pumpAndSettle();
    expect(countOf(sound), 1, reason: '던지기 착지음만 났어야 합니다');

    unawaited(key.currentState!.reveal());

    // 첫 장이 내려앉는 시점(revealDuration 900ms의 0.72 ≈ 648ms) 전입니다.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(countOf(sound), 1, reason: '아직 카드가 떠 있는 동안이라 소리가 없어야 합니다');

    // 내려앉는 시점을 지나면 재생됩니다.
    await tester.pump(const Duration(milliseconds: 350));
    expect(countOf(sound), 2);

    await tester.pumpAndSettle();
    expect(countOf(sound), 2, reason: '남은 연출에서 중복 재생되면 안 됩니다');
    expect(tester.takeException(), isNull);
  });

  // 이미 공개가 끝난 패를 다시 그리는 경우(재접속, 화면 재구성)에는 연출이
  // 시작되지 않으므로 소리도 나면 안 됩니다.
  testWidgets('이미 공개된 패를 다시 그릴 때는 재생하지 않는다', (tester) async {
    final sound = _RecordingSoundProvider();
    final key = GlobalKey<CardPlayAnimationState>();

    await pumpPlay(
      tester,
      sound,
      revealCards: false,
      autoplay: true,
      animationKey: key,
    );
    await tester.pumpAndSettle();
    unawaited(key.currentState!.reveal());
    await tester.pumpAndSettle();
    expect(countOf(sound), 2);

    unawaited(key.currentState!.reveal());
    await tester.pumpAndSettle();

    expect(countOf(sound), 2);
    expect(tester.takeException(), isNull);
  });
}
