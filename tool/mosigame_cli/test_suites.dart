import 'dart:io';

import 'doctor.dart';
import 'process_runner.dart';
import 'repository_snapshot.dart';
import 'result.dart';
import 'validate.dart';

const selectedFlutterTestTimeout = Duration(minutes: 30);
const functionsBuildTimeout = Duration(minutes: 5);
const selectedFunctionsTestTimeout = Duration(minutes: 15);

const supportedTestSuiteNames = <String>{'session', 'auth'};

final class TestSuiteDefinition {
  const TestSuiteDefinition({
    required this.name,
    required this.flutterTests,
    required this.functionsTests,
  });

  final String name;
  final List<String> flutterTests;
  final List<String> functionsTests;
}

const sessionTestSuite = TestSuiteDefinition(
  name: 'session',
  flutterTests: <String>[
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
  ],
  functionsTests: <String>[
    'functions/test/controller-presence-timer.test.mjs',
    'functions/test/room-lifecycle.test.mjs',
  ],
);

const authTestSuite = TestSuiteDefinition(
  name: 'auth',
  flutterTests: <String>[
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
  ],
  functionsTests: <String>[
    'functions/test/auth-delete-account.test.mjs',
    'functions/test/auth-onboarding.test.mjs',
  ],
);

TestSuiteDefinition? testSuiteByName(String name) => switch (name) {
  'session' => sessionTestSuite,
  'auth' => authTestSuite,
  _ => null,
};

final class TestSuiteOutcome {
  const TestSuiteOutcome({
    required this.steps,
    required this.status,
    required this.exitCode,
  });

  final List<ValidationStepResult> steps;
  final CliStatus status;
  final int exitCode;
}

final class TestSuiteRunner {
  TestSuiteRunner({
    required this.repositoryRoot,
    required this.suite,
    required this.processRunner,
    required this.fileSystem,
    required this.snapshotter,
    required this.runDoctorChecks,
    required this.progressWriter,
  });

  final String repositoryRoot;
  final TestSuiteDefinition suite;
  final ProcessRunner processRunner;
  final FileSystemProbe fileSystem;
  final RepositorySnapshotter snapshotter;
  final DoctorCheckRunner runDoctorChecks;
  final ProgressWriter progressWriter;

  Future<TestSuiteOutcome> run() async {
    final steps = <ValidationStepResult>[];
    final manifestResult = _validateManifest();
    steps.add(manifestResult);
    if (manifestResult.status != CliStatus.pass) {
      return TestSuiteOutcome(
        steps: steps,
        status: CliStatus.invalid,
        exitCode: CliExitCode.invalid,
      );
    }

    final preflightStopwatch = Stopwatch()..start();
    List<CliCheckResult> checks;
    try {
      progressWriter('Running preflight checks...');
      checks = await runDoctorChecks();
    } catch (_) {
      preflightStopwatch.stop();
      steps.add(
        ValidationStepResult(
          id: 'preflight',
          status: CliStatus.fail,
          message: 'Preflight failed because of a Project CLI internal error.',
          durationMs: preflightStopwatch.elapsedMilliseconds,
          processExitCode: null,
          timedOut: false,
        ),
      );
      return TestSuiteOutcome(
        steps: steps,
        status: CliStatus.fail,
        exitCode: CliExitCode.internalError,
      );
    }
    preflightStopwatch.stop();
    if (checks.any((check) => check.status != CliStatus.pass)) {
      steps.add(
        ValidationStepResult(
          id: 'preflight',
          status: CliStatus.blocked,
          message: 'Preflight requirements are not satisfied.',
          durationMs: preflightStopwatch.elapsedMilliseconds,
          processExitCode: null,
          timedOut: false,
          details: <String, Object?>{
            'checks': checks.map((check) => check.toJson()).toList(),
          },
        ),
      );
      return TestSuiteOutcome(
        steps: steps,
        status: CliStatus.blocked,
        exitCode: CliExitCode.blocked,
      );
    }
    steps.add(
      ValidationStepResult(
        id: 'preflight',
        status: CliStatus.pass,
        message: 'Preflight requirements are satisfied.',
        durationMs: preflightStopwatch.elapsedMilliseconds,
        processExitCode: null,
        timedOut: false,
        details: <String, Object?>{
          'checks': checks.map((check) => check.toJson()).toList(),
        },
      ),
    );

    final mutationStopwatch = Stopwatch()..start();
    late RepositorySnapshot beforeSnapshot;
    try {
      progressWriter('Capturing working-tree snapshot A...');
      beforeSnapshot = await snapshotter.capture();
    } on SnapshotBlockedException catch (error) {
      mutationStopwatch.stop();
      steps.add(
        ValidationStepResult(
          id: 'working-tree-mutation',
          status: CliStatus.blocked,
          message: error.message,
          durationMs: mutationStopwatch.elapsedMilliseconds,
          processExitCode: null,
          timedOut: false,
        ),
      );
      return TestSuiteOutcome(
        steps: steps,
        status: CliStatus.blocked,
        exitCode: CliExitCode.blocked,
      );
    } catch (_) {
      mutationStopwatch.stop();
      steps.add(
        ValidationStepResult(
          id: 'working-tree-mutation',
          status: CliStatus.fail,
          message: 'Working-tree snapshot A failed internally.',
          durationMs: mutationStopwatch.elapsedMilliseconds,
          processExitCode: null,
          timedOut: false,
        ),
      );
      return TestSuiteOutcome(
        steps: steps,
        status: CliStatus.fail,
        exitCode: CliExitCode.internalError,
      );
    }

    var internalError = false;
    try {
      final flutterResult = await _runFlutterTests();
      steps.add(flutterResult);
      internalError = _isUnsafeInternalError(flutterResult);
      if (!internalError) {
        final functionsResult = await _runFunctionsTests();
        steps.add(functionsResult);
        internalError = _isUnsafeInternalError(functionsResult);
      }
    } catch (_) {
      internalError = true;
    } finally {
      try {
        progressWriter('Capturing working-tree snapshot B...');
        final afterSnapshot = await snapshotter.capture();
        mutationStopwatch.stop();
        final unchanged = beforeSnapshot.hasSameStateAs(afterSnapshot);
        steps.add(
          ValidationStepResult(
            id: 'working-tree-mutation',
            status: unchanged ? CliStatus.pass : CliStatus.fail,
            message: unchanged
                ? 'Tracked and untracked working-tree state is unchanged.'
                : 'Repository state changed during test execution.',
            durationMs: mutationStopwatch.elapsedMilliseconds,
            processExitCode: null,
            timedOut: false,
          ),
        );
      } catch (_) {
        mutationStopwatch.stop();
        internalError = true;
        steps.add(
          ValidationStepResult(
            id: 'working-tree-mutation',
            status: CliStatus.fail,
            message: 'Working-tree snapshot B or comparison failed internally.',
            durationMs: mutationStopwatch.elapsedMilliseconds,
            processExitCode: null,
            timedOut: false,
          ),
        );
      }
    }

    if (internalError) {
      return TestSuiteOutcome(
        steps: steps,
        status: CliStatus.fail,
        exitCode: CliExitCode.internalError,
      );
    }
    final status = aggregateValidationStatus(steps);
    return TestSuiteOutcome(
      steps: steps,
      status: status,
      exitCode: CliExitCode.fromStatus(status),
    );
  }

  ValidationStepResult _validateManifest() {
    final stopwatch = Stopwatch()..start();
    final errors = <String>[];
    if (!supportedTestSuiteNames.contains(suite.name)) {
      errors.add('The suite name is not supported.');
    }
    if (suite.flutterTests.isEmpty || suite.functionsTests.isEmpty) {
      errors.add('The suite test lists must not be empty.');
    }

    final allPaths = <String>[...suite.flutterTests, ...suite.functionsTests];
    final normalizedPaths = <String>{};
    for (final path in allPaths) {
      final normalizedPath = path.replaceAll('\\', '/');
      if (path.trim().isEmpty || _isAbsolutePath(path)) {
        errors.add('Test paths must be repository-relative.');
      }
      if (normalizedPath.split('/').contains('..')) {
        errors.add('Test paths must not contain parent traversal.');
      }
      if (RegExp(r'[*?\[\]{}]').hasMatch(path)) {
        errors.add('Test paths must not contain glob characters.');
      }
      if (!normalizedPaths.add(normalizedPath)) {
        errors.add('Test paths must not be duplicated.');
      }
    }

    for (final path in suite.flutterTests) {
      if (!path.endsWith('.dart')) {
        errors.add('Flutter test paths must end in .dart.');
      }
    }
    for (final path in suite.functionsTests) {
      if (!path.endsWith('.test.mjs')) {
        errors.add('Functions test paths must end in .test.mjs.');
      }
    }
    if (errors.isEmpty) {
      for (final path in allPaths) {
        if (!fileSystem.fileExists(_repositoryPath(path))) {
          errors.add('A required suite test file is missing: $path');
        }
      }
    }

    stopwatch.stop();
    if (errors.isNotEmpty) {
      return ValidationStepResult(
        id: 'manifest',
        status: CliStatus.invalid,
        message: errors.first,
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: null,
        timedOut: false,
        details: <String, Object?>{'errorCount': errors.length},
      );
    }
    return ValidationStepResult(
      id: 'manifest',
      status: CliStatus.pass,
      message: 'The ${suite.name} suite manifest is valid.',
      durationMs: stopwatch.elapsedMilliseconds,
      processExitCode: null,
      timedOut: false,
      details: <String, Object?>{
        'flutterTests': suite.flutterTests.length,
        'functionsTests': suite.functionsTests.length,
      },
    );
  }

  Future<ValidationStepResult> _runFlutterTests() async {
    return _runProcessStep(
      id: 'flutter-test',
      executable: 'flutter',
      arguments: <String>['test', '--no-pub', ...suite.flutterTests],
      timeout: selectedFlutterTestTimeout,
      passedMessage: 'Selected Flutter tests passed.',
      failedMessage: 'Selected Flutter tests exited with a non-zero status.',
      timeoutMessage: 'Selected Flutter tests timed out.',
    );
  }

  Future<ValidationStepResult> _runFunctionsTests() async {
    final stopwatch = Stopwatch()..start();
    try {
      progressWriter('Running functions-test build...');
      final build = await _runProcess(
        executable: 'npm',
        arguments: const <String>['--prefix', 'functions', 'run', 'build'],
        timeout: functionsBuildTimeout,
      );
      final buildFailure = _executionFailure(
        id: 'functions-test',
        execution: build,
        stopwatch: stopwatch,
        phase: 'build',
        timeoutMessage: 'Functions build timed out.',
        failedMessage: 'Functions build exited with a non-zero status.',
      );
      if (buildFailure != null) return buildFailure;

      progressWriter('Running selected functions tests...');
      final tests = await _runProcess(
        executable: 'node',
        arguments: <String>['--test', ...suite.functionsTests],
        timeout: selectedFunctionsTestTimeout,
      );
      stopwatch.stop();
      if (!tests.terminationConfirmed) {
        return ValidationStepResult(
          id: 'functions-test',
          status: CliStatus.fail,
          message: 'Process cleanup could not be confirmed safely.',
          durationMs: stopwatch.elapsedMilliseconds,
          processExitCode: tests.timedOut ? null : tests.exitCode,
          timedOut: tests.timedOut,
          details: const <String, Object?>{
            'failedPhase': 'test',
            'cleanupConfirmed': false,
          },
        );
      }
      if (tests.timedOut) {
        return ValidationStepResult(
          id: 'functions-test',
          status: CliStatus.fail,
          message: 'Selected Functions tests timed out.',
          durationMs: stopwatch.elapsedMilliseconds,
          processExitCode: null,
          timedOut: true,
          details: <String, Object?>{
            'failedPhase': 'test',
            ..._outputDetails(tests),
          },
        );
      }
      final passed = tests.exitCode == 0;
      return ValidationStepResult(
        id: 'functions-test',
        status: passed ? CliStatus.pass : CliStatus.fail,
        message: passed
            ? 'Selected Functions tests passed.'
            : 'Selected Functions tests exited with a non-zero status.',
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: tests.exitCode,
        timedOut: false,
        details: <String, Object?>{
          if (!passed) 'failedPhase': 'test',
          ..._outputDetails(tests),
        },
      );
    } on ProcessException {
      stopwatch.stop();
      return ValidationStepResult(
        id: 'functions-test',
        status: CliStatus.blocked,
        message: 'Required Functions test executable could not be started.',
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: null,
        timedOut: false,
      );
    } on FileSystemException {
      stopwatch.stop();
      return ValidationStepResult(
        id: 'functions-test',
        status: CliStatus.blocked,
        message: 'Required Functions test capability is unavailable.',
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: null,
        timedOut: false,
      );
    } catch (_) {
      stopwatch.stop();
      return ValidationStepResult(
        id: 'functions-test',
        status: CliStatus.fail,
        message:
            'Functions test step failed because of a Project CLI internal error.',
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: null,
        timedOut: false,
        details: const <String, Object?>{'internalError': true},
      );
    }
  }

  Future<ValidationStepResult> _runProcessStep({
    required String id,
    required String executable,
    required List<String> arguments,
    required Duration timeout,
    required String passedMessage,
    required String failedMessage,
    required String timeoutMessage,
  }) async {
    final stopwatch = Stopwatch()..start();
    progressWriter('Running $id...');
    try {
      final execution = await _runProcess(
        executable: executable,
        arguments: arguments,
        timeout: timeout,
      );
      stopwatch.stop();
      if (!execution.terminationConfirmed) {
        return ValidationStepResult(
          id: id,
          status: CliStatus.fail,
          message: 'Process cleanup could not be confirmed safely.',
          durationMs: stopwatch.elapsedMilliseconds,
          processExitCode: execution.timedOut ? null : execution.exitCode,
          timedOut: execution.timedOut,
          details: const <String, Object?>{'cleanupConfirmed': false},
        );
      }
      if (execution.timedOut) {
        return ValidationStepResult(
          id: id,
          status: CliStatus.fail,
          message: timeoutMessage,
          durationMs: stopwatch.elapsedMilliseconds,
          processExitCode: null,
          timedOut: true,
          details: _outputDetails(execution),
        );
      }
      final passed = execution.exitCode == 0;
      return ValidationStepResult(
        id: id,
        status: passed ? CliStatus.pass : CliStatus.fail,
        message: passed ? passedMessage : failedMessage,
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: execution.exitCode,
        timedOut: false,
        details: _outputDetails(execution),
      );
    } on ProcessException {
      stopwatch.stop();
      return ValidationStepResult(
        id: id,
        status: CliStatus.blocked,
        message: 'Required test executable could not be started.',
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: null,
        timedOut: false,
      );
    } on FileSystemException {
      stopwatch.stop();
      return ValidationStepResult(
        id: id,
        status: CliStatus.blocked,
        message: 'Required test capability is unavailable.',
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: null,
        timedOut: false,
      );
    } catch (_) {
      stopwatch.stop();
      return ValidationStepResult(
        id: id,
        status: CliStatus.fail,
        message: 'Test step failed because of a Project CLI internal error.',
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: null,
        timedOut: false,
        details: const <String, Object?>{'internalError': true},
      );
    }
  }

  Future<ProcessExecution> _runProcess({
    required String executable,
    required List<String> arguments,
    required Duration timeout,
  }) {
    return processRunner.run(
      executable,
      arguments,
      workingDirectory: repositoryRoot,
      timeout: timeout,
      terminationGrace: defaultTerminationGrace,
      maxCapturedCharacters: defaultProcessCaptureLimitCharacters,
      onStdout: progressWriter,
      onStderr: progressWriter,
    );
  }

  ValidationStepResult? _executionFailure({
    required String id,
    required ProcessExecution execution,
    required Stopwatch stopwatch,
    required String phase,
    required String timeoutMessage,
    required String failedMessage,
  }) {
    if (!execution.terminationConfirmed) {
      stopwatch.stop();
      return ValidationStepResult(
        id: id,
        status: CliStatus.fail,
        message: 'Process cleanup could not be confirmed safely.',
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: execution.timedOut ? null : execution.exitCode,
        timedOut: execution.timedOut,
        details: <String, Object?>{
          'failedPhase': phase,
          'cleanupConfirmed': false,
        },
      );
    }
    if (execution.timedOut) {
      stopwatch.stop();
      return ValidationStepResult(
        id: id,
        status: CliStatus.fail,
        message: timeoutMessage,
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: null,
        timedOut: true,
        details: <String, Object?>{
          'failedPhase': phase,
          ..._outputDetails(execution),
        },
      );
    }
    if (execution.exitCode != 0) {
      stopwatch.stop();
      return ValidationStepResult(
        id: id,
        status: CliStatus.fail,
        message: failedMessage,
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: execution.exitCode,
        timedOut: false,
        details: <String, Object?>{
          'failedPhase': phase,
          ..._outputDetails(execution),
        },
      );
    }
    return null;
  }

  String _repositoryPath(String portablePath) => <String>[
    repositoryRoot,
    ...portablePath.split(RegExp(r'[\\/]')),
  ].join(Platform.pathSeparator);
}

bool _isUnsafeInternalError(ValidationStepResult result) =>
    result.details['cleanupConfirmed'] == false ||
    result.details['internalError'] == true;

bool _isAbsolutePath(String path) =>
    path.startsWith('/') ||
    path.startsWith('\\') ||
    RegExp(r'^[A-Za-z]:[\\/]').hasMatch(path);

Map<String, Object?> _outputDetails(ProcessExecution execution) =>
    <String, Object?>{
      if (execution.stdoutTruncated) 'stdoutTruncated': true,
      if (execution.stderrTruncated) 'stderrTruncated': true,
    };
