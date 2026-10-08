import 'dart:io';

import 'package:game_kit/core/assets/game_asset_cache.dart';
import 'package:game_kit/core/assets/game_asset_manifest.dart';
import 'package:game_kit/core/assets/game_asset_source.dart';

/// 로컬 원본을 런타임과 같은 검증 경로로 개발 기기의 캐시에 설치합니다.
Future<GameAssetManifest> installLocalGameAssets({
  required Directory sourceDirectory,
  required Directory cacheRoot,
  int currentPatchNumber = 0,
}) async {
  final source = LocalGameAssetSource(sourceDirectory);
  final manifest = GameAssetManifest.decode(
    await File('${sourceDirectory.path}/manifest.json').readAsString(),
  );
  final cache = GameAssetCache(root: cacheRoot);
  await cache.install(
    manifest: manifest,
    source: source,
    currentPatchNumber: currentPatchNumber,
  );
  if (!await cache.verifyInstalled(manifest)) {
    throw StateError('로컬 게임 에셋 캐시 검증에 실패했습니다.');
  }
  return manifest;
}

/// 앱에 포함되지 않는 개발 도구·테스트용 파일 source입니다.
final class LocalGameAssetSource implements GameAssetSource {
  const LocalGameAssetSource(this.directory);

  final Directory directory;

  @override
  Future<GameAssetManifest> fetchManifest(String gameId) async {
    final manifest = GameAssetManifest.decode(
      await File('${directory.path}/manifest.json').readAsString(),
    );
    if (manifest.gameId != gameId) {
      throw StateError('로컬 매니페스트의 게임 ID가 일치하지 않습니다.');
    }
    return manifest;
  }

  @override
  Future<void> downloadFile({
    required GameAssetManifest manifest,
    required GameAssetFile file,
    required File destination,
  }) async {
    manifest.validate();
    file.validate();
    await File(
      '${directory.path}/${manifest.assetVersion}/${file.path}',
    ).copy(destination.path);
  }
}

Future<void> main(List<String> arguments) async {
  const usage =
      'dart run tool/install_local_game_assets.dart '
      '--source <game directory> --cache-root <Application Support/mosigame> '
      '[--patch-number <number>]';
  if (arguments.length == 1 && arguments.single == '--help') {
    stdout.writeln(usage);
    return;
  }
  try {
    final options = <String, String>{};
    for (var i = 0; i < arguments.length; i += 2) {
      final option = arguments[i];
      if (i + 1 >= arguments.length ||
          !const {
            '--source',
            '--cache-root',
            '--patch-number',
          }.contains(option) ||
          options.containsKey(option) ||
          arguments[i + 1].trim().isEmpty) {
        throw const FormatException('잘못된 인자입니다.');
      }
      options[option] = arguments[i + 1];
    }
    final source = options['--source'];
    final cache = options['--cache-root'];
    final patch = int.tryParse(options['--patch-number'] ?? '0');
    if (source == null || cache == null || patch == null || patch < 0) {
      throw const FormatException('원본·캐시 경로와 유효한 패치 번호가 필요합니다.');
    }
    final manifest = await installLocalGameAssets(
      sourceDirectory: Directory(source),
      cacheRoot: Directory(cache),
      currentPatchNumber: patch,
    );
    stdout.writeln(
      'PASS: ${manifest.gameId} v${manifest.assetVersion}, '
      '${manifest.files.length} files installed and verified.',
    );
  } on FormatException catch (error) {
    stderr.writeln('${error.message}\n$usage');
    exitCode = 2;
  } catch (error) {
    stderr.writeln('FAIL: $error');
    exitCode = 1;
  }
}
