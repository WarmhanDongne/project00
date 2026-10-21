import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/sound/services/sound_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final native = _AndroidAudioHost();
  late GameAssetStore originalAssets;
  late TargetPlatform? originalPlatform;
  late String originalCachePrefix;
  late SoundService sound;

  setUpAll(() async {
    originalAssets = GameAssetStore.instance;
    originalPlatform = debugDefaultTargetPlatformOverride;
    originalCachePrefix = AudioCache.instance.prefix;
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    GameAssetStore.instance = _FileSoundAssets();
    native.install();
    sound = SoundService.instance;
    await sound.initialize();
  });

  tearDownAll(() async {
    await sound.dispose();
    native.uninstall();
    GameAssetStore.instance = originalAssets;
    debugDefaultTargetPlatformOverride = originalPlatform;
    AudioCache.instance.prefix = originalCachePrefix;
  });

  test('Android effects mix with BGM without taking its audio focus', () async {
    const bgm = 'bgm.mp3';
    const fallback = 'fallback.mp3';
    const dealing = 'dealing.mp3';
    const solo = 'narration.mp3';
    const sustained = 'roulette.mp3';

    await sound.playBgm(bgm);
    final bgmId = native.resumesFor(bgm).single;
    expect(native.players[bgmId]!.focus, AndroidAudioFocus.gain.value);
    expect(native.players[bgmId]!.releaseMode, ReleaseMode.loop.toString());

    void expectBgmPlaying(String effect) {
      expect(native.playing, contains(bgmId), reason: 'BGM during $effect');
      expect(native.focusOwner, bgmId, reason: 'BGM owns focus during $effect');
      expect(native.playing, contains(native.resumesFor(effect).last));
    }

    // Cross the fallback pool boundary to check reused players as well.
    for (var index = 0; index < 10; index += 1) {
      await sound.playEffect(fallback);
      expectBgmPlaying(fallback);
    }
    expect(native.resumesFor(fallback).toSet(), hasLength(8));

    await sound.preloadEffects([dealing]);
    for (var index = 0; index < 6; index += 1) {
      await sound.playEffect(dealing);
      expectBgmPlaying(dealing);
    }
    expect(native.resumesFor(dealing).toSet(), hasLength(4));
    expect(
      native.sources.where((source) => source.path == dealing),
      hasLength(4),
    );

    await sound.preloadEffects([solo], solo: true);
    for (var index = 0; index < 2; index += 1) {
      await sound.playEffect(solo);
      expectBgmPlaying(solo);
    }
    expect(native.resumesFor(solo).toSet(), hasLength(1));

    await sound.playSustainedEffect(sustained);
    expectBgmPlaying(sustained);
    await sound.playSustainedEffect(
      sustained,
      window: const Duration(seconds: 2),
    );
    expectBgmPlaying(sustained);
    final sustainedId = native.resumesFor(sustained).toSet().single;
    expect(native.players[sustainedId]!.position, 4000);
    await sound.stopSustainedEffect();
    expect(native.playing, isNot(contains(sustainedId)));
    expect(native.playing, contains(bgmId));
    expect(native.focusOwner, bgmId);

    // Focus must be configured before source preparation, not only at resume.
    expect(
      native.sources
          .where((source) => source.path != bgm)
          .map((source) => source.focus),
      everyElement(AndroidAudioFocus.none.value),
    );
    await sound.stopBgm();
    expect(native.playing, isNot(contains(bgmId)));
    expect(native.focusOwner, isNull);
  });
}

class _FileSoundAssets extends GameAssetStore {
  @override
  Source soundSourceFor(String assetPath) => DeviceFileSource(assetPath);

  @override
  String? cacheableAssetPath(String assetPath) => null;
}

/// Models Android focus loss while keeping audioplayers' real Dart lifecycle.
class _AndroidAudioHost {
  static const _channel = MethodChannel('xyz.luan/audioplayers');
  static const _global = MethodChannel('xyz.luan/audioplayers.global');
  static const _globalEvents = MethodChannel(
    'xyz.luan/audioplayers.global/events',
  );
  static const _codec = StandardMethodCodec();

  final _messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  final players = <String, _NativePlayer>{};
  final playing = <String>{};
  final sources = <({String path, int focus})>[];
  final _resumes = <({String path, String playerId})>[];
  String? focusOwner;

  List<String> resumesFor(String path) => [
    for (final resume in _resumes)
      if (resume.path == path) resume.playerId,
  ];

  void install() {
    _messenger.setMockMethodCallHandler(_channel, _handle);
    _messenger.setMockMethodCallHandler(_global, (_) async => null);
    _messenger.setMockMethodCallHandler(_globalEvents, (_) async => null);
  }

  void uninstall() {
    _messenger.setMockMethodCallHandler(_channel, null);
    _messenger.setMockMethodCallHandler(_global, null);
    _messenger.setMockMethodCallHandler(_globalEvents, null);
    for (final playerId in players.keys) {
      _messenger.setMockMethodCallHandler(_events(playerId), null);
    }
  }

  MethodChannel _events(String playerId) =>
      MethodChannel('xyz.luan/audioplayers/events/$playerId');

  Future<void> _emit(String playerId, String event, {Object? value}) async {
    await _messenger.handlePlatformMessage(
      _events(playerId).name,
      _codec.encodeSuccessEnvelope({'event': event, 'value': value}),
      (_) {},
    );
  }

  Future<Object?> _handle(MethodCall call) async {
    final args = call.arguments as Map;
    final playerId = args['playerId'] as String;
    if (call.method == 'create') {
      players[playerId] = _NativePlayer();
      _messenger.setMockMethodCallHandler(_events(playerId), (_) async => null);
      return null;
    }
    final player = players[playerId]!;
    switch (call.method) {
      case 'setAudioContext':
        player.focus = args['audioFocus'] as int;
      case 'setReleaseMode':
        player.releaseMode = args['releaseMode'] as String;
      case 'setSourceUrl':
        player.source = args['url'] as String;
        player.position = 0;
        sources.add((path: player.source!, focus: player.focus));
        await _emit(playerId, 'audio.onPrepared', value: true);
      case 'seek':
        player.position = args['position'] as int;
        await _emit(playerId, 'audio.onSeekComplete');
      case 'resume':
        // Android's default gain interrupts the previous focus owner. A
        // no-focus effect plays alongside it without replacing that owner.
        if (player.focus != AndroidAudioFocus.none.value) {
          if (focusOwner != playerId) playing.remove(focusOwner);
          focusOwner = playerId;
        }
        playing.add(playerId);
        _resumes.add((path: player.source!, playerId: playerId));
      case 'stop':
      case 'pause':
      case 'release':
      case 'dispose':
        playing.remove(playerId);
        if (focusOwner == playerId) focusOwner = null;
      case 'getCurrentPosition':
        return player.position;
      case 'getDuration':
        return 6000;
    }
    return null;
  }
}

class _NativePlayer {
  int focus = AndroidAudioFocus.gain.value;
  String? source;
  String? releaseMode;
  int position = 0;
}
