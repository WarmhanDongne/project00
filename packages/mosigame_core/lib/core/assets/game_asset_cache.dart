import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:mosigame_core/core/assets/game_asset_manifest.dart';
import 'package:mosigame_core/core/assets/game_asset_source.dart';

/// 검증된 게임 파일만 버전 디렉터리에 설치하는 런타임 캐시입니다.
class GameAssetCache {
  GameAssetCache({required this.root});

  final Directory root;
  final Map<String, Future<void>> _installs = {};

  Future<void> install({
    required GameAssetManifest manifest,
    required GameAssetSource source,
    required int currentPatchNumber,
  }) async {
    manifest.validate();
    if (!manifest.supportsPatch(currentPatchNumber)) {
      throw StateError('현재 코드 패치가 에셋 매니페스트 요구 버전보다 낮습니다.');
    }
    final key = '${manifest.gameId}:${manifest.assetVersion}';
    final inFlight = _installs[key];
    if (inFlight != null) return inFlight;

    final operation = _install(manifest: manifest, source: source);
    _installs[key] = operation;
    try {
      await operation;
    } finally {
      _installs.remove(key);
    }
  }

  Future<void> _install({
    required GameAssetManifest manifest,
    required GameAssetSource source,
  }) async {
    final versionRoot = _versionRoot(manifest.gameId, manifest.assetVersion);
    await versionRoot.create(recursive: true);
    final marker = File('${versionRoot.path}/.complete');
    final hasValidInstalledSet =
        await marker.exists() &&
        await _allFilesAreValid(versionRoot: versionRoot, manifest: manifest);
    if (hasValidInstalledSet) {
      await _writeManifest(versionRoot, manifest);
      return;
    }
    if (await marker.exists()) await marker.delete();

    for (final entry in manifest.files) {
      final target = File('${versionRoot.path}/${entry.path}');
      if (await _isValid(target, entry)) continue;
      await target.parent.create(recursive: true);
      final partial = File('${target.path}.part');
      try {
        if (await partial.exists()) await partial.delete();
        await source.downloadFile(
          manifest: manifest,
          file: entry,
          destination: partial,
        );
        if (!await _isValid(partial, entry)) {
          throw const FormatException('다운로드한 게임 에셋 검증에 실패했습니다.');
        }
        if (await target.exists()) {
          await target.delete();
        }
        await partial.rename(target.path);
      } catch (_) {
        if (await partial.exists()) await partial.delete();
        rethrow;
      }
    }

    await _writeManifest(versionRoot, manifest);
    await marker.writeAsString(
      '${manifest.gameId}:${manifest.assetVersion}',
      flush: true,
    );
  }

  bool isInstalled(String gameId, int assetVersion) =>
      File('${_versionRoot(gameId, assetVersion).path}/.complete').existsSync();

  /// 완료 마커뿐 아니라 모든 파일의 크기와 SHA-256을 다시 확인합니다.
  ///
  /// 앱을 강제 종료했거나 사용자가 저장 공간을 정리한 뒤 남은 불완전 캐시가
  /// 실행 가능 상태로 오인되지 않도록 게임 진입 직전에 사용합니다.
  Future<bool> verifyInstalled(GameAssetManifest manifest) async {
    manifest.validate();
    final versionRoot = _versionRoot(manifest.gameId, manifest.assetVersion);
    final marker = File('${versionRoot.path}/.complete');
    if (!await marker.exists()) return false;
    final valid = await _allFilesAreValid(
      versionRoot: versionRoot,
      manifest: manifest,
    );
    if (!valid && await marker.exists()) await marker.delete();
    return valid;
  }

  /// 이전 실행에서 검증하고 설치한 매니페스트를 읽습니다.
  ///
  /// 완료 마커·형식·게임 id·버전 중 하나라도 맞지 않으면 설치된 것으로
  /// 취급하지 않습니다. 네트워크 없이 재실행할 수 있게 하는 경계입니다.
  Future<GameAssetManifest?> readInstalledManifest(
    String gameId,
    int assetVersion,
  ) async {
    if (!isSafeGameId(gameId) || assetVersion < 0) return null;
    final versionRoot = _versionRoot(gameId, assetVersion);
    final marker = File('${versionRoot.path}/.complete');
    final manifestFile = File('${versionRoot.path}/.manifest.json');
    if (!await marker.exists() || !await manifestFile.exists()) return null;
    try {
      if (await marker.readAsString() != '$gameId:$assetVersion') {
        await marker.delete();
        return null;
      }
      final manifest = GameAssetManifest.decode(
        await manifestFile.readAsString(),
      );
      if (manifest.gameId != gameId || manifest.assetVersion != assetVersion) {
        await marker.delete();
        return null;
      }
      return manifest;
    } on FormatException {
      if (await marker.exists()) await marker.delete();
      return null;
    }
  }

  String? resolve(String gameId, int assetVersion, String logicalPath) {
    if (!isSafeGameId(gameId) ||
        assetVersion < 0 ||
        !isSafeLogicalAssetPath(logicalPath)) {
      return null;
    }
    if (!isInstalled(gameId, assetVersion)) return null;
    final file = File(
      '${_versionRoot(gameId, assetVersion).path}/$logicalPath',
    );
    return file.existsSync() ? file.path : null;
  }

  Directory _versionRoot(String gameId, int assetVersion) =>
      Directory('${root.path}/games/$gameId/$assetVersion');

  Future<bool> _isValid(File file, GameAssetFile expected) async {
    if (!await file.exists() || await file.length() != expected.bytes) {
      return false;
    }
    final digest = sha256.convert(await file.readAsBytes()).toString();
    return digest == expected.sha256;
  }

  Future<bool> _allFilesAreValid({
    required Directory versionRoot,
    required GameAssetManifest manifest,
  }) async {
    for (final entry in manifest.files) {
      if (!await _isValid(File('${versionRoot.path}/${entry.path}'), entry)) {
        return false;
      }
    }
    return true;
  }

  Future<void> _writeManifest(
    Directory versionRoot,
    GameAssetManifest manifest,
  ) async {
    await File(
      '${versionRoot.path}/.manifest.json',
    ).writeAsString(manifest.encode(), flush: true);
  }
}
