import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/mosigame_cli/process_runner.dart';

void main() {
  test('runs an executable with a separate argument list', () async {
    const runner = SystemProcessRunner();
    final git = resolveExecutable('git');

    expect(git, isNotNull);
    final result = await runner.run(git!, const <String>[
      '--version',
    ], timeout: const Duration(seconds: 5));

    expect(result.exitCode, 0);
    expect(result.timedOut, isFalse);
    expect(result.combinedOutput, startsWith('git version'));
  });

  test('combines stdout and stderr without invoking a shell string', () {
    const result = ProcessExecution(
      exitCode: 0,
      stdoutText: 'stdout',
      stderrText: 'stderr',
      timedOut: false,
    );

    expect(result.combinedOutput, 'stdout\nstderr');
  });

  test('runs npm through the platform-appropriate executable', () async {
    const runner = SystemProcessRunner();
    final npm = resolveExecutable('npm');

    expect(npm, isNotNull);
    final result = await runner.run(npm!, const <String>[
      '--version',
    ], timeout: const Duration(seconds: 5));

    expect(result.exitCode, 0);
    expect(result.timedOut, isFalse);
    expect(result.combinedOutput, matches(RegExp(r'^\d+\.\d+\.\d+')));
  });

  test(
    'drains both streams, bounds tails, and tolerates malformed bytes',
    () async {
      final directory = await Directory.systemTemp.createTemp(
        'mosigame_process_',
      );
      final script = File(
        '${directory.path}${Platform.pathSeparator}output.dart',
      );
      await script.writeAsString('''
import 'dart:io';
void main() {
  stdout.write('a' * (256 * 1024));
  stdout.add(<int>[255]);
  stderr.write('b' * (256 * 1024));
}
''');
      final streamedStdout = StringBuffer();
      final streamedStderr = StringBuffer();
      final dart = resolveExecutable('dart');
      expect(dart, isNotNull);
      try {
        final result = await const SystemProcessRunner().run(
          dart!,
          <String>[script.path],
          timeout: const Duration(seconds: 10),
          maxCapturedCharacters: 100,
          onStdout: streamedStdout.write,
          onStderr: streamedStderr.write,
        );

        expect(result.exitCode, 0);
        expect(result.stdoutText.length, 100);
        expect(result.stderrText.length, 100);
        expect(result.stdoutTruncated, isTrue);
        expect(result.stderrTruncated, isTrue);
        expect(streamedStdout.length, (256 * 1024) + 1);
        expect(streamedStderr.length, 256 * 1024);
        expect(result.stdoutText, endsWith('\uFFFD'));
      } finally {
        await directory.delete(recursive: true);
      }
    },
  );

  test('reports timeout and confirms safe process cleanup', () async {
    final directory = await Directory.systemTemp.createTemp(
      'mosigame_timeout_',
    );
    final script = File(
      '${directory.path}${Platform.pathSeparator}timeout.dart',
    );
    await script.writeAsString('''
Future<void> main() async {
  await Future<void>.delayed(const Duration(minutes: 1));
}
''');
    final dart = resolveExecutable('dart');
    expect(dart, isNotNull);
    try {
      final result = await const SystemProcessRunner().run(
        dart!,
        <String>[script.path],
        timeout: const Duration(milliseconds: 100),
        terminationGrace: const Duration(seconds: 5),
      );

      expect(result.timedOut, isTrue);
      expect(result.terminationConfirmed, isTrue);
    } finally {
      await directory.delete(recursive: true);
    }
  });
}
