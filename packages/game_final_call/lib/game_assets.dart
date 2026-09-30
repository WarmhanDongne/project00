// [game_assets.dart] 는 파이널콜에서 사용하는 생성된 에셋 경로를 실행 코드에 연결하는 파일이다.
//
// - [Package] : 파이널콜
// - [AssetBridge] : 생성된 에셋 경로를 실행 코드에 연결함
//
// 즉, 게임 화면이 번들 에셋을 GameImage로 일관되게 사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'package:game_final_call/gen/assets.gen.dart';
import 'package:game_kit/core/assets/game_image.dart';
export 'package:game_kit/core/assets/game_image.dart';
// ============================================================

// ---------------------------------------------------------------------------
// 한 장의 번들 이미지 변환
// ---------------------------------------------------------------------------
//[게임이미지] 생성된 에셋 경로에 파이널콜 패키지 이름을 함께 넣어 변환
extension FinalCallImageX on AssetGenImage {
  GameImage get game => GameImage.bundled(path, package: Assets.package);
}

// ---------------------------------------------------------------------------
// 여러 장의 번들 이미지 변환
// ---------------------------------------------------------------------------
//[읽기전용] 변환한 목록을 화면 밖에서 실수로 수정하지 못하게 고정
extension FinalCallImageListX on List<AssetGenImage> {
  List<GameImage> get game =>
      List.unmodifiable([for (final asset in this) asset.game]);
}
