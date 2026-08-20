import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/sound/service/sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SoundProvider extends ChangeNotifier {
  SoundProvider({SoundService? service, SharedPreferencesAsync? preferences})
    : _service = service ?? SoundService(),
      _preferences = preferences ?? SharedPreferencesAsync();

  static const _masterVolumeKey = 'sound.masterVolume';
  static const _effectVolumeKey = 'sound.effectVolume';
  static const _bgmVolumeKey = 'sound.bgmVolume';

  final SoundService _service;
  final SharedPreferencesAsync _preferences;

  double _masterVolume = 50;
  double _effectVolume = 80;
  double _bgmVolume = 30;
  bool _initialized = false;
  bool _initializing = false;

  double get masterVolume => _masterVolume;
  double get effectVolume => _effectVolume;
  double get bgmVolume => _bgmVolume;
  bool get initialized => _initialized;

  double get effectiveEffectVolume =>
      (_masterVolume / 100) * (_effectVolume / 100);
  double get effectiveBgmVolume => (_masterVolume / 100) * (_bgmVolume / 100);

  Future<void> initialize() async {
    if (_initialized || _initializing) return;
    _initializing = true;

    try {
      final savedVolumes = await Future.wait([
        _preferences.getDouble(_masterVolumeKey),
        _preferences.getDouble(_effectVolumeKey),
        _preferences.getDouble(_bgmVolumeKey),
      ]);

      _masterVolume = _sliderValue(savedVolumes[0] ?? _masterVolume);
      _effectVolume = _sliderValue(savedVolumes[1] ?? _effectVolume);
      _bgmVolume = _sliderValue(savedVolumes[2] ?? _bgmVolume);
    } catch (error, stackTrace) {
      debugPrint('저장된 사운드 설정을 불러오지 못했습니다: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _service.initialize();
      await _applyVolumes();
    } catch (error, stackTrace) {
      // 사운드 초기화 실패가 앱 화면 렌더링까지 중단시키면 안 됩니다.
      debugPrint('사운드 플레이어를 초기화하지 못했습니다: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _initializing = false;
      _initialized = true;
      notifyListeners();
    }
  }

  void setMasterVolume(double value) {
    _masterVolume = _sliderValue(value);
    notifyListeners();
    _runSafely(_preferences.setDouble(_masterVolumeKey, _masterVolume));
    _runSafely(_applyVolumes());
  }

  void setEffectVolume(double value) {
    _effectVolume = _sliderValue(value);
    notifyListeners();
    _runSafely(_preferences.setDouble(_effectVolumeKey, _effectVolume));
    _runSafely(_applyVolumes());
  }

  void setBgmVolume(double value) {
    _bgmVolume = _sliderValue(value);
    notifyListeners();
    _runSafely(_preferences.setDouble(_bgmVolumeKey, _bgmVolume));
    _runSafely(_applyVolumes());
  }

  Future<void> playBgm(String assetPath) => _service.playBgm(assetPath);

  Future<void> stopBgm() => _service.stopBgm();

  Future<void> pauseBgm() => _service.pauseBgm();

  Future<void> resumeBgm() => _service.resumeBgm();

  Future<void> playEffect(String assetPath) => _service.playEffect(assetPath);

  Future<void> _applyVolumes() {
    return _service.setMasterVolume(
      bgmVolume: effectiveBgmVolume,
      effectVolume: effectiveEffectVolume,
    );
  }

  double _sliderValue(double value) => value.clamp(0.0, 100.0).toDouble();

  void _runSafely(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stackTrace) {
        debugPrint('사운드 설정 적용 중 오류가 발생했습니다: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
  }

  @override
  void dispose() {
    unawaited(_service.dispose());
    super.dispose();
  }
}
