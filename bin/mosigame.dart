import 'dart:io';

import '../tool/mosigame_cli/command_runner.dart';
import '../tool/mosigame_cli/guard_arguments.dart';
import '../tool/mosigame_cli/result.dart';

Future<void> main(List<String> arguments) async {
  try {
    signalGuardStartup(Platform.environment);
    final effectiveArguments = readGuardedCliArguments(
      arguments,
      Platform.environment,
    );
    exitCode = await runMosigameCli(effectiveArguments);
  } on FormatException {
    stderr.writeln(
      'Mosigame Project CLI invocation failed because the guarded argument '
      'payload was invalid.',
    );
    exitCode = CliExitCode.internalError;
  }
}
