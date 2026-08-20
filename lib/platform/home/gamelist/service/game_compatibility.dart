import 'package:project00/core/constants/app_constants.dart';
import 'package:project00/core/utils/app_version.dart';
import 'package:project00/games/game_registry.dart';
import 'package:project00/platform/home/gamelist/models/game_info.dart';

//=======================게임 실행 가능 여부==============================
// 스토어에 배포된 앱은 이후 Firestore에 추가된 게임 문서를 그대로 받아
// 목록에 보여줍니다. 그 게임의 코드가 이 빌드에 없거나(레지스트리 미등록)
// 요구 버전이 더 높으면, 시작을 막고 업데이트를 안내해야 합니다.
// 이 판단은 반드시 이 한 곳을 거칩니다.

/// 이 빌드가 [game]을 실제로 실행할 수 있는지 확인합니다.
bool isGamePlayableOnThisBuild(GameInfo game) {
  if (GameRegistry.find(game.id) == null) return false;
  return isAppVersionAtLeast(
    current: AppConstants.appVersion,
    minimum: game.minAppVersion,
  );
}

/// 실행할 수 없을 때 사용자에게 보여줄 안내 문구입니다.
const gameRequiresUpdateMessage = '이 게임은 최신 버전에서 이용할 수 있습니다.\n앱을 업데이트해 주세요.';
