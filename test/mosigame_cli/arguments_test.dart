import 'package:flutter_test/flutter_test.dart';

import '../../tool/mosigame_cli/arguments.dart';

void main() {
  group('CliArguments', () {
    test('parses doctor', () {
      final result = CliArguments.parse(const <String>['doctor']);

      expect(result.command, 'doctor');
      expect(result.json, isFalse);
    });

    test('parses --json before or after doctor', () {
      expect(
        CliArguments.parse(const <String>['doctor', '--json']).json,
        isTrue,
      );
      expect(
        CliArguments.parse(const <String>['--json', 'doctor']).json,
        isTrue,
      );
    });

    test('parses validate --full with JSON in any position', () {
      for (final arguments in <List<String>>[
        const <String>['validate', '--full'],
        const <String>['validate', '--full', '--json'],
        const <String>['--json', 'validate', '--full'],
        const <String>['--full', 'validate', '--json'],
      ]) {
        final result = CliArguments.parse(arguments);
        expect(result.command, 'validate');
        expect(result.validationMode, 'full');
        expect(result.json, arguments.contains('--json'));
      }
    });

    test('rejects missing, unknown, duplicate, and extra arguments', () {
      for (final arguments in <List<String>>[
        const <String>[],
        const <String>['unknown-command'],
        const <String>['doctor', '--unknown'],
        const <String>['doctor', '--json', '--json'],
        const <String>['doctor', '--full'],
        const <String>['doctor', 'extra'],
        const <String>['validate'],
        const <String>['validate', '--changed'],
        const <String>['validate', '--unknown'],
        const <String>['validate', '--full', '--full'],
        const <String>['validate', '--full', '--json', '--json'],
        const <String>['validate', '--full', 'extra'],
      ]) {
        expect(
          () => CliArguments.parse(arguments),
          throwsA(isA<CliUsageException>()),
        );
      }
    });

    test('detects validate intent before full argument validation', () {
      expect(
        CliArguments.targetsValidate(const <String>['validate', '--changed']),
        isTrue,
      );
      expect(
        CliArguments.targetsValidate(const <String>['unknown-command']),
        isFalse,
      );
    });

    test('detects JSON intent before full validation', () {
      expect(
        CliArguments.wantsJson(const <String>['unknown-command', '--json']),
        isTrue,
      );
    });
  });
}
