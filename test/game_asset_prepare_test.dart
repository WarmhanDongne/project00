import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/game_holdem.dart';
import 'package:game_kit/core/assets/game_asset_cache.dart';
import 'package:game_kit/core/assets/game_asset_manifest.dart';
import 'package:game_kit/core/assets/game_asset_source.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:project00/game_assets/game_asset_prepare.dart';

void main() {
  late Directory temporaryDirectory;
  late GameAssetStore previousStore;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'mosigame-holdem-assets-',
    );
    previousStore = GameAssetStore.instance;
  });

  tearDown(() async {
    GameAssetStore.instance = previousStore;
    await temporaryDirectory.delete(recursive: true);
  });

  test('시뮬레이터 개발 빌드는 원격 다운로드 없이 홀덤을 준비한다', () async {
    final store = GameAssetStore(
      cache: GameAssetCache(root: temporaryDirectory),
      currentPatchNumber: 0,
    );
    GameAssetStore.instance = store;

    await prepareGameAssetsForPlay(const HoldemGame());

    expect(const HoldemGame().requiredAssetVersion, 0);
  });

  test('홀덤 운영 v2 에셋은 설치 후 캐시를 재사용한다', () async {
    final source = _MemorySource();
    final store =
        GameAssetStore(
          cache: GameAssetCache(root: temporaryDirectory),
          currentPatchNumber: 0,
        )..registerDownloadableGame(
          gameId: 'holdem',
          requiredAssetVersion: 2,
          source: source,
        );
    GameAssetStore.instance = store;

    await store.downloadGame('holdem');
    await store.prepareGame('holdem');
    await store.prepareGame('holdem');

    expect(source.manifestFetchCount, 1);
    expect(source.fileDownloadCount, 1);
    expect(store.isGameCompatible('holdem', requiredAssetVersion: 2), isTrue);
  });
}

class _MemorySource implements GameAssetSource {
  static const bytes = <int>[1, 2, 3, 4];
  int manifestFetchCount = 0;
  int fileDownloadCount = 0;

  @override
  Future<GameAssetManifest> fetchManifest(String gameId) async {
    manifestFetchCount += 1;
    return GameAssetManifest(
      gameId: gameId,
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
  }

  @override
  Future<void> downloadFile({
    required GameAssetManifest manifest,
    required GameAssetFile file,
    required File destination,
  }) async {
    fileDownloadCount += 1;
    await destination.writeAsBytes(bytes, flush: true);
  }
}
