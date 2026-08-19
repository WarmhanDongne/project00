import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// 앱 전체에서 사용하는 공용 사운드 서비스.
///
/// - BGM은 하나의 플레이어를 계속 재사용합니다.
/// - 효과음은 동시에 여러 개가 재생될 수 있도록
///   재생할 때마다 별도의 AudioPlayer를 생성합니다.
class SoundService {
  SoundService._();

  static final SoundService instance = SoundService._();

  final AudioPlayer _bgmPlayer = AudioPlayer();

  /// 도중에 멈춰야 하는 긴 효과음 전용 플레이어입니다.
  ///
  /// 룰렛 사운드처럼 연출보다 파일이 긴 효과음은 재생만 하고 끝낼 수 없습니다.
  /// 한 번에 하나만 재생되며, 새로 재생하면 이전 것을 끊습니다.
  final AudioPlayer _sustainedEffectPlayer = AudioPlayer();

  /// 짧은 효과음을 돌려쓰는 플레이어 풀입니다.
  ///
  /// 카드 분배처럼 짧은 간격으로 여러 번 재생되는 소리는 그때마다 새 플레이어를
  /// 만들면 지연과 흔들림이 누적됩니다. 미리 만든 플레이어를 순서대로 재사용해
  /// 재생 요청이 바로 시작되게 합니다.
  static const int _effectPlayerPoolSize = 8;
  final List<AudioPlayer> _effectPlayers = [];
  int _nextEffectPlayer = 0;

  /// 소리별로 소스를 미리 물려 둔 플레이어입니다.
  ///
  /// `play(AssetSource)`는 매번 네이티브 준비(setSource)를 기다립니다. 파일을
  /// 캐시에 풀어 둬도 이 준비 비용은 그대로 남아, 카드 분배 첫 소리나 도장처럼
  /// 한 번만 나는 소리가 화면보다 늦게 들립니다.
  ///
  /// 그래서 [preloadEffects]에서 소스까지 물려 준비를 끝내 두고, 재생할 때는
  /// 되감아 다시 트는 것만 합니다. 같은 소리가 겹칠 수 있도록 소리마다 여러
  /// 개를 두고 돌려씁니다.
  static const int _playersPerEffect = 4;
  final Map<String, List<AudioPlayer>> _preparedEffects = {};
  final Map<String, int> _nextPreparedEffect = {};

  bool _initialized = false;
  Future<void>? _initialization;

  /// SoundProvider가 마스터 볼륨까지 계산해 넘겨준 최종 재생 볼륨입니다.
  /// 초기화 직후 곧바로 덮어쓰므로 기본값은 최대치로 둡니다.
  double _bgmVolume = 1;
  double _effectVolume = 1;

  Future<void> initialize() {
    if (_initialized) {
      return Future.value();
    }

    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    await _bgmPlayer.setReleaseMode(ReleaseMode.loop);
    await _bgmPlayer.setVolume(_bgmVolume);
    await _sustainedEffectPlayer.setReleaseMode(ReleaseMode.stop);
    await _sustainedEffectPlayer.setVolume(_effectVolume);

    // 효과음 플레이어를 미리 만들어 둡니다. 재생 시점에 네이티브 플레이어를
    // 만들면 그만큼 소리가 늦게 시작됩니다.
    for (var index = 0; index < _effectPlayerPoolSize; index += 1) {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      _effectPlayers.add(player);
    }

    _initialized = true;
  }

  /// 효과음 에셋을 미리 준비해 첫 재생이 늦지 않게 합니다.
  ///
  /// audioplayers는 asset을 임시 파일로 풀어낸 뒤 재생합니다. 이 작업이 첫
  /// 재생에서 일어나면 소리가 화면보다 눈에 띄게 늦습니다. 게임에 들어가기 전에
  /// 미리 풀어 두면 이후 재생은 곧바로 시작됩니다.
  ///
  /// 한 파일이 실패해도 나머지는 계속 준비합니다. 사운드는 보조 기능이라
  /// 준비 실패로 게임 진입을 막지 않습니다.
  Future<void> preloadEffects(Iterable<String> assetPaths) async {
    await initialize();

    for (final assetPath in assetPaths) {
      if (_preparedEffects.containsKey(assetPath)) continue;

      try {
        // 에셋을 파일로 풀어 두고,
        await AudioCache.instance.load(_normalizeAssetPath(assetPath));

        // 그 파일을 물린 플레이어까지 미리 준비 상태로 만들어 둡니다.
        final players = <AudioPlayer>[];
        for (var index = 0; index < _playersPerEffect; index += 1) {
          final player = AudioPlayer();
          await player.setReleaseMode(ReleaseMode.stop);
          await player.setVolume(_effectVolume);
          // setSource는 네이티브 준비가 끝날 때까지 기다립니다. 이 비용을
          // 재생 시점이 아니라 지금 치릅니다.
          await player.setSource(AssetSource(_normalizeAssetPath(assetPath)));
          players.add(player);
        }
        _preparedEffects[assetPath] = players;
        _nextPreparedEffect[assetPath] = 0;
      } catch (error) {
        debugPrint('효과음을 미리 준비하지 못했습니다($assetPath): $error');
      }
    }
  }

  /// 미리 준비된 플레이어가 있으면 그중 하나를 되감아 즉시 재생합니다.
  ///
  /// 준비된 플레이어가 없으면 null을 돌려 기존 재생 경로를 쓰게 합니다.
  Future<void>? _playPreparedEffect(String assetPath) {
    final players = _preparedEffects[assetPath];
    if (players == null || players.isEmpty) return null;

    final index = _nextPreparedEffect[assetPath] ?? 0;
    _nextPreparedEffect[assetPath] = (index + 1) % players.length;

    final player = players[index];
    // 이미 소스가 물려 있으므로 되감아 다시 트는 것만으로 끝납니다.
    return player.seek(Duration.zero).then((_) => player.resume());
  }

  /// 다음 효과음에 사용할 플레이어를 돌려씁니다.
  ///
  /// 풀을 한 바퀴 돌면 가장 오래전에 시작한 소리를 끊고 재사용합니다. 짧은
  /// 효과음이 [_effectPlayerPoolSize]개보다 많이 겹치는 경우는 없습니다.
  AudioPlayer _takeEffectPlayer() {
    final player = _effectPlayers[_nextEffectPlayer];
    _nextEffectPlayer = (_nextEffectPlayer + 1) % _effectPlayers.length;
    return player;
  }

  // ============================================================
  // BGM
  // ============================================================

  /// 지정한 asset BGM을 반복 재생합니다.
  Future<void> playBgm(String assetPath) async {
    await initialize();

    await _bgmPlayer.play(
      AssetSource(_normalizeAssetPath(assetPath)),
      volume: _bgmVolume,
    );
  }

  /// 현재 재생 중인 BGM을 정지합니다.
  Future<void> stopBgm() async {
    await _bgmPlayer.stop();
  }

  /// 현재 재생 중인 BGM을 일시정지합니다.
  Future<void> pauseBgm() async {
    await _bgmPlayer.pause();
  }

  /// 일시정지된 BGM을 다시 재생합니다.
  Future<void> resumeBgm() async {
    await initialize();
    await _bgmPlayer.resume();
  }

  /// BGM 볼륨을 설정합니다.
  ///
  /// [volume] 범위:
  /// - 0.0 = 음소거
  /// - 1.0 = 최대 볼륨
  Future<void> setBgmVolume(double volume) async {
    _bgmVolume = _normalizeVolume(volume);

    await initialize();
    await _bgmPlayer.setVolume(_bgmVolume);
  }

  // ============================================================
  // Effect
  // ============================================================

  /// 효과음을 1회 재생합니다.
  ///
  /// 미리 만들어 둔 플레이어 풀을 돌려쓰므로 여러 효과음이 겹쳐 재생되고,
  /// 재생 요청과 실제 소리 사이의 지연이 짧습니다.
  ///
  /// 소리를 제때 내려면 [preloadEffects]로 에셋을 미리 준비해 두세요.
  Future<void> playEffect(String assetPath) async {
    await initialize();

    final prepared = _playPreparedEffect(assetPath);
    if (prepared != null) {
      await prepared;
      return;
    }

    // 준비되지 않은 소리는 그 자리에서 불러옵니다. 이 경로는 첫 재생이 늦으니
    // 제때 나야 하는 소리는 [preloadEffects]에 등록하세요.
    await _takeEffectPlayer().play(
      AssetSource(_normalizeAssetPath(assetPath)),
      volume: _effectVolume,
    );
  }

  /// 도중에 멈출 수 있는 효과음을 재생합니다.
  ///
  /// [window]를 주면 **뒷부분을 자르지 않고 앞부분을 건너뛰어** 남은 재생
  /// 길이가 [window]와 같아지도록 맞춥니다. 그래서 효과음은 연출이 끝나는
  /// 시점에 자연스럽게 끝나고, 마지막 소리와 여운은 원본 그대로 남습니다.
  ///
  /// 룰렛처럼 멈추는 순간의 소리가 핵심인 효과음은 연출 길이에 맞춘다고 뒤를
  /// 끊으면 안 됩니다. 파일이 [window]보다 짧으면 그냥 처음부터 재생합니다.
  Future<void> playSustainedEffect(String assetPath, {Duration? window}) async {
    await initialize();

    await _sustainedEffectPlayer.stop();
    final source = AssetSource(_normalizeAssetPath(assetPath));

    if (window == null) {
      await _sustainedEffectPlayer.play(source, volume: _effectVolume);
      return;
    }

    await _sustainedEffectPlayer.setSource(source);
    await _sustainedEffectPlayer.setVolume(_effectVolume);

    final total = await _sustainedEffectPlayer.getDuration();
    final start = startOffsetFor(total: total, window: window);
    if (start > Duration.zero) {
      await _sustainedEffectPlayer.seek(start);
    }
    await _sustainedEffectPlayer.resume();
  }

  /// 효과음의 **앞부분을** 얼마나 건너뛸지 계산합니다.
  ///
  /// 남은 재생 길이가 [window]와 같아지는 지점입니다. 파일이 [window]보다
  /// 짧거나 길이를 알 수 없으면 처음부터 재생합니다. 어떤 경우에도 뒤를
  /// 자르지 않으므로 마지막 소리와 여운은 그대로 남습니다.
  @visibleForTesting
  static Duration startOffsetFor({
    required Duration? total,
    required Duration window,
  }) {
    if (total == null || total <= window) return Duration.zero;
    return total - window;
  }

  /// [playSustainedEffect]로 재생 중인 효과음을 멈춥니다.
  Future<void> stopSustainedEffect() async {
    await _sustainedEffectPlayer.stop();
  }

  /// 효과음 볼륨을 설정합니다.
  ///
  /// 이후 재생되는 효과음부터 적용됩니다.
  Future<void> setEffectVolume(double volume) async {
    _effectVolume = _normalizeVolume(volume);
    // 재생 중인 긴 효과음은 즉시 반영합니다.
    await _sustainedEffectPlayer.setVolume(_effectVolume);
    // 미리 준비해 둔 플레이어는 재생할 때 볼륨을 넘기지 않으므로 여기서
    // 갱신해야 설정 변경이 반영됩니다.
    for (final players in _preparedEffects.values) {
      for (final player in players) {
        await player.setVolume(_effectVolume);
      }
    }
  }

  // ============================================================
  // Volume
  // ============================================================

  /// BGM과 효과음 볼륨을 한 번에 설정합니다.
  Future<void> setMasterVolume({
    required double bgmVolume,
    required double effectVolume,
  }) async {
    await setBgmVolume(bgmVolume);
    await setEffectVolume(effectVolume);
  }

  // ============================================================
  // Utils
  // ============================================================

  /// audioplayers의 AssetSource 형식에 맞게
  /// 경로 앞의 `assets/`를 제거합니다.
  ///
  /// 예:
  /// assets/sounds/common/click.mp3
  /// → sounds/common/click.mp3
  String _normalizeAssetPath(String path) {
    const assetPrefix = 'assets/';

    if (path.startsWith(assetPrefix)) {
      return path.substring(assetPrefix.length);
    }

    return path;
  }

  /// 볼륨 값을 0.0 ~ 1.0 범위로 제한합니다.
  double _normalizeVolume(double value) {
    return value.clamp(0.0, 1.0).toDouble();
  }

  // ============================================================
  // Dispose
  // ============================================================

  /// SoundService가 보유한 리소스를 정리합니다.
  ///
  /// 일반적으로 앱 전체에서 Singleton으로 사용한다면
  /// 앱 실행 중에는 호출하지 않아도 됩니다.
  Future<void> dispose() async {
    await _bgmPlayer.dispose();
  }
}
