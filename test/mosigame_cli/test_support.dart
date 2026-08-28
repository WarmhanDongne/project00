import 'dart:io';

import '../../tool/mosigame_cli/doctor.dart';
import '../../tool/mosigame_cli/process_runner.dart';
import '../../tool/mosigame_cli/repository_snapshot.dart';
import '../../tool/mosigame_cli/result.dart';

String joinTestPath(String first, [String? second, String? third]) {
  var result = first;
  for (final part in <String?>[second, third]) {
    if (part == null) continue;
    result = '$result${Platform.pathSeparator}$part';
  }
  return result;
}

String get testRepositoryRoot => Platform.isWindows ? r'C:\repo' : '/repo';

String get testFlutterLauncher =>
    Platform.isWindows ? r'C:\flutter\bin\flutter.bat' : '/flutter/bin/flutter';

final class FakeFileSystemProbe implements FileSystemProbe {
  final Set<String> files = <String>{};
  final Set<String> directories = <String>{};
  final Map<String, String> contents = <String, String>{};
  final Map<String, String> executables = <String, String>{};
  bool throwOnAccess = false;

  @override
  bool directoryExists(String path) {
    _checkAccess();
    return directories.contains(path);
  }

  @override
  bool fileExists(String path) {
    _checkAccess();
    return files.contains(path);
  }

  @override
  String? findExecutable(String name) {
    _checkAccess();
    return executables[name];
  }

  @override
  String? readTextFile(String path) {
    _checkAccess();
    return contents[path];
  }

  void addFile(String path, [String contentsValue = '']) {
    files.add(path);
    contents[path] = contentsValue;
  }

  void _checkAccess() {
    if (throwOnAccess) throw StateError('Synthetic file-system failure.');
  }
}

final class RecordedProcess {
  const RecordedProcess({
    required this.executable,
    required this.arguments,
    required this.workingDirectory,
    required this.timeout,
  });

  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
  final Duration timeout;
}

typedef FakeProcessHandler =
    ProcessExecution Function(RecordedProcess invocation);

final class FakeProcessRunner implements ProcessRunner {
  final Map<String, ProcessExecution> responses = <String, ProcessExecution>{};
  final Map<String, ProcessExecution> exactResponses =
      <String, ProcessExecution>{};
  final List<RecordedProcess> invocations = <RecordedProcess>[];
  FakeProcessHandler? handler;

  @override
  Future<ProcessExecution> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 30),
    Duration terminationGrace = defaultTerminationGrace,
    int maxCapturedCharacters = defaultProcessCaptureLimitCharacters,
    ProcessOutputCallback? onStdout,
    ProcessOutputCallback? onStderr,
  }) async {
    final invocation = RecordedProcess(
      executable: executable,
      arguments: List<String>.unmodifiable(arguments),
      workingDirectory: workingDirectory,
      timeout: timeout,
    );
    invocations.add(invocation);
    final response =
        handler?.call(invocation) ??
        exactResponses[_invocationKey(executable, arguments)] ??
        responses[_commandName(executable)] ??
        const ProcessExecution(
          exitCode: 127,
          stdoutText: '',
          stderrText: 'not found',
          timedOut: false,
        );
    if (response.stdoutText.isNotEmpty) {
      onStdout?.call(response.stdoutText);
    }
    if (response.stderrText.isNotEmpty) {
      onStderr?.call(response.stderrText);
    }
    return response;
  }
}

final class FakeRepositorySnapshotter implements RepositorySnapshotter {
  FakeRepositorySnapshotter([List<Object>? outcomes])
    : outcomes =
          outcomes ??
          <Object>[
            const RepositorySnapshot('same'),
            const RepositorySnapshot('same'),
          ];

  final List<Object> outcomes;
  int captureCount = 0;

  @override
  Future<RepositorySnapshot> capture() async {
    final outcome = outcomes[captureCount++];
    if (outcome is RepositorySnapshot) return outcome;
    throw outcome;
  }
}

const healthyDoctorChecks = <CliCheckResult>[
  CliCheckResult(
    id: 'repository-root',
    status: CliStatus.pass,
    message: 'Repository root detected.',
  ),
  CliCheckResult(
    id: 'git',
    status: CliStatus.pass,
    message: 'Git is available.',
  ),
  CliCheckResult(
    id: 'dart',
    status: CliStatus.pass,
    message: 'Dart is available.',
  ),
  CliCheckResult(
    id: 'flutter',
    status: CliStatus.pass,
    message: 'Flutter is available.',
  ),
  CliCheckResult(
    id: 'node',
    status: CliStatus.pass,
    message: 'Node.js is available.',
  ),
  CliCheckResult(
    id: 'npm',
    status: CliStatus.pass,
    message: 'npm is available.',
  ),
  CliCheckResult(
    id: 'functions-dependencies',
    status: CliStatus.pass,
    message: 'Functions dependencies are present.',
  ),
  CliCheckResult(
    id: 'project-config',
    status: CliStatus.pass,
    message: 'Required config is present.',
  ),
  CliCheckResult(
    id: 'os-capability',
    status: CliStatus.pass,
    message: 'Operating system is supported.',
  ),
];

FakeFileSystemProbe healthyFileSystem() {
  final fileSystem = FakeFileSystemProbe();
  fileSystem.directories.addAll(<String>{
    joinTestPath(testRepositoryRoot, '.git'),
    joinTestPath(testRepositoryRoot, 'functions', 'node_modules'),
  });
  fileSystem.addFile(joinTestPath(testRepositoryRoot, 'pubspec.yaml'));
  fileSystem.addFile(joinTestPath(testRepositoryRoot, 'firebase.json'));
  fileSystem.addFile(joinTestPath(testRepositoryRoot, '.nvmrc'), '22\n');
  fileSystem.addFile(
    joinTestPath(testRepositoryRoot, 'functions', 'package.json'),
  );
  fileSystem.addFile(
    joinTestPath(testRepositoryRoot, 'functions', 'package-lock.json'),
  );
  fileSystem.executables.addAll(<String, String>{
    'git': joinTestPath(Platform.isWindows ? r'C:\tools' : '/tools', 'git.exe'),
    'flutter': testFlutterLauncher,
    'node': joinTestPath(
      Platform.isWindows ? r'C:\tools' : '/tools',
      'node.exe',
    ),
    'npm': joinTestPath(
      Platform.isWindows ? r'C:\tools' : '/tools',
      Platform.isWindows ? 'npm.cmd' : 'npm',
    ),
  });
  final flutterRoot = File(testFlutterLauncher).parent.parent.path;
  fileSystem.addFile(
    joinTestPath(
      joinTestPath(joinTestPath(flutterRoot, 'bin'), 'cache'),
      'flutter.version.json',
    ),
    '{"frameworkVersion":"3.44.8","channel":"stable"}',
  );
  return fileSystem;
}

FakeProcessRunner healthyProcessRunner() {
  final runner = FakeProcessRunner();
  runner.responses.addAll(<String, ProcessExecution>{
    'git': const ProcessExecution(
      exitCode: 0,
      stdoutText: 'git version 2.50.0',
      stderrText: '',
      timedOut: false,
    ),
    'node': const ProcessExecution(
      exitCode: 0,
      stdoutText: 'v22.18.0',
      stderrText: '',
      timedOut: false,
    ),
    'npm': const ProcessExecution(
      exitCode: 0,
      stdoutText: '10.9.3',
      stderrText: '',
      timedOut: false,
    ),
  });
  return runner;
}

String _commandName(String executable) {
  final name = executable.split(RegExp(r'[\\/]')).last.toLowerCase();
  return name.replaceFirst(RegExp(r'\.(exe|cmd|bat|com)$'), '');
}

String processInvocationKey(String executable, List<String> arguments) =>
    _invocationKey(executable, arguments);

String _invocationKey(String executable, List<String> arguments) =>
    '${_commandName(executable)}\u0000${arguments.join('\u0000')}';
