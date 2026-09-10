@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

//=======================코드가 가리키는 번들 파일==============================
// 루트뿐 아니라 모든 workspace package의 생성 코드와 직접 경로를 검사합니다.
// 패키지 이동 뒤 예전 테스트가 루트 lib/만 보면서 누락을 놓치지 않게 합니다.
void main() {
  const pendingArtwork = <String>{};
  final owners = _assetOwners();
  final references = _assetReferences(owners);

  test('배선만 해 둔 그림은 아직 파일이 없다', () {
    for (final path in pendingArtwork) {
      expect(
        File(path).existsSync(),
        isFalse,
        reason: '$path 파일이 들어왔습니다. pendingArtwork에서 지워 주세요.',
      );
    }
  });

  test('workspace 코드의 번들 에셋 경로는 모두 실제 파일이 있다', () {
    final missing = <String>[];
    for (final reference in references) {
      if (reference.path.contains(r'$') ||
          pendingArtwork.contains(reference.path)) {
        continue;
      }
      final resolved = _resolve(reference, owners);
      if (!resolved.existsSync()) {
        missing.add('${reference.path}  ← ${reference.source.path}');
      }
    }

    expect(missing, isEmpty, reason: '없는 에셋 파일을 가리킵니다:\n${missing.join('\n')}');
  });

  test('번들 에셋 경로에 OS별로 다르게 처리되는 분해 문자가 없다', () {
    final nonPortable = references
        .where((reference) => _containsDecomposedUnicode(reference.path))
        .map((reference) => '${reference.path}  ← ${reference.source.path}')
        .toList();

    expect(
      nonPortable,
      isEmpty,
      reason:
          'macOS와 Linux에서 다른 파일로 처리될 수 있는 '
          '분해된 Unicode 경로입니다:\n${nonPortable.join('\n')}',
    );
  });

  test('workspace 코드의 번들 에셋은 소유 package pubspec에 등록돼 있다', () {
    final unregistered = <String>{};
    for (final reference in references) {
      if (reference.path.contains(r'$')) continue;
      final owner = _ownerOf(reference, owners);
      if (owner == null) {
        unregistered.add('${reference.path} (알 수 없는 package)');
        continue;
      }
      final localPath = _localAssetPath(reference.path);
      final declared = _declaredAssets(owner.pubspec);
      if (!declared.any(
        (entry) => entry.endsWith('/')
            ? localPath.startsWith(entry)
            : localPath == entry,
      )) {
        unregistered.add('${owner.name}: $localPath');
      }
    }

    expect(unregistered, isEmpty);
  });
}

final class _AssetOwner {
  const _AssetOwner({required this.name, required this.root});

  final String name;
  final Directory root;

  Directory get lib => Directory('${root.path}/lib');
  File get pubspec => File('${root.path}/pubspec.yaml');
}

final class _AssetReference {
  const _AssetReference({
    required this.path,
    required this.source,
    required this.sourceOwner,
  });

  final String path;
  final File source;
  final _AssetOwner sourceOwner;
}

Map<String, _AssetOwner> _assetOwners() {
  final result = <String, _AssetOwner>{
    'project00': _AssetOwner(name: 'project00', root: Directory.current),
  };
  final packages = Directory('packages');
  if (!packages.existsSync()) return result;
  for (final entity in packages.listSync()) {
    if (entity is! Directory) continue;
    final pubspec = File('${entity.path}/pubspec.yaml');
    if (!pubspec.existsSync()) continue;
    final match = RegExp(
      r'^name:\s*([A-Za-z0-9_]+)\s*$',
      multiLine: true,
    ).firstMatch(pubspec.readAsStringSync());
    if (match == null) continue;
    final name = match.group(1)!;
    result[name] = _AssetOwner(name: name, root: entity);
  }
  return result;
}

List<_AssetReference> _assetReferences(Map<String, _AssetOwner> owners) {
  final pattern = RegExp(
    r'''['"]((?:packages/[^/'"]+/)?assets/[^'"]+\.(?:png|jpg|jpeg|webp|svg|mp3|m4a|wav|ogg))['"]''',
  );
  final result = <_AssetReference>[];
  for (final owner in owners.values) {
    if (!owner.lib.existsSync()) continue;
    for (final entity in owner.lib.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(entity.readAsStringSync())) {
        result.add(
          _AssetReference(
            path: match.group(1)!,
            source: entity,
            sourceOwner: owner,
          ),
        );
      }
    }
  }
  return result;
}

_AssetOwner? _ownerOf(
  _AssetReference reference,
  Map<String, _AssetOwner> owners,
) {
  if (!reference.path.startsWith('packages/')) return reference.sourceOwner;
  final segments = reference.path.split('/');
  return segments.length > 2 ? owners[segments[1]] : null;
}

File _resolve(_AssetReference reference, Map<String, _AssetOwner> owners) {
  final owner = _ownerOf(reference, owners);
  if (owner == null) return File(reference.path);
  return File('${owner.root.path}/${_localAssetPath(reference.path)}');
}

String _localAssetPath(String path) {
  if (!path.startsWith('packages/')) return path;
  return path.split('/').skip(2).join('/');
}

bool _containsDecomposedUnicode(String path) => path.runes.any(
  (rune) =>
      (rune >= 0x0300 && rune <= 0x036F) || // Combining Diacritical Marks
      (rune >= 0x1100 && rune <= 0x11FF), // Hangul Jamo used by NFD
);

Set<String> _declaredAssets(File pubspec) =>
    RegExp(r'^\s+- (assets/\S+)$', multiLine: true)
        .allMatches(pubspec.readAsStringSync())
        .map((match) => match.group(1)!)
        .toSet();
