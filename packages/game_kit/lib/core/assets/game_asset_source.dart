// [game_asset_source.dart] 는 여러 게임이 함께 사용하는 게임 에셋 저장·검증·경로 해석을 담당하는 파일이다.
//
// - [Package] : 게임 공통 기반
// - [AssetSource] : 게임 에셋 저장·검증·경로 해석을 담당함
//
// 즉, 번들 파일과 내려받은 파일을 안전하게 같은 방식으로 사용하기 위해 필요한 파일이다.

// ========================[ import ]==========================
import 'dart:io';
import 'package:game_kit/core/assets/game_asset_manifest.dart';
// ============================================================

/// 다운로드 게임의 매니페스트와 파일을 제공하는 외부 저장소 경계입니다.
///
/// core는 Firebase Storage SDK를 직접 알지 않습니다. 앱 셸이 이 계약의 Firebase
/// 구현을 주입하므로 테스트에서는 로컬 서버나 메모리 대역을 사용할 수 있습니다.
abstract interface class GameAssetSource {
  Future<GameAssetManifest> fetchManifest(String gameId);

  Future<void> downloadFile({
    required GameAssetManifest manifest,
    required GameAssetFile file,
    required File destination,
  });
}
