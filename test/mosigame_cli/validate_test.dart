import 'package:flutter_test/flutter_test.dart';

import '../../tool/mosigame_cli/process_runner.dart';
import '../../tool/mosigame_cli/repository_snapshot.dart';
import '../../tool/mosigame_cli/result.dart';
import '../../tool/mosigame_cli/validate.dart';
import 'test_support.dart';

void main() {
  test('runs the frozen full pipeline in order with exact arguments', () async {
    final runner = _passingRunner();
    final snapshotter = FakeRepositorySnapshotter();

    final outcome = await _validator(
      runner: runner,
      snapshotter: snapshotter,
    ).run();

    expect(outcome.exitCode, CliExitCode.success);
    expect(outcome.status, CliStatus.pass);
    expect(outcome.steps.map((step) => step.id), <String>[
      'preflight',
      'dart-format',
      'flutter-analyze',
      'flutter-test',
      'functions-lint',
      'functions-test',
      'working-tree-mutation',
    ]);
    expect(snapshotter.captureCount, 2);
    expect(runner.invocations, hasLength(5));
    _expectInvocation(runner.invocations[0], 'dart', <String>[
      'format',
      '--output=none',
      '--set-exit-if-changed',
      'bin',
      'lib',
      'test',
      'tool/mosigame_cli',
    ], dartFormatTimeout);
    _expectInvocation(runner.invocations[1], 'flutter', <String>[
      'analyze',
      '--no-pub',
    ], flutterAnalyzeTimeout);
    _expectInvocation(runner.invocations[2], 'flutter', <String>[
      'test',
      '--no-pub',
    ], flutterTestTimeout);
    _expectInvocation(runner.invocations[3], 'npm', <String>[
      '--prefix',
      'functions',
      'run',
      'lint',
    ], functionsLintTimeout);
    _expectInvocation(runner.invocations[4], 'npm', <String>[
      '--prefix',
      'functions',
      'test',
    ], functionsTestTimeout);
  });

  test('runs all steps after a validation failure', () async {
    final runner = _passingRunner();
    runner.handler = (invocation) {
      if (invocation.executable == 'flutter' &&
          invocation.arguments.first == 'analyze') {
        return const ProcessExecution(
          exitCode: 1,
          stdoutText: '',
          stderrText: 'analysis failure',
          timedOut: false,
        );
      }
      return _success;
    };

    final outcome = await _validator(runner: runner).run();

    expect(outcome.exitCode, CliExitCode.failure);
    expect(runner.invocations, hasLength(5));
    expect(
      outcome.steps.singleWhere((step) => step.id == 'flutter-analyze').status,
      CliStatus.fail,
    );
    expect(outcome.steps.last.status, CliStatus.pass);
  });

  test('timeout is FAIL with null process code and continues safely', () async {
    final runner = _passingRunner();
    runner.handler = (invocation) {
      if (invocation.executable == 'flutter' &&
          invocation.arguments.first == 'test') {
        return const ProcessExecution(
          exitCode: -1,
          stdoutText: '',
          stderrText: '',
          timedOut: true,
        );
      }
      return _success;
    };

    final outcome = await _validator(runner: runner).run();
    final step = outcome.steps.singleWhere(
      (candidate) => candidate.id == 'flutter-test',
    );

    expect(outcome.exitCode, CliExitCode.failure);
    expect(step.status, CliStatus.fail);
    expect(step.timedOut, isTrue);
    expect(step.processExitCode, isNull);
    expect(runner.invocations, hasLength(5));
  });

  test('blocked preflight skips both snapshot and pipeline', () async {
    final runner = _passingRunner();
    final snapshotter = FakeRepositorySnapshotter();

    final outcome = await _validator(
      runner: runner,
      snapshotter: snapshotter,
      checks: const <CliCheckResult>[
        CliCheckResult(
          id: 'npm',
          status: CliStatus.blocked,
          message: 'npm is unavailable.',
        ),
      ],
    ).run();

    expect(outcome.exitCode, CliExitCode.blocked);
    expect(outcome.steps.single.id, 'preflight');
    expect(outcome.steps.single.status, CliStatus.blocked);
    expect(snapshotter.captureCount, 0);
    expect(runner.invocations, isEmpty);
  });

  test(
    'snapshot A capability failure skips the pipeline with exit 3',
    () async {
      final runner = _passingRunner();
      final snapshotter = FakeRepositorySnapshotter(<Object>[
        const SnapshotBlockedException('Git snapshot is unavailable.'),
      ]);

      final outcome = await _validator(
        runner: runner,
        snapshotter: snapshotter,
      ).run();

      expect(outcome.exitCode, CliExitCode.blocked);
      expect(outcome.steps.first.id, 'preflight');
      expect(outcome.steps.last.id, 'working-tree-mutation');
      expect(outcome.steps.last.status, CliStatus.blocked);
      expect(runner.invocations, isEmpty);
    },
  );

  test('snapshot B failure has internal-error priority', () async {
    final snapshotter = FakeRepositorySnapshotter(<Object>[
      const RepositorySnapshot('before'),
      const SnapshotBlockedException('Second snapshot failed.'),
    ]);

    final outcome = await _validator(snapshotter: snapshotter).run();

    expect(outcome.exitCode, CliExitCode.internalError);
    expect(outcome.steps.last.id, 'working-tree-mutation');
    expect(outcome.steps.last.status, CliStatus.fail);
  });

  test('detects mutation without restoring the working tree', () async {
    final snapshotter = FakeRepositorySnapshotter(<Object>[
      const RepositorySnapshot('before'),
      const RepositorySnapshot('after'),
    ]);

    final outcome = await _validator(snapshotter: snapshotter).run();

    expect(outcome.exitCode, CliExitCode.failure);
    expect(outcome.steps.last.status, CliStatus.fail);
    expect(outcome.steps.last.message, contains('changed'));
  });

  test(
    'snapshot A internal failure exits 4 without running the pipeline',
    () async {
      final runner = _passingRunner();
      final snapshotter = FakeRepositorySnapshotter(<Object>[
        const SnapshotInternalException('Synthetic snapshot bug.'),
      ]);

      final outcome = await _validator(
        runner: runner,
        snapshotter: snapshotter,
      ).run();

      expect(outcome.exitCode, CliExitCode.internalError);
      expect(runner.invocations, isEmpty);
      expect(outcome.steps.last.id, 'working-tree-mutation');
      expect(outcome.steps.last.status, CliStatus.fail);
    },
  );

  test(
    'unexpected validation exception stops safely and still snapshots B',
    () async {
      final runner = _passingRunner()..handler = (_) => throw StateError('bug');
      final snapshotter = FakeRepositorySnapshotter();

      final outcome = await _validator(
        runner: runner,
        snapshotter: snapshotter,
      ).run();

      expect(outcome.exitCode, CliExitCode.internalError);
      expect(runner.invocations, hasLength(1));
      expect(snapshotter.captureCount, 2);
      expect(outcome.steps.map((step) => step.id), <String>[
        'preflight',
        'dart-format',
        'working-tree-mutation',
      ]);
    },
  );

  test(
    'preserves multiple child exit codes while returning top-level 1',
    () async {
      final runner = _passingRunner();
      runner.handler = (invocation) {
        if (invocation.executable == 'dart') {
          return const ProcessExecution(
            exitCode: 7,
            stdoutText: '',
            stderrText: '',
            timedOut: false,
          );
        }
        if (invocation.executable == 'npm') {
          return const ProcessExecution(
            exitCode: 2,
            stdoutText: '',
            stderrText: '',
            timedOut: false,
          );
        }
        return _success;
      };

      final outcome = await _validator(runner: runner).run();

      expect(outcome.exitCode, CliExitCode.failure);
      expect(
        outcome.steps
            .where((step) => step.status == CliStatus.fail)
            .map((step) => step.processExitCode),
        <int?>[7, 2, 2],
      );
    },
  );

  test(
    'unsafe timeout cleanup stops the pipeline but attempts snapshot B',
    () async {
      final runner = _passingRunner();
      runner.handler = (_) => const ProcessExecution(
        exitCode: -1,
        stdoutText: '',
        stderrText: '',
        timedOut: true,
        terminationConfirmed: false,
      );
      final snapshotter = FakeRepositorySnapshotter();

      final outcome = await _validator(
        runner: runner,
        snapshotter: snapshotter,
      ).run();

      expect(outcome.exitCode, CliExitCode.internalError);
      expect(runner.invocations, hasLength(1));
      expect(snapshotter.captureCount, 2);
      expect(outcome.steps.last.id, 'working-tree-mutation');
    },
  );

  test(
    'streams child output to the progress writer and omits raw output from steps',
    () async {
      final progress = <String>[];
      final runner = _passingRunner();
      runner.handler = (_) => const ProcessExecution(
        exitCode: 0,
        stdoutText: 'child stdout',
        stderrText: 'child stderr',
        timedOut: false,
        stdoutTruncated: true,
      );

      final outcome = await FullValidator(
        repositoryRoot: testRepositoryRoot,
        processRunner: runner,
        snapshotter: FakeRepositorySnapshotter(),
        runDoctorChecks: () async => healthyDoctorChecks,
        progressWriter: progress.add,
      ).run();

      expect(progress, contains('child stdout'));
      expect(progress, contains('child stderr'));
      final step = outcome.steps.singleWhere(
        (candidate) => candidate.id == 'dart-format',
      );
      expect(step.details['stdoutTruncated'], isTrue);
      expect(step.toJson().toString(), isNot(contains('child stdout')));
    },
  );
}

const _success = ProcessExecution(
  exitCode: 0,
  stdoutText: '',
  stderrText: '',
  timedOut: false,
);

FakeProcessRunner _passingRunner() =>
    FakeProcessRunner()..handler = (_) => _success;

FullValidator _validator({
  FakeProcessRunner? runner,
  FakeRepositorySnapshotter? snapshotter,
  List<CliCheckResult> checks = healthyDoctorChecks,
}) => FullValidator(
  repositoryRoot: testRepositoryRoot,
  processRunner: runner ?? _passingRunner(),
  snapshotter: snapshotter ?? FakeRepositorySnapshotter(),
  runDoctorChecks: () async => checks,
  progressWriter: (_) {},
);

void _expectInvocation(
  RecordedProcess invocation,
  String executable,
  List<String> arguments,
  Duration timeout,
) {
  expect(invocation.executable, executable);
  expect(invocation.arguments, arguments);
  expect(invocation.workingDirectory, testRepositoryRoot);
  expect(invocation.timeout, timeout);
}
