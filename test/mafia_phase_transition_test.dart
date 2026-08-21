import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/animations/mafia_phase_transition.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/widgets/phone/day_discussion_view.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';

//=======================단계 전환==============================
// 확정(2026-08): 단계가 바뀌면 있던 요소가 빠지고 새 요소가 들어옵니다.
// 배경·보관 카드처럼 그대로 있는 요소는 셸이 맡아 전환에서 제외합니다.
void main() {
  /// 화면에 실제로 그려지는 이미지의 에셋 경로를 모읍니다.
  List<String> assetPaths(WidgetTester tester) => [
    for (final image in tester.widgetList<Image>(find.byType(Image)))
      if (image.image case AssetImage(:final assetName)) assetName,
  ];

  group('MafiaPhaseTransition', () {
    testWidgets('key가 같으면 전환 없이 그대로 이어 그린다', (tester) async {
      Widget host(String label) => MaterialApp(
        home: MafiaPhaseTransition(
          child: KeyedSubtree(key: const ValueKey('day'), child: Text(label)),
        ),
      );

      await tester.pumpWidget(host('첫 문구'));
      expect(find.text('첫 문구'), findsOneWidget);

      // 같은 단계의 상태 변화입니다. 사라지지 않고 바로 갱신돼야 합니다.
      await tester.pumpWidget(host('바뀐 문구'));
      await tester.pump();
      expect(find.text('바뀐 문구'), findsOneWidget);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    });

    testWidgets('key가 바뀌면 이전 것이 먼저 빠지고 새것이 들어온다', (tester) async {
      Widget host(String key) => MaterialApp(
        home: MafiaPhaseTransition(
          child: KeyedSubtree(key: ValueKey(key), child: Text(key)),
        ),
      );

      await tester.pumpWidget(host('night'));
      expect(find.text('night'), findsOneWidget);

      await tester.pumpWidget(host('morning'));
      // 물러나는 동안에는 아직 이전 내용만 있습니다(겹쳐 흐려지지 않습니다).
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.text('night'), findsOneWidget);
      expect(find.text('morning'), findsNothing);
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, lessThan(1));

      // 다 물러나면 새 내용이 들어옵니다.
      await tester.pump(const Duration(milliseconds: 200));
      expect(find.text('morning'), findsOneWidget);
      expect(find.text('night'), findsNothing);

      await tester.pumpAndSettle();
      expect(tester.widget<Opacity>(find.byType(Opacity)).opacity, 1);
    });
  });

  group('셸이 맡는 공통 요소', () {
    Widget dayView() =>
        MafiaDayDiscussionView(role: MafiaRoles.find('citizen'));

    testWidgets('셸 표시가 없으면 화면이 자기 배경과 보관 카드를 그린다', (tester) async {
      await tester.pumpWidget(MaterialApp(home: dayView()));

      final paths = assetPaths(tester);
      expect(paths.any((path) => path.contains('background_morning')), isTrue);
      expect(paths.any((path) => path.contains('cards/role_')), isTrue);
    });

    testWidgets('셸이 맡으면 화면은 배경·보관 카드를 그리지 않는다', (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: MafiaPhoneShellChrome(child: dayView())),
      );

      final paths = assetPaths(tester);
      // 배경이 두 겹이 되면 전환 도중 화면이 한 번 어두워집니다.
      expect(paths.any((path) => path.contains('background_morning')), isFalse);
      expect(paths.any((path) => path.contains('cards/role_')), isFalse);
      // 그 화면 고유의 그림(토론 삽화)은 그대로 있습니다.
      expect(paths.any((path) => path.contains('talk_phone')), isTrue);
    });
  });
}
