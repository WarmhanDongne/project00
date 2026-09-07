import 'package:flutter_test/flutter_test.dart';
import 'package:mosigame_core/core/diagnostics/game_communication_log.dart';

void main() {
  final log = GameCommunicationLog.instance;

  setUp(log.clear);
  tearDown(log.clear);

  test('오류·지연만 미확인 문제 수에 포함한다', () {
    log.add(level: GameCommunicationLevel.info, title: '전송', detail: '1회차');
    log.add(
      level: GameCommunicationLevel.success,
      title: '성공',
      detail: '120ms',
    );
    log.add(level: GameCommunicationLevel.warning, title: '재시도', detail: '2회차');
    log.add(level: GameCommunicationLevel.failure, title: '실패', detail: '시간초과');

    expect(log.unseenProblemCount, 2);
    log.markSeen();
    expect(log.unseenProblemCount, 0);
    expect(log.entries, hasLength(4));
  });

  test('RTDB 기록에 revision과 phase만 남기고 카드 값은 남기지 않는다', () {
    log.recordRealtimeSnapshot(
      channel: '공개 게임',
      value: {
        'revision': 19,
        'phase': 'penalty',
        'status': 'playing',
        'card': 'secret-card-value',
      },
    );

    final entry = log.entries.single;
    expect(entry.detail, contains('revision=19'));
    expect(entry.detail, contains('phase=penalty'));
    expect(entry.detail, contains('status=playing'));
    expect(entry.detail, isNot(contains('secret-card-value')));
  });

  test('연결 상태가 바뀌 때만 타임라인을 추가한다', () {
    log.recordConnection(true);
    log.recordConnection(true);
    log.recordConnection(false);

    expect(log.entries, hasLength(2));
    expect(log.isRealtimeConnected, isFalse);
    expect(log.entries.first.title, 'Firebase 연결 끊김');
    expect(log.unseenProblemCount, 1);
  });

  test('최근 200건만 유지한다', () {
    for (var index = 0; index < GameCommunicationLog.maxEntries + 5; index++) {
      log.add(
        level: GameCommunicationLevel.info,
        title: '상태 수신',
        detail: 'revision=$index',
      );
    }

    expect(log.entries, hasLength(GameCommunicationLog.maxEntries));
    expect(log.entries.first.detail, 'revision=204');
  });
}
