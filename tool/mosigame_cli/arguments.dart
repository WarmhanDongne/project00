final class CliArguments {
  const CliArguments({
    required this.command,
    required this.json,
    this.validationMode,
    this.testSuite,
  });

  static const usage = '''Usage:
  dart run :mosigame doctor [--json]
  dart run :mosigame validate --full [--json]
  dart run :mosigame test <session|auth> [--json]''';

  final String command;
  final bool json;
  final String? validationMode;
  final String? testSuite;

  static bool wantsJson(List<String> arguments) => arguments.contains('--json');

  static bool targetsValidate(List<String> arguments) => arguments
      .where((argument) => !argument.startsWith('-'))
      .contains('validate');

  static bool targetsTest(List<String> arguments) {
    for (final argument in arguments) {
      if (!argument.startsWith('-')) return argument == 'test';
    }
    return false;
  }

  static String? requestedTestSuite(List<String> arguments) {
    final positional = arguments
        .where((argument) => !argument.startsWith('-'))
        .toList();
    final testIndex = positional.indexOf('test');
    if (testIndex < 0 || testIndex + 1 >= positional.length) return null;
    return positional[testIndex + 1];
  }

  static CliArguments parse(List<String> arguments) {
    var json = false;
    String? validationMode;
    final positional = <String>[];

    for (final argument in arguments) {
      if (argument == '--json') {
        if (json) {
          throw const CliUsageException(
            'The --json option was provided twice.',
          );
        }
        json = true;
        continue;
      }

      if (argument == '--full') {
        if (validationMode != null) {
          throw const CliUsageException(
            'More than one validation mode was provided.',
          );
        }
        validationMode = 'full';
        continue;
      }

      if (argument.startsWith('-')) {
        throw const CliUsageException('Unknown option.');
      }

      positional.add(argument);
    }

    if (positional.isEmpty) {
      throw const CliUsageException('A command is required.');
    }
    final command = positional.first;
    if (command != 'doctor' && command != 'validate' && command != 'test') {
      throw const CliUsageException('Unknown command.');
    }
    if (command == 'doctor' && positional.length != 1) {
      throw const CliUsageException('The doctor command accepts no arguments.');
    }
    if (command == 'doctor' && validationMode != null) {
      throw const CliUsageException(
        'The doctor command does not accept a validation mode.',
      );
    }
    if (command == 'validate' && positional.length != 1) {
      throw const CliUsageException(
        'The validate command accepts no positional arguments.',
      );
    }
    if (command == 'validate' && validationMode == null) {
      throw const CliUsageException(
        'The validate command requires the --full mode.',
      );
    }
    if (command == 'test' && validationMode != null) {
      throw const CliUsageException(
        'The test command does not accept a validation mode.',
      );
    }
    if (command == 'test' && positional.length < 2) {
      throw const CliUsageException('The test command requires a suite.');
    }
    if (command == 'test' && positional.length > 2) {
      throw const CliUsageException(
        'The test command accepts exactly one suite.',
      );
    }
    final testSuite = command == 'test' ? positional[1] : null;
    if (testSuite != null && testSuite != 'session' && testSuite != 'auth') {
      throw const CliUsageException('Unknown test suite.');
    }

    return CliArguments(
      command: command,
      json: json,
      validationMode: validationMode,
      testSuite: testSuite,
    );
  }
}

final class CliUsageException implements Exception {
  const CliUsageException(this.message);

  final String message;

  @override
  String toString() => message;
}
