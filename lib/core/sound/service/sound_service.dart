import 'package:audioplayers/audioplayers.dart';

class SoundService {
  final AudioPlayer _bgmPlayer = AudioPlayer();
  final AudioPlayer _effectPlayer = AudioPlayer();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _effectPlayer.setReleaseMode(ReleaseMode.stop);
    _initialized = true;
  }

  /// ----------------------------
  /// BGM
  /// ----------------------------

  Future<void> playBgm(String assetPath) async {
    await initialize();
    await _bgmPlayer.play(AssetSource(_normalizeAssetPath(assetPath)));
  }

  Future<void> stopBgm() async {
    await _bgmPlayer.stop();
  }

  Future<void> pauseBgm() async {
    await _bgmPlayer.pause();
  }

  Future<void> resumeBgm() async {
    await initialize();
    await _bgmPlayer.resume();
  }

  Future<void> setBgmVolume(double volume) async {
    await initialize();
    await _bgmPlayer.setVolume(_normalizedVolume(volume));
  }

  /// ----------------------------
  /// Effect
  /// ----------------------------

  Future<void> playEffect(String assetPath) async {
    await initialize();
    await _effectPlayer.play(AssetSource(_normalizeAssetPath(assetPath)));
  }

  Future<void> setEffectVolume(double volume) async {
    await initialize();
    await _effectPlayer.setVolume(_normalizedVolume(volume));
  }

  /// ----------------------------
  /// Master
  /// ----------------------------

  Future<void> setMasterVolume({
    required double bgmVolume,
    required double effectVolume,
  }) async {
    await initialize();
    await Future.wait([
      _bgmPlayer.setVolume(_normalizedVolume(bgmVolume)),
      _effectPlayer.setVolume(_normalizedVolume(effectVolume)),
    ]);
  }

  String _normalizeAssetPath(String path) {
    const assetPrefix = 'assets/';
    return path.startsWith(assetPrefix)
        ? path.substring(assetPrefix.length)
        : path;
  }

  double _normalizedVolume(double value) => value.clamp(0.0, 1.0).toDouble();

  /// ----------------------------
  /// Dispose
  /// ----------------------------

  Future<void> dispose() async {
    await Future.wait([_bgmPlayer.dispose(), _effectPlayer.dispose()]);
  }
}
