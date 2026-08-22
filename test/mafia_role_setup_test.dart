import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/screens/tablet/tablet_role_setup_screen.dart';

//=======================역할 배치 (게임 시작 전)==============================
// 확정(2026-08): 마피아는 시작 전에 자리 배치 대신 **역할 배치**를 합니다.
// 고른 역할은 한 자리씩 차지하고, 남은 자리는 시민이 채웁니다.
// 고르면 이름이 검정, 고르지 않으면 회색입니다.
void main() {
  const design = Size(1280, 800);

  Future<Map<String, int>?> pumpSetup(
    WidgetTester tester, {
    int playerCount = 6,
  }) async {
    Map<String, int>? confirmed;
    tester.view.physicalSize = design;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaRoleSetupScreen(
          playerCount: playerCount,
          onCancel: () async => true,
          onConfirm: (composition) async {
            confirmed = composition;
            return true;
          },
        ),
      ),
    );
    return confirmed;
  }

  /// 지금 그려진 역할 이름의 색입니다.
  ///
  /// 역할 이름은 [AnimatedDefaultTextStyle]에서 색을 물려받으므로, Text에는
  /// 색이 없습니다. 그려질 때 실제로 쓰이는 색을 읽습니다.
  Color? labelColor(WidgetTester tester, String name) {
    final finder = find.text(name);
    final text = tester.widget<Text>(finder);
    return text.style?.color ??
        DefaultTextStyle.of(tester.element(finder)).style.color;
  }

  /// 이 역할 아이콘에 걸린 색 필터입니다.
  ///
  /// 아이콘과 이름은 같은 Row의 형제라, 이름에서 가장 가까운 Row를 찾아
  /// 그 안의 필터를 봅니다.
  ColorFilter iconFilter(WidgetTester tester, String roleName) {
    final row = find
        .ancestor(of: find.text(roleName), matching: find.byType(Row))
        .first;
    final filter = find.descendant(
      of: row,
      matching: find.byType(ColorFiltered),
    );
    return tester.widget<ColorFiltered>(filter.first).colorFilter;
  }

  testWidgets('세 팀 판과 시안의 역할이 모두 놓인다', (tester) async {
    await pumpSetup(tester);

    expect(find.text('시민팀'), findsOneWidget);
    expect(find.text('마피아팀'), findsOneWidget);
    expect(find.text('중립'), findsOneWidget);
    // 시안에 그려진 19개 역할입니다(각 팀에서 하나씩만 확인).
    for (final name in [
      '시민',
      '군인',
      '기자',
      '자경단원',
      '경찰',
      '정치인',
      '건달',
      '의사',
      '영매',
      '사립탐정',
      '마피아',
      '마담',
      '스파이',
      '도둑',
      '짐승인간',
      '광대',
      '교주',
      '처형자',
      '연쇄살인마',
    ]) {
      expect(find.text(name), findsOneWidget, reason: '$name 칸이 없습니다');
    }
    expect(find.text('설정 완료'), findsOneWidget);
    // Tip은 인원별 추천 조합을 알려 줍니다.
    expect(find.textContaining('6인원수일때'), findsOneWidget);
  });

  testWidgets('추천 조합이 처음부터 골라져 있다', (tester) async {
    await pumpSetup(tester);

    // 6인 추천: 마피아·경찰·의사·군인 + 시민 2
    expect(labelColor(tester, '마피아'), Colors.black);
    expect(labelColor(tester, '경찰'), Colors.black);
    expect(labelColor(tester, '군인'), Colors.black);
    // 고르지 않은 역할은 회색입니다.
    expect(labelColor(tester, '광대'), isNot(Colors.black));
    expect(labelColor(tester, '스파이'), isNot(Colors.black));
  });

  testWidgets('누르면 색이 들어오고 다시 누르면 회색이 된다', (tester) async {
    await pumpSetup(tester);
    expect(labelColor(tester, '광대'), isNot(Colors.black));

    await tester.tap(find.text('광대'));
    await tester.pumpAndSettle();
    expect(labelColor(tester, '광대'), Colors.black);

    await tester.tap(find.text('광대'));
    await tester.pumpAndSettle();
    expect(labelColor(tester, '광대'), isNot(Colors.black));
  });

  testWidgets('고르지 않은 아이콘은 회색조로 그린다', (tester) async {
    await pumpSetup(tester);

    // 아이콘마다 색 필터가 **늘 한 겹**입니다. 고른 것은 원색 행렬,
    // 고르지 않은 것은 회색조 행렬을 씁니다. (겹 수가 상태에 따라 달라지면
    // 그림이 한 프레임 튀고, 투명도를 따로 겹치면 Impeller가 경고합니다.)
    expect(find.byType(ColorFiltered), findsNWidgets(19));
    // 고른 역할은 원색(t=1), 고르지 않은 역할은 옅은 회색조(t=0) 행렬입니다.
    expect(iconFilter(tester, '경찰'), ColorFilter.matrix(mafiaRoleIconTint(1)));
    expect(iconFilter(tester, '광대'), ColorFilter.matrix(mafiaRoleIconTint(0)));

    await tester.tap(find.text('광대'));
    await tester.pumpAndSettle();
    expect(find.byType(ColorFiltered), findsNWidgets(19));
    expect(iconFilter(tester, '광대'), ColorFilter.matrix(mafiaRoleIconTint(1)));
  });

  testWidgets('남은 자리는 시민이 채운 구성으로 시작한다', (tester) async {
    Map<String, int>? confirmed;
    tester.view.physicalSize = design;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaRoleSetupScreen(
          playerCount: 6,
          onCancel: () async => true,
          onConfirm: (composition) async {
            confirmed = composition;
            return true;
          },
        ),
      ),
    );

    await tester.tap(find.text('설정 완료'));
    await tester.pumpAndSettle();

    // 특수직 4개는 한 자리씩, 남은 두 자리는 시민입니다.
    expect(confirmed, {
      'mafia': 1,
      'police': 1,
      'doctor': 1,
      'soldier': 1,
      'citizen': 2,
    });
  });

  testWidgets('인원보다 많이 고르면 시작할 수 없다', (tester) async {
    Map<String, int>? confirmed;
    tester.view.physicalSize = design;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaRoleSetupScreen(
          // 4인 판에 특수직을 다섯 개 고르면 자리가 없습니다.
          playerCount: 4,
          onCancel: () async => true,
          onConfirm: (composition) async {
            confirmed = composition;
            return true;
          },
        ),
      ),
    );

    for (final name in ['의사', '군인', '기자', '자경단원']) {
      await tester.tap(find.text(name));
      await tester.pump();
    }
    await tester.tap(find.text('설정 완료'));
    await tester.pumpAndSettle();
    expect(confirmed, isNull, reason: '자리가 모자란 구성으로 시작하면 서버가 거절합니다');
  });

  testWidgets('필수 신분(마피아·시민)은 눌러도 회색이 되지 않는다', (tester) async {
    // 확정(2026-08): 마피아가 없으면 아무 일도 일어나지 않는 판이 되고,
    // 시민이 없으면 남은 자리를 채울 역할이 없습니다. 둘은 잠가 둡니다.
    await pumpSetup(tester);

    for (final name in ['마피아', '시민']) {
      expect(labelColor(tester, name), Colors.black);
      await tester.tap(find.text(name));
      await tester.pumpAndSettle();
      expect(
        labelColor(tester, name),
        Colors.black,
        reason: '$name은 필수 신분이라 끌 수 없습니다',
      );
    }
  });

  testWidgets('필수 신분은 잠긴 채로 시작할 수 있다', (tester) async {
    Map<String, int>? confirmed;
    tester.view.physicalSize = design;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaRoleSetupScreen(
          playerCount: 6,
          onCancel: () async => true,
          onConfirm: (composition) async {
            confirmed = composition;
            return true;
          },
        ),
      ),
    );

    // 특수직을 다 끄더라도 마피아·시민은 남습니다.
    for (final name in ['경찰', '의사', '군인']) {
      await tester.tap(find.text(name));
      await tester.pump();
    }
    await tester.tap(find.text('설정 완료'));
    await tester.pumpAndSettle();

    expect(confirmed, {'mafia': 1, 'citizen': 5});
  });
}
