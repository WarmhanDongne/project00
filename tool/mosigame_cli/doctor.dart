import 'dart:convert';
import 'dart:io';

import 'process_runner.dart';
import 'result.dart';

abstract interface class FileSystemProbe {
  bool fileExists(String path);

  bool directoryExists(String path);

  String? readTextFile(String path);

  String? findExecutable(String name);
}

final class LocalFileSystemProbe implements FileSystemProbe {
  const LocalFileSystemProbe();

  @override
  bool fileExists(String path) => File(path).existsSync();

  @override
  bool directoryExists(String path) => Directory(path).existsSync();

  @override
  String? readTextFile(String path) {
    try {
      return File(path).readAsStringSync();
    } on FileSystemException {
      return null;
    }
  }

  @override
  String? findExecutable(String name) => resolveExecutable(name);
}

final class RuntimeEnvironment {
  const RuntimeEnvironment({
    required this.operatingSystem,
    required this.operatingSystemVersion,
    required this.dartVersion,
  });

  factory RuntimeEnvironment.current() => RuntimeEnvironment(
    operatingSystem: Platform.operatingSystem,
    operatingSystemVersion: Platform.operatingSystemVersion,
    dartVersion: Platform.version.split(' ').first,
  );

  final String operatingSystem;
  final String operatingSystemVersion;
  final String dartVersion;

  bool get isSupported =>
      const <String>{'windows', 'linux', 'macos'}.contains(operatingSystem);
}

final class Doctor {
  Doctor({
    required this.repositoryRoot,
    required this.processRunner,
    required this.fileSystem,
    required this.runtime,
    this.processTimeout = const Duration(seconds: 15),
  });

  final String repositoryRoot;
  final ProcessRunner processRunner;
  final FileSystemProbe fileSystem;
  final RuntimeEnvironment runtime;
  final Duration processTimeout;

  Future<List<CliCheckResult>> runChecks() async => <CliCheckResult>[
    _repositoryRootCheck(),
    await _versionCommandCheck(
      id: 'git',
      label: 'Git',
      executable: 'git',
      arguments: const <String>['--version'],
    ),
    _dartCheck(),
    _flutterCheck(),
    await _nodeCheck(),
    await _versionCommandCheck(
      id: 'npm',
      label: 'npm',
      executable: 'npm',
      arguments: const <String>['--version'],
    ),
    _functionsDependenciesCheck(),
    _projectConfigCheck(),
    _operatingSystemCheck(),
  ];

  CliCheckResult _repositoryRootCheck() {
    final gitPath = _path('.git');
    final hasGit =
        fileSystem.directoryExists(gitPath) || fileSystem.fileExists(gitPath);
    final hasPubspec = fileSystem.fileExists(_path('pubspec.yaml'));
    if (hasGit && hasPubspec) {
      return const CliCheckResult(
        id: 'repository-root',
        status: CliStatus.pass,
        message: 'Repository root detected.',
      );
    }
    return const CliCheckResult(
      id: 'repository-root',
      status: CliStatus.blocked,
      message: 'Run the command from the repository root.',
    );
  }

  CliCheckResult _dartCheck() => CliCheckResult(
    id: 'dart',
    status: CliStatus.pass,
    message: 'Dart ${runtime.dartVersion} is running the Project CLI.',
    details: <String, Object?>{'version': runtime.dartVersion},
  );

  CliCheckResult _flutterCheck() {
    final launcher = fileSystem.findExecutable('flutter');
    if (launcher == null) {
      return const CliCheckResult(
        id: 'flutter',
        status: CliStatus.blocked,
        message: 'Flutter is not available on PATH.',
      );
    }

    final sdkRoot = File(launcher).parent.parent.path;
    final metadataPath = _joinParts(<String>[
      sdkRoot,
      'bin',
      'cache',
      'flutter.version.json',
    ]);
    final metadata = fileSystem.readTextFile(metadataPath);
    if (metadata == null) {
      return const CliCheckResult(
        id: 'flutter',
        status: CliStatus.blocked,
        message: 'Flutter was found, but its version metadata is unavailable.',
      );
    }

    try {
      final decoded = jsonDecode(metadata);
      if (decoded is! Map<String, Object?>) throw const FormatException();
      final version = decoded['frameworkVersion'];
      if (version is! String || version.trim().isEmpty) {
        throw const FormatException();
      }
      return CliCheckResult(
        id: 'flutter',
        status: CliStatus.pass,
        message: 'Flutter $version is available.',
        details: <String, Object?>{
          'version': version,
          if (decoded['channel'] is String) 'channel': decoded['channel'],
        },
      );
    } on FormatException {
      return const CliCheckResult(
        id: 'flutter',
        status: CliStatus.blocked,
        message: 'Flutter version metadata is invalid.',
      );
    }
  }

  Future<CliCheckResult> _nodeCheck() async {
    final result = await _runVersionCommand(
      executable: 'node',
      arguments: const <String>['--version'],
    );
    if (result == null) {
      return const CliCheckResult(
        id: 'node',
        status: CliStatus.blocked,
        message: 'Node.js is not available.',
      );
    }

    final version = _firstLine(result.combinedOutput);
    final expectedVersion = fileSystem.readTextFile(_path('.nvmrc'))?.trim();
    final actualMajor = _majorVersion(version);
    final expectedMajor = _majorVersion(expectedVersion ?? '');
    if (expectedMajor != null && actualMajor != expectedMajor) {
      return CliCheckResult(
        id: 'node',
        status: CliStatus.blocked,
        message: 'Node.js major version does not match .nvmrc.',
        details: <String, Object?>{
          'version': version,
          'expectedMajor': expectedMajor,
        },
      );
    }

    return CliCheckResult(
      id: 'node',
      status: CliStatus.pass,
      message: 'Node.js $version is available.',
      details: <String, Object?>{'version': version},
    );
  }

  Future<CliCheckResult> _versionCommandCheck({
    required String id,
    required String label,
    required String executable,
    required List<String> arguments,
  }) async {
    final result = await _runVersionCommand(
      executable: executable,
      arguments: arguments,
    );
    if (result == null) {
      return CliCheckResult(
        id: id,
        status: CliStatus.blocked,
        message: '$label is not available.',
      );
    }
    final version = _firstLine(result.combinedOutput);
    return CliCheckResult(
      id: id,
      status: CliStatus.pass,
      message: '$label is available.',
      details: <String, Object?>{'version': version},
    );
  }

  Future<ProcessExecution?> _runVersionCommand({
    required String executable,
    required List<String> arguments,
  }) async {
    final resolvedExecutable = fileSystem.findExecutable(executable);
    if (resolvedExecutable == null) return null;
    try {
      final result = await processRunner.run(
        resolvedExecutable,
        arguments,
        workingDirectory: repositoryRoot,
        timeout: processTimeout,
      );
      if (result.timedOut || result.exitCode != 0) return null;
      return result;
    } on ProcessException {
      return null;
    } on FileSystemException {
      return null;
    }
  }

  CliCheckResult _functionsDependenciesCheck() {
    final nodeModules = fileSystem.directoryExists(
      _pathParts(<String>['functions', 'node_modules']),
    );
    final lockFile = fileSystem.fileExists(
      _pathParts(<String>['functions', 'package-lock.json']),
    );
    if (nodeModules && lockFile) {
      return const CliCheckResult(
        id: 'functions-dependencies',
        status: CliStatus.pass,
        message: 'Functions dependencies are present.',
      );
    }
    return CliCheckResult(
      id: 'functions-dependencies',
      status: CliStatus.blocked,
      message: 'Functions dependencies are incomplete.',
      details: <String, Object?>{
        'nodeModulesPresent': nodeModules,
        'lockFilePresent': lockFile,
      },
    );
  }

  CliCheckResult _projectConfigCheck() {
    const requiredFiles = <String>[
      'pubspec.yaml',
      'firebase.json',
      '.nvmrc',
      'functions/package.json',
    ];
    final missing = requiredFiles
        .where((path) => !fileSystem.fileExists(_pathPortable(path)))
        .toList();
    if (missing.isEmpty) {
      return const CliCheckResult(
        id: 'project-config',
        status: CliStatus.pass,
        message: 'Required project config files are present.',
      );
    }
    return CliCheckResult(
      id: 'project-config',
      status: CliStatus.blocked,
      message: 'Required project config files are missing.',
      details: <String, Object?>{'missing': missing},
    );
  }

  CliCheckResult _operatingSystemCheck() {
    if (!runtime.isSupported) {
      return CliCheckResult(
        id: 'os-capability',
        status: CliStatus.blocked,
        message: 'This operating system is not supported.',
        details: <String, Object?>{'os': runtime.operatingSystem},
      );
    }
    return CliCheckResult(
      id: 'os-capability',
      status: CliStatus.pass,
      message: 'Operating system is supported.',
      details: <String, Object?>{
        'os': runtime.operatingSystem,
        'version': runtime.operatingSystemVersion,
      },
    );
  }

  String _path(String child) => _joinParts(<String>[repositoryRoot, child]);

  String _pathParts(List<String> children) =>
      _joinParts(<String>[repositoryRoot, ...children]);

  String _pathPortable(String path) =>
      _pathParts(path.split('/').where((part) => part.isNotEmpty).toList());
}

String _joinParts(List<String> parts) {
  var result = parts.first;
  for (final part in parts.skip(1)) {
    if (result.endsWith('/') || result.endsWith('\\')) {
      result = '$result$part';
    } else {
      result = '$result${Platform.pathSeparator}$part';
    }
  }
  return result;
}

String _firstLine(String value) {
  for (final line in const LineSplitter().convert(value.trim())) {
    if (line.trim().isNotEmpty) return line.trim();
  }
  return 'unknown';
}

int? _majorVersion(String version) {
  final match = RegExp(r'^[^0-9]*(\d+)').firstMatch(version.trim());
  return match == null ? null : int.tryParse(match.group(1)!);
}
