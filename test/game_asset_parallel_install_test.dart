import 'dart:async';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_kit/core/assets/game_asset_cache.dart';
import 'package:game_kit/core/assets/game_asset_manifest.dart';
import 'package:game_kit/core/assets/game_asset_source.dart';

void main() {
  late Directory root;
  late GameAssetCache cache;
  late _Source source;
  final manifest = GameAssetManifest(
    gameId: 'holdem',
    assetVersion: 2,
    requiredPatchNumber: 0,
    files: [
      for (var i = 0; i < 4; i++)
        GameAssetFile(
          path: 'images/$i.webp',
          sha256: sha256.convert([1, 2, 3]).toString(),
          bytes: 3,
          device: 'both',
        ),
    ],
  );
  setUp(() async {
    root = await Directory.systemTemp.createTemp('mosigame-parallel-assets-');
    cache = GameAssetCache(root: root);
    source = _Source();
  });
  tearDown(() => root.delete(recursive: true));
  Future<void> install() =>
      cache.install(manifest: manifest, source: source, currentPatchNumber: 0);

  test(
    'three files overlap; duplicate install shares work; marker waits for all',
    () async {
      final first = install();
      final duplicate = install();
      await source.firstBatch.future;
      expect(source.started, 3);
      expect(source.active, 3);
      expect(cache.isInstalled('holdem', 2), isFalse);
      for (var i = 0; i < 3; i++) {
        source.gates[i].complete();
      }
      await source.lastBatch.future;
      expect(cache.isInstalled('holdem', 2), isFalse);
      source.gates[3].complete();
      await Future.wait([first, duplicate]);
      expect(source.started, 4);
      expect(source.maxActive, 3);
      expect(await cache.verifyInstalled(manifest), isTrue);
    },
  );

  test(
    'failed batch drains before retry and never publishes a complete marker',
    () async {
      source.failFirst = true;
      var finished = false;
      final result = expectLater(
        install().whenComplete(() => finished = true),
        throwsStateError,
      );
      await source.firstBatch.future;
      source.gates[0].complete();
      await source.firstFailure.future;
      expect(finished, isFalse);
      expect(cache.isInstalled('holdem', 2), isFalse);
      source.gates[1].complete();
      source.gates[2].complete();
      await result;
      expect(source.active, 0);
      expect(source.started, 3);
      expect(
        await root
            .list(recursive: true)
            .where((f) => f.path.endsWith('.part'))
            .toList(),
        isEmpty,
      );
      source = _Source();
      for (final gate in source.gates) {
        gate.complete();
      }
      await install();
      expect(
        source.started,
        2,
        reason: 'Valid files from the failed batch are reused',
      );
      expect(await cache.verifyInstalled(manifest), isTrue);
    },
  );
}

class _Source implements GameAssetSource {
  final gates = List.generate(4, (_) => Completer<void>());
  final firstBatch = Completer<void>(),
      lastBatch = Completer<void>(),
      firstFailure = Completer<void>();
  int active = 0, maxActive = 0, started = 0;
  bool failFirst = false;
  @override
  Future<GameAssetManifest> fetchManifest(String gameId) =>
      throw UnimplementedError();
  @override
  Future<void> downloadFile({
    required GameAssetManifest manifest,
    required GameAssetFile file,
    required File destination,
  }) async {
    final index = int.parse(file.path.split('/').last.split('.').first);
    started++;
    active++;
    if (active > maxActive) maxActive = active;
    if (started == 3) firstBatch.complete();
    if (started == 4) lastBatch.complete();
    try {
      await gates[index].future;
      if (index == 0 && failFirst) {
        firstFailure.complete();
        throw StateError('download failed');
      }
      await destination.writeAsBytes([1, 2, 3]);
    } finally {
      active--;
    }
  }
}
