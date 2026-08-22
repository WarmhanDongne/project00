import 'package:flutter_test/flutter_test.dart';

//=======================내려찍는 안내 문구 기다리기==============================
/// 다음 박자가 화면에 찍힐 때까지 조금씩 돌립니다.
///
/// 안내 문구는 긴 문장을 두 박자로 나눠 띄우는데(`MafiaEjectionText`), 다음
/// 박자는 **머무르기(Timer) → 퇴장(애니메이션) → 등장(애니메이션)**을 거쳐
/// 옵니다. 타이머와 애니메이션이 번갈아 걸리므로 한 번의 `pump(큰 시간)`으로는
/// 도달하지 않습니다. 그래서 짧게 여러 번 돌리며 기다립니다.
Future<void> pumpUntilText(
  WidgetTester tester,
  String text, {
  Duration limit = const Duration(seconds: 8),
}) async {
  const step = Duration(milliseconds: 100);
  var waited = Duration.zero;
  while (waited < limit) {
    if (find.text(text).evaluate().isNotEmpty) return;
    await tester.pump(step);
    waited += step;
  }
  expect(find.text(text), findsOneWidget, reason: '"$text" 박자가 오지 않았습니다');
}
