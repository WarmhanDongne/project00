import 'package:game_kit/core/assets/game_image.dart';

/// 홀덤 에셋 v2입니다. 카드 앞면은 `HoldemCardView`가 직접 그립니다.
///
/// 개발·정식 빌드 모두 검증된 다운로드 캐시를 사용합니다.
abstract final class HoldemAssets {
  static const String gameId = 'holdem';
  static const int assetVersion = 2;

  static final phoneBackground = _image('images/background/phone.webp');
  static final tabletBackground = _image('images/background/tablet.webp');
  static final layoutTable = _image('images/layout/table.webp');
  static final layoutChair = _image('images/layout/chair.webp');
  static final cardBack = _image('images/cards/back.webp');

  static GameImage _image(String logicalPath) => GameImage.remote(
    gameId: gameId,
    assetVersion: assetVersion,
    logicalPath: logicalPath,
  );
}
