import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/mosigame_cli/command_runner.dart';
import '../../tool/mosigame_cli/doctor.dart';
import '../../tool/mosigame_cli/process_runner.dart';
import '../../tool/mosigame_cli/result.dart';
import 'test_support.dart';

void main() {
  const runtime = RuntimeEnvironment(
    operatingSystem: 'windows',
    operatingSystemVersion: 'test',
    dartVersion: '3.12.2',
  );

  test('runs doctor and emits human-readable output', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final code = await runMosigameCli(
      const <String>['doctor'],
      processRunner: healthyProcessRunner(),
      fileSystem: healthyFileSystem(),
      runtime: runtime,
      workingDirectory: testRepositoryRoot,
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(code, 0);
    expect(stdoutLines.join('\n'), contains('doctor: PASS'));
    expect(stderrLines, isEmpty);
  });

  test('--json writes one machine-readable document to stdout', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final code = await runMosigameCli(
      const <String>['doctor', '--json'],
      processRunner: healthyProcessRunner(),
      fileSystem: healthyFileSystem(),
      runtime: runtime,
      workingDirectory: testRepositoryRoot,
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(code, 0);
    expect(stdoutLines, hasLength(1));
    final json = jsonDecode(stdoutLines.single) as Map<String, Object?>;
    expect(json['schemaVersion'], 1);
    expect(json['command'], 'doctor');
    expect(json['status'], 'PASS');
    expect(json['checks'], isA<List<Object?>>());
    expect(json['summary'], isA<Map<String, Object?>>());
    expect(stderrLines, isEmpty);
  });

  test(
    'invalid command is human-readable and exits 2 without a stack trace',
    () async {
      final stdoutLines = <String>[];
      final stderrLines = <String>[];

      final code = await runMosigameCli(
        const <String>['unknown-command'],
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(code, 2);
      expect(stdoutLines, isEmpty);
      expect(stderrLines.join('\n'), contains('INVALID'));
      expect(stderrLines.join('\n'), contains('Unknown command.'));
      expect(stderrLines.join('\n'), isNot(contains('#0')));
    },
  );

  test('doctor exits 3 when an environment requirement is BLOCKED', () async {
    final fileSystem = healthyFileSystem();
    fileSystem.directories.remove(
      joinTestPath(testRepositoryRoot, 'functions', 'node_modules'),
    );
    final stdoutLines = <String>[];

    final code = await runMosigameCli(
      const <String>['doctor'],
      processRunner: healthyProcessRunner(),
      fileSystem: fileSystem,
      runtime: runtime,
      workingDirectory: testRepositoryRoot,
      stdoutWriter: stdoutLines.add,
    );

    expect(code, 3);
    expect(stdoutLines.join('\n'), contains('BLOCKED'));
  });

  test('invalid JSON invocation keeps stdout machine-readable', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final code = await runMosigameCli(
      const <String>['unknown-command', '--json'],
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(code, 2);
    expect(stdoutLines, hasLength(1));
    expect(
      (jsonDecode(stdoutLines.single) as Map<String, Object?>)['status'],
      'INVALID',
    );
    expect(stderrLines, isEmpty);
  });

  test(
    'unexpected internal errors exit 4 without exposing a stack trace',
    () async {
      final fileSystem = healthyFileSystem()..throwOnAccess = true;
      final stdoutLines = <String>[];
      final stderrLines = <String>[];

      final code = await runMosigameCli(
        const <String>['doctor'],
        processRunner: healthyProcessRunner(),
        fileSystem: fileSystem,
        runtime: runtime,
        workingDirectory: testRepositoryRoot,
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(code, 4);
      expect(stdoutLines, isEmpty);
      expect(stderrLines.join('\n'), contains('internal error'));
      expect(stderrLines.join('\n'), isNot(contains('#0')));
    },
  );

  test(
    'dispatches validate --full and emits human summary to stdout',
    () async {
      final stdoutLines = <String>[];
      final stderrLines = <String>[];
      final runner = FakeProcessRunner()
        ..handler = (_) => const ProcessExecution(
          exitCode: 0,
          stdoutText: 'process output',
          stderrText: '',
          timedOut: false,
        );

      final code = await runMosigameCli(
        const <String>['validate', '--full'],
        processRunner: runner,
        workingDirectory: testRepositoryRoot,
        repositorySnapshotter: FakeRepositorySnapshotter(),
        doctorCheckRunner: () async => healthyDoctorChecks,
        stdoutWriter: stdoutLines.add,
        stderrWriter: stderrLines.add,
      );

      expect(code, 0);
      expect(stdoutLines.join('\n'), contains('validate: PASS'));
      expect(stdoutLines.join('\n'), contains('working-tree-mutation'));
      expect(stderrLines.join('\n'), contains('Running dart-format'));
      expect(stderrLines.join('\n'), contains('process output'));
    },
  );

  test('validate JSON keeps stdout to one machine-readable document', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];
    final runner = FakeProcessRunner()
      ..handler = (_) => const ProcessExecution(
        exitCode: 0,
        stdoutText: 'diagnostic output',
        stderrText: '',
        timedOut: false,
      );

    final code = await runMosigameCli(
      const <String>['--json', 'validate', '--full'],
      processRunner: runner,
      workingDirectory: testRepositoryRoot,
      repositorySnapshotter: FakeRepositorySnapshotter(),
      doctorCheckRunner: () async => healthyDoctorChecks,
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(code, 0);
    expect(stdoutLines, hasLength(1));
    final json = jsonDecode(stdoutLines.single) as Map<String, Object?>;
    expect(json['command'], 'validate');
    expect(json['status'], 'PASS');
    expect(json.containsKey('steps'), isTrue);
    expect(json.containsKey('checks'), isFalse);
    expect(stdoutLines.single, isNot(contains('diagnostic output')));
    expect(stderrLines.join('\n'), contains('diagnostic output'));
  });

  test('invalid validate invocation uses steps and exits 2', () async {
    final stdoutLines = <String>[];
    final stderrLines = <String>[];

    final code = await runMosigameCli(
      const <String>['validate', '--changed', '--json'],
      stdoutWriter: stdoutLines.add,
      stderrWriter: stderrLines.add,
    );

    expect(code, CliExitCode.invalid);
    expect(stdoutLines, hasLength(1));
    final json = jsonDecode(stdoutLines.single) as Map<String, Object?>;
    expect(json['command'], 'validate');
    expect(json['status'], 'INVALID');
    expect(json['steps'], isA<List<Object?>>());
    expect(json.containsKey('checks'), isFalse);
    expect(stderrLines, isEmpty);
  });
}
