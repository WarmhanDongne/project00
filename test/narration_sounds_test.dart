import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/core/sound/providers/sound_provider.dart';
import 'package:project00/games/final_call/models/final_call_models.dart';
import 'package:project00/games/final_call/sound/final_call_sounds.dart';
import 'package:project00/games/liars_poker/sound/liars_poker_sounds.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_game_layout.dart';
import 'package:project00/games/mafia/sound/mafia_sounds.dart';
import 'package:provider/provider.dart';
// SoundProvider가 SharedPreferences를 직접 만들기 때문에, 테스트에서는 메모리
// 구현으로 바꿔 끼웁니다. shared_preferences가 함께 가져오는 패키지입니다.
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
// ignore: depend_on_referenced_packages
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

//=======================나레이션 파일==============================
// 2026-08-22에 받은 사람 목소리 9개입니다. 경로를 한 글자만 틀려도 **소리가
// 조용히 안 나기만** 하고 화면은 정상으로 보입니다(재생 실패는 삼킵니다).
// 그래서 파일이 번들에 실제로 있는지, 미리 준비 목록에 올랐는지 확인합니다.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const narrations = <String, String>{
    '라이어!': LiarsPokerSounds.voiceLiar,
    '콜!': FinalCallSounds.voiceCall,
    '블루팀 승리': FinalCallSounds.voiceWinBlue,
    '레드팀 승리': FinalCallSounds.voiceWinRed,
    '무승부': FinalCallSounds.voiceDraw,
    '밤이 되었습니다': MafiaSounds.voiceNight,
    '지금부터 토론을 시작합니다': MafiaSounds.voiceDiscussion,
    '시민팀 승리': MafiaSounds.voiceWinCitizen,
    '마피아팀 승리': MafiaSounds.voiceWinMafia,
  };

  test('나레이션 9개가 모두 번들에 들어 있다', () async {
    for (final entry in narrations.entries) {
      final data = await rootBundle.load(entry.value);
      expect(
        data.lengthInBytes,
        greaterThan(2000),
        reason: '${entry.key}(${entry.value})이 비어 있거나 없습니다',
      );
    }
  });

  test('나레이션은 게임 진입 때 미리 준비한다', () {
    // 준비하지 않으면 첫 재생이 화면보다 늦습니다. 나레이션은 한 판에 한 번씩만
    // 나므로 매번 그 지연을 겪습니다.
    expect(
      LiarsPokerSounds.narrationTargets,
      contains(LiarsPokerSounds.voiceLiar),
    );
    for (final path in [
      FinalCallSounds.voiceCall,
      FinalCallSounds.voiceWinBlue,
      FinalCallSounds.voiceWinRed,
      FinalCallSounds.voiceDraw,
    ]) {
      expect(FinalCallSounds.narrationTargets, contains(path));
    }
    for (final path in [
      MafiaSounds.voiceNight,
      MafiaSounds.voiceDiscussion,
      MafiaSounds.voiceWinCitizen,
      MafiaSounds.voiceWinMafia,
    ]) {
      expect(MafiaSounds.narrationTargets, contains(path));
    }
  });

  test('나레이션은 효과음 목록과 섞지 않는다', () {
    // 안내 음성은 겹쳐 나지 않아 사본을 하나만 둡니다(`solo: true`). 효과음
    // 목록에 섞이면 사본이 4개씩 잡혀, 기기 디코더가 모자라 **뒤쪽 소리가
    // 통째로 준비되지 않습니다** — 2026-08 iOS에서 마피아 승리 음성이 그렇게
    // 실패했습니다.
    for (final entry in narrations.entries) {
      expect(
        [
          ...LiarsPokerSounds.preloadTargets,
          ...FinalCallSounds.preloadTargets,
          ...MafiaSounds.preloadTargets,
        ],
        isNot(contains(entry.value)),
        reason: '${entry.key}이 효과음 목록에 들어 있습니다',
      );
    }
  });

  test('마피아는 이긴 진영에 맞는 나레이션을 고른다', () {
    expect(
      MafiaSounds.winVoiceFor(MafiaFaction.citizen),
      MafiaSounds.voiceWinCitizen,
    );
    expect(
      MafiaSounds.winVoiceFor(MafiaFaction.mafia),
      MafiaSounds.voiceWinMafia,
    );
    // 중립 개별 승리는 아직 파일이 없어 조용히 지나갑니다.
    expect(MafiaSounds.winVoiceFor(MafiaFaction.neutral), isNull);
    expect(MafiaSounds.winVoiceFor(null), isNull);
  });

  group('밤 안내 나레이션', () {
    setUp(() {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
    });

    Future<_RecordingSound> pumpNotice(
      WidgetTester tester, {
      required bool isNight,
    }) async {
      final sound = _RecordingSound();
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<SoundProvider>.value(
          value: sound,
          child: MaterialApp(
            home: isNight
                ? const MafiaTabletNotice.night(text: '밤이 되었습니다')
                : const MafiaTabletNotice.day(text: '아침이 되었습니다'),
          ),
        ),
      );
      // 나레이션은 첫 프레임 뒤에 냅니다(context를 쓰는 일).
      await tester.pump();
      return sound;
    }

    testWidgets('밤 안내가 뜨면 나레이션을 낸다', (tester) async {
      final sound = await pumpNotice(tester, isNight: true);
      expect(sound.played, [MafiaSounds.voiceNight]);

      // 안내가 화면에 남아 있는 동안 다시 내지 않습니다.
      await tester.pump(const Duration(seconds: 2));
      expect(sound.played.length, 1);
    });

    testWidgets('낮 안내는 그 안내의 음성만 낸다', (tester) async {
      // 아침 안내에는 음성이 없습니다.
      final sound = await pumpNotice(tester, isNight: false);
      expect(sound.played, isEmpty);
    });

    testWidgets('토론 시작 안내는 그 음성을 낸다', (tester) async {
      // 안내마다 음성이 따로 있습니다. 문구로 추측하지 않고 받아서 냅니다.
      final sound = _RecordingSound();
      tester.view.physicalSize = const Size(1194, 834);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ChangeNotifierProvider<SoundProvider>.value(
          value: sound,
          child: const MaterialApp(
            home: MafiaTabletNotice.day(
              text: '토론을 시작합니다',
              voice: MafiaSounds.voiceDiscussion,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(sound.played, [MafiaSounds.voiceDiscussion]);
    });
  });

  test('파이널 콜은 결과에 맞는 나레이션을 고른다', () {
    expect(
      FinalCallSounds.resultVoiceFor(
        isDraw: false,
        winningTeam: FinalCallTeam.blue,
      ),
      FinalCallSounds.voiceWinBlue,
    );
    expect(
      FinalCallSounds.resultVoiceFor(
        isDraw: false,
        winningTeam: FinalCallTeam.red,
      ),
      FinalCallSounds.voiceWinRed,
    );
    // 무승부는 팀과 무관합니다.
    expect(
      FinalCallSounds.resultVoiceFor(isDraw: true, winningTeam: null),
      FinalCallSounds.voiceDraw,
    );
  });
}

/// 재생 요청만 적어 두는 가짜 사운드입니다(실제 소리는 내지 않습니다).
class _RecordingSound extends SoundProvider {
  final played = <String>[];

  @override
  Future<void> playEffect(String assetPath) async {
    played.add(assetPath);
  }
}
