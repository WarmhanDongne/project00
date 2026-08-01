import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/app/app.dart';

void main() {
  testWidgets('빈 앱이 실행된다', (tester) async {
    await tester.pumpWidget(App(userChanges: Stream<User?>.value(null)));
    expect(tester.takeException(), isNull);
  });
}
