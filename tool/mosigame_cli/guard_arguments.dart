import 'dart:convert';
import 'dart:io';

const guardArgumentsEnvironmentKey = 'MOSIGAME_GUARD_CLI_ARGUMENTS';
const guardStartupMarkerEnvironmentKey = 'MOSIGAME_GUARD_STARTUP_MARKER';

void signalGuardStartup(Map<String, String> environment) {
  final markerPath = environment[guardStartupMarkerEnvironmentKey];
  if (markerPath == null) return;

  final marker = File(markerPath).absolute;
  final systemTemp = Directory.systemTemp.absolute.path.toLowerCase();
  final markerParent = marker.parent.path.toLowerCase();
  final markerName = marker.uri.pathSegments.last;
  final validName = RegExp(
    r'^mosigame-guard-startup-[0-9a-f-]+\.marker$',
  ).hasMatch(markerName);
  if (markerParent != systemTemp || !validName) {
    throw const FormatException('Guard startup marker path is invalid.');
  }
  marker.createSync(exclusive: true);
}

List<String> readGuardedCliArguments(
  List<String> rawArguments,
  Map<String, String> environment,
) {
  final encodedArguments = environment[guardArgumentsEnvironmentKey];
  if (encodedArguments == null) return rawArguments;

  try {
    final decodedText = utf8.decode(base64Decode(encodedArguments));
    final decodedValue = jsonDecode(decodedText);
    if (decodedValue is! List<Object?> ||
        decodedValue.any((argument) => argument is! String)) {
      throw const FormatException('Guard arguments must be a string list.');
    }
    return List<String>.unmodifiable(decodedValue.cast<String>());
  } on FormatException {
    rethrow;
  } catch (_) {
    throw const FormatException('Guard arguments could not be decoded.');
  }
}
