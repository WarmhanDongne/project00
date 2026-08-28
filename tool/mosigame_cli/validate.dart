import 'dart:io';

import 'process_runner.dart';
import 'repository_snapshot.dart';
import 'result.dart';

const dartFormatTimeout = Duration(minutes: 2);
const flutterAnalyzeTimeout = Duration(minutes: 10);
const flutterTestTimeout = Duration(minutes: 30);
const functionsLintTimeout = Duration(minutes: 5);
const functionsTestTimeout = Duration(minutes: 15);

typedef DoctorCheckRunner = Future<List<CliCheckResult>> Function();
typedef ProgressWriter = void Function(String value);

final class FullValidationOutcome {
  const FullValidationOutcome({
    required this.steps,
    required this.status,
    required this.exitCode,
  });

  final List<ValidationStepResult> steps;
  final CliStatus status;
  final int exitCode;
}

final class FullValidator {
  FullValidator({
    required this.repositoryRoot,
    required this.processRunner,
    required this.snapshotter,
    required this.runDoctorChecks,
    required this.progressWriter,
  });

  final String repositoryRoot;
  final ProcessRunner processRunner;
  final RepositorySnapshotter snapshotter;
  final DoctorCheckRunner runDoctorChecks;
  final ProgressWriter progressWriter;

  Future<FullValidationOutcome> run() async {
    final steps = <ValidationStepResult>[];
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
      return FullValidationOutcome(
        steps: steps,
        status: CliStatus.fail,
        exitCode: CliExitCode.internalError,
      );
    }
    preflightStopwatch.stop();
    final blockedChecks = checks
        .where((check) => check.status != CliStatus.pass)
        .toList();
    if (blockedChecks.isNotEmpty) {
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
      return FullValidationOutcome(
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
      return FullValidationOutcome(
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
      return FullValidationOutcome(
        steps: steps,
        status: CliStatus.fail,
        exitCode: CliExitCode.internalError,
      );
    }

    var internalError = false;
    try {
      for (final specification in _pipeline) {
        final result = await _runStep(specification);
        steps.add(result);
        if (result.details['cleanupConfirmed'] == false ||
            result.details['internalError'] == true) {
          internalError = true;
          break;
        }
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
                : 'Repository state changed during validation.',
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
      return FullValidationOutcome(
        steps: steps,
        status: CliStatus.fail,
        exitCode: CliExitCode.internalError,
      );
    }
    final status = aggregateValidationStatus(steps);
    return FullValidationOutcome(
      steps: steps,
      status: status,
      exitCode: CliExitCode.fromStatus(status),
    );
  }

  Future<ValidationStepResult> _runStep(
    _ValidationStepSpecification specification,
  ) async {
    final stopwatch = Stopwatch()..start();
    progressWriter('Running ${specification.id}...');
    try {
      final execution = await processRunner.run(
        specification.executable,
        specification.arguments,
        workingDirectory: repositoryRoot,
        timeout: specification.timeout,
        terminationGrace: defaultTerminationGrace,
        maxCapturedCharacters: defaultProcessCaptureLimitCharacters,
        onStdout: progressWriter,
        onStderr: progressWriter,
      );
      stopwatch.stop();
      if (!execution.terminationConfirmed) {
        return ValidationStepResult(
          id: specification.id,
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
          id: specification.id,
          status: CliStatus.fail,
          message: 'Validation step timed out.',
          durationMs: stopwatch.elapsedMilliseconds,
          processExitCode: null,
          timedOut: true,
          details: _outputDetails(execution),
        );
      }
      final passed = execution.exitCode == 0;
      return ValidationStepResult(
        id: specification.id,
        status: passed ? CliStatus.pass : CliStatus.fail,
        message: passed
            ? 'Validation step passed.'
            : 'Validation command exited with a non-zero status.',
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: execution.exitCode,
        timedOut: false,
        details: _outputDetails(execution),
      );
    } on ProcessException {
      stopwatch.stop();
      return ValidationStepResult(
        id: specification.id,
        status: CliStatus.blocked,
        message: 'Required validation executable could not be started.',
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: null,
        timedOut: false,
      );
    } on FileSystemException {
      stopwatch.stop();
      return ValidationStepResult(
        id: specification.id,
        status: CliStatus.blocked,
        message: 'Required validation capability is unavailable.',
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: null,
        timedOut: false,
      );
    } catch (_) {
      stopwatch.stop();
      return ValidationStepResult(
        id: specification.id,
        status: CliStatus.fail,
        message:
            'Validation step failed because of a Project CLI internal error.',
        durationMs: stopwatch.elapsedMilliseconds,
        processExitCode: null,
        timedOut: false,
        details: const <String, Object?>{'internalError': true},
      );
    }
  }
}

Map<String, Object?> _outputDetails(ProcessExecution execution) =>
    <String, Object?>{
      if (execution.stdoutTruncated) 'stdoutTruncated': true,
      if (execution.stderrTruncated) 'stderrTruncated': true,
    };

final class _ValidationStepSpecification {
  const _ValidationStepSpecification({
    required this.id,
    required this.executable,
    required this.arguments,
    required this.timeout,
  });

  final String id;
  final String executable;
  final List<String> arguments;
  final Duration timeout;
}

const _pipeline = <_ValidationStepSpecification>[
  _ValidationStepSpecification(
    id: 'dart-format',
    executable: 'dart',
    arguments: <String>[
      'format',
      '--output=none',
      '--set-exit-if-changed',
      'bin',
      'lib',
      'test',
      'tool/mosigame_cli',
    ],
    timeout: dartFormatTimeout,
  ),
  _ValidationStepSpecification(
    id: 'flutter-analyze',
    executable: 'flutter',
    arguments: <String>['analyze', '--no-pub'],
    timeout: flutterAnalyzeTimeout,
  ),
  _ValidationStepSpecification(
    id: 'flutter-test',
    executable: 'flutter',
    arguments: <String>['test', '--no-pub'],
    timeout: flutterTestTimeout,
  ),
  _ValidationStepSpecification(
    id: 'functions-lint',
    executable: 'npm',
    arguments: <String>['--prefix', 'functions', 'run', 'lint'],
    timeout: functionsLintTimeout,
  ),
  _ValidationStepSpecification(
    id: 'functions-test',
    executable: 'npm',
    arguments: <String>['--prefix', 'functions', 'test'],
    timeout: functionsTestTimeout,
  ),
];
