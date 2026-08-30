import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final root = Directory.current.path;

  String read(String relativePath) => File(
    <String>[root, relativePath].join(Platform.pathSeparator),
  ).readAsStringSync();

  test('setup entries preserve the repository safety boundary', () {
    final windows = read('tool/setup_mosigame.ps1');
    final macos = read('tool/setup_mosigame.sh');

    for (final script in <String>[windows, macos]) {
      expect(script, contains('git status --porcelain=v2'));
      expect(script, contains('docs/engineering/ENGINEERING_CONTRACT.md'));
      expect(script, contains('docs/engineering/PROJECT_CLI.md'));
      expect(script, contains('doctor'));
      expect(script, contains('validate --full'));
      expect(script, isNot(contains('firebase deploy')));
      expect(script, isNot(contains('git reset')));
      expect(script, isNot(contains('git restore')));
      expect(script, isNot(contains('sudo ')));
    }
  });

  test('team-facing setup documents route to canonical contracts', () {
    final human = read('docs/development/DEVELOPMENT_SETUP.md');
    final agent = read('docs/development/AGENT_SETUP.md');
    final plan = read('docs/development/DEVELOPMENT_ENVIRONMENT_PLAN.md');

    expect(human, contains('PROJECT_CLI.md'));
    expect(agent, contains('AGENTS.md'));
    expect(agent, contains('ENGINEERING_CONTRACT.md'));
    expect(plan, contains('USER VERIFICATION REQUIRED'));
    expect(plan, contains('Emulator/integration pilot'));
  });
}
