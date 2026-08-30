import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/mosigame_cli/result.dart';

void main() {
  test('status names and exit codes follow the common contract', () {
    expect(CliStatus.values.map((status) => status.wireName), <String>[
      'PASS',
      'FAIL',
      'BLOCKED',
      'INVALID',
    ]);
    expect(CliExitCode.fromStatus(CliStatus.pass), 0);
    expect(CliExitCode.fromStatus(CliStatus.fail), 1);
    expect(CliExitCode.fromStatus(CliStatus.invalid), 2);
    expect(CliExitCode.fromStatus(CliStatus.blocked), 3);
    expect(CliExitCode.internalError, 4);
  });

  test('aggregate status preserves failure severity', () {
    const pass = CliCheckResult(
      id: 'pass',
      status: CliStatus.pass,
      message: 'pass',
    );
    const blocked = CliCheckResult(
      id: 'blocked',
      status: CliStatus.blocked,
      message: 'blocked',
    );
    const fail = CliCheckResult(
      id: 'fail',
      status: CliStatus.fail,
      message: 'fail',
    );

    expect(aggregateStatus(const <CliCheckResult>[pass]), CliStatus.pass);
    expect(
      aggregateStatus(const <CliCheckResult>[pass, blocked]),
      CliStatus.blocked,
    );
    expect(
      aggregateStatus(const <CliCheckResult>[pass, blocked, fail]),
      CliStatus.fail,
    );
  });

  test('serializes the stable JSON skeleton and summary', () {
    final result = CliCommandResult(
      command: 'doctor',
      status: CliStatus.blocked,
      startedAt: DateTime.utc(2026, 8, 28, 1, 2, 3),
      durationMs: 42,
      checks: const <CliCheckResult>[
        CliCheckResult(
          id: 'git',
          status: CliStatus.pass,
          message: 'Git is available.',
        ),
        CliCheckResult(
          id: 'node',
          status: CliStatus.blocked,
          message: 'Node.js is not available.',
        ),
      ],
      exitCode: CliExitCode.blocked,
    );

    final json = jsonDecode(result.toJsonString()) as Map<String, Object?>;
    expect(json['schemaVersion'], 1);
    expect(json['command'], 'doctor');
    expect(json['status'], 'BLOCKED');
    expect(json['startedAt'], '2026-08-28T01:02:03.000Z');
    expect(json['durationMs'], 42);
    expect(json['checks'], isA<List<Object?>>());
    expect(json['summary'], <String, Object?>{
      'passed': 1,
      'failed': 0,
      'blocked': 1,
      'invalid': 0,
      'total': 2,
    });
  });

  test('serializes validate steps without raw process output', () {
    final result = ValidateCommandResult(
      command: 'validate',
      status: CliStatus.fail,
      startedAt: DateTime.utc(2026, 8, 28, 2, 3, 4),
      durationMs: 99,
      steps: const <ValidationStepResult>[
        ValidationStepResult(
          id: 'flutter-test',
          status: CliStatus.fail,
          message: 'Validation command exited with a non-zero status.',
          durationMs: 12,
          processExitCode: 1,
          timedOut: false,
        ),
      ],
      exitCode: CliExitCode.failure,
    );

    final json = jsonDecode(result.toJsonString()) as Map<String, Object?>;
    expect(json['schemaVersion'], 1);
    expect(json['command'], 'validate');
    expect(json['status'], 'FAIL');
    expect(json.containsKey('checks'), isFalse);
    final steps = json['steps']! as List<Object?>;
    expect(steps, hasLength(1));
    expect(steps.single, <String, Object?>{
      'id': 'flutter-test',
      'status': 'FAIL',
      'message': 'Validation command exited with a non-zero status.',
      'durationMs': 12,
      'processExitCode': 1,
      'timedOut': false,
    });
  });

  test('validate aggregation gives BLOCKED priority over FAIL', () {
    const fail = ValidationStepResult(
      id: 'fail',
      status: CliStatus.fail,
      message: 'fail',
      durationMs: 0,
      processExitCode: 1,
      timedOut: false,
    );
    const blocked = ValidationStepResult(
      id: 'blocked',
      status: CliStatus.blocked,
      message: 'blocked',
      durationMs: 0,
      processExitCode: null,
      timedOut: false,
    );

    expect(
      aggregateValidationStatus(const <ValidationStepResult>[fail, blocked]),
      CliStatus.blocked,
    );
  });

  test('serializes test steps with a top-level suite', () {
    final result = TestCommandResult(
      command: 'test',
      suite: 'session',
      status: CliStatus.pass,
      startedAt: DateTime.utc(2026, 8, 28, 3, 4, 5),
      durationMs: 123,
      steps: const <ValidationStepResult>[
        ValidationStepResult(
          id: 'manifest',
          status: CliStatus.pass,
          message: 'Manifest is valid.',
          durationMs: 1,
          processExitCode: null,
          timedOut: false,
        ),
      ],
      exitCode: CliExitCode.success,
    );

    final json = jsonDecode(result.toJsonString()) as Map<String, Object?>;
    expect(json['schemaVersion'], 1);
    expect(json['command'], 'test');
    expect(json['suite'], 'session');
    expect(json['status'], 'PASS');
    expect(json.containsKey('steps'), isTrue);
    expect(json.containsKey('checks'), isFalse);
  });
}
