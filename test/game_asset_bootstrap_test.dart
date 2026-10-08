import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/assets/game_asset_manifest.dart';
import 'package:game_kit/core/assets/game_asset_source.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/template_game.dart';
import 'package:project00/game_assets/game_asset_bootstrap.dart';

void main() {
  late Directory temporaryDirectory;
  late GameAssetStore previousStore;

  setUp(() async {
    temporaryDirectory = await Directory.systemTemp.createTemp(
      'mosigame-game-asset-bootstrap-',
    );
    previousStore = GameAssetStore.instance;
  });

  tearDown(() async {
    GameAssetStore.instance = previousStore;
    await temporaryDirectory.delete(recursive: true);
  });

  test('개발 빌드는 Shorebird 경고 없이 patch 0으로 초기화한다', () async {
    final printedLines = <String>[];

    await runZoned(
      () => initializeGameAssets(
        catalog: const EmptyGameCatalog(),
        supportDirectory: () async => temporaryDirectory,
        source: const _UnusedSource(),
      ),
      zoneSpecification: ZoneSpecification(
        print: (self, parent, zone, line) => printedLines.add(line),
      ),
    );

    expect(GameAssetStore.instance.currentPatchNumber, 0);
    expect(
      printedLines.where(
        (line) => line.contains('Shorebird Updater is unavailable'),
      ),
      isEmpty,
    );
  });
}

final class _UnusedSource implements GameAssetSource {
  const _UnusedSource();

  @override
  Future<void> downloadFile({
    required GameAssetManifest manifest,
    required GameAssetFile file,
    required File destination,
  }) => throw UnimplementedError();

  @override
  Future<GameAssetManifest> fetchManifest(String gameId) =>
      throw UnimplementedError();
}
