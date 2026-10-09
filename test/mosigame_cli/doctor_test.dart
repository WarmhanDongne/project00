import 'package:flutter_test/flutter_test.dart';

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

  test('checks the complete Step 1 doctor surface', () async {
    final fileSystem = healthyFileSystem();
    final processRunner = healthyProcessRunner();
    final doctor = Doctor(
      repositoryRoot: testRepositoryRoot,
      processRunner: processRunner,
      fileSystem: fileSystem,
      runtime: runtime,
    );

    final checks = await doctor.runChecks();

    expect(checks.map((check) => check.id), <String>[
      'repository-root',
      'git',
      'dart',
      'flutter',
      'node',
      'npm',
      'functions-dependencies',
      'project-config',
      'os-capability',
    ]);
    expect(checks.every((check) => check.status == CliStatus.pass), isTrue);
    expect(processRunner.invocations, hasLength(3));
    expect(
      processRunner.invocations.every(
        (invocation) => invocation.workingDirectory == testRepositoryRoot,
      ),
      isTrue,
    );
  });

  test('reports dependency and version gaps as BLOCKED', () async {
    final fileSystem = healthyFileSystem();
    fileSystem.directories.remove(
      joinTestPath(testRepositoryRoot, 'functions', 'node_modules'),
    );
    final processRunner = healthyProcessRunner();
    processRunner.responses['node'] = const ProcessExecution(
      exitCode: 0,
      stdoutText: 'v20.0.0',
      stderrText: '',
      timedOut: false,
    );

    final checks = await Doctor(
      repositoryRoot: testRepositoryRoot,
      processRunner: processRunner,
      fileSystem: fileSystem,
      runtime: runtime,
    ).runChecks();

    expect(
      checks.singleWhere((check) => check.id == 'node').status,
      CliStatus.blocked,
    );
    expect(
      checks
          .singleWhere((check) => check.id == 'functions-dependencies')
          .status,
      CliStatus.blocked,
    );
    expect(aggregateStatus(checks), CliStatus.blocked);
  });

  test('reports missing commands and unsupported OS as BLOCKED', () async {
    final fileSystem = healthyFileSystem();
    fileSystem.executables.remove('git');
    final checks = await Doctor(
      repositoryRoot: testRepositoryRoot,
      processRunner: healthyProcessRunner(),
      fileSystem: fileSystem,
      runtime: const RuntimeEnvironment(
        operatingSystem: 'unknown',
        operatingSystemVersion: 'test',
        dartVersion: '3.12.2',
      ),
    ).runChecks();

    expect(
      checks.singleWhere((check) => check.id == 'git').status,
      CliStatus.blocked,
    );
    expect(
      checks.singleWhere((check) => check.id == 'os-capability').status,
      CliStatus.blocked,
    );
  });
}
