import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/assets/game_asset_cache.dart';
import 'package:game_kit/core/assets/game_asset_manifest.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';

import '../tool/install_local_game_assets.dart';

void main() {
  late Directory temporaryRoot;
  late Directory sourceDirectory;
  late Directory cacheRoot;
  late GameAssetManifest manifest;
  const bytes = [1, 2, 3, 4];

  setUp(() async {
    temporaryRoot = await Directory.systemTemp.createTemp('local-game-assets-');
    sourceDirectory = Directory('${temporaryRoot.path}/source');
    cacheRoot = Directory('${temporaryRoot.path}/cache');
    final sourceFile = File('${sourceDirectory.path}/2/images/background.webp');
    await sourceFile.parent.create(recursive: true);
    await sourceFile.writeAsBytes(bytes);
    manifest = GameAssetManifest(
      gameId: 'holdem',
      assetVersion: 2,
      requiredPatchNumber: 0,
      files: [
        GameAssetFile(
          path: 'images/background.webp',
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
          device: 'both',
        ),
      ],
    );
    await File(
      '${sourceDirectory.path}/manifest.json',
    ).writeAsString(manifest.encode());
  });
  tearDown(() => temporaryRoot.delete(recursive: true));

  test('로컬 설치 캐시는 앱을 재실행해도 네트워크 없이 준비된다', () async {
    await installLocalGameAssets(
      sourceDirectory: sourceDirectory,
      cacheRoot: cacheRoot,
    );
    await sourceDirectory.delete(recursive: true);
    final cache = GameAssetCache(root: cacheRoot);
    final store = GameAssetStore(cache: cache)
      ..registerDownloadableGame(
        gameId: 'holdem',
        requiredAssetVersion: 2,
        source: LocalGameAssetSource(sourceDirectory),
      );
    await store.prepareGame('holdem');
    expect(cache.isInstalled('holdem', 2), isTrue);
    expect(
      await File(
        cache.resolve('holdem', 2, 'images/background.webp')!,
      ).readAsBytes(),
      bytes,
    );
  });

  test('원본 해시 불일치에서는 완료 마커나 부분 파일을 남기지 않는다', () async {
    await File(
      '${sourceDirectory.path}/2/images/background.webp',
    ).writeAsBytes([4, 3, 2, 1]);
    await expectLater(
      installLocalGameAssets(
        sourceDirectory: sourceDirectory,
        cacheRoot: cacheRoot,
      ),
      throwsFormatException,
    );
    expect(GameAssetCache(root: cacheRoot).isInstalled('holdem', 2), isFalse);
    expect(
      await cacheRoot
          .list(recursive: true)
          .where((file) => file.path.endsWith('.part'))
          .toList(),
      isEmpty,
    );
  });

  test('다른 게임 ID의 로컬 매니페스트를 요청하면 거부한다', () async {
    await expectLater(
      LocalGameAssetSource(sourceDirectory).fetchManifest('mafia'),
      throwsStateError,
    );
  });
}
