import 'dart:convert';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:game_kit/core/assets/game_asset_manifest.dart';
import 'package:game_kit/core/assets/game_asset_source.dart';

/// Firebase Storage의 `game-assets/`를 다운로드 게임 저장소로 연결합니다.
///
/// 예상 경로:
/// - `game-assets/<gameId>/manifest.json`
/// - `game-assets/<gameId>/<assetVersion>/<logicalPath>`
///
/// Storage Rules가 로그인 사용자에게 읽기만 허용하면 SDK가 현재 Firebase Auth
/// 자격 증명을 사용합니다. 앱은 이 구현을 등록해도 자동 다운로드하지 않습니다.
final class FirebaseGameAssetSource implements GameAssetSource {
  FirebaseGameAssetSource({FirebaseStorage? storage})
    : _storage = storage ?? FirebaseStorage.instance;

  static const int _maxManifestBytes = 1024 * 1024;
  final FirebaseStorage _storage;

  @override
  Future<GameAssetManifest> fetchManifest(String gameId) async {
    if (!isSafeGameId(gameId)) {
      throw const FormatException('게임 식별자가 올바르지 않습니다.');
    }
    final bytes = await _storage
        .ref('game-assets/$gameId/manifest.json')
        .getData(_maxManifestBytes);
    if (bytes == null) throw StateError('게임 에셋 매니페스트를 받지 못했습니다.');
    return GameAssetManifest.decode(utf8.decode(bytes));
  }

  @override
  Future<void> downloadFile({
    required GameAssetManifest manifest,
    required GameAssetFile file,
    required File destination,
  }) async {
    manifest.validate();
    file.validate();
    final reference = _storage.ref(
      'game-assets/${manifest.gameId}/${manifest.assetVersion}/${file.path}',
    );
    await reference.writeToFile(destination);
  }
}
