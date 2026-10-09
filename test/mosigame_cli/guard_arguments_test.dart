import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/mosigame_cli/guard_arguments.dart';

void main() {
  test('uses raw arguments when the guard payload is absent', () {
    const raw = <String>['doctor', '--json'];

    expect(readGuardedCliArguments(raw, const <String, String>{}), same(raw));
  });

  test('decodes ordered string arguments without shell parsing', () {
    const arguments = <String>[
      'test',
      'space value',
      'quote"value',
      'amp&value',
      'percent%value',
      'caret^value',
    ];
    final encoded = base64Encode(utf8.encode(jsonEncode(arguments)));

    expect(
      readGuardedCliArguments(const <String>[], <String, String>{
        guardArgumentsEnvironmentKey: encoded,
      }),
      arguments,
    );
  });

  test('rejects malformed or non-string guard payloads', () {
    for (final encoded in <String>[
      'not-base64',
      base64Encode(utf8.encode('{"not":"a list"}')),
      base64Encode(utf8.encode('["doctor", 1]')),
    ]) {
      expect(
        () => readGuardedCliArguments(const <String>[], <String, String>{
          guardArgumentsEnvironmentKey: encoded,
        }),
        throwsFormatException,
      );
    }
  });

  test('startup marker is exclusive and restricted to system temp', () {
    final marker = File(
      '${Directory.systemTemp.path}${Platform.pathSeparator}'
      'mosigame-guard-startup-${DateTime.now().microsecondsSinceEpoch}.marker',
    );
    addTearDown(() {
      if (marker.existsSync()) marker.deleteSync();
    });

    signalGuardStartup(<String, String>{
      guardStartupMarkerEnvironmentKey: marker.path,
    });

    expect(marker.existsSync(), isTrue);
    expect(
      () => signalGuardStartup(<String, String>{
        guardStartupMarkerEnvironmentKey: marker.path,
      }),
      throwsA(isA<FileSystemException>()),
    );
    expect(
      () => signalGuardStartup(const <String, String>{
        guardStartupMarkerEnvironmentKey: r'C:\not-temp\marker',
      }),
      throwsFormatException,
    );
  });
}
