import 'dart:async';

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

  //=======================전체 대기 시간 상한==============================
  // 이 상한이 없을 때 휴대폰이 멈췄습니다. callable 기본 타임아웃 70초가 4번
  // 이어지면 최악 281초 동안 응답을 기다렸고, 그동안 isCommandInFlight가 true라
  // 제출·라이어 버튼이 전부 잠겼습니다. 턴 제한은 30초입니다.
  test('응답이 오지 않아도 전체 예산 안에서 포기한다', () async {
    const budget = Duration(milliseconds: 300);
    const timedOut = CallableRetryPolicy(
      baseDelay: Duration.zero,
      attemptTimeout: Duration(milliseconds: 100),
      totalBudget: budget,
    );
    final elapsed = Stopwatch()..start();

    await expectLater(
      // 절대 완료되지 않는 요청입니다.
      timedOut.run(() => Completer<String>().future, enabled: true),
      throwsA(isA<TimeoutException>()),
    );

    elapsed.stop();
    expect(elapsed.elapsed, lessThan(budget * 3));
  });

  test('응답이 늦어도 성공하면 그 값을 그대로 돌려준다', () async {
    const slow = CallableRetryPolicy(
      baseDelay: Duration.zero,
      attemptTimeout: Duration(milliseconds: 200),
      totalBudget: Duration(seconds: 1),
    );

    final result = await slow.run(() async {
      await Future<void>.delayed(const Duration(milliseconds: 20));
      return 'ok';
    }, enabled: true);

    expect(result, 'ok');
  });

  test('재전송이 꺼져 있어도 무한정 기다리지 않는다', () async {
    const noRetry = CallableRetryPolicy(
      baseDelay: Duration.zero,
      attemptTimeout: Duration(milliseconds: 80),
      totalBudget: Duration(milliseconds: 200),
    );

    await expectLater(
      noRetry.run(() => Completer<String>().future, enabled: false),
      throwsA(isA<TimeoutException>()),
    );
  });
}
