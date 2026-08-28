final class CliArguments {
  const CliArguments({
    required this.command,
    required this.json,
    this.validationMode,
  });

  static const usage = '''Usage:
  dart run :mosigame doctor [--json]
  dart run :mosigame validate --full [--json]''';

  final String command;
  final bool json;
  final String? validationMode;

  static bool wantsJson(List<String> arguments) => arguments.contains('--json');

  static bool targetsValidate(List<String> arguments) => arguments
      .where((argument) => !argument.startsWith('-'))
      .contains('validate');

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
    if (command != 'doctor' && command != 'validate') {
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

    return CliArguments(
      command: command,
      json: json,
      validationMode: validationMode,
    );
  }
}

final class CliUsageException implements Exception {
  const CliUsageException(this.message);

  final String message;

  @override
  String toString() => message;
}
