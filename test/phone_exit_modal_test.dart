import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/widgets/phone_exit_modal.dart';

//=======================공용 퇴장 모달==============================
// 게임마다 삽화 크기가 달라, 큰 그림이 없는 게임은 모달을 작게 띄웁니다.
void main() {
  Future<void> pumpModal(
    WidgetTester tester, {
    double? imageHeight,
    double maxWidth = 380,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(402, 874);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: SharedPhoneExitModal(
          doorImage: const SizedBox.expand(key: Key('exit-art')),
          imageHeight: imageHeight,
          maxWidth: maxWidth,
          surfaceColor: Colors.white,
          primaryColor: const Color(0xFF212730),
          titleColor: Colors.black,
          descriptionColor: Colors.black,
        ),
      ),
    );
  }

  testWidgets('기본값은 화면 높이에 맞춘 삽화 크기를 쓴다', (tester) async {
    await pumpModal(tester);

    // 874 * 0.34 = 297.16 → 280으로 잘립니다.
    expect(tester.getSize(find.byKey(const Key('exit-art'))).height, 280);
  });

  testWidgets('imageHeight와 maxWidth를 주면 모달이 작아진다', (tester) async {
    await pumpModal(tester, imageHeight: 96, maxWidth: 320);

    final art = tester.getSize(find.byKey(const Key('exit-art')));
    expect(art.height, 96);
    expect(art.width, lessThanOrEqualTo(320));
    expect(find.text('게임과 그룹에서 나갈까요?'), findsOneWidget);
    expect(
      find.text('현재 게임을 종료하고 그룹에서도 나갑니다. 다시 참여하려면 방 코드를 입력해야 합니다.'),
      findsOneWidget,
    );
    expect(find.text('계속 참여'), findsOneWidget);
    expect(find.text('나가기'), findsOneWidget);
  });
}
