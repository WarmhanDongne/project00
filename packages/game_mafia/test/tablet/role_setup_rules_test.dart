import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_mafia/shared/models/game_rules.dart';
import 'package:game_mafia/tablet/screens/role_setup_screen.dart';

void main() {
  testWidgets('기본 프리셋과 선택한 규칙이 시작 요청에 함께 전달된다', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    MafiaRules? rules;
    Map<String, int>? composition;
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaRoleSetupScreen(
          playerCount: 10,
          onRulesChanged: (value) => rules = value,
          onConfirm: (value) async {
            composition = value;
            return false;
          },
          onCancel: () async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('기본'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('selected-role-reporter')), findsNothing);
    await tester.tap(find.byKey(const ValueKey('setup-rules')));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(SwitchListTile));
    await tester.tap(find.text('비공개'));
    await tester.tap(find.text('적용'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('confirm-roles')));
    await tester.pumpAndSettle();
    expect(composition, {'mafia': 2, 'police': 1, 'doctor': 1, 'citizen': 6});
    expect(rules, const MafiaRules(trial: true, executionReveal: 'hidden'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('시작부터 마피아 과반인 조합은 시작을 막되 숫자 편집은 가능하다', (tester) async {
    tester.view.physicalSize = const Size(1280, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    var submitted = false;
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaRoleSetupScreen(
          playerCount: 6,
          onConfirm: (_) async {
            submitted = true;
            return false;
          },
          onCancel: () async => false,
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('기본'));
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('edit-role-mafia')),
      const Offset(0, 160),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('confirm-roles')));
    await tester.pumpAndSettle();
    expect(submitted, isFalse);
    expect(find.textContaining('시작부터'), findsOneWidget);
    await tester.drag(
      find.byKey(const ValueKey('edit-role-mafia')),
      const Offset(0, -80),
    );
    await tester.pump(const Duration(seconds: 2));
    await tester.tap(find.byKey(const ValueKey('confirm-roles')));
    await tester.pumpAndSettle();
    expect(submitted, isTrue);
  });
}
