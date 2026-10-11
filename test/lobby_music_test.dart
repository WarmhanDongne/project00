import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/sound/providers/sound_provider.dart';
import 'package:project00/platform/sound/lobby_music.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('로비 곡은 상점에서 상점 곡으로 바뀌고 게임 화면에서는 멈췄다가 돌아오면 다시 흐른다', (
    tester,
  ) async {
    final sound = _Sound();
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ChangeNotifierProvider<SoundProvider>.value(
        value: sound,
        child: MaterialApp(
          navigatorKey: navigator,
          home: const LobbyMusic(
            track: LobbyTracks.lobby,
            child: Scaffold(body: Text('로비')),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(sound.calls, ['play ${LobbyTracks.lobby}']);

    // 설정 같은 모달이 떠도 곡은 그대로입니다.
    showDialog<void>(
      context: navigator.currentContext!,
      builder: (_) => const AlertDialog(content: Text('설정')),
    );
    await tester.pumpAndSettle();
    expect(sound.calls, ['play ${LobbyTracks.lobby}']);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();

    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const LobbyMusic(
          track: LobbyTracks.store,
          child: Scaffold(body: Text('상점')),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(sound.calls.last, 'play ${LobbyTracks.store}');
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(sound.calls.last, 'play ${LobbyTracks.lobby}');

    sound.calls.clear();
    navigator.currentState!.push(
      MaterialPageRoute<void>(
        builder: (_) => const Scaffold(body: Text('게임')),
      ),
    );
    await tester.pumpAndSettle();
    expect(sound.calls, ['stop']);
    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(sound.calls, ['stop', 'play ${LobbyTracks.lobby}']);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(sound.calls.last, 'stop');
  });

  testWidgets('앱이 백그라운드로 가면 멈추고 돌아오면 다시 재생한다', (tester) async {
    final sound = _Sound();
    await tester.pumpWidget(
      ChangeNotifierProvider<SoundProvider>.value(
        value: sound,
        child: const MaterialApp(
          home: LobbyMusic(
            track: LobbyTracks.lobby,
            child: Scaffold(body: Text('로비')),
          ),
        ),
      ),
    );
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(sound.calls.last, 'stop');
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    expect(sound.calls.last, 'play ${LobbyTracks.lobby}');
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _Sound extends SoundProvider {
  _Sound() : super(preferences: _Preferences());

  final calls = <String>[];

  @override
  Future<void> playBgm(String assetPath) async => calls.add('play $assetPath');

  @override
  Future<void> stopBgm() async => calls.add('stop');
}

class _Preferences implements SharedPreferencesAsync {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
