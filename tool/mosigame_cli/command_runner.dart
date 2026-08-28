import 'dart:io';

import 'arguments.dart';
import 'doctor.dart';
import 'process_runner.dart';
import 'repository_snapshot.dart';
import 'result.dart';
import 'validate.dart';

typedef LineWriter = void Function(String value);

Future<int> runMosigameCli(
  List<String> rawArguments, {
  ProcessRunner processRunner = const SystemProcessRunner(),
  FileSystemProbe fileSystem = const LocalFileSystemProbe(),
  RuntimeEnvironment? runtime,
  String? workingDirectory,
  LineWriter? stdoutWriter,
  LineWriter? stderrWriter,
  DateTime Function()? clock,
  RepositorySnapshotter? repositorySnapshotter,
  DoctorCheckRunner? doctorCheckRunner,
}) async {
  final LineWriter writeOut = stdoutWriter ?? (value) => stdout.writeln(value);
  final LineWriter writeError =
      stderrWriter ?? (value) => stderr.writeln(value);
  final currentTime = clock ?? DateTime.now;
  final startedAt = currentTime().toUtc();
  final stopwatch = Stopwatch()..start();
  final wantsJson = CliArguments.wantsJson(rawArguments);
  final targetsValidate = CliArguments.targetsValidate(rawArguments);
  final repositoryRoot = workingDirectory ?? Directory.current.path;

  try {
    final arguments = CliArguments.parse(rawArguments);
    final doctor = Doctor(
      repositoryRoot: repositoryRoot,
      processRunner: processRunner,
      fileSystem: fileSystem,
      runtime: runtime ?? RuntimeEnvironment.current(),
    );
    if (arguments.command == 'validate') {
      final outcome = await FullValidator(
        repositoryRoot: repositoryRoot,
        processRunner: processRunner,
        snapshotter:
            repositorySnapshotter ??
            GitRepositorySnapshotter(
              repositoryRoot: repositoryRoot,
              processRunner: processRunner,
            ),
        runDoctorChecks: doctorCheckRunner ?? doctor.runChecks,
        progressWriter: writeError,
      ).run();
      stopwatch.stop();
      final result = ValidateCommandResult(
        command: 'validate',
        status: outcome.status,
        startedAt: startedAt,
        durationMs: stopwatch.elapsedMilliseconds,
        steps: outcome.steps,
        exitCode: outcome.exitCode,
      );
      _emitValidateResult(
        result,
        json: arguments.json,
        stdoutWriter: writeOut,
        stderrWriter: writeError,
      );
      return result.exitCode;
    }

    final checks = await doctor.runChecks();
    stopwatch.stop();
    final status = aggregateStatus(checks);
    final result = CliCommandResult(
      command: arguments.command,
      status: status,
      startedAt: startedAt,
      durationMs: stopwatch.elapsedMilliseconds,
      checks: checks,
      exitCode: CliExitCode.fromStatus(status),
    );
    _emitResult(
      result,
      json: arguments.json,
      stdoutWriter: writeOut,
      stderrWriter: writeError,
    );
    return result.exitCode;
  } on CliUsageException catch (error) {
    stopwatch.stop();
    if (targetsValidate) {
      final result = ValidateCommandResult(
        command: 'validate',
        status: CliStatus.invalid,
        startedAt: startedAt,
        durationMs: stopwatch.elapsedMilliseconds,
        steps: <ValidationStepResult>[
          ValidationStepResult(
            id: 'arguments',
            status: CliStatus.invalid,
            message: error.message,
            durationMs: 0,
            processExitCode: null,
            timedOut: false,
          ),
        ],
        exitCode: CliExitCode.invalid,
      );
      _emitValidateResult(
        result,
        json: wantsJson,
        stdoutWriter: writeOut,
        stderrWriter: writeError,
      );
      if (!wantsJson) writeError(CliArguments.usage);
      return CliExitCode.invalid;
    }
    final result = CliCommandResult(
      command: 'invalid',
      status: CliStatus.invalid,
      startedAt: startedAt,
      durationMs: stopwatch.elapsedMilliseconds,
      checks: <CliCheckResult>[
        CliCheckResult(
          id: 'arguments',
          status: CliStatus.invalid,
          message: error.message,
        ),
      ],
      exitCode: CliExitCode.invalid,
    );
    _emitResult(
      result,
      json: wantsJson,
      stdoutWriter: writeOut,
      stderrWriter: writeError,
    );
    if (!wantsJson) writeError(CliArguments.usage);
    return CliExitCode.invalid;
  } catch (_) {
    stopwatch.stop();
    if (targetsValidate) {
      final result = ValidateCommandResult(
        command: 'validate',
        status: CliStatus.fail,
        startedAt: startedAt,
        durationMs: stopwatch.elapsedMilliseconds,
        steps: const <ValidationStepResult>[
          ValidationStepResult(
            id: 'internal-error',
            status: CliStatus.fail,
            message: 'Project CLI internal error.',
            durationMs: 0,
            processExitCode: null,
            timedOut: false,
          ),
        ],
        exitCode: CliExitCode.internalError,
      );
      _emitValidateResult(
        result,
        json: wantsJson,
        stdoutWriter: writeOut,
        stderrWriter: writeError,
      );
      return CliExitCode.internalError;
    }
    final result = CliCommandResult(
      command: 'internal-error',
      status: CliStatus.fail,
      startedAt: startedAt,
      durationMs: stopwatch.elapsedMilliseconds,
      checks: const <CliCheckResult>[
        CliCheckResult(
          id: 'internal-error',
          status: CliStatus.fail,
          message: 'Project CLI internal error.',
        ),
      ],
      exitCode: CliExitCode.internalError,
    );
    _emitResult(
      result,
      json: wantsJson,
      stdoutWriter: writeOut,
      stderrWriter: writeError,
    );
    return CliExitCode.internalError;
  }
}

void _emitValidateResult(
  ValidateCommandResult result, {
  required bool json,
  required LineWriter stdoutWriter,
  required LineWriter stderrWriter,
}) {
  if (json) {
    stdoutWriter(result.toJsonString());
    return;
  }

  final target =
      result.status == CliStatus.invalid ||
          result.exitCode == CliExitCode.internalError
      ? stderrWriter
      : stdoutWriter;
  target('Mosigame Project CLI — ${result.command}: ${result.status.wireName}');
  for (final step in result.steps) {
    target('[${step.status.wireName}] ${step.id}: ${step.message}');
  }
  final summary = result.summary;
  target(
    'Summary: ${summary.passed} passed, ${summary.failed} failed, '
    '${summary.blocked} blocked, ${summary.invalid} invalid.',
  );
}

void _emitResult(
  CliCommandResult result, {
  required bool json,
  required LineWriter stdoutWriter,
  required LineWriter stderrWriter,
}) {
  if (json) {
    stdoutWriter(result.toJsonString());
    return;
  }

  final target =
      result.status == CliStatus.invalid ||
          result.exitCode == CliExitCode.internalError
      ? stderrWriter
      : stdoutWriter;
  target('Mosigame Project CLI — ${result.command}: ${result.status.wireName}');
  for (final check in result.checks) {
    target('[${check.status.wireName}] ${check.id}: ${check.message}');
  }
  final summary = result.summary;
  target(
    'Summary: ${summary.passed} passed, ${summary.failed} failed, '
    '${summary.blocked} blocked, ${summary.invalid} invalid.',
  );
}
