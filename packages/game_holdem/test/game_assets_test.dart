import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/game_assets.dart';

void main() {
  testWidgets('개발 빌드는 홀덤 v2 번들 에셋 5개를 열 수 있다', (tester) async {
    expect(kDebugMode, isTrue);
    final images = [
      HoldemAssets.phoneBackground,
      HoldemAssets.tabletBackground,
      HoldemAssets.layoutTable,
      HoldemAssets.layoutChair,
      HoldemAssets.cardBack,
    ];

    for (final image in images) {
      final provider = image.provider();
      expect(provider, isA<AssetImage>());
      final asset = provider as AssetImage;
      final key = await asset.obtainKey(ImageConfiguration.empty);
      final bytes = await rootBundle.load(key.name);
      expect(bytes.lengthInBytes, greaterThan(0));
    }
  });
}
