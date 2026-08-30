import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/mosigame_cli/process_runner.dart';
import '../../tool/mosigame_cli/repository_snapshot.dart';

void main() {
  test(
    'snapshot detects tracked, staged, and untracked content but ignores ignored files',
    () async {
      final root = await Directory.systemTemp.createTemp('mosigame_snapshot_');
      final git = resolveExecutable('git');
      expect(git, isNotNull);
      try {
        await _git(git!, root.path, <String>['init']);
        await _git(git, root.path, <String>[
          'config',
          'user.email',
          'mosigame-test@example.invalid',
        ]);
        await _git(git, root.path, <String>[
          'config',
          'user.name',
          'Mosigame Test',
        ]);
        await File(_path(root.path, '.gitignore')).writeAsString('build/\n');
        final tracked = File(_path(root.path, 'tracked.bin'));
        await tracked.writeAsBytes(<int>[0, 1, 2, 255]);
        await _git(git, root.path, <String>['add', '.']);
        await _git(git, root.path, <String>['commit', '-m', 'fixture']);

        final snapshotter = GitRepositorySnapshotter(
          repositoryRoot: root.path,
          processRunner: const SystemProcessRunner(),
        );
        final baseline = await snapshotter.capture();

        final ignored = File(_path(root.path, 'build', 'ignored.bin'));
        await ignored.parent.create(recursive: true);
        await ignored.writeAsBytes(<int>[9, 8, 7]);
        expect(baseline.hasSameStateAs(await snapshotter.capture()), isTrue);

        await tracked.writeAsBytes(<int>[0, 1, 3, 255]);
        final dirty = await snapshotter.capture();
        expect(baseline.hasSameStateAs(dirty), isFalse);
        expect(dirty.hasSameStateAs(await snapshotter.capture()), isTrue);
        await tracked.writeAsBytes(<int>[0, 1, 4, 255]);
        expect(dirty.hasSameStateAs(await snapshotter.capture()), isFalse);

        await tracked.writeAsBytes(<int>[0, 1, 2, 255]);
        expect(baseline.hasSameStateAs(await snapshotter.capture()), isTrue);

        final untracked = File(_path(root.path, 'new.bin'));
        await untracked.writeAsBytes(<int>[10, 0, 20]);
        final untrackedA = await snapshotter.capture();
        expect(baseline.hasSameStateAs(untrackedA), isFalse);
        await untracked.writeAsBytes(<int>[10, 0, 21]);
        expect(untrackedA.hasSameStateAs(await snapshotter.capture()), isFalse);
        await untracked.delete();
        expect(baseline.hasSameStateAs(await snapshotter.capture()), isTrue);

        await tracked.delete();
        expect(baseline.hasSameStateAs(await snapshotter.capture()), isFalse);
        await tracked.writeAsBytes(<int>[0, 1, 2, 255]);
        expect(baseline.hasSameStateAs(await snapshotter.capture()), isTrue);

        final renamed = File(_path(root.path, 'renamed.bin'));
        await tracked.rename(renamed.path);
        expect(baseline.hasSameStateAs(await snapshotter.capture()), isFalse);
        await renamed.rename(tracked.path);
        expect(baseline.hasSameStateAs(await snapshotter.capture()), isTrue);

        await _git(git, root.path, <String>[
          'update-index',
          '--chmod=+x',
          'tracked.bin',
        ]);
        expect(baseline.hasSameStateAs(await snapshotter.capture()), isFalse);
        await _git(git, root.path, <String>[
          'update-index',
          '--chmod=-x',
          'tracked.bin',
        ]);
        expect(baseline.hasSameStateAs(await snapshotter.capture()), isTrue);

        await tracked.writeAsBytes(<int>[5, 6, 7]);
        await _git(git, root.path, <String>['add', 'tracked.bin']);
        expect(baseline.hasSameStateAs(await snapshotter.capture()), isFalse);

        final added = File(_path(root.path, 'added.bin'));
        await added.writeAsBytes(<int>[4, 3, 2, 1]);
        await _git(git, root.path, <String>['add', 'added.bin']);
        expect(baseline.hasSameStateAs(await snapshotter.capture()), isFalse);
      } finally {
        if (root.existsSync()) await root.delete(recursive: true);
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}

Future<void> _git(
  String executable,
  String root,
  List<String> arguments,
) async {
  final result = await Process.run(
    executable,
    arguments,
    workingDirectory: root,
  );
  if (result.exitCode != 0) {
    throw StateError('git ${arguments.join(' ')} failed: ${result.stderr}');
  }
}

String _path(String root, String first, [String? second]) =>
    <String>[root, first, ?second].join(Platform.pathSeparator);
