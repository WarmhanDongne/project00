import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/mafia_copy.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';

/// 신분 공개 문구의 조사입니다.
///
/// 역할 이름이 34개이고 앞으로 더 늘어납니다. 받침 유무에 따라 `이었습니다`와
/// `였습니다`가 갈리므로, 역할을 추가할 때마다 문장을 손대지 않도록 규칙으로
/// 처리했습니다. 이 테스트는 **모든 역할 이름**에 대해 조사가 맞는지 봅니다.
///
/// 문구는 두 박자로 나뉘어 화면에 찍힙니다(확정 2026-08). 조사는 뒤 박자에
/// 붙으므로 그 박자를 봅니다.
void main() {
  test('받침이 있으면 이었습니다, 없으면 였습니다', () {
    // 받침 있음
    expect(MafiaCopy.wasRoleBeats('가', '시민'), ['가님은', '시민이었습니다']);
    expect(MafiaCopy.wasRoleBeats('가', '경찰'), ['가님은', '경찰이었습니다']);
    expect(MafiaCopy.wasRoleBeats('가', '사냥꾼'), ['가님은', '사냥꾼이었습니다']);
    // 받침 없음
    expect(MafiaCopy.wasRoleBeats('가', '마피아'), ['가님은', '마피아였습니다']);
    expect(MafiaCopy.wasRoleBeats('가', '의사'), ['가님은', '의사였습니다']);
    expect(MafiaCopy.wasRoleBeats('가', '광대'), ['가님은', '광대였습니다']);
  });

  test('모든 역할 이름에서 조사가 자연스럽게 붙는다', () {
    for (final role in MafiaRoles.all) {
      final sentence = MafiaCopy.wasRoleBeats('홍길동', role.displayName).last;
      final expected = MafiaCopy.hasFinalConsonant(role.displayName)
          ? '이었습니다'
          : '였습니다';
      expect(
        sentence.endsWith('${role.displayName}$expected'),
        isTrue,
        reason: '${role.id}: $sentence',
      );
      // 잘못된 조합이 섞여 나오지 않아야 합니다.
      expect(sentence, isNot(contains('아이었습니다')));
    }
  });

  test('한글이 아닌 이름도 문장이 깨지지 않는다', () {
    expect(MafiaCopy.wasRoleBeats('kim', 'Mafia'), ['kim님은', 'Mafia이었습니다']);
    expect(MafiaCopy.wasRoleBeats('', ''), ['님은', '이었습니다']);
  });

  test('두 박자로 나뉘는 발표 문구', () {
    expect(MafiaCopy.executedBeats('홍길동'), ['홍길동님이', '처형되었습니다']);
    expect(MafiaCopy.unknownRoleBeats('홍길동'), ['홍길동님의', '신분을 확인할 수 없습니다']);
    expect(MafiaCopy.deathBeats('홍길동'), ['홍길동님은', '밤을 넘기지 못했습니다']);
  });
}
