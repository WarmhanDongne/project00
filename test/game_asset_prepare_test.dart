import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/game_holdem.dart';
import 'package:game_kit/core/assets/game_asset_cache.dart';
import 'package:game_kit/core/assets/game_asset_manifest.dart';
import 'package:game_kit/core/assets/game_asset_source.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/template_game.dart';
import 'package:project00/game_assets/game_asset_bootstrap.dart';
import 'package:project00/game_assets/game_asset_prepare.dart';
import 'package:project00/games/game_registry.dart';

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

  test('앱에 포함된 홀덤은 다운로드 게임으로 등록하지 않고 받지 않고 바로 들어간다', () async {
    // 2026-10-11부터 홀덤은 라이어스 포커·마피아·파이널콜과 같은 출시 기본
    // 게임입니다. 이미지는 패키지에 들어 있어 내려받을 파일이 없습니다.
    final source = _MemorySource();
    await initializeGameAssets(
      catalog: const GameRegistry(),
      supportDirectory: () async => temporaryDirectory,
      patchNumber: () async => 0,
      source: source,
    );
    final store = GameAssetStore.instance;
    expect(const HoldemGame().requiredAssetVersion, 0);

    await store.prepareGame('holdem');
    await prepareGameAssetsForPlay(const HoldemGame());

    expect(source.manifestFetchCount, 0);
    expect(source.fileDownloadCount, 0);
    expect(store.isGameCompatible('holdem', requiredAssetVersion: 0), isTrue);
  });

  // 아래 두 검사는 앞으로 나올 다운로드 게임의 받기·재시도·캐시 경로를
  // 지킵니다. 기본 게임에는 다운로드 게임이 없어 대역 게임으로 확인합니다.
  test('다운로드 게임 설치 실패는 진입을 거부하고 다음 진입에서 재시도한다', () async {
    final source = _MemorySource()..failDownloads = true;
    final store =
        GameAssetStore(cache: GameAssetCache(root: temporaryDirectory))
          ..registerDownloadableGame(
            gameId: _downloadGameId,
            requiredAssetVersion: 2,
            source: source,
          );
    GameAssetStore.instance = store;
    await expectLater(
      prepareGameAssetsForPlay(const _DownloadGame()),
      throwsStateError,
    );
    expect(
      store.isGameCompatible(_downloadGameId, requiredAssetVersion: 2),
      isFalse,
    );
    source.failDownloads = false;
    await prepareGameAssetsForPlay(const _DownloadGame());
    expect(
      store.isGameCompatible(_downloadGameId, requiredAssetVersion: 2),
      isTrue,
    );
    expect(source.fileDownloadCount, 2);
  });

  test('다운로드 게임 v2 에셋은 설치 후 캐시를 재사용한다', () async {
    final source = _MemorySource();
    final store =
        GameAssetStore(
          cache: GameAssetCache(root: temporaryDirectory),
          currentPatchNumber: 0,
        )..registerDownloadableGame(
          gameId: _downloadGameId,
          requiredAssetVersion: 2,
          source: source,
        );
    GameAssetStore.instance = store;

    await store.downloadGame(_downloadGameId);
    await store.prepareGame(_downloadGameId);
    await store.prepareGame(_downloadGameId);

    GameAssetStore.instance =
        GameAssetStore(cache: GameAssetCache(root: temporaryDirectory))
          ..registerDownloadableGame(
            gameId: _downloadGameId,
            requiredAssetVersion: 2,
            source: source,
          );
    source.failDownloads = true;
    await prepareGameAssetsForPlay(const _DownloadGame());

    expect(source.manifestFetchCount, 1);
    expect(source.fileDownloadCount, 1);
    expect(
      store.isGameCompatible(_downloadGameId, requiredAssetVersion: 2),
      isTrue,
    );
  });
}

class _MemorySource implements GameAssetSource {
  static const bytes = <int>[1, 2, 3, 4];
  int manifestFetchCount = 0;
  int fileDownloadCount = 0;
  bool failDownloads = false;

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
    if (failDownloads) throw StateError('download unavailable');
    await destination.writeAsBytes(bytes, flush: true);
  }
}

const _downloadGameId = 'download_game';

/// 에셋을 내려받아야 하는 신작 게임 대역입니다.
class _DownloadGame extends TemplateGame {
  const _DownloadGame();
  @override
  String get id => _downloadGameId;
  @override
  int get requiredAssetVersion => 2;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
