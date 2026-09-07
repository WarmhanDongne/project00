import 'package:flutter_test/flutter_test.dart';
import 'package:mosigame_core/core/assets/game_asset_manifest.dart';

void main() {
  const digest =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  test('manifest parses version, patch gate, and files', () {
    final manifest = GameAssetManifest.fromJson({
      'gameId': 'future_game',
      'assetVersion': 3,
      'requiredPatchNumber': 12,
      'files': [
        {
          'path': 'images/background.webp',
          'sha256': digest,
          'bytes': 42,
          'device': 'both',
        },
      ],
    });

    expect(manifest.assetVersion, 3);
    expect(manifest.supportsPatch(11), isFalse);
    expect(manifest.supportsPatch(12), isTrue);
    expect(manifest.files.single.path, 'images/background.webp');
    final decoded = GameAssetManifest.decode(manifest.encode());
    expect(decoded.toJson(), manifest.toJson());
  });

  test('manifest rejects traversal and malformed hashes', () {
    Map<String, Object?> manifestWith(String path, String hash) => {
      'gameId': 'future_game',
      'assetVersion': 1,
      'requiredPatchNumber': 0,
      'files': [
        {'path': path, 'sha256': hash, 'bytes': 1, 'device': 'both'},
      ],
    };

    expect(
      () => GameAssetManifest.fromJson(manifestWith('../token', digest)),
      throwsFormatException,
    );
    expect(
      () => GameAssetManifest.fromJson(manifestWith('images/a', 'bad')),
      throwsFormatException,
    );
  });

  test(
    'manifest rejects unsafe game ids, fractional numbers, and duplicates',
    () {
      Map<String, Object?> manifestWith({
        Object? gameId = 'future_game',
        Object? assetVersion = 1,
        Object? bytes = 1,
        bool duplicate = false,
      }) => {
        'gameId': gameId,
        'assetVersion': assetVersion,
        'requiredPatchNumber': 0,
        'files': [
          {
            'path': 'images/a',
            'sha256': digest,
            'bytes': bytes,
            'device': 'both',
          },
          if (duplicate)
            {
              'path': 'images/a',
              'sha256': digest,
              'bytes': 1,
              'device': 'both',
            },
        ],
      };

      expect(
        () => GameAssetManifest.fromJson(manifestWith(gameId: '../escape')),
        throwsFormatException,
      );
      expect(
        () => GameAssetManifest.fromJson(manifestWith(assetVersion: 1.5)),
        throwsFormatException,
      );
      expect(
        () => GameAssetManifest.fromJson(manifestWith(bytes: 1.5)),
        throwsFormatException,
      );
      expect(
        () => GameAssetManifest.fromJson(manifestWith(duplicate: true)),
        throwsFormatException,
      );
    },
  );
}
