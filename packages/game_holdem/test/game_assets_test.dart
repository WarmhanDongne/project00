import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/game_assets.dart';
import 'package:game_holdem/game_holdem.dart';
import 'package:game_kit/core/assets/game_asset_store.dart';

void main() {
  late GameAssetStore previousStore;
  setUp(() {
    previousStore = GameAssetStore.instance;
  });
  tearDown(() {
    GameAssetStore.instance = previousStore;
  });
  final images = [
    HoldemAssets.phoneBackground,
    HoldemAssets.tabletBackground,
    HoldemAssets.layoutTable,
    HoldemAssets.layoutChair,
    HoldemAssets.cardBack,
  ];
  testWidgets('홀덤 원본 5개를 다운로드 없이 패키지 에셋으로 읽는다', (tester) async {
    expect(const HoldemGame().requiredAssetVersion, 0);
    await tester.runAsync(() async {
      for (final image in images) {
        final provider = image.provider();
        expect(provider, isA<AssetImage>());
        final asset = provider as AssetImage;
        expect(asset.package, 'game_holdem');
        // 번들 경로는 이미 `assets/...`로 시작합니다.
        final file = File(image.path);
        expect(file.existsSync(), isTrue);
        final data = await rootBundle.load(
          'packages/game_holdem/${image.path}',
        );
        final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
        final frame = await codec.getNextFrame();
        expect(frame.image.width, greaterThan(0));
        expect(frame.image.height, greaterThan(0));
        frame.image.dispose();
        codec.dispose();
      }
    });
  });
}
