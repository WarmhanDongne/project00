import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/app/app.dart';

void main() {
  testWidgets('홈 화면이 표시된다', (tester) async {
    await tester.pumpWidget(const App());
    expect(find.text('Project 00'), findsOneWidget);
    expect(find.text('게임 스토어'), findsOneWidget);
  });
}
