import 'dart:async';

import 'package:flutter/material.dart';
import 'package:project00/core/sound/app_sounds.dart';
import 'package:project00/core/sound/service/sound_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// 앱의 사운드 설정 상태를 관리하는 Provider.
///
/// 역할:
/// - 마스터 / 효과음 / BGM 볼륨 상태 관리
/// - SharedPreferences를 통한 설정 저장 및 복원
/// - SoundService에 실제 볼륨 적용
/// - BGM 및 효과음 재생 요청 전달
class SoundProvider extends ChangeNotifier {
  SoundProvider({SoundService? service, SharedPreferencesAsync? preferences})
    : _service = service ?? SoundService.instance,
      _preferences = preferences ?? SharedPreferencesAsync();

  // ============================================================
  // Preferences Keys
  // ============================================================

  static const String _masterVolumeKey = 'sound.masterVolume';
  static const String _effectVolumeKey = 'sound.effectVolume';
  static const String _bgmVolumeKey = 'sound.bgmVolume';

  // ============================================================
  // Dependencies
  // ============================================================

  final SoundService _service;
  final SharedPreferencesAsync _preferences;

  // ============================================================
  // State
  // ============================================================

  double _masterVolume = 50;
  double _effectVolume = 80;
  double _bgmVolume = 30;

  bool _initialized = false;
  bool _initializing = false;

  // ============================================================
  // Getters
  // ============================================================

  double get masterVolume => _masterVolume;
  double get effectVolume => _effectVolume;
  double get bgmVolume => _bgmVolume;

  bool get initialized => _initialized;

  /// 마스터 볼륨이 적용된 최종 효과음 볼륨입니다.
  ///
  /// 예:
  /// master = 50
  /// effect = 80
  /// 최종 볼륨 = 0.4
  double get effectiveEffectVolume =>
      (_masterVolume / 100) * (_effectVolume / 100);

  /// 마스터 볼륨이 적용된 최종 BGM 볼륨입니다.
  double get effectiveBgmVolume => (_masterVolume / 100) * (_bgmVolume / 100);

  // ============================================================
  // Initialization
  // ============================================================

  /// 저장된 사운드 설정을 불러오고 SoundService를 초기화합니다.
  ///
  /// 이미 초기화되었거나 초기화 중이라면 다시 실행하지 않습니다.
  Future<void> initialize() async {
    if (_initialized || _initializing) return;

    _initializing = true;

    try {
      await _loadSavedVolumes();
    } catch (error, stackTrace) {
      debugPrint('저장된 사운드 설정을 불러오지 못했습니다: $error');
      debugPrintStack(stackTrace: stackTrace);
    }

    try {
      await _service.initialize();
      await _applyVolumes();
      // 첫 재생이 늦지 않도록 공용 효과음을 미리 풀어 둡니다.
      await _service.preloadEffects(AppSounds.preloadTargets);
    } catch (error, stackTrace) {
      // 사운드 초기화 실패가 앱 화면 렌더링까지 막지 않도록 처리합니다.
      debugPrint('사운드 플레이어를 초기화하지 못했습니다: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _initializing = false;
      _initialized = true;

      notifyListeners();
    }
  }

  /// SharedPreferences에서 저장된 볼륨 설정을 불러옵니다.
  Future<void> _loadSavedVolumes() async {
    final savedVolumes = await Future.wait([
      _preferences.getDouble(_masterVolumeKey),
      _preferences.getDouble(_effectVolumeKey),
      _preferences.getDouble(_bgmVolumeKey),
    ]);

    _masterVolume = _normalizeSliderValue(savedVolumes[0] ?? _masterVolume);

    _effectVolume = _normalizeSliderValue(savedVolumes[1] ?? _effectVolume);

    _bgmVolume = _normalizeSliderValue(savedVolumes[2] ?? _bgmVolume);
  }

  // ============================================================
  // Volume
  // ============================================================

  /// 마스터 볼륨을 변경합니다.
  void setMasterVolume(double value) {
    _masterVolume = _normalizeSliderValue(value);

    notifyListeners();

    _saveVolume(_masterVolumeKey, _masterVolume);
    _runSafely(_applyVolumes());
  }

  /// 효과음 볼륨을 변경합니다.
  void setEffectVolume(double value) {
    _effectVolume = _normalizeSliderValue(value);

    notifyListeners();

    _saveVolume(_effectVolumeKey, _effectVolume);
    _runSafely(_applyVolumes());
  }

  /// BGM 볼륨을 변경합니다.
  void setBgmVolume(double value) {
    _bgmVolume = _normalizeSliderValue(value);

    notifyListeners();

    _saveVolume(_bgmVolumeKey, _bgmVolume);
    _runSafely(_applyVolumes());
  }

  /// 현재 설정된 마스터 / 효과음 / BGM 볼륨을
  /// SoundService에 실제 재생 볼륨으로 적용합니다.
  Future<void> _applyVolumes() {
    return _service.setMasterVolume(
      bgmVolume: effectiveBgmVolume,
      effectVolume: effectiveEffectVolume,
    );
  }

  // ============================================================
  // Playback
  // ============================================================

  /// BGM을 재생합니다.
  Future<void> playBgm(String assetPath) {
    return _service.playBgm(assetPath);
  }

  /// 현재 BGM을 정지합니다.
  Future<void> stopBgm() {
    return _service.stopBgm();
  }

  /// 현재 BGM을 **서서히 줄이며** 정지합니다.
  ///
  /// 사용자의 볼륨 설정은 그대로 둡니다(재생 볼륨에 곱하는 배율만 내립니다).
  Future<void> fadeOutBgm({
    Duration duration = const Duration(milliseconds: 1200),
  }) {
    return _service.fadeOutBgm(duration: duration);
  }

  /// 현재 BGM을 일시정지합니다.
  Future<void> pauseBgm() {
    return _service.pauseBgm();
  }

  /// 일시정지된 BGM을 다시 재생합니다.
  Future<void> resumeBgm() {
    return _service.resumeBgm();
  }

  /// 게임 전용 효과음을 미리 준비합니다.
  ///
  /// 게임 진입 준비 단계에서 호출하세요. 준비하지 않으면 그 게임의 첫 효과음이
  /// 화면보다 늦게 납니다. 공용 효과음은 [initialize]에서 이미 준비합니다.
  Future<void> preloadEffects(Iterable<String> assetPaths) {
    return _service.preloadEffects(assetPaths);
  }

  /// 효과음을 1회 재생합니다.
  Future<void> playEffect(String assetPath) {
    return _service.playEffect(assetPath);
  }

  /// 도중에 멈출 수 있는 효과음을 재생합니다.
  ///
  /// [window]를 주면 효과음의 앞부분을 건너뛰어 연출이 끝나는 시점에 소리도
  /// 끝나게 맞춥니다. 뒷부분은 자르지 않습니다.
  Future<void> playSustainedEffect(String assetPath, {Duration? window}) {
    return _service.playSustainedEffect(assetPath, window: window);
  }

  /// [playSustainedEffect]로 재생 중인 효과음을 멈춥니다.
  Future<void> stopSustainedEffect() {
    return _service.stopSustainedEffect();
  }

  // ============================================================
  // Preferences
  // ============================================================

  /// 변경된 볼륨 값을 SharedPreferences에 저장합니다.
  void _saveVolume(String key, double value) {
    _runSafely(_preferences.setDouble(key, value));
  }

  // ============================================================
  // Utils
  // ============================================================

  /// 슬라이더 값을 0 ~ 100 범위로 제한합니다.
  double _normalizeSliderValue(double value) {
    return value.clamp(0.0, 100.0).toDouble();
  }

  /// UI 동작을 막지 않고 비동기 작업을 실행합니다.
  ///
  /// 실패하더라도 앱 흐름에는 영향을 주지 않고 로그만 출력합니다.
  void _runSafely(Future<void> operation) {
    unawaited(
      operation.catchError((Object error, StackTrace stackTrace) {
        debugPrint('사운드 작업 중 오류가 발생했습니다: $error');
        debugPrintStack(stackTrace: stackTrace);
      }),
    );
  }
}
