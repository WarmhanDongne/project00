// [game_assets.dart]는 게임 에셋 경로를 GameImage로 변환하는 파일이다.
//
// - [SingleImage] : 이미지 한 장을 GameImage로 변환
// - [ImageList] : 여러 이미지를 GameImage 목록으로 변환
// - [PackagePath] : game_kit 패키지의 에셋 경로를 함께 적용
// - [ReadOnly] : 변환된 이미지 목록을 수정할 수 없게 고정
//
// 즉, 생성된 에셋 경로를 게임 화면에서
// 같은 방식으로 사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:game_kit/gen/assets.gen.dart';
import 'package:game_kit/core/assets/game_image.dart';
export 'package:game_kit/core/assets/game_image.dart';
// ============================================================

//==========[ 한 장의 번들 이미지 변환 ]==========
//[게임이미지] 생성된 에셋 경로에 game_kit 패키지 이름을 함께 넣어 변환
extension GameKitImageX on AssetGenImage {
  GameImage get game => GameImage.bundled(path, package: Assets.package);
}

//==========[ 여러 장의 번들 이미지 변환 ]==========
//[읽기전용] 변환한 목록을 화면 밖에서 실수로 수정하지 못하게 고정
extension GameKitImageListX on List<AssetGenImage> {
  List<GameImage> get game =>
      List<GameImage>.unmodifiable(map((asset) => asset.game));
}
