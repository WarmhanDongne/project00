import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_contract/games/template_game.dart';
import 'package:game_liars_poker/games/liars_poker/liars_poker_game.dart';
import 'package:mosigame_core/core/assets/game_asset_manifest.dart';
import 'package:mosigame_core/core/assets/game_asset_source.dart';
import 'package:mosigame_core/core/assets/game_asset_store.dart';
import 'package:project00/game_assets/game_asset_bootstrap.dart';

void main() {
  late Directory supportDirectory;
  late GameAssetStore previousStore;

  setUp(() async {
    supportDirectory = await Directory.systemTemp.createTemp(
      'mosigame-support-',
    );
    previousStore = GameAssetStore.instance;
  });

  tearDown(() async {
    GameAssetStore.instance = previousStore;
    if (await supportDirectory.exists()) {
      await supportDirectory.delete(recursive: true);
    }
  });

  test('startup wires permanent cache without downloading assets', () async {
    final bytes = <int>[9, 8, 7];
    final manifest = GameAssetManifest(
      gameId: 'future_game',
      assetVersion: 2,
      requiredPatchNumber: 7,
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

    await initializeGameAssets(
      catalog: const _Catalog(),
      supportDirectory: () async => supportDirectory,
      patchNumber: () async => 7,
      source: source,
    );

    expect(
      GameAssetStore.instance.cache?.root.path,
      '${supportDirectory.path}/mosigame',
    );
    expect(GameAssetStore.instance.currentPatchNumber, 7);
    expect(source.fetchCount, 0);
    expect(source.downloadCount, 0);

    await GameAssetStore.instance.downloadGame('future_game');
    expect(source.fetchCount, 1);
    expect(source.downloadCount, 1);
    expect(
      GameAssetStore.instance.isGameCompatible(
        'future_game',
        requiredAssetVersion: 2,
      ),
      isTrue,
    );
  });
}

final class _Catalog implements GameCatalog {
  const _Catalog();

  @override
  Iterable<TemplateGame> get games => const [_DownloadableGame()];

  @override
  TemplateGame? find(String id) => id == 'future_game' ? games.first : null;
}

final class _DownloadableGame extends LiarsPokerGame {
  const _DownloadableGame();

  @override
  String get id => 'future_game';

  @override
  int get requiredAssetVersion => 2;
}

final class _FakeAssetSource implements GameAssetSource {
  _FakeAssetSource({required this.manifest, required this.bytes});

  final GameAssetManifest manifest;
  final List<int> bytes;
  int fetchCount = 0;
  int downloadCount = 0;

  @override
  Future<GameAssetManifest> fetchManifest(String gameId) async {
    fetchCount += 1;
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
