import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';

/// 역할 카드 파일 이름과 역할 id를 하나로 유지합니다.
///
/// 규칙은 `assets/games/mafia/images/cards/role_<id>.png` 하나입니다. 규칙이
/// 지켜지면 카드를 받았을 때 `card:` 한 줄만 추가하면 되고, 어긋나면 어느 카드가
/// 어느 역할인지 사람이 매번 다시 확인해야 합니다.
void main() {
  final cardsDir = Directory('assets/games/mafia/images/cards');

  test('카드 파일은 모두 role_<id>.png 규칙을 따른다', () {
    final files = cardsDir
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.endsWith('.png'))
        .toList();

    expect(files, isNotEmpty, reason: '카드 폴더가 비어 있습니다');
    for (final name in files) {
      expect(
        name.startsWith('role_'),
        isTrue,
        reason: '$name — 카드는 role_ 로 시작해야 합니다',
      );
    }
  });

  test('카드 파일 이름이 모두 실제 역할 id와 짝이 맞는다', () {
    final knownIds = MafiaRoles.all.map((role) => role.id).toSet();
    final cardIds = cardsDir
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.startsWith('role_') && name.endsWith('.png'))
        .map((name) => name.substring('role_'.length, name.length - 4))
        // 뒷면은 역할이 아닙니다.
        .where((id) => id != 'back')
        .toSet();

    final orphaned = cardIds.difference(knownIds);
    expect(
      orphaned,
      isEmpty,
      reason: '카탈로그에 없는 카드 파일: $orphaned — id를 맞추거나 역할을 추가하세요',
    );
  });

  test('카드가 있는 역할은 카탈로그에 연결돼 있다', () {
    final cardIds = cardsDir
        .listSync()
        .whereType<File>()
        .map((file) => file.uri.pathSegments.last)
        .where((name) => name.startsWith('role_') && name.endsWith('.png'))
        .map((name) => name.substring('role_'.length, name.length - 4))
        .where((id) => id != 'back')
        .toSet();

    for (final role in MafiaRoles.all) {
      if (!cardIds.contains(role.id)) continue;
      expect(
        role.card,
        isNotNull,
        reason: '${role.id} — 카드 파일이 있는데 card: 연결이 빠졌습니다',
      );
    }
  });
}
