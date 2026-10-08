import 'package:flutter/foundation.dart';
import 'package:game_kit/core/assets/game_image.dart';

/// 홀덤 에셋 v2입니다. 카드 앞면은 `HoldemCardView`가 직접 그립니다.
///
/// 시뮬레이터를 쓰는 개발 빌드는 패키지의 번들 에셋을 사용하고,
/// release 빌드는 기존 Firebase Storage 다운로드 경로를 유지합니다.
abstract final class HoldemAssets {
  static const String gameId = 'holdem';
  static const int assetVersion = 2;

  static final phoneBackground = _image('images/background/phone.webp');
  static final tabletBackground = _image('images/background/tablet.webp');
  static final layoutTable = _image('images/layout/table.webp');
  static final layoutChair = _image('images/layout/chair.webp');
  static final cardBack = _image('images/cards/back.webp');

  static GameImage _image(String logicalPath) => kDebugMode
      ? GameImage.bundled('assets/$logicalPath', package: 'game_holdem')
      : GameImage.remote(
          gameId: gameId,
          assetVersion: assetVersion,
          logicalPath: logicalPath,
        );
}
