// [game_assets.dart] 자동 생성된 라이어스 포커 이미지 경로를
// 게임 화면이 사용하는 GameImage로 변환하는 파일이다.

// ========================[ import ]==========================
import 'package:game_liars_poker/gen/assets.gen.dart';
import 'package:game_kit/core/assets/game_image.dart';
export 'package:game_kit/core/assets/game_image.dart';
// ============================================================

// ---------------------------------------------------------------------------
// 한 장의 번들 이미지 변환
// ---------------------------------------------------------------------------
/// 생성된 에셋 경로에 패키지 이름을 더해 game_kit의 공용 이미지 규격으로 변환합니다.
extension LiarsPokerImageX on AssetGenImage {
  GameImage get game => GameImage.bundled(path, package: Assets.package);
}

// ---------------------------------------------------------------------------
// 여러 장의 번들 이미지 변환
// ---------------------------------------------------------------------------
/// 변환한 목록을 화면 밖에서 실수로 수정하지 못하도록 읽기 전용으로 고정합니다.
extension LiarsPokerImageListX on List<AssetGenImage> {
  List<GameImage> get game =>
      List.unmodifiable([for (final asset in this) asset.game]);
}
