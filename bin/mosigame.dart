import 'dart:io';

import '../tool/mosigame_cli/command_runner.dart';

Future<void> main(List<String> arguments) async {
  exitCode = await runMosigameCli(arguments);
}
