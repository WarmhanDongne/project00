import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/assets/game_asset_cache.dart';
import 'package:game_kit/core/assets/game_asset_manifest.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/core/assets/game_asset_source.dart';
import 'package:game_kit/core/assets/game_image.dart';

void main() {
  late Directory cacheRoot;

  setUp(() async {
    cacheRoot = await Directory.systemTemp.createTemp('mosigame-asset-store-');
  });

  tearDown(() async {
    if (await cacheRoot.exists()) await cacheRoot.delete(recursive: true);
  });

  test(
    'remote sound reference resolves only from a complete cache version',
    () async {
      final versionRoot = Directory(
        '${cacheRoot.path}/games/future_game/2/sounds',
      );
      await versionRoot.create(recursive: true);
      await File('${versionRoot.path}/turn.mp3').writeAsBytes(const [1, 2, 3]);
      await File(
        '${cacheRoot.path}/games/future_game/2/.complete',
      ).writeAsString('future_game:2');
      final store = GameAssetStore(cache: GameAssetCache(root: cacheRoot));
      final reference = GameAssetStore.remoteSoundReference(
        gameId: 'future_game',
        assetVersion: 2,
        logicalPath: 'sounds/turn.mp3',
      );

      expect(store.soundSourceFor(reference), isA<DeviceFileSource>());
      expect(store.cacheableAssetPath(reference), isNull);
    },
  );

  test('downloadable registration rejects unsafe ids and versions', () {
    final store = GameAssetStore(cache: GameAssetCache(root: cacheRoot));
    final source = _FakeAssetSource.empty();

    expect(
      () => store.registerDownloadableGame(
        gameId: '../escape',
        requiredAssetVersion: 1,
        source: source,
      ),
      throwsFormatException,
    );
    expect(
      () => store.registerDownloadableGame(
        gameId: 'future_game',
        requiredAssetVersion: 0,
        source: source,
      ),
      throwsFormatException,
    );
    expect(
      () => GameAssetStore.remoteSoundReference(
        gameId: '../escape',
        assetVersion: 1,
        logicalPath: 'sounds/a.mp3',
      ),
      throwsFormatException,
    );
  });

  test('registration and game readiness never start a download', () async {
    final bytes = <int>[1, 3, 5, 7];
    final manifest = GameAssetManifest(
      gameId: 'future_game',
      assetVersion: 2,
      requiredPatchNumber: 4,
      files: [
        GameAssetFile(
          path: 'images/background.webp',
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
          device: 'both',
        ),
      ],
    );
    final source = _FakeAssetSource(manifest: manifest, bytes: bytes);
    final store =
        GameAssetStore(
          cache: GameAssetCache(root: cacheRoot),
          currentPatchNumber: 4,
        )..registerDownloadableGame(
          gameId: 'future_game',
          requiredAssetVersion: 2,
          source: source,
        );

    expect(source.fetchCount, 0);
    await expectLater(store.prepareGame('future_game'), throwsStateError);
    expect(source.fetchCount, 0, reason: '게임 진입 검사는 Storage를 읽지 않아야 합니다');
    expect(source.downloadCount, 0);

    await store.downloadGame('future_game');
    expect(source.fetchCount, 1);
    expect(source.downloadCount, 1);
    expect(
      store.isGameCompatible('future_game', requiredAssetVersion: 2),
      isTrue,
    );
  });

  test('a fresh store verifies a persistent cache without network', () async {
    final bytes = <int>[2, 4, 6, 8];
    final manifest = GameAssetManifest(
      gameId: 'future_game',
      assetVersion: 3,
      requiredPatchNumber: 5,
      files: [
        GameAssetFile(
          path: 'sounds/turn.mp3',
          sha256: sha256.convert(bytes).toString(),
          bytes: bytes.length,
          device: 'both',
        ),
      ],
    );
    final onlineSource = _FakeAssetSource(manifest: manifest, bytes: bytes);
    final firstStore =
        GameAssetStore(
          cache: GameAssetCache(root: cacheRoot),
          currentPatchNumber: 5,
        )..registerDownloadableGame(
          gameId: 'future_game',
          requiredAssetVersion: 3,
          source: onlineSource,
        );
    await firstStore.downloadGame('future_game');

    final offlineSource = _FakeAssetSource(
      manifest: manifest,
      bytes: bytes,
      failFetch: true,
    );
    final restartedStore =
        GameAssetStore(
          cache: GameAssetCache(root: cacheRoot),
          currentPatchNumber: 5,
        )..registerDownloadableGame(
          gameId: 'future_game',
          requiredAssetVersion: 3,
          source: offlineSource,
        );

    await restartedStore.ensureGameReady('future_game');
    expect(offlineSource.fetchCount, 0);
    expect(offlineSource.downloadCount, 0);
  });

  test('package image keeps the package-qualified bundle key', () {
    final provider = const GameImage.bundled(
      'assets/games/mafia/images/cards/role_back.webp',
      package: 'game_mafia',
    ).provider();

    expect(provider, isA<AssetImage>());
    expect(
      (provider as AssetImage).keyName,
      'packages/game_mafia/assets/games/mafia/images/cards/role_back.webp',
    );
  });

  test('same local image path in different packages is not equal', () {
    const localPath = 'assets/images/shared.webp';

    expect(
      const GameImage.bundled(localPath, package: 'game_mafia'),
      isNot(const GameImage.bundled(localPath, package: 'game_liars_poker')),
    );
  });

  test('package sound keeps its complete root-bundle key', () {
    const path =
        'packages/game_liars_poker/assets/games/liars_poker/sounds/submit.mp3';

    final source = GameAssetStore().soundSourceFor(path);

    expect(source, isA<AssetSource>());
    expect((source as AssetSource).path, path);
  });
}

final class _FakeAssetSource implements GameAssetSource {
  _FakeAssetSource({
    required this.manifest,
    required this.bytes,
    this.failFetch = false,
  });

  factory _FakeAssetSource.empty() => _FakeAssetSource(
    manifest: const GameAssetManifest(
      gameId: 'future_game',
      assetVersion: 1,
      requiredPatchNumber: 0,
      files: <GameAssetFile>[],
    ),
    bytes: const <int>[],
  );

  final GameAssetManifest manifest;
  final List<int> bytes;
  final bool failFetch;
  int fetchCount = 0;
  int downloadCount = 0;

  @override
  Future<GameAssetManifest> fetchManifest(String gameId) async {
    fetchCount += 1;
    if (failFetch) throw const SocketException('offline');
    return manifest;
  }

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
