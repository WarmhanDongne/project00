import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_composition.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';

void main() {
  //=======================카탈로그 정합성==============================
  test('역할 id는 중복되지 않는다', () {
    final ids = MafiaRoles.all.map((role) => role.id).toList();
    expect(ids.toSet().length, ids.length);
  });

  test('all에 등록되지 않은 역할이 없도록 byTier 합계가 all과 같다', () {
    final fromTiers = MafiaRoleTier.values
        .expand(MafiaRoles.byTier)
        .toList(growable: false);
    expect(fromTiers.length, MafiaRoles.all.length);
  });

  // 밤에 대상을 고르는 역할은 해결 순서가 있어야 서버가 처리할 수 있습니다.
  // (모델 assert와 별개로, 카탈로그 전체를 한 번 훑어 확인합니다.)
  test('밤 행동이 있는 역할은 모두 해결 단계를 가진다', () {
    for (final role in MafiaRoles.all) {
      if (role.actsAtNight) {
        expect(role.nightPhase, isNotNull, reason: role.id);
      }
    }
  });

  test('중립 역할은 개별 승리 조건을 가진다', () {
    for (final role in MafiaRoles.all) {
      if (role.faction == MafiaFaction.neutral) {
        expect(role.hasIndividualWinCondition, isTrue, reason: role.id);
      }
    }
  });

  test('시민·마피아 진영은 진영 승리 조건을 따른다', () {
    for (final role in MafiaRoles.all) {
      if (role.faction != MafiaFaction.neutral) {
        expect(role.winCondition, MafiaWinCondition.faction, reason: role.id);
      }
    }
  });

  //=======================인원별 구성표==============================
  // 합계가 인원과 다르면 배분이 실패하거나 누군가 역할을 못 받습니다.
  test('구성표 합계는 인원수와 같다', () {
    for (final entry in MafiaComposition.recommended.entries) {
      final total = entry.value.values.fold(0, (sum, count) => sum + count);
      expect(total, entry.key, reason: '${entry.key}인 구성');
    }
  });

  test('구성표는 4~12인을 빠짐없이 담는다', () {
    for (
      var count = MafiaComposition.minPlayers;
      count <= MafiaComposition.maxPlayers;
      count += 1
    ) {
      expect(
        MafiaComposition.recommendedFor(count),
        isNotNull,
        reason: '$count인',
      );
    }
  });

  test('구성표가 쓰는 역할 id는 모두 카탈로그에 있다', () {
    for (final entry in MafiaComposition.recommended.entries) {
      for (final id in entry.value.keys) {
        expect(MafiaRoles.find(id), isNotNull, reason: '${entry.key}인의 $id');
      }
    }
  });

  test('모든 구성에 마피아 진영이 최소 1명 있다', () {
    for (final entry in MafiaComposition.recommended.entries) {
      final mafiaCount = entry.value.entries
          .where((e) => MafiaRoles.find(e.key)?.faction == MafiaFaction.mafia)
          .fold(0, (sum, e) => sum + e.value);
      expect(mafiaCount, greaterThan(0), reason: '${entry.key}인 구성');
    }
  });

  // 마피아 수가 시민 수 이상이면 시작 즉시 마피아 승리 조건이 성립합니다.
  test('시작 시점에 시민 진영이 마피아 진영보다 많다', () {
    for (final entry in MafiaComposition.recommended.entries) {
      var mafia = 0;
      var others = 0;
      for (final roleEntry in entry.value.entries) {
        final role = MafiaRoles.find(roleEntry.key);
        if (role?.faction == MafiaFaction.mafia) {
          mafia += roleEntry.value;
        } else {
          others += roleEntry.value;
        }
      }
      expect(others, greaterThan(mafia), reason: '${entry.key}인 구성');
    }
  });

  //=======================밤 해결 순서==============================
  // 순서가 어긋나면 프레이머·차단자 규칙이 깨집니다.
  test('밤 해결 순서는 명세 단계 번호대로 정렬된다', () {
    final orders = MafiaComposition.nightResolutionOrder
        .map((phase) => phase.order)
        .toList();
    final sorted = [...orders]..sort();
    expect(orders, sorted);
    expect(orders.toSet().length, orders.length);
  });

  test('차단은 보호보다, 조사 조작은 조사보다 먼저 처리된다', () {
    int indexOf(MafiaNightPhase phase) =>
        MafiaComposition.nightResolutionOrder.indexOf(phase);

    expect(
      indexOf(MafiaNightPhase.roleblock),
      lessThan(indexOf(MafiaNightPhase.protect)),
    );
    expect(
      indexOf(MafiaNightPhase.frame),
      lessThan(indexOf(MafiaNightPhase.investigate)),
    );
    expect(
      indexOf(MafiaNightPhase.protect),
      lessThan(indexOf(MafiaNightPhase.mafiaAttack)),
    );
  });

  //=======================구현 여부 게이트==============================
  // 정의만 있는 역할이 배분되면 게임이 멈춥니다. 시작 가능 인원은 구현된
  // 역할만으로 구성된 인원수여야 합니다.
  test('지금 시작할 수 있는 인원은 구현된 역할만 쓴다', () {
    for (final count in MafiaComposition.playableCounts) {
      expect(MafiaComposition.unimplementedRolesFor(count), isEmpty);
    }
  });

  // 2026-08 확정 목록입니다(마피아42 표준 룰). 이 목록이 바뀌면 서버 표
  // (functions/src/mafia/roles.ts)도 같이 바뀌어야 하고, 그 대조는
  // functions/test/mafia-role-parity.test.mjs가 합니다.
  test('구현 완료 역할 목록', () {
    expect(MafiaRoles.implemented.map((role) => role.id).toSet(), {
      // 클래식 4종
      'citizen', 'police', 'doctor', 'mafia',
      // 데이터만으로 동작해 함께 켠 역할
      'bodyguard', 'mafia_boss',
      // 시민팀 확정 역할
      'soldier', 'politician', 'medium', 'gangster', 'vigilante',
      'reporter', 'detective',
      // 마피아팀 확정 역할
      'spy', 'beast', 'madam', 'thief',
      // 중립 확정 역할 (광신도는 교주의 전향으로만 생깁니다)
      'jester', 'executioner', 'serial_killer', 'cult_leader', 'cultist',
    });
  });

  // 구현된 역할은 카드가 **전부** 있어야 합니다(2026-08-22 8종 수령 완료).
  // 카드가 없으면 화면이 뒷면으로 대신 보여 주므로 게임이 깨지지는 않지만,
  // 그 역할을 받은 사람은 자기 신분을 그림으로 확인할 수 없습니다.
  test('구현된 역할은 모두 카드 그림이 있다', () {
    final missing = MafiaRoles.implemented
        .where((role) => role.card == null)
        .map((role) => role.id)
        .toList();
    expect(missing, isEmpty, reason: '카드가 없는 역할: $missing');
  });

  test('전향으로만 생기는 역할은 배분 목록에서 빠진다', () {
    // 교주 없이 광신도로 시작하면 교단 승리 조건이 성립하지 않습니다.
    expect(MafiaRoles.convertOnlyIds, {'cultist'});
    expect(
      MafiaRoles.distributable.map((role) => role.id),
      isNot(contains('cultist')),
    );
    for (final composition in MafiaComposition.recommended.values) {
      for (final id in composition.keys) {
        expect(MafiaRoles.convertOnlyIds, isNot(contains(id)));
      }
    }
  });

  test('구성표의 모든 인원(4~12)을 시작할 수 있다', () {
    expect(
      MafiaComposition.playableCounts,
      MafiaComposition.recommended.keys.toList(),
      reason: '구성표에 미구현 역할이 섞이면 그 인원은 시작할 수 없습니다',
    );
    expect(MafiaComposition.playableCounts, [4, 5, 6, 7, 8, 9, 10, 11, 12]);
  });

  test('구현된 역할은 밤 행동이 있으면 해결 단계도 있다', () {
    // 단계가 없으면 서버가 언제 처리할지 몰라 그 사람의 밤이 사라집니다.
    for (final role in MafiaRoles.implemented) {
      if (role.actsAtNight) {
        expect(role.nightPhase, isNotNull, reason: role.id);
      }
    }
  });

  //=======================조사 결과 조작==============================
  test('밀러는 마피아로, 마피아 보스와 배신자는 시민으로 보인다', () {
    expect(
      MafiaRoles.miller.investigationAppearance,
      MafiaInvestigationAppearance.asMafia,
    );
    expect(
      MafiaRoles.mafiaBoss.investigationAppearance,
      MafiaInvestigationAppearance.asCitizen,
    );
    expect(
      MafiaRoles.traitor.investigationAppearance,
      MafiaInvestigationAppearance.asCitizen,
    );
  });

  //=======================게임 모드 풀==============================
  test('클래식 모드는 기본 등급만, 혼돈 모드는 모든 등급을 쓴다', () {
    expect(MafiaGameMode.classic.allowedTiers, [MafiaRoleTier.basic]);
    expect(
      MafiaGameMode.chaos.allowedTiers.toSet(),
      MafiaRoleTier.values.toSet(),
    );
  });
}
