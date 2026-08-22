import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/mafia_result_art.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';

//=======================중립 승리 포스터 고르기==============================
// 중립은 진영 대결이 아니라 **개별 승리**라, 진영만으로는 그림을 고를 수
// 없습니다. 광대가 처형돼서 이긴 판과 교단이 판을 장악한 판은 다른 그림입니다.
//
// 여기서 짝이 어긋나면 결과 화면에 엉뚱한 포스터가 뜨는데, 게임은 정상 동작해서
// 조용히 지나갑니다. 그래서 테스트로 잠급니다.
void main() {
  const neutral = MafiaFaction.neutral;

  test('중립은 이긴 역할마다 다른 포스터를 쓴다', () {
    final posters = <String, String>{};
    for (final id in [
      'jester',
      'executioner',
      'serial_killer',
      'cult_leader',
    ]) {
      final phone = MafiaResultArt.phonePoster(neutral, winnerRoleIds: {id});
      final tablet = MafiaResultArt.tabletPoster(neutral, winnerRoleIds: {id});
      expect(phone, isNotNull, reason: '$id: 휴대폰 포스터가 없습니다');
      expect(tablet, isNotNull, reason: '$id: 태블릿 포스터가 없습니다');
      posters[id] = phone!.path;
    }
    // 네 역할이 같은 그림을 나눠 쓰면 안 됩니다.
    expect(posters.values.toSet().length, 4, reason: '포스터가 겹칩니다: $posters');
  });

  test('교주와 광신도는 한 세력이라 같은 포스터를 쓴다', () {
    final leader = MafiaResultArt.phonePoster(
      neutral,
      winnerRoleIds: {'cult_leader'},
    );
    final both = MafiaResultArt.phonePoster(
      neutral,
      winnerRoleIds: {'cult_leader', 'cultist'},
    );
    expect(both!.path, leader!.path);
  });

  test('포스터 파일 이름이 역할과 맞는다', () {
    final expected = {
      'jester': 'jester',
      'executioner': 'executioner',
      'serial_killer': 'serial_killer',
      'cult_leader': 'cult',
    };
    for (final entry in expected.entries) {
      final phone = MafiaResultArt.phonePoster(
        neutral,
        winnerRoleIds: {entry.key},
      )!;
      final tablet = MafiaResultArt.tabletPoster(
        neutral,
        winnerRoleIds: {entry.key},
      )!;
      expect(phone.path, contains('background_${entry.value}_win_phone'));
      expect(tablet.path, contains('background_${entry.value}_win.'));
    }
  });

  test('시민·마피아 포스터는 승자 역할과 무관하게 그대로다', () {
    // 진영 승리는 이긴 사람이 누구든 한 장입니다.
    for (final faction in [MafiaFaction.citizen, MafiaFaction.mafia]) {
      final plain = MafiaResultArt.phonePoster(faction);
      final withRoles = MafiaResultArt.phonePoster(
        faction,
        winnerRoleIds: {'police', 'doctor'},
      );
      expect(withRoles!.path, plain!.path);
    }
  });

  test('그림이 없는 중립 승리는 null이라 문구로 넘어간다', () {
    // 생존자는 아직 포스터가 없습니다. 화면이 문구로 대신 알립니다.
    expect(
      MafiaRoles.find('survivor')!.winCondition,
      MafiaWinCondition.surviveToEnd,
    );
    expect(
      MafiaResultArt.phonePoster(neutral, winnerRoleIds: {'survivor'}),
      isNull,
    );
    // 승자 역할을 못 읽은 경우(구버전 앱)도 조용히 문구로 넘어갑니다.
    expect(MafiaResultArt.phonePoster(neutral), isNull);
    expect(
      MafiaResultArt.tabletPoster(neutral, winnerRoleIds: {'???'}),
      isNull,
    );
  });

  test('포스터가 있는 승리는 네 가지 승리 조건을 모두 덮는다', () {
    // 구현된 중립 역할의 승리 조건마다 그림이 있어야 합니다(생존자 제외).
    final covered = {
      MafiaWinCondition.lynchedSelf,
      MafiaWinCondition.lynchTarget,
      MafiaWinCondition.lastStanding,
      MafiaWinCondition.factionDominance,
    };
    final implemented = MafiaRoles.implemented
        .where((role) => role.faction == MafiaFaction.neutral)
        .map((role) => role.winCondition)
        .toSet();
    expect(
      implemented.difference(covered),
      isEmpty,
      reason: '포스터 없는 중립 승리 조건이 구현됐습니다',
    );
  });
}
