import 'package:flutter_test/flutter_test.dart';

import '../../tool/mosigame_cli/process_runner.dart';
import '../../tool/mosigame_cli/repository_snapshot.dart';
import '../../tool/mosigame_cli/result.dart';
import '../../tool/mosigame_cli/test_suites.dart';
import 'test_support.dart';

void main() {
  group('frozen manifests', () {
    test('session has the exact approved file order', () {
      expect(sessionTestSuite.flutterTests, const <String>[
        'test/controller_presence_test.dart',
        'test/controller_reconnect_guard_test.dart',
        'test/controller_room_lifecycle_test.dart',
        'test/game_reconnect_screen_test.dart',
        'test/restorable_player_session_test.dart',
        'test/room_join_feedback_test.dart',
        'test/room_leave_intent_test.dart',
        'test/room_leave_state_test.dart',
        'test/room_restore_to_waiting_test.dart',
        'test/session_return_prompt_test.dart',
      ]);
      expect(sessionTestSuite.functionsTests, const <String>[
        'functions/test/controller-presence-timer.test.mjs',
        'functions/test/room-lifecycle.test.mjs',
      ]);
    });

    test('auth has the exact approved file order', () {
      expect(authTestSuite.flutterTests, const <String>[
        'test/auth/auth_gate_email_link_test.dart',
        'test/auth/auth_gate_rotation_test.dart',
        'test/auth/auth_gate_stuck_loading_test.dart',
        'test/auth/email_link_error_message_test.dart',
        'test/auth/google_login_button_test.dart',
        'test/auth/onboarding_parity_test.dart',
        'test/auth/register_loading_test.dart',
        'test/auth/tablet_auth_parity_test.dart',
        'test/platform_auth_shell_test.dart',
        'test/social_login_button_test.dart',
      ]);
      expect(authTestSuite.functionsTests, const <String>[
        'functions/test/auth-delete-account.test.mjs',
        'functions/test/auth-onboarding.test.mjs',
      ]);
    });

    test('registry supports only exact lowercase pilot names', () {
      expect(testSuiteByName('session'), same(sessionTestSuite));
      expect(testSuiteByName('auth'), same(authTestSuite));
      expect(testSuiteByName('Session'), isNull);
      expect(testSuiteByName('mafia'), isNull);
    });
  });

  group('manifest validation', () {
    test(
      'missing file is INVALID before preflight, snapshot, or process',
      () async {
        final runner = _passingRunner();
        final snapshotter = FakeRepositorySnapshotter();
        var preflightCalls = 0;

        final outcome = await _suiteRunner(
          runner: runner,
          snapshotter: snapshotter,
          fileSystem: healthyFileSystem(),
          doctorChecks: () async {
            preflightCalls++;
            return healthyDoctorChecks;
          },
        ).run();

        expect(outcome.status, CliStatus.invalid);
        expect(outcome.exitCode, CliExitCode.invalid);
        expect(outcome.steps.single.id, 'manifest');
        expect(outcome.steps.single.status, CliStatus.invalid);
        expect(preflightCalls, 0);
        expect(snapshotter.captureCount, 0);
        expect(runner.invocations, isEmpty);
      },
    );

    test('duplicate path is INVALID', () async {
      const suite = TestSuiteDefinition(
        name: 'session',
        flutterTests: <String>['test/a_test.dart', 'test/a_test.dart'],
        functionsTests: <String>['functions/test/a.test.mjs'],
      );

      final outcome = await _suiteRunner(suite: suite).run();

      expect(outcome.exitCode, CliExitCode.invalid);
      expect(outcome.steps.single.message, contains('duplicated'));
    });

    test('absolute, traversal, and glob paths are INVALID', () async {
      for (final path in <String>[
        '/absolute/a_test.dart',
        r'C:\absolute\a_test.dart',
        '../a_test.dart',
        'test/*_test.dart',
      ]) {
        final suite = TestSuiteDefinition(
          name: 'session',
          flutterTests: <String>[path],
          functionsTests: const <String>['functions/test/a.test.mjs'],
        );

        final outcome = await _suiteRunner(suite: suite).run();

        expect(
          outcome.exitCode,
          CliExitCode.invalid,
          reason: 'Expected invalid manifest path: $path',
        );
      }
    });

    test('unknown, empty, and wrong-extension manifests are INVALID', () async {
      for (final suite in const <TestSuiteDefinition>[
        TestSuiteDefinition(
          name: 'unknown',
          flutterTests: <String>['test/a_test.dart'],
          functionsTests: <String>['functions/test/a.test.mjs'],
        ),
        TestSuiteDefinition(
          name: 'session',
          flutterTests: <String>[],
          functionsTests: <String>['functions/test/a.test.mjs'],
        ),
        TestSuiteDefinition(
          name: 'session',
          flutterTests: <String>['test/a.txt'],
          functionsTests: <String>['functions/test/a.dart'],
        ),
      ]) {
        final outcome = await _suiteRunner(suite: suite).run();
        expect(outcome.exitCode, CliExitCode.invalid);
      }
    });
  });

  group('pipeline', () {
    test(
      'runs manifest, preflight, selected tests, and mutation in order',
      () async {
        final runner = _passingRunner();
        final snapshotter = FakeRepositorySnapshotter();

        final outcome = await _suiteRunner(
          runner: runner,
          snapshotter: snapshotter,
        ).run();

        expect(outcome.exitCode, CliExitCode.success);
        expect(outcome.steps.map((step) => step.id), <String>[
          'manifest',
          'preflight',
          'flutter-test',
          'functions-test',
          'working-tree-mutation',
        ]);
        expect(snapshotter.captureCount, 2);
        expect(runner.invocations, hasLength(3));
        _expectInvocation(runner.invocations[0], 'flutter', <String>[
          'test',
          '--no-pub',
          ...sessionTestSuite.flutterTests,
        ], selectedFlutterTestTimeout);
        _expectInvocation(runner.invocations[1], 'npm', const <String>[
          '--prefix',
          'functions',
          'run',
          'build',
        ], functionsBuildTimeout);
        _expectInvocation(runner.invocations[2], 'node', <String>[
          '--test',
          ...sessionTestSuite.functionsTests,
        ], selectedFunctionsTestTimeout);
      },
    );

    test('Flutter failure preserves code and still runs Functions', () async {
      final runner = _passingRunner()
        ..handler = (invocation) => invocation.executable == 'flutter'
            ? const ProcessExecution(
                exitCode: 5,
                stdoutText: '',
                stderrText: 'flutter failed',
                timedOut: false,
              )
            : _success;

      final outcome = await _suiteRunner(runner: runner).run();

      expect(outcome.exitCode, CliExitCode.failure);
      expect(runner.invocations, hasLength(3));
      expect(
        outcome.steps
            .singleWhere((step) => step.id == 'flutter-test')
            .processExitCode,
        5,
      );
      expect(outcome.steps.last.id, 'working-tree-mutation');
    });

    test(
      'Functions build failure skips stale Node tests and still snapshots',
      () async {
        final runner = _passingRunner()
          ..handler = (invocation) => invocation.executable == 'npm'
              ? const ProcessExecution(
                  exitCode: 2,
                  stdoutText: '',
                  stderrText: 'build failed',
                  timedOut: false,
                )
              : _success;
        final snapshotter = FakeRepositorySnapshotter();

        final outcome = await _suiteRunner(
          runner: runner,
          snapshotter: snapshotter,
        ).run();
        final functions = outcome.steps.singleWhere(
          (step) => step.id == 'functions-test',
        );

        expect(outcome.exitCode, CliExitCode.failure);
        expect(runner.invocations, hasLength(2));
        expect(
          runner.invocations.any((call) => call.executable == 'node'),
          isFalse,
        );
        expect(functions.processExitCode, 2);
        expect(functions.details['failedPhase'], 'build');
        expect(snapshotter.captureCount, 2);
      },
    );

    test(
      'Functions test failure preserves code and mutation guard runs',
      () async {
        final runner = _passingRunner()
          ..handler = (invocation) => invocation.executable == 'node'
              ? const ProcessExecution(
                  exitCode: 7,
                  stdoutText: '',
                  stderrText: 'node tests failed',
                  timedOut: false,
                )
              : _success;

        final outcome = await _suiteRunner(runner: runner).run();
        final functions = outcome.steps.singleWhere(
          (step) => step.id == 'functions-test',
        );

        expect(outcome.exitCode, CliExitCode.failure);
        expect(functions.processExitCode, 7);
        expect(functions.details['failedPhase'], 'test');
        expect(outcome.steps.last.id, 'working-tree-mutation');
      },
    );

    test('Flutter timeout is FAIL and continues after safe cleanup', () async {
      final runner = _passingRunner()
        ..handler = (invocation) => invocation.executable == 'flutter'
            ? const ProcessExecution(
                exitCode: -1,
                stdoutText: '',
                stderrText: '',
                timedOut: true,
              )
            : _success;

      final outcome = await _suiteRunner(runner: runner).run();
      final flutter = outcome.steps.singleWhere(
        (step) => step.id == 'flutter-test',
      );

      expect(outcome.exitCode, CliExitCode.failure);
      expect(flutter.timedOut, isTrue);
      expect(flutter.processExitCode, isNull);
      expect(runner.invocations, hasLength(3));
    });

    test(
      'unsafe timeout cleanup stops processes with internal exit 4',
      () async {
        final runner = _passingRunner()
          ..handler = (_) => const ProcessExecution(
            exitCode: -1,
            stdoutText: '',
            stderrText: '',
            timedOut: true,
            terminationConfirmed: false,
          );
        final snapshotter = FakeRepositorySnapshotter();

        final outcome = await _suiteRunner(
          runner: runner,
          snapshotter: snapshotter,
        ).run();

        expect(outcome.exitCode, CliExitCode.internalError);
        expect(runner.invocations, hasLength(1));
        expect(snapshotter.captureCount, 2);
        expect(outcome.steps.last.id, 'working-tree-mutation');
      },
    );

    test('unexpected process error exits 4 and still snapshots B', () async {
      final runner = _passingRunner()
        ..handler = (_) => throw StateError('synthetic runner bug');
      final snapshotter = FakeRepositorySnapshotter();

      final outcome = await _suiteRunner(
        runner: runner,
        snapshotter: snapshotter,
      ).run();

      expect(outcome.exitCode, CliExitCode.internalError);
      expect(runner.invocations, hasLength(1));
      expect(snapshotter.captureCount, 2);
    });

    test('blocked preflight skips snapshots and selected tests', () async {
      final runner = _passingRunner();
      final snapshotter = FakeRepositorySnapshotter();

      final outcome = await _suiteRunner(
        runner: runner,
        snapshotter: snapshotter,
        doctorChecks: () async => const <CliCheckResult>[
          CliCheckResult(
            id: 'npm',
            status: CliStatus.blocked,
            message: 'npm is unavailable.',
          ),
        ],
      ).run();

      expect(outcome.exitCode, CliExitCode.blocked);
      expect(snapshotter.captureCount, 0);
      expect(runner.invocations, isEmpty);
    });

    test('snapshot A capability failure is BLOCKED', () async {
      final runner = _passingRunner();
      final snapshotter = FakeRepositorySnapshotter(<Object>[
        const SnapshotBlockedException('Git snapshot unavailable.'),
      ]);

      final outcome = await _suiteRunner(
        runner: runner,
        snapshotter: snapshotter,
      ).run();

      expect(outcome.exitCode, CliExitCode.blocked);
      expect(runner.invocations, isEmpty);
      expect(outcome.steps.last.status, CliStatus.blocked);
    });

    test('snapshot A internal failure exits 4', () async {
      final runner = _passingRunner();
      final snapshotter = FakeRepositorySnapshotter(<Object>[
        const SnapshotInternalException('Synthetic snapshot bug.'),
      ]);

      final outcome = await _suiteRunner(
        runner: runner,
        snapshotter: snapshotter,
      ).run();

      expect(outcome.exitCode, CliExitCode.internalError);
      expect(runner.invocations, isEmpty);
    });

    test('snapshot B failure has internal-error priority', () async {
      final snapshotter = FakeRepositorySnapshotter(<Object>[
        const RepositorySnapshot('before'),
        const SnapshotBlockedException('Second snapshot failed.'),
      ]);

      final outcome = await _suiteRunner(snapshotter: snapshotter).run();

      expect(outcome.exitCode, CliExitCode.internalError);
      expect(outcome.steps.last.id, 'working-tree-mutation');
      expect(outcome.steps.last.status, CliStatus.fail);
    });

    test('mutation is FAIL without automatic restoration', () async {
      final snapshotter = FakeRepositorySnapshotter(<Object>[
        const RepositorySnapshot('before'),
        const RepositorySnapshot('after'),
      ]);

      final outcome = await _suiteRunner(snapshotter: snapshotter).run();

      expect(outcome.exitCode, CliExitCode.failure);
      expect(outcome.steps.last.status, CliStatus.fail);
      expect(outcome.steps.last.message, contains('changed'));
    });

    test(
      'raw process output is streamed but omitted from result JSON',
      () async {
        final progress = <String>[];
        final runner = _passingRunner()
          ..handler = (_) => const ProcessExecution(
            exitCode: 0,
            stdoutText: 'child stdout',
            stderrText: 'child stderr',
            timedOut: false,
            stdoutTruncated: true,
          );

        final outcome = await _suiteRunner(
          runner: runner,
          progress: progress,
        ).run();

        expect(progress, contains('child stdout'));
        expect(progress, contains('child stderr'));
        expect(outcome.steps.toString(), isNot(contains('child stdout')));
        expect(
          outcome.steps
              .singleWhere((step) => step.id == 'flutter-test')
              .details,
          containsPair('stdoutTruncated', true),
        );
      },
    );
  });
}

const _success = ProcessExecution(
  exitCode: 0,
  stdoutText: '',
  stderrText: '',
  timedOut: false,
);

FakeProcessRunner _passingRunner() =>
    FakeProcessRunner()..handler = (_) => _success;

TestSuiteRunner _suiteRunner({
  TestSuiteDefinition suite = sessionTestSuite,
  FakeProcessRunner? runner,
  FakeFileSystemProbe? fileSystem,
  FakeRepositorySnapshotter? snapshotter,
  Future<List<CliCheckResult>> Function()? doctorChecks,
  List<String>? progress,
}) => TestSuiteRunner(
  repositoryRoot: testRepositoryRoot,
  suite: suite,
  processRunner: runner ?? _passingRunner(),
  fileSystem: fileSystem ?? healthyFileSystemWithTestSuites(),
  snapshotter: snapshotter ?? FakeRepositorySnapshotter(),
  runDoctorChecks: doctorChecks ?? () async => healthyDoctorChecks,
  progressWriter: progress?.add ?? (_) {},
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
