import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/services/callable_retry_policy.dart';

void main() {
  const policy = CallableRetryPolicy(baseDelay: Duration.zero);

  test('일시 오류가 나면 최초 요청 이후 3번 재전송한다', () async {
    var attempts = 0;

    final result = await policy.run(() async {
      attempts += 1;
      if (attempts < 4) {
        throw FirebaseFunctionsException(
          code: 'unavailable',
          message: 'temporary',
        );
      }
      return 'success';
    }, enabled: true);

    expect(result, 'success');
    expect(attempts, 4);
  });

  test('규칙 오류는 재전송하지 않고 즉시 반환한다', () async {
    var attempts = 0;

    await expectLater(
      policy.run(() async {
        attempts += 1;
        throw FirebaseFunctionsException(
          code: 'failed-precondition',
          message: 'invalid phase',
        );
      }, enabled: true),
      throwsA(isA<FirebaseFunctionsException>()),
    );

    expect(attempts, 1);
  });
}
