import 'package:game_kit/core/assets/game_asset_store.dart';
import 'package:game_kit/template_game.dart';

/// 게임 진입 직전에 캐시를 검증하고, 다운로드 게임이면 사용자 진입 동작을
/// 계기로 필요한 파일을 설치한 뒤 다시 검증합니다.
Future<void> prepareGameAssetsForPlay(TemplateGame game) async {
  final store = GameAssetStore.instance;
  try {
    await store.prepareGame(game.id);
    return;
  } catch (_) {
    if (game.requiredAssetVersion <= 0) rethrow;
  }

  await store.downloadGame(game.id);
  await store.prepareGame(game.id);
}
