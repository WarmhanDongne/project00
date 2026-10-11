import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_holdem/game_assets.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';

void main() {
  test('기본 무료 게임은 오래된 유료 카탈로그 값에도 누구나 플레이할 수 있다', () {
    const catalog = GameRegistry();
    for (final id in bundledFreeGameIds) {
      final game = GameInfo.fromJson({'id': id, 'accessType': 'paid'});
      expect(game.isFree, isTrue, reason: id);
      expect(game.isAccessible, isTrue, reason: id);
      expect(catalog.find(id)?.requiredAssetVersion, 0, reason: id);
    }
    final other = GameInfo.fromJson({
      'id': 'paid_future_game',
      'accessType': 'paid',
    });
    expect(other.isFree, isFalse);
    expect(other.isAccessible, isFalse);
  });

  testWidgets('앱 번들에 홀덤 필수 이미지 다섯 개가 포함된다', (tester) async {
    final images = [
      HoldemAssets.phoneBackground,
      HoldemAssets.tabletBackground,
      HoldemAssets.layoutTable,
      HoldemAssets.layoutChair,
      HoldemAssets.cardBack,
    ];
    for (final image in images) {
      final data = await rootBundle.load('packages/game_holdem/${image.path}');
      expect(data.lengthInBytes, greaterThan(0), reason: image.path);
    }
  });
}
