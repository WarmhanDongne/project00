// [game_assets.dart] 는 마피아 이미지 에셋을 실행 코드에 연결하는 파일이다.
//
// - [Package] : 마피아
// - [AssetBridge] : 생성된 에셋 경로를 GameImage로 변환
//
// 즉, 게임 화면이 번들 에셋을 일관된 방식으로 사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:game_mafia/gen/assets.gen.dart';
import 'package:game_kit/core/assets/game_image.dart';
export 'package:game_kit/core/assets/game_image.dart';
// ============================================================

// ---------------------------------------------------------------------------
// 한 장의 번들 이미지 변환
// ---------------------------------------------------------------------------
//[게임이미지] 생성된 에셋 경로에 마피아 패키지 이름을 함께 넣어 변환
extension MafiaImageX on AssetGenImage {
  GameImage get game => GameImage.bundled(path, package: Assets.package);
}

// ---------------------------------------------------------------------------
// 여러 장의 번들 이미지 변환
// ---------------------------------------------------------------------------
//[읽기전용] 변환한 목록을 화면 밖에서 실수로 수정하지 못하게 고정
extension MafiaImageListX on List<AssetGenImage> {
  List<GameImage> get game =>
      List.unmodifiable([for (final asset in this) asset.game]);
}
