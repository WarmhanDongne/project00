import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mosigame_core/core/assets/game_asset_cache.dart';
import 'package:mosigame_core/core/assets/game_asset_manifest.dart';
import 'package:mosigame_core/core/assets/game_asset_source.dart';

void main() {
  late Directory cacheRoot;

  setUp(() async {
    cacheRoot = await Directory.systemTemp.createTemp('mosigame-asset-cache-');
  });

  tearDown(() async {
    if (await cacheRoot.exists()) await cacheRoot.delete(recursive: true);
  });

  test('downloads, verifies, and atomically exposes a manifest file', () async {
    final bytes = <int>[1, 2, 3, 4, 5];
    final manifest = GameAssetManifest(
      gameId: 'future_game',
      assetVersion: 3,
      requiredPatchNumber: 12,
      files: [
        GameAssetFile(
          path: 'images/background.webp',
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
          device: 'both',
        ),
      ],
    );
    final cache = GameAssetCache(root: cacheRoot);
    final source = _FakeAssetSource(manifest: manifest, bytes: bytes);

    await Future.wait([
      cache.install(manifest: manifest, source: source, currentPatchNumber: 12),
      cache.install(manifest: manifest, source: source, currentPatchNumber: 12),
    ]);

    final installedPath = cache.resolve(
      'future_game',
      3,
      'images/background.webp',
    );
    expect(installedPath, isNotNull);
    expect(await File(installedPath!).readAsBytes(), bytes);
    expect(cache.isInstalled('future_game', 3), isTrue);
    expect(source.downloadCount, 1, reason: '동시 준비 요청은 같은 설치 Future를 공유해야 합니다');
    expect(await cache.readInstalledManifest('future_game', 3), isNotNull);
  });

  test('does not expose invalid downloads or unsafe paths', () async {
    const manifest = GameAssetManifest(
      gameId: 'future_game',
      assetVersion: 1,
      requiredPatchNumber: 0,
      files: [
        GameAssetFile(
          path: 'images/a',
          sha256:
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          bytes: 1,
          device: 'both',
        ),
      ],
    );
    final cache = GameAssetCache(root: cacheRoot);
    final source = _FakeAssetSource(manifest: manifest, bytes: const <int>[9]);

    await expectLater(
      cache.install(manifest: manifest, source: source, currentPatchNumber: 0),
      throwsFormatException,
    );

    expect(cache.isInstalled('future_game', 1), isFalse);
    expect(cache.resolve('../escape', 1, 'images/a'), isNull);
    expect(cache.resolve('future_game', 1, '../escape'), isNull);
    expect(
      File('${cacheRoot.path}/games/future_game/1/images/a.part').existsSync(),
      isFalse,
    );
  });

  test(
    'rejects a manifest requiring a newer patch before downloading',
    () async {
      const manifest = GameAssetManifest(
        gameId: 'future_game',
        assetVersion: 1,
        requiredPatchNumber: 8,
        files: <GameAssetFile>[],
      );
      final cache = GameAssetCache(root: cacheRoot);
      final source = _FakeAssetSource(manifest: manifest, bytes: const []);

      await expectLater(
        cache.install(
          manifest: manifest,
          source: source,
          currentPatchNumber: 7,
        ),
        throwsStateError,
      );
      expect(source.downloadCount, 0);
    },
  );

  test('damaged installed files invalidate the completion marker', () async {
    final bytes = <int>[4, 3, 2, 1];
    final manifest = GameAssetManifest(
      gameId: 'future_game',
      assetVersion: 4,
      requiredPatchNumber: 0,
      files: [
        GameAssetFile(
          path: 'images/card.webp',
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
          device: 'both',
        ),
      ],
    );
    final cache = GameAssetCache(root: cacheRoot);
    await cache.install(
      manifest: manifest,
      source: _FakeAssetSource(manifest: manifest, bytes: bytes),
      currentPatchNumber: 0,
    );
    await File(
      '${cacheRoot.path}/games/future_game/4/images/card.webp',
    ).writeAsBytes(const [0, 0, 0, 0]);

    expect(await cache.verifyInstalled(manifest), isFalse);
    expect(cache.isInstalled('future_game', 4), isFalse);
  });

  test(
    'a malformed persisted manifest is never treated as installed',
    () async {
      final versionRoot = Directory('${cacheRoot.path}/games/future_game/5');
      await versionRoot.create(recursive: true);
      await File(
        '${versionRoot.path}/.complete',
      ).writeAsString('future_game:5');
      await File('${versionRoot.path}/.manifest.json').writeAsString('{broken');
      final cache = GameAssetCache(root: cacheRoot);

      expect(await cache.readInstalledManifest('future_game', 5), isNull);
      expect(cache.isInstalled('future_game', 5), isFalse);
    },
  );
}

final class _FakeAssetSource implements GameAssetSource {
  _FakeAssetSource({required this.manifest, required this.bytes});

  final GameAssetManifest manifest;
  final List<int> bytes;
  int downloadCount = 0;

  @override
  Future<GameAssetManifest> fetchManifest(String gameId) async => manifest;

  @override
  Future<void> downloadFile({
    required GameAssetManifest manifest,
    required GameAssetFile file,
    required File destination,
  }) async {
    downloadCount += 1;
    await destination.writeAsBytes(bytes, flush: true);
  }
}
