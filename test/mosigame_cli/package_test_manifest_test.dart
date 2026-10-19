import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/mosigame_cli/package_test_manifest.dart';
import '../../tool/mosigame_cli/test_suites.dart';

void main() {
  test('FULL includes game_kit and all five registered games', () {
    expect(packageTestTargets.map((target) => target.name), [
      'game_kit',
      'game_liars_poker',
      'game_final_call',
      'game_mafia',
      'game_holdem',
      'game_yut',
    ]);
    expect(
      packageTestTargets.map((target) => target.stepId).toSet(),
      hasLength(6),
    );
    final workspace = File('pubspec.yaml').readAsStringSync();
    final workspacePackages =
        RegExp(r'^  - packages/(game_\w+)\s*$', multiLine: true)
            .allMatches(workspace)
            .map((match) => match.group(1)!)
            .where((name) => name != 'game_template')
            .toSet();
    expect(
      packageTestTargets.map((target) => target.name).toSet(),
      workspacePackages,
    );

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
