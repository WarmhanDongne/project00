import 'package:game_kit/core/assets/game_image.dart';

/// 앱에 포함되는 홀덤 이미지입니다. 카드 앞면은 `HoldemCardView`가 직접 그립니다.
abstract final class HoldemAssets {
  static final phoneBackground = _image('images/background/phone.webp');
  static final tabletBackground = _image('images/background/tablet.webp');
  static final layoutTable = _image('images/layout/table.webp');
  static final layoutChair = _image('images/layout/chair.webp');
  static final cardBack = _image('images/cards/back.webp');

  static GameImage _image(String logicalPath) =>
      GameImage.bundled('assets/$logicalPath', package: 'game_holdem');
}
