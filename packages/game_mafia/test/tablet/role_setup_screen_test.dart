import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_mafia/shared/models/game_composition.dart';
import 'package:game_mafia/tablet/screens/role_setup_screen.dart';
import 'package:game_mafia/tablet/widgets/role_setup_card.dart';

Finder key(String value) => find.byKey(ValueKey(value));

Future<void> mountSetup(
  WidgetTester tester, {
  int players = 6,
  Size size = const Size(1280, 800),
  Future<bool> Function(Map<String, int>)? onConfirm,
  Future<bool> Function()? onCancel,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: MafiaRoleSetupScreen(
        playerCount: players,
        onConfirm: onConfirm ?? (_) async => false,
        onCancel: onCancel ?? () async => false,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Future<void> addRole(WidgetTester tester, String id) async {
  await tester.tap(key('add-role'));
  await tester.pumpAndSettle();
  await tester.scrollUntilVisible(
    key('pick-role-$id'),
    160,
    scrollable: find.descendant(
      of: key('role-picker-grid'),
      matching: find.byType(Scrollable),
    ),
  );
  // 목록의 스크롤 보정이 끝난 뒤 화면 안의 카드를 누릅니다.
  await tester.pumpAndSettle();
  await tester.ensureVisible(key('pick-role-$id'));
  await tester.pumpAndSettle();
  await tester.tap(key('pick-role-$id'));
  await tester.pumpAndSettle();
}

void main() {
  for (final width in [1280.0, 1920.0]) {
    for (final players in [9, 10, 11, 12]) {
      testWidgets('$width 폭의 $players인 구성도 최대 6열로 두 줄 표시한다', (tester) async {
        await mountSetup(tester, players: players, size: Size(width, 800));
        final ids = MafiaComposition.recommended[players]!.keys.toList();
        final rects = ids
            .map((id) => tester.getRect(key('selected-role-$id')))
            .toList();
        final tops = rects.map((rect) => rect.top).toSet().toList()..sort();
        expect(tops, hasLength(2));
        expect(
          rects.where((rect) => rect.top == tops.first).length,
          lessThanOrEqualTo(6),
        );
        final rail = tester.getRect(key('role-add-rail'));
        expect(rail.top, tops.first);
        expect(
          rail.bottom,
          closeTo(
            rects.map((rect) => rect.bottom).reduce((a, b) => a > b ? a : b) -
                44,
            .1,
          ),
        );
        for (final rect in rects) {
          expect(rect.right, lessThan(rail.left));
        }
        expect(tester.takeException(), isNull);
      });
    }
  }

  testWidgets('6종은 넓은 화면에서 한 줄, 좁으면 그림 폭을 확보해 두 줄이다', (tester) async {
    await mountSetup(tester, players: 8);
    expect(
      tester.getTopLeft(key('selected-role-citizen')).dy,
      tester.getTopLeft(key('selected-role-politician')).dy,
    );
    tester.view.physicalSize = const Size(1024, 800);
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(key('selected-role-politician')).dy,
      greaterThan(tester.getTopLeft(key('selected-role-citizen')).dy),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('6종에서 7종을 추가하면 두 줄, 삭제하면 한 줄로 돌아온다', (tester) async {
    await mountSetup(tester, players: 8);
    await addRole(tester, 'medium');
    expect(
      tester.getTopLeft(key('selected-role-medium')).dy,
      greaterThan(tester.getTopLeft(key('selected-role-citizen')).dy),
    );
    await tester.tap(key('remove-role-medium'));
    await tester.pumpAndSettle();
    expect(
      tester.getTopLeft(key('selected-role-politician')).dy,
      tester.getTopLeft(key('selected-role-citizen')).dy,
    );
    expect(tester.takeException(), isNull);
  });

  int countOf(WidgetTester tester, String id) => tester
      .widget<MafiaSetupRoleCard>(
        find.descendant(
          of: key('selected-role-$id'),
          matching: find.byType(MafiaSetupRoleCard),
        ),
      )
      .count!;

  testWidgets('카드 중앙에서 인원을 조절하고 손을 뗀 2초 뒤 복귀한다', (tester) async {
    Map<String, int>? submitted;
    await mountSetup(
      tester,
      onConfirm: (value) async {
        submitted = value;
        return false;
      },
    );
    await tester.tap(key('edit-role-mafia'));
    await tester.pump();
    expect(key('count-editor-mafia'), findsOneWidget);
    await tester.drag(key('edit-role-mafia'), const Offset(0, 80));
    await tester.pump();
    expect(countOf(tester, 'mafia'), 2);
    expect(countOf(tester, 'citizen'), 1);
    await tester.pump(const Duration(milliseconds: 1999));
    expect(key('count-editor-mafia'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(key('count-editor-mafia'), findsNothing);
    expect(countOf(tester, 'mafia'), 2);
    await tester.tap(key('confirm-roles'));
    await tester.pumpAndSettle();
    expect(submitted!['mafia'], 2);
    expect(submitted!.values.reduce((a, b) => a + b), 6);
  });

  testWidgets('누르는 동안 유지하고 다시 만지면 2초를 새로 계산한다', (tester) async {
    await mountSetup(tester);
    await tester.tap(key('edit-role-mafia'));
    await tester.pump(const Duration(milliseconds: 1500));
    final hold = await tester.startGesture(
      tester.getCenter(key('edit-role-mafia')),
    );
    await tester.pump(const Duration(seconds: 3));
    expect(key('count-editor-mafia'), findsOneWidget);
    await hold.up();
    await tester.pump(const Duration(milliseconds: 1500));
    expect(key('count-editor-mafia'), findsOneWidget);
    await tester.tap(key('edit-role-mafia'));
    await tester.pump(const Duration(milliseconds: 1500));
    expect(key('count-editor-mafia'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    expect(key('count-editor-mafia'), findsNothing);
  });

  testWidgets('인원 상한·최소 1명 제한을 지키며 위로 밀면 감소한다', (tester) async {
    await mountSetup(tester);
    await tester.drag(key('edit-role-mafia'), const Offset(0, 400));
    await tester.pump();
    expect(countOf(tester, 'mafia'), 2);
    expect(countOf(tester, 'citizen'), 1);
    expect(tester.widget<InkWell>(key('add-role')).onTap, isNull);
    await tester.drag(key('edit-role-mafia'), const Offset(0, -400));
    await tester.pump();
    expect(countOf(tester, 'mafia'), 1);
    expect(countOf(tester, 'citizen'), 2);
    expect(tester.widget<InkWell>(key('add-role')).onTap, isNotNull);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('다른 카드 선택·삭제·화면 제거 시 이전 편집을 정리한다', (tester) async {
    await mountSetup(tester, players: 10, size: const Size(800, 600));
    await tester.tap(key('edit-role-mafia'));
    await tester.pump();
    await tester.tap(key('edit-role-doctor'));
    await tester.pump();
    expect(key('count-editor-mafia'), findsNothing);
    expect(key('count-editor-doctor'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.tap(key('remove-role-doctor'));
    await tester.pumpAndSettle();
    expect(key('count-editor-doctor'), findsNothing);
    await tester.tap(key('edit-role-mafia'));
    await tester.pump();
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 3));
    expect(tester.takeException(), isNull);
  });

  testWidgets('편집 중 제출하면 최신 숫자를 사용하고 추가 조작을 막는다', (tester) async {
    final pending = Completer<bool>();
    Map<String, int>? submitted;
    await mountSetup(
      tester,
      onConfirm: (value) {
        submitted = value;
        return pending.future;
      },
    );
    await tester.drag(key('edit-role-mafia'), const Offset(0, 80));
    await tester.pump();
    await tester.tap(key('confirm-roles'));
    await tester.pump();
    expect(submitted!['mafia'], 2);
    expect(key('count-editor-mafia'), findsNothing);
    await tester.drag(key('edit-role-mafia'), const Offset(0, -80));
    await tester.pump();
    expect(countOf(tester, 'mafia'), 2);
    expect(key('count-editor-mafia'), findsNothing);
    pending.complete(false);
    await tester.pumpAndSettle();
  });

  for (final players in MafiaComposition.recommended.keys) {
    testWidgets('$players인 추천 인원수를 그대로 제출한다', (tester) async {
      Map<String, int>? submitted;
      await mountSetup(
        tester,
        players: players,
        onConfirm: (value) async {
          submitted = value;
          return false;
        },
      );
      await tester.tap(key('confirm-roles'));
      await tester.pumpAndSettle();
      expect(submitted, MafiaComposition.recommended[players]);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('추가 목록은 2열이며 선택하면 오른쪽에 붙고 +가 돌아온다', (tester) async {
    Map<String, int>? submitted;
    await mountSetup(
      tester,
      onConfirm: (value) async {
        submitted = value;
        return false;
      },
    );
    final before = tester.getSize(key('selected-role-citizen')).width;
    await tester.tap(key('add-role'));
    await tester.pumpAndSettle();
    expect(key('add-role'), findsNothing);
    expect(key('pick-role-citizen'), findsNothing);
    final grid = tester.widget<GridView>(key('role-picker-grid'));
    expect(
      (grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount)
          .crossAxisCount,
      2,
    );
    await tester.tap(key('pick-role-politician'));
    await tester.pumpAndSettle();
    expect(key('role-picker-grid'), findsNothing);
    expect(key('add-role'), findsOneWidget);
    expect(
      tester.getSize(key('selected-role-citizen')).width,
      lessThan(before),
    );
    expect(
      tester.getTopLeft(key('selected-role-politician')).dx,
      greaterThan(tester.getTopLeft(key('selected-role-soldier')).dx),
    );
    await tester.tap(key('confirm-roles'));
    await tester.pumpAndSettle();
    expect(submitted, {
      'citizen': 1,
      'mafia': 1,
      'police': 1,
      'doctor': 1,
      'soldier': 1,
      'politician': 1,
    });
    await tester.tap(key('remove-role-politician'));
    await tester.pumpAndSettle();
    expect(key('selected-role-politician'), findsNothing);
    await tester.tap(key('confirm-roles'));
    await tester.pumpAndSettle();
    expect(submitted, MafiaComposition.recommended[6]);
  });

  testWidgets('두 줄 배치에서도 +는 두 줄 전체 높이를 차지한다', (tester) async {
    await mountSetup(tester, players: 12, size: const Size(1024, 768));
    final first = tester.getRect(key('selected-role-mafia'));
    final last = tester.getRect(key('selected-role-jester'));
    final rail = tester.getRect(key('role-add-rail'));
    expect(last.top, greaterThan(first.top));
    expect(rail.top, first.top);
    expect(rail.bottom, closeTo(last.bottom - 44, .1));
    expect(rail.left, greaterThan(last.right));
    expect(key('add-role'), findsOneWidget);
    // 추천 구성의 마피아 2명을 포함해 이미 12명이므로 먼저 한 자리를 비웁니다.
    expect(tester.widget<InkWell>(key('add-role')).onTap, isNull);
    await tester.tap(key('remove-role-jester'));
    await tester.pumpAndSettle();
    await tester.tap(key('add-role'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.tap(key('close-role-picker'));
    await tester.pumpAndSettle();
    expect(tester.getRect(key('role-add-rail')), rail);
  });

  testWidgets('삭제로 잘못된 구성이 되면 시작을 막고 다시 추가할 수 있다', (tester) async {
    await mountSetup(tester);
    await tester.tap(key('remove-role-mafia'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(key('confirm-roles')).onPressed, isNull);
    expect(find.text('마피아팀 신분을 하나 이상 추가해 주세요.'), findsOneWidget);
    await addRole(tester, 'mafia');
    expect(
      tester.widget<FilledButton>(key('confirm-roles')).onPressed,
      isNotNull,
    );
    await tester.tap(key('remove-role-citizen'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(key('confirm-roles')).onPressed, isNull);
    expect(find.text('신분이 부족해요. 시민이나 다른 신분을 추가해 주세요.'), findsOneWidget);
    await addRole(tester, 'citizen');
    expect(
      tester.widget<FilledButton>(key('confirm-roles')).onPressed,
      isNotNull,
    );
  });

  testWidgets('시민 한 자리를 남기고 인원이 차면 추가 자체를 막는다', (tester) async {
    Map<String, int>? submitted;
    await mountSetup(
      tester,
      players: 4,
      onConfirm: (value) async {
        submitted = value;
        return false;
      },
    );
    await addRole(tester, 'doctor');
    expect(tester.widget<InkWell>(key('add-role')).onTap, isNull);
    await tester.tap(key('add-role'));
    await tester.pumpAndSettle();
    expect(key('role-picker-grid'), findsNothing);
    expect(
      tester.widget<FilledButton>(key('confirm-roles')).onPressed,
      isNotNull,
    );
    await tester.tap(key('confirm-roles'));
    await tester.pumpAndSettle();
    expect(submitted, {'mafia': 1, 'police': 1, 'doctor': 1, 'citizen': 1});

    // 시민을 직접 빼면 그 한 자리에는 다른 신분을 넣을 수 있습니다.
    await tester.tap(key('remove-role-citizen'));
    await tester.pumpAndSettle();
    expect(tester.widget<InkWell>(key('add-role')).onTap, isNotNull);
    await addRole(tester, 'soldier');
    expect(tester.widget<InkWell>(key('add-role')).onTap, isNull);
    await tester.tap(key('confirm-roles'));
    await tester.pumpAndSettle();
    expect(submitted, {'mafia': 1, 'police': 1, 'doctor': 1, 'soldier': 1});
    expect(find.text('참여 인원보다 신분이 많아요. 카드를 삭제해 주세요.'), findsNothing);

    await tester.tap(key('remove-role-soldier'));
    await tester.pumpAndSettle();
    await addRole(tester, 'citizen');
    expect(tester.widget<InkWell>(key('add-role')).onTap, isNull);
    expect(
      tester.widget<FilledButton>(key('confirm-roles')).onPressed,
      isNotNull,
    );
  });

  testWidgets('진행 중에는 편집·중복 제출을 막고 실패 후 다시 활성화한다', (tester) async {
    final pending = Completer<bool>();
    var calls = 0;
    await mountSetup(
      tester,
      onConfirm: (_) {
        calls++;
        return pending.future;
      },
    );
    await tester.tap(key('confirm-roles'));
    await tester.pump();
    await tester.tap(key('confirm-roles'));
    await tester.tap(key('remove-role-doctor'));
    await tester.tap(key('add-role'));
    await tester.pump();
    expect(calls, 1);
    expect(key('selected-role-doctor'), findsOneWidget);
    expect(key('role-picker-grid'), findsNothing);
    pending.complete(false);
    await tester.pumpAndSettle();
    expect(
      tester.widget<FilledButton>(key('confirm-roles')).onPressed,
      isNotNull,
    );
    expect(find.text('게임을 시작하지 못했습니다. 연결을 확인하고 다시 눌러 주세요.'), findsOneWidget);
  });

  testWidgets('목록에서 뒤로 가면 목록만 닫고 그 다음에 취소한다', (tester) async {
    var cancelled = 0;
    await mountSetup(
      tester,
      onCancel: () async {
        cancelled++;
        return false;
      },
    );
    await tester.tap(key('add-role'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(key('add-role'), findsOneWidget);
    expect(cancelled, 0);
    await tester.tap(find.byTooltip('뒤로가기'));
    await tester.pumpAndSettle();
    expect(cancelled, 1);
    expect(find.text('나가기를 처리하지 못했습니다. 다시 눌러 주세요.'), findsOneWidget);
  });

  for (final size in [const Size(800, 600), const Size(600, 900)]) {
    testWidgets('$size 화면에서 인원 한도 내 신분 교체와 두 줄 배치를 유지한다', (tester) async {
      await mountSetup(tester, players: 12, size: size);
      var replaceId = 'jester';
      for (final id in [
        'citizen',
        'medium',
        'vigilante',
        'beast',
        'thief',
        'executioner',
        'serial_killer',
        'cult_leader',
      ]) {
        expect(tester.widget<InkWell>(key('add-role')).onTap, isNull);
        await tester.tap(key('remove-role-$replaceId'));
        await tester.pumpAndSettle();
        await addRole(tester, id);
        replaceId = id;
        expect(tester.takeException(), isNull);
      }
      expect(find.byType(AnimatedPositioned), findsNWidgets(12));
      final rail = tester.getRect(key('role-add-rail'));
      expect(rail.right, lessThanOrEqualTo(size.width));
      for (final element in find.byType(IconButton).evaluate()) {
        final rect = tester.getRect(find.byWidget(element.widget));
        expect(rect.bottom, lessThanOrEqualTo(size.height));
        expect(rect.right, lessThanOrEqualTo(size.width));
      }
      await tester.tap(key('add-role'));
      await tester.pumpAndSettle();
      expect(key('role-picker-grid'), findsNothing);
      expect(tester.takeException(), isNull);
    });
  }
}
