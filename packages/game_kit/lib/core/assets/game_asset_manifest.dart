import 'dart:convert';

class GameAssetManifest {
  const GameAssetManifest({
    required this.gameId,
    required this.assetVersion,
    required this.requiredPatchNumber,
    required this.files,
  });

  factory GameAssetManifest.fromJson(Map<String, Object?> json) {
    final gameId = json['gameId'];
    final assetVersion = json['assetVersion'];
    final requiredPatchNumber = json['requiredPatchNumber'];
    final rawFiles = json['files'];
    if (gameId is! String ||
        !isSafeGameId(gameId) ||
        !_isNonNegativeInt(assetVersion) ||
        !_isNonNegativeInt(requiredPatchNumber) ||
        rawFiles is! List) {
      throw const FormatException('게임 에셋 매니페스트 형식이 올바르지 않습니다.');
    }
    final manifest = GameAssetManifest(
      gameId: gameId,
      assetVersion: (assetVersion as num).toInt(),
      requiredPatchNumber: (requiredPatchNumber as num).toInt(),
      files: List.unmodifiable(
        rawFiles.map((value) {
          if (value is! Map) throw const FormatException('에셋 파일 형식 오류');
          return GameAssetFile.fromJson(Map<String, Object?>.from(value));
        }),
      ),
    );
    manifest.validate();
    return manifest;
  }

  factory GameAssetManifest.decode(String source) => GameAssetManifest.fromJson(
    Map<String, Object?>.from(jsonDecode(source) as Map),
  );

  final String gameId;
  final int assetVersion;
  final int requiredPatchNumber;
  final List<GameAssetFile> files;

  Map<String, Object?> toJson() => {
    'gameId': gameId,
    'assetVersion': assetVersion,
    'requiredPatchNumber': requiredPatchNumber,
    'files': files.map((file) => file.toJson()).toList(growable: false),
  };

  String encode() => jsonEncode(toJson());

  /// `const` 생성자로 만든 매니페스트도 설치 전에 같은 계약을 검사합니다.
  void validate() {
    if (!isSafeGameId(gameId) || assetVersion < 0 || requiredPatchNumber < 0) {
      throw const FormatException('게임 에셋 매니페스트 형식이 올바르지 않습니다.');
    }
    final paths = <String>{};
    for (final file in files) {
      file.validate();
      if (!paths.add(file.path)) {
        throw const FormatException('중복된 게임 에셋 경로가 있습니다.');
      }
    }
  }

  bool supportsPatch(int currentPatchNumber) =>
      currentPatchNumber >= requiredPatchNumber;
}

class GameAssetFile {
  const GameAssetFile({
    required this.path,
    required this.sha256,
    required this.bytes,
    required this.device,
  });

  factory GameAssetFile.fromJson(Map<String, Object?> json) {
    final path = json['path'];
    final digest = json['sha256'];
    final bytes = json['bytes'];
    final device = json['device'];
    if (path is! String ||
        !isSafeLogicalAssetPath(path) ||
        digest is! String ||
        !_sha256.hasMatch(digest) ||
        !_isNonNegativeInt(bytes) ||
        device is! String ||
        !const {'both', 'phone', 'tablet'}.contains(device)) {
      throw const FormatException('게임 에셋 파일 정보가 올바르지 않습니다.');
    }
    return GameAssetFile(
      path: path,
      sha256: digest.toLowerCase(),
      bytes: (bytes as num).toInt(),
      device: device,
    );
  }

  final String path;
  final String sha256;
  final int bytes;
  final String device;

  Map<String, Object?> toJson() => {
    'path': path,
    'sha256': sha256,
    'bytes': bytes,
    'device': device,
  };

  void validate() {
    if (!isSafeLogicalAssetPath(path) ||
        !_sha256.hasMatch(sha256) ||
        bytes < 0 ||
        !const {'both', 'phone', 'tablet'}.contains(device)) {
      throw const FormatException('게임 에셋 파일 정보가 올바르지 않습니다.');
    }
  }
}

bool isSafeGameId(String value) => _safeGameId.hasMatch(value);

bool isSafeLogicalAssetPath(String value) => _safeLogicalPath.hasMatch(value);

bool _isNonNegativeInt(Object? value) =>
    value is num && value.isFinite && value == value.toInt() && value >= 0;

final _safeGameId = RegExp(r'^[A-Za-z0-9_-]+$');
final _safeLogicalPath = RegExp(
  r'^(?!/)(?!.*(?:^|/)\.\.(?:/|$))[A-Za-z0-9_./-]+$',
);
final _sha256 = RegExp(r'^[A-Fa-f0-9]{64}$');
