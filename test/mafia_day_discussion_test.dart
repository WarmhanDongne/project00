import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/models/mafia_roles.dart';
import 'package:project00/games/mafia/widgets/phone/day_discussion_view.dart';
import 'package:project00/games/mafia/widgets/phone/mafia_phone_layout.dart';

/// 낮 자유 토론 화면(P6)입니다.
///
/// 시안이 정한 것은 두 가지뿐입니다. 남은 시간의 **표기법**과, 시간이 임박했을
/// 때 **빨간색으로 바뀌는 것**. 골든 이미지는 기기·폰트에 따라 달라지므로
/// 그 두 규칙만 직접 확인합니다.
void main() {
  Future<void> pumpView(
    WidgetTester tester, {
    int? remainingSeconds,
    bool canEndDiscussion = true,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaDayDiscussionView(
          role: MafiaRoles.find('police'),
          remainingSeconds: remainingSeconds,
          canEndDiscussion: canEndDiscussion,
          onEndDiscussion: () {},
        ),
      ),
    );
  }

  Color? timerColorOf(WidgetTester tester, String text) =>
      tester.widget<Text>(find.text(text)).style?.color;

  group('토론 종료 버튼', _skipVoteTests);

  group('남은 시간 표기', () {
    test('1분 이상은 분·초를, 1분 미만은 초만 보여 준다', () {
      expect(MafiaDayDiscussionView.formatRemaining(150), '2m 30s');
      expect(MafiaDayDiscussionView.formatRemaining(60), '1m 0s');
      expect(MafiaDayDiscussionView.formatRemaining(29), '29s');
      expect(MafiaDayDiscussionView.formatRemaining(0), '0s');
    });

    test('서버 시계 보정으로 음수가 들어와도 0초로 보여 준다', () {
      expect(MafiaDayDiscussionView.formatRemaining(-3), '0s');
    });
  });

  testWidgets('시간이 남아 있으면 타이머가 검은색이다', (tester) async {
    await pumpView(tester, remainingSeconds: 150);

    expect(find.text('자유 토론'), findsOneWidget);
    expect(timerColorOf(tester, '2m 30s'), Colors.black);
  });

  testWidgets('시간이 임박하면 타이머가 빨간색으로 바뀐다', (tester) async {
    await pumpView(
      tester,
      remainingSeconds: MafiaDayDiscussionView.urgentThreshold - 1,
    );

    expect(timerColorOf(tester, '29s'), const Color(0xFFFF0000));
  });

  testWidgets('경계값(30초)은 아직 검은색이다', (tester) async {
    await pumpView(
      tester,
      remainingSeconds: MafiaDayDiscussionView.urgentThreshold,
    );

    expect(timerColorOf(tester, '30s'), Colors.black);
  });

  testWidgets('남은 시간이 없으면 타이머를 그리지 않는다', (tester) async {
    await pumpView(tester);

    expect(find.text('자유 토론'), findsOneWidget);
    expect(find.textContaining('s'), findsNothing);
  });

  testWidgets('토론을 끝낼 수 없으면 버튼이 비활성이다', (tester) async {
    await pumpView(tester, remainingSeconds: 150, canEndDiscussion: false);

    final button = tester.widget<MafiaPhoneActionButton>(
      find.byType(MafiaPhoneActionButton),
    );
    expect(button.enabled, isFalse);
  });
}

//=======================토론 종료 버튼 (확정 2026-08)==============================
// 내가 누르기 전까지는 원래 문구를 두고, 누른 뒤에는 '동의한 사람/살아 있는
// 사람' 집계로 바뀌며 버튼이 비활성됩니다. 남이 눌렀다고 내 버튼 문구가 먼저
// 바뀌면 아직 눌러야 하는지 헷갈립니다.
void _skipVoteTests() {
  Future<void> pumpButton(
    WidgetTester tester, {
    required bool hasVotedToSkip,
    int skipVoteCount = 0,
    int aliveCount = 6,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: MafiaDayDiscussionView(
          role: MafiaRoles.find('citizen'),
          remainingSeconds: 120,
          canEndDiscussion: true,
          skipVoteCount: skipVoteCount,
          aliveCount: aliveCount,
          hasVotedToSkip: hasVotedToSkip,
          onEndDiscussion: () {},
        ),
      ),
    );
  }

  MafiaPhoneActionButton buttonOf(WidgetTester tester) => tester
      .widget<MafiaPhoneActionButton>(find.byType(MafiaPhoneActionButton));

  testWidgets('누르기 전에는 원래 문구이고 누를 수 있다', (tester) async {
    // 남이 둘 눌렀어도 내 버튼은 그대로입니다.
    await pumpButton(tester, hasVotedToSkip: false, skipVoteCount: 2);

    final button = buttonOf(tester);
    expect(button.label, '토론 종료 하기');
    expect(button.enabled, isTrue);
    expect(find.text('2/6'), findsNothing);
  });

  testWidgets('누른 뒤에는 집계 숫자로 바뀌고 비활성된다', (tester) async {
    await pumpButton(tester, hasVotedToSkip: true, skipVoteCount: 3);

    final button = buttonOf(tester);
    expect(button.label, '3/6');
    expect(button.enabled, isFalse);
    expect(button.labelColor, const Color(0xFFFF0000));
  });

  testWidgets('비활성된 뒤에도 집계는 계속 올라간다', (tester) async {
    await pumpButton(tester, hasVotedToSkip: true, skipVoteCount: 3);
    expect(buttonOf(tester).label, '3/6');

    // 남이 한 명 더 누르면 숫자만 올라갑니다.
    await pumpButton(tester, hasVotedToSkip: true, skipVoteCount: 4);
    expect(buttonOf(tester).label, '4/6');
    expect(buttonOf(tester).enabled, isFalse);
  });
}
