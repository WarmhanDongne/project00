import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/widgets.dart';
import 'package:mosigame_core/core/assets/game_asset_cache.dart';
import 'package:mosigame_core/core/assets/game_asset_manifest.dart';
import 'package:mosigame_core/core/assets/game_asset_source.dart';

//=======================게임 에셋 단일 해석 지점==============================
/// 게임 이미지·사운드가 실제로 어디서 오는지를 한곳에서 결정합니다.
///
/// 번들 게임은 앱 에셋을, 다운로드 게임은 SHA-256으로 검증된 파일을
/// 돌려줍니다. 게임 화면은 저장 위치를 몰라야 하며, 이 클래스가 다음을
/// 단일 경계에서 처리합니다:
///
/// 1. [downloadGame]에서 서버 매니페스트 버전을 확인하고 부족한 파일을 내려받음
/// 2. [imageProviderFor]·[soundSourceFor]가 내려받은 파일을 우선 반환
/// 3. 번들 게임은 항상 번들 경로를 쓰고, 다운로드 게임은 검증된 캐시만 사용
///
/// ## 게임 코드 규칙
/// - `packages/game_*/lib/games/` 안에서 이미지는 `Assets....game`([GameImage])으로만 씁니다.
///   `Assets....image()`를 직접 호출하면 서버 전환 때 그 화면만 남아서 깨집니다.
/// - 소리는 지금처럼 [SoundService]/[SoundEffects] 경로 문자열을 쓰면 됩니다.
///   소스 해석은 SoundService가 이 클래스에 위임합니다.
class GameAssetStore {
  GameAssetStore({this.cache, this.currentPatchNumber = 0});

  final GameAssetCache? cache;
  final int currentPatchNumber;
  final Map<String, _DownloadableGameAssets> _downloadableGames = {};

  /// 전역 인스턴스. 서버 에셋 구현이나 테스트 대역으로 교체할 수 있습니다.
  static GameAssetStore instance = GameAssetStore();

  /// 게임 입장 준비 훅입니다. 각 게임의 에셋 preload 단계에서 호출하세요.
  ///
  /// 번들 게임은 빈 작업으로 끝나며, 다운로드 게임은 이미 설치된 파일만
  /// 검사합니다. 다운로드는 사용자 동작에서 [downloadGame]으로만 시작합니다.
  Future<void> prepareGame(String gameId) async {
    if (!_downloadableGames.containsKey(gameId)) return;
    await ensureGameReady(gameId);
  }

  /// 향후 소유 게임 다운로드 버튼이 사용할 저장소를 등록합니다.
  ///
  /// 등록만으로 네트워크 요청이나 다운로드는 일어나지 않습니다. 앱 시작 시에는
  /// Shorebird 패치 확인만 수행하고, [downloadGame]은 사용자 동작에서 호출합니다.
  void registerDownloadableGame({
    required String gameId,
    required int requiredAssetVersion,
    required GameAssetSource source,
  }) {
    if (!isSafeGameId(gameId) || requiredAssetVersion <= 0) {
      throw const FormatException('게임 에셋 다운로드 설정이 올바르지 않습니다.');
    }
    _downloadableGames[gameId] = _DownloadableGameAssets(
      requiredAssetVersion: requiredAssetVersion,
      source: source,
    );
  }

  /// 등록된 저장소에서 매니페스트와 에셋을 받아 영구 캐시에 설치합니다.
  ///
  /// 서버가 다른 gameId/assetVersion을 반환하면 파일을 받기 전에 거부합니다.
  Future<void> downloadGame(String gameId) async {
    final remote = _downloadableGames[gameId];
    final targetCache = cache;
    if (remote == null || targetCache == null) {
      throw StateError('게임 에셋 다운로드가 구성되지 않았습니다.');
    }
    final manifest = await remote.source.fetchManifest(gameId);
    if (manifest.gameId != gameId ||
        manifest.assetVersion != remote.requiredAssetVersion) {
      throw StateError('게임 코드와 에셋 버전이 일치하지 않습니다.');
    }
    await targetCache.install(
      manifest: manifest,
      source: remote.source,
      currentPatchNumber: currentPatchNumber,
    );
    remote.manifest = manifest;
  }

  /// 다운로드 게임이 완전하게 설치되었는지 파일 해시까지 확인합니다.
  Future<void> ensureGameReady(String gameId) async {
    final remote = _downloadableGames[gameId];
    if (remote == null) return;
    final targetCache = cache;
    if (targetCache == null) throw StateError('게임 에셋 캐시가 준비되지 않았습니다.');
    final manifest =
        remote.manifest ??
        await targetCache.readInstalledManifest(
          gameId,
          remote.requiredAssetVersion,
        );
    if (manifest == null) {
      throw StateError('게임 에셋을 먼저 다운로드해야 합니다.');
    }
    if (manifest.gameId != gameId ||
        manifest.assetVersion != remote.requiredAssetVersion ||
        !manifest.supportsPatch(currentPatchNumber)) {
      throw StateError('게임 코드와 에셋 버전이 일치하지 않습니다.');
    }
    remote.manifest = manifest;
    if (!await targetCache.verifyInstalled(manifest)) {
      throw StateError('게임 에셋을 먼저 다운로드해야 합니다.');
    }
  }

  bool isGameCompatible(String gameId, {required int requiredAssetVersion}) {
    if (requiredAssetVersion == 0) return true;
    if (requiredAssetVersion < 0) return false;
    final targetCache = cache;
    final remote = _downloadableGames[gameId];
    return remote != null &&
        remote.requiredAssetVersion == requiredAssetVersion &&
        targetCache != null &&
        targetCache.isInstalled(gameId, requiredAssetVersion);
  }

  /// [GameImage]가 실제 이미지를 그릴 때 사용하는 provider입니다.
  ImageProvider imageProviderFor(String assetPath, {String? package}) =>
      AssetImage(assetPath, package: package);

  ImageProvider remoteImageProviderFor({
    required String gameId,
    required int assetVersion,
    required String logicalPath,
  }) {
    final path = cache?.resolve(gameId, assetVersion, logicalPath);
    if (path == null) throw StateError('준비되지 않은 게임 이미지입니다: $logicalPath');
    return FileImage(File(path));
  }

  /// 사운드 경로(`assets/...`)를 재생 소스로 바꿉니다.
  Source soundSourceFor(String assetPath) {
    final remote = _remoteAsset(assetPath);
    return remote == null ? AssetSource(assetPath) : DeviceFileSource(remote);
  }

  /// 사전 준비(AudioCache) 대상 번들 경로입니다.
  ///
  /// 서버에서 내려받은 파일은 이미 기기에 있어 캐시 준비가 필요 없으므로,
  /// 서버 구현에서는 null을 돌려줍니다.
  String? cacheableAssetPath(String assetPath) =>
      _remoteAsset(assetPath) == null ? assetPath : null;

  /// 다운로드 게임의 사운드를 기존 [SoundService] 문자열 API에 전달할 핸들입니다.
  static String remoteSoundReference({
    required String gameId,
    required int assetVersion,
    required String logicalPath,
  }) {
    if (!isSafeGameId(gameId) ||
        assetVersion < 0 ||
        !isSafeLogicalAssetPath(logicalPath)) {
      throw const FormatException('원격 사운드 경로가 올바르지 않습니다.');
    }
    return 'mosigame-asset://$gameId/$assetVersion/$logicalPath';
  }

  /// 예전 호출부와 호환을 위한 경로 보조 함수입니다.
  static String stripAssetPrefix(String path) {
    const assetPrefix = 'assets/';
    if (path.startsWith(assetPrefix)) {
      return path.substring(assetPrefix.length);
    }
    return path;
  }

  String? _remoteAsset(String reference) {
    final uri = Uri.tryParse(reference);
    if (uri == null || uri.scheme != 'mosigame-asset') return null;
    if (!isSafeGameId(uri.host) ||
        uri.pathSegments.length < 2 ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const FormatException('원격 사운드 경로가 올바르지 않습니다.');
    }
    final assetVersion = int.tryParse(uri.pathSegments.first);
    final logicalPath = uri.pathSegments.skip(1).join('/');
    if (assetVersion == null ||
        assetVersion < 0 ||
        !isSafeLogicalAssetPath(logicalPath)) {
      throw const FormatException('원격 사운드 경로가 올바르지 않습니다.');
    }
    final path = cache?.resolve(uri.host, assetVersion, logicalPath);
    if (path == null) {
      throw StateError('준비되지 않은 게임 사운드입니다: $logicalPath');
    }
    return path;
  }
}

class _DownloadableGameAssets {
  _DownloadableGameAssets({
    required this.requiredAssetVersion,
    required this.source,
  });

  final int requiredAssetVersion;
  final GameAssetSource source;
  GameAssetManifest? manifest;
}
