import 'dart:convert';

enum CliStatus {
  pass('PASS'),
  fail('FAIL'),
  blocked('BLOCKED'),
  invalid('INVALID');

  const CliStatus(this.wireName);

  final String wireName;
}

abstract final class CliExitCode {
  static const success = 0;
  static const failure = 1;
  static const invalid = 2;
  static const blocked = 3;
  static const internalError = 4;

  static int fromStatus(CliStatus status) => switch (status) {
    CliStatus.pass => success,
    CliStatus.fail => failure,
    CliStatus.invalid => invalid,
    CliStatus.blocked => blocked,
  };
}

final class CliCheckResult {
  const CliCheckResult({
    required this.id,
    required this.status,
    required this.message,
    this.details = const <String, Object?>{},
  });

  final String id;
  final CliStatus status;
  final String message;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'status': status.wireName,
    'message': message,
    if (details.isNotEmpty) 'details': details,
  };
}

final class CliSummary {
  const CliSummary({
    required this.passed,
    required this.failed,
    required this.blocked,
    required this.invalid,
  });

  factory CliSummary.fromChecks(Iterable<CliCheckResult> checks) {
    return CliSummary.fromStatuses(checks.map((check) => check.status));
  }

  factory CliSummary.fromSteps(Iterable<ValidationStepResult> steps) {
    return CliSummary.fromStatuses(steps.map((step) => step.status));
  }

  factory CliSummary.fromStatuses(Iterable<CliStatus> statuses) {
    var passed = 0;
    var failed = 0;
    var blocked = 0;
    var invalid = 0;

    for (final status in statuses) {
      switch (status) {
        case CliStatus.pass:
          passed++;
        case CliStatus.fail:
          failed++;
        case CliStatus.blocked:
          blocked++;
        case CliStatus.invalid:
          invalid++;
      }
    }

    return CliSummary(
      passed: passed,
      failed: failed,
      blocked: blocked,
      invalid: invalid,
    );
  }

  final int passed;
  final int failed;
  final int blocked;
  final int invalid;

  int get total => passed + failed + blocked + invalid;

  Map<String, Object?> toJson() => <String, Object?>{
    'passed': passed,
    'failed': failed,
    'blocked': blocked,
    'invalid': invalid,
    'total': total,
  };
}

final class ValidationStepResult {
  const ValidationStepResult({
    required this.id,
    required this.status,
    required this.message,
    required this.durationMs,
    required this.processExitCode,
    required this.timedOut,
    this.details = const <String, Object?>{},
  });

  final String id;
  final CliStatus status;
  final String message;
  final int durationMs;
  final int? processExitCode;
  final bool timedOut;
  final Map<String, Object?> details;

  Map<String, Object?> toJson() => <String, Object?>{
    'id': id,
    'status': status.wireName,
    'message': message,
    'durationMs': durationMs,
    'processExitCode': processExitCode,
    'timedOut': timedOut,
    if (details.isNotEmpty) 'details': details,
  };
}

final class ValidateCommandResult {
  const ValidateCommandResult({
    required this.command,
    required this.status,
    required this.startedAt,
    required this.durationMs,
    required this.steps,
    required this.exitCode,
  });

  final String command;
  final CliStatus status;
  final DateTime startedAt;
  final int durationMs;
  final List<ValidationStepResult> steps;
  final int exitCode;

  CliSummary get summary => CliSummary.fromSteps(steps);

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': CliCommandResult.schemaVersion,
    'command': command,
    'status': status.wireName,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'durationMs': durationMs,
    'exitCode': exitCode,
    'steps': steps.map((step) => step.toJson()).toList(),
    'summary': summary.toJson(),
  };

  String toJsonString() => jsonEncode(toJson());
}

final class TestCommandResult {
  const TestCommandResult({
    required this.command,
    required this.suite,
    required this.status,
    required this.startedAt,
    required this.durationMs,
    required this.steps,
    required this.exitCode,
  });

  final String command;
  final String? suite;
  final CliStatus status;
  final DateTime startedAt;
  final int durationMs;
  final List<ValidationStepResult> steps;
  final int exitCode;

  CliSummary get summary => CliSummary.fromSteps(steps);

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': CliCommandResult.schemaVersion,
    'command': command,
    'suite': suite,
    'status': status.wireName,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'durationMs': durationMs,
    'exitCode': exitCode,
    'steps': steps.map((step) => step.toJson()).toList(),
    'summary': summary.toJson(),
  };

  String toJsonString() => jsonEncode(toJson());
}

final class CliCommandResult {
  const CliCommandResult({
    required this.command,
    required this.status,
    required this.startedAt,
    required this.durationMs,
    required this.checks,
    required this.exitCode,
  });

  static const schemaVersion = 1;

  final String command;
  final CliStatus status;
  final DateTime startedAt;
  final int durationMs;
  final List<CliCheckResult> checks;
  final int exitCode;

  CliSummary get summary => CliSummary.fromChecks(checks);

  Map<String, Object?> toJson() => <String, Object?>{
    'schemaVersion': schemaVersion,
    'command': command,
    'status': status.wireName,
    'startedAt': startedAt.toUtc().toIso8601String(),
    'durationMs': durationMs,
    'exitCode': exitCode,
    'checks': checks.map((check) => check.toJson()).toList(),
    'summary': summary.toJson(),
  };

  String toJsonString() => jsonEncode(toJson());
}

CliStatus aggregateStatus(Iterable<CliCheckResult> checks) {
  final statuses = checks.map((check) => check.status).toSet();
  if (statuses.contains(CliStatus.invalid)) return CliStatus.invalid;
  if (statuses.contains(CliStatus.fail)) return CliStatus.fail;
  if (statuses.contains(CliStatus.blocked)) return CliStatus.blocked;
  return CliStatus.pass;
}

CliStatus aggregateValidationStatus(Iterable<ValidationStepResult> steps) {
  final statuses = steps.map((step) => step.status).toSet();
  if (statuses.contains(CliStatus.invalid)) return CliStatus.invalid;
  if (statuses.contains(CliStatus.blocked)) return CliStatus.blocked;
  if (statuses.contains(CliStatus.fail)) return CliStatus.fail;
  return CliStatus.pass;
}
