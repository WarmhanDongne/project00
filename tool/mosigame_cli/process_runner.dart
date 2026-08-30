import 'dart:async';
import 'dart:convert';
import 'dart:io';

typedef ProcessOutputCallback = void Function(String value);

const defaultProcessCaptureLimitCharacters = 64 * 1024;
const defaultTerminationGrace = Duration(seconds: 5);

abstract interface class ProcessRunner {
  Future<ProcessExecution> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 30),
    Duration terminationGrace = defaultTerminationGrace,
    int maxCapturedCharacters = defaultProcessCaptureLimitCharacters,
    ProcessOutputCallback? onStdout,
    ProcessOutputCallback? onStderr,
  });
}

final class ProcessExecution {
  const ProcessExecution({
    required this.exitCode,
    required this.stdoutText,
    required this.stderrText,
    required this.timedOut,
    this.terminationConfirmed = true,
    this.stdoutTruncated = false,
    this.stderrTruncated = false,
  });

  final int exitCode;
  final String stdoutText;
  final String stderrText;
  final bool timedOut;
  final bool terminationConfirmed;
  final bool stdoutTruncated;
  final bool stderrTruncated;

  String get combinedOutput {
    final stdoutValue = stdoutText.trim();
    final stderrValue = stderrText.trim();
    if (stdoutValue.isEmpty) return stderrValue;
    if (stderrValue.isEmpty) return stdoutValue;
    return '$stdoutValue\n$stderrValue';
  }
}

final class SystemProcessRunner implements ProcessRunner {
  const SystemProcessRunner();

  @override
  Future<ProcessExecution> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Duration timeout = const Duration(seconds: 30),
    Duration terminationGrace = defaultTerminationGrace,
    int maxCapturedCharacters = defaultProcessCaptureLimitCharacters,
    ProcessOutputCallback? onStdout,
    ProcessOutputCallback? onStderr,
  }) async {
    final resolvedExecutable = resolveExecutable(executable) ?? executable;
    final lowerExecutable = resolvedExecutable.toLowerCase();
    final requiresShell =
        Platform.isWindows &&
        (lowerExecutable.endsWith('.bat') || lowerExecutable.endsWith('.cmd'));
    final process = await Process.start(
      resolvedExecutable,
      arguments,
      workingDirectory: workingDirectory,
      runInShell: requiresShell,
    );
    final stdoutCapture = _BoundedTextCapture(maxCapturedCharacters);
    final stderrCapture = _BoundedTextCapture(maxCapturedCharacters);
    final stdoutDone = Completer<void>();
    final stderrDone = Completer<void>();
    final stdoutSubscription = process.stdout
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          (value) {
            stdoutCapture.add(value);
            onStdout?.call(value);
          },
          onError: (_) {
            if (!stdoutDone.isCompleted) stdoutDone.complete();
          },
          onDone: stdoutDone.complete,
          cancelOnError: false,
        );
    final stderrSubscription = process.stderr
        .transform(const Utf8Decoder(allowMalformed: true))
        .listen(
          (value) {
            stderrCapture.add(value);
            onStderr?.call(value);
          },
          onError: (_) {
            if (!stderrDone.isCompleted) stderrDone.complete();
          },
          onDone: stderrDone.complete,
          cancelOnError: false,
        );

    var timedOut = false;
    var terminationConfirmed = true;
    int processExitCode;
    final exitFuture = process.exitCode;
    try {
      processExitCode = await exitFuture.timeout(timeout);
    } on TimeoutException {
      timedOut = true;
      process.kill();
      try {
        processExitCode = await exitFuture.timeout(terminationGrace);
      } on TimeoutException {
        terminationConfirmed = false;
        processExitCode = -1;
      }
    }

    if (terminationConfirmed) {
      try {
        await Future.wait(<Future<void>>[
          stdoutDone.future,
          stderrDone.future,
        ]).timeout(terminationGrace);
      } on TimeoutException {
        terminationConfirmed = false;
      }
    }
    if (!terminationConfirmed) {
      await stdoutSubscription.cancel();
      await stderrSubscription.cancel();
    }

    return ProcessExecution(
      exitCode: processExitCode,
      stdoutText: stdoutCapture.value,
      stderrText: stderrCapture.value,
      timedOut: timedOut,
      terminationConfirmed: terminationConfirmed,
      stdoutTruncated: stdoutCapture.truncated,
      stderrTruncated: stderrCapture.truncated,
    );
  }
}

final class _BoundedTextCapture {
  _BoundedTextCapture(this.limit) : assert(limit > 0);

  final int limit;
  String _value = '';
  bool truncated = false;

  String get value => _value;

  void add(String chunk) {
    if (chunk.isEmpty) return;
    if (chunk.length >= limit) {
      _value = chunk.substring(chunk.length - limit);
      truncated = true;
      return;
    }
    final keepFromExisting = limit - chunk.length;
    if (_value.length > keepFromExisting) {
      _value = _value.substring(_value.length - keepFromExisting);
      truncated = true;
    }
    _value += chunk;
  }
}

String? resolveExecutable(String executable) {
  if (_containsPathSeparator(executable)) {
    return File(executable).existsSync() ? executable : null;
  }

  final pathValue = Platform.environment['PATH'];
  if (pathValue == null || pathValue.trim().isEmpty) return null;

  final names = Platform.isWindows
      ? <String>[
          '$executable.exe',
          '$executable.com',
          '$executable.cmd',
          '$executable.bat',
          executable,
        ]
      : <String>[executable];

  for (final rawDirectory in pathValue.split(Platform.isWindows ? ';' : ':')) {
    final directory = rawDirectory.trim().replaceAll('"', '');
    if (directory.isEmpty) continue;
    for (final name in names) {
      final candidate = _joinPath(directory, name);
      if (File(candidate).existsSync()) return candidate;
    }
  }
  return null;
}

bool _containsPathSeparator(String value) =>
    value.contains('/') || value.contains('\\');

String _joinPath(String first, String second) {
  if (first.endsWith('/') || first.endsWith('\\')) return '$first$second';
  return '$first${Platform.pathSeparator}$second';
}
