import 'dart:convert';
import 'dart:io';

import 'process_runner.dart';

const gitSnapshotTimeout = Duration(minutes: 2);
const gitSnapshotCaptureLimitCharacters = 16 * 1024 * 1024;

abstract interface class RepositorySnapshotter {
  Future<RepositorySnapshot> capture();
}

final class RepositorySnapshot {
  const RepositorySnapshot(this.fingerprint);

  final String fingerprint;

  bool hasSameStateAs(RepositorySnapshot other) =>
      fingerprint == other.fingerprint;
}

final class SnapshotBlockedException implements Exception {
  const SnapshotBlockedException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class SnapshotInternalException implements Exception {
  const SnapshotInternalException(this.message);

  final String message;

  @override
  String toString() => message;
}

final class GitRepositorySnapshotter implements RepositorySnapshotter {
  GitRepositorySnapshotter({
    required this.repositoryRoot,
    required this.processRunner,
    this.timeout = gitSnapshotTimeout,
  });

  final String repositoryRoot;
  final ProcessRunner processRunner;
  final Duration timeout;

  @override
  Future<RepositorySnapshot> capture() async {
    final stopwatch = Stopwatch()..start();
    try {
      final head = await _git(const <String>[
        'rev-parse',
        '--verify',
        'HEAD',
      ], stopwatch);
      final index = await _git(const <String>[
        'ls-files',
        '--stage',
        '-z',
      ], stopwatch);
      final worktreeDiff = await _git(const <String>[
        'diff',
        '--raw',
        '--no-renames',
        '-z',
      ], stopwatch);
      final changedPaths = _nulSeparated(
        await _git(const <String>[
          'diff',
          '--name-only',
          '--no-renames',
          '-z',
        ], stopwatch),
      );
      final untrackedPaths = _nulSeparated(
        await _git(const <String>[
          'ls-files',
          '--others',
          '--exclude-standard',
          '-z',
        ], stopwatch),
      );

      final changedContent = <String, String>{};
      for (final path in changedPaths..sort()) {
        changedContent[path] = await _contentFingerprint(path, stopwatch);
      }
      final untrackedContent = <String, String>{};
      for (final path in untrackedPaths..sort()) {
        untrackedContent[path] = await _contentFingerprint(path, stopwatch);
      }

      return RepositorySnapshot(
        jsonEncode(<String, Object?>{
          'head': head,
          'index': index,
          'worktreeDiff': worktreeDiff,
          'changedContent': changedContent,
          'untrackedContent': untrackedContent,
        }),
      );
    } on SnapshotBlockedException {
      rethrow;
    } on ProcessException catch (error) {
      throw SnapshotBlockedException(
        'Git snapshot command could not start: ${error.message}',
      );
    } on FileSystemException catch (error) {
      throw SnapshotBlockedException(
        'Git snapshot could not read the working tree: ${error.message}',
      );
    } on SnapshotInternalException {
      rethrow;
    } catch (_) {
      throw const SnapshotInternalException(
        'Unexpected error while creating the Git working-tree snapshot.',
      );
    } finally {
      stopwatch.stop();
    }
  }

  Future<String> _contentFingerprint(String path, Stopwatch stopwatch) async {
    final entityType = FileSystemEntity.typeSync(_nativePath(path));
    if (entityType == FileSystemEntityType.notFound) return '<missing>';
    if (entityType == FileSystemEntityType.directory) {
      return '<directory:${await _git(<String>['rev-parse', 'HEAD:$path'], stopwatch)}>';
    }
    return (await _git(<String>[
      'hash-object',
      '--no-filters',
      '--',
      path,
    ], stopwatch)).trim();
  }

  Future<String> _git(List<String> arguments, Stopwatch stopwatch) async {
    final remaining = timeout - stopwatch.elapsed;
    if (remaining <= Duration.zero) {
      throw const SnapshotBlockedException('Git snapshot timed out.');
    }
    final execution = await processRunner.run(
      'git',
      arguments,
      workingDirectory: repositoryRoot,
      timeout: remaining,
      maxCapturedCharacters: gitSnapshotCaptureLimitCharacters,
    );
    if (!execution.terminationConfirmed) {
      throw const SnapshotInternalException(
        'Git snapshot process cleanup could not be confirmed.',
      );
    }
    if (execution.timedOut) {
      throw const SnapshotBlockedException('Git snapshot timed out.');
    }
    if (execution.stdoutTruncated || execution.stderrTruncated) {
      throw const SnapshotBlockedException(
        'Git snapshot output exceeded the safe capture limit.',
      );
    }
    if (execution.exitCode != 0) {
      throw SnapshotBlockedException(
        'Git snapshot command failed (${arguments.first}).',
      );
    }
    return execution.stdoutText;
  }

  String _nativePath(String gitPath) {
    final parts = gitPath.split('/');
    return <String>[repositoryRoot, ...parts].join(Platform.pathSeparator);
  }
}

List<String> _nulSeparated(String value) =>
    value.split('\u0000').where((part) => part.isNotEmpty).toSet().toList();
