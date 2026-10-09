import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/mosigame_cli/package_test_manifest.dart';
import '../../tool/mosigame_cli/test_suites.dart';

void main() {
  test('FULL includes game_kit and all four registered games', () {
    expect(packageTestTargets.map((target) => target.name), [
      'game_kit',
      'game_liars_poker',
      'game_final_call',
      'game_mafia',
      'game_holdem',
    ]);
    expect(
      packageTestTargets.map((target) => target.stepId).toSet(),
      hasLength(5),
    );
    final workspace = File('pubspec.yaml').readAsStringSync();
    for (final target in packageTestTargets) {
      expect(workspace, contains('  - ${target.directory}'));
      expect(File('${target.directory}/pubspec.yaml').existsSync(), isTrue);
      expect(
        Directory('${target.directory}/test')
            .listSync(recursive: true)
            .whereType<File>()
            .where((file) => file.path.endsWith('_test.dart')),
        isNotEmpty,
      );
    }
  });

  test('the repository contains every required session/auth regression', () {
    for (final suite in [sessionTestSuite, authTestSuite]) {
      for (final path in [...suite.flutterTests, ...suite.functionsTests]) {
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });
}
