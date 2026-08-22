@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

//=======================코드가 가리키는 그림 파일==============================
// 코드에 적힌 에셋 경로와 실제 파일이 어긋나도 앱은 조용히 돌아갑니다
// (errorBuilder가 빈 자리를 그립니다). 그래서 png를 webp로 한꺼번에 바꾸는
// 작업처럼 경로만 남는 경우를 사람 눈으로 잡기 어렵습니다. 여기서 막습니다.
void main() {
  // 파일을 넣으면 바로 보이도록 **미리 배선해 둔** 경로입니다. 그림이 없어도
  // 화면이 깨지지 않게 errorBuilder로 대체 표시를 그립니다. 파일이 들어오면
  // 이 목록에서 지워야 합니다(아래 시험이 알려 줍니다).
  const pendingArtwork = <String>{};

  test('배선만 해 둔 그림은 아직 파일이 없다', () {
    for (final path in pendingArtwork) {
      expect(
        File(path).existsSync(),
        isFalse,
        reason: '$path 파일이 들어왔습니다. pendingArtwork에서 지워 주세요.',
      );
    }
  });

  test('lib에 적힌 에셋 경로는 모두 실제 파일이 있다', () {
    final pattern = RegExp(r"'(assets/[^']+\.(?:png|jpg|jpeg|webp|svg))'");
    final missing = <String>[];

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(entity.readAsStringSync())) {
        final path = match.group(1)!;
        // 문자열을 조립해 만드는 경로(캐릭터 id 등)는 여기서 확인할 수 없습니다.
        if (path.contains(r'$')) continue;
        if (pendingArtwork.contains(path)) continue;
        if (File(path).existsSync()) continue;
        missing.add('$path  ← ${entity.path}');
      }
    }

    expect(missing, isEmpty, reason: '없는 그림 파일을 가리킵니다:\n${missing.join('\n')}');
  });

  test('pubspec에 등록되지 않은 에셋 폴더를 가리키지 않는다', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final declared = RegExp(
      r'^\s+- (assets/\S*/)$',
      multiLine: true,
    ).allMatches(pubspec).map((match) => match.group(1)!).toSet();
    final pattern = RegExp(r"'(assets/[^']+\.(?:png|jpg|jpeg|webp|svg))'");
    final unregistered = <String>{};

    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      for (final match in pattern.allMatches(entity.readAsStringSync())) {
        final path = match.group(1)!;
        if (path.contains(r'$')) continue;
        final folder = '${path.substring(0, path.lastIndexOf('/'))}/';
        if (!declared.contains(folder)) unregistered.add(folder);
      }
    }

    expect(unregistered, isEmpty);
  });
}
