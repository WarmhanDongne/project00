import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/game_assets.dart';
import 'package:game_kit/core/assets/game_asset_cache.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';

import '../../../tool/install_local_game_assets.dart';

void main() {
  late Directory cacheRoot;
  late GameAssetStore previousStore;
  setUp(() async {
    cacheRoot = await Directory.systemTemp.createTemp('holdem-image-cache-');
    previousStore = GameAssetStore.instance;
    GameAssetStore.instance = GameAssetStore(
      cache: GameAssetCache(root: cacheRoot),
    );
  });
  tearDown(() async {
    GameAssetStore.instance = previousStore;
    await cacheRoot.delete(recursive: true);
  });
  final images = [
    HoldemAssets.phoneBackground,
    HoldemAssets.tabletBackground,
    HoldemAssets.layoutTable,
    HoldemAssets.layoutChair,
    HoldemAssets.cardBack,
  ];
  test('설치되지 않은 홀덤 이미지는 번들로 대체하지 않는다', () {
    for (final image in images) {
      expect(image.provider, throwsStateError);
    }
  });
  testWidgets('홀덤 v2 원본 5개를 캐시에 검증 설치하고 실제 이미지로 읽는다', (tester) async {
    await tester.runAsync(() async {
      final source = [
        Directory('assets/game-assets/holdem'),
        Directory('../../assets/game-assets/holdem'),
      ].firstWhere((directory) => directory.existsSync());
      final manifest = await installLocalGameAssets(
        sourceDirectory: source,
        cacheRoot: cacheRoot,
      );
      expect(manifest.gameId, 'holdem');
      expect(manifest.assetVersion, 2);
      expect(manifest.files, hasLength(5));
      for (final image in images) {
        final provider = image.provider();
        expect(provider, isA<FileImage>());
        final file = (provider as FileImage).file;
        expect(file.path, startsWith(cacheRoot.path));
        final codec = await ui.instantiateImageCodec(await file.readAsBytes());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      }
    });
  });
}
