import 'dart:io';

import 'package:game_contract/games/template_game.dart';
import 'package:mosigame_core/core/assets/game_asset_cache.dart';
import 'package:mosigame_core/core/assets/game_asset_source.dart';
import 'package:mosigame_core/core/assets/game_asset_store.dart';
import 'package:path_provider/path_provider.dart';
import 'package:project00/game_assets/firebase_game_asset_source.dart';
import 'package:shorebird_code_push/shorebird_code_push.dart';

/// 영구 캐시와 다운로드 게임 저장소를 앱 전역 [GameAssetStore]에 연결합니다.
///
/// 네트워크 요청은 하지 않습니다. [catalog]에 `requiredAssetVersion > 0`인 게임이
/// 패치로 추가되면 다운로드 대상으로 등록만 하며, 실제 다운로드는 나중에 소유
/// 게임 버튼이 [GameAssetStore.downloadGame]을 호출할 때 시작됩니다.
Future<void> initializeGameAssets({
  required GameCatalog catalog,
  Future<Directory> Function()? supportDirectory,
  Future<int> Function()? patchNumber,
  GameAssetSource? source,
}) async {
  final applicationSupport =
      await (supportDirectory ?? getApplicationSupportDirectory)();
  final currentPatchNumber = await (patchNumber ?? _readPatchNumber)();
  final store = GameAssetStore(
    cache: GameAssetCache(
      root: Directory('${applicationSupport.path}/mosigame'),
    ),
    currentPatchNumber: currentPatchNumber,
  );
  final gameAssetSource = source ?? FirebaseGameAssetSource();
  for (final game in catalog.games) {
    if (game.requiredAssetVersion <= 0) continue;
    store.registerDownloadableGame(
      gameId: game.id,
      requiredAssetVersion: game.requiredAssetVersion,
      source: gameAssetSource,
    );
  }
  GameAssetStore.instance = store;
}

Future<int> _readPatchNumber() async {
  final updater = ShorebirdUpdater();
  if (!updater.isAvailable) return 0;
  final patch = await updater.readCurrentPatch();
  return patch?.number ?? 0;
}
