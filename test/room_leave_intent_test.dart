import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/room/services/room_leave_intent.dart';

void main() {
  setUp(RoomLeaveIntent.resetForTesting);

  test('아무 기록이 없으면 복원을 막지 않는다', () {
    expect(RoomLeaveIntent.isLeaving('ABCDE'), isFalse);
    expect(RoomLeaveIntent.hasLeft('ABCDE'), isFalse);
    expect(RoomLeaveIntent.blocksRestore('ABCDE'), isFalse);
  });

  test('퇴장 진행 중에는 복원을 막는다', () {
    RoomLeaveIntent.begin('ABCDE');
    expect(RoomLeaveIntent.isLeaving('ABCDE'), isTrue);
    expect(RoomLeaveIntent.hasLeft('ABCDE'), isFalse);
    expect(RoomLeaveIntent.blocksRestore('ABCDE'), isTrue);
  });

  test('퇴장 결과가 미확정이면 복원을 계속 막는다', () {
    RoomLeaveIntent.begin('ABCDE');
    RoomLeaveIntent.fail('ABCDE');
    expect(RoomLeaveIntent.isLeaving('ABCDE'), isTrue);
    expect(RoomLeaveIntent.blocksRestore('ABCDE'), isTrue);
  });

  test('퇴장이 확정되면 다시 입장할 때까지 복원을 막는다', () {
    RoomLeaveIntent.begin('ABCDE');
    RoomLeaveIntent.complete('ABCDE');
    expect(RoomLeaveIntent.isLeaving('ABCDE'), isFalse);
    expect(RoomLeaveIntent.hasLeft('ABCDE'), isTrue);
    expect(RoomLeaveIntent.blocksRestore('ABCDE'), isTrue);

    RoomLeaveIntent.forget('ABCDE');
    expect(RoomLeaveIntent.blocksRestore('ABCDE'), isFalse);
  });

  test('다른 방의 퇴장 기록은 서로 영향을 주지 않는다', () {
    RoomLeaveIntent.complete('ABCDE');
    expect(RoomLeaveIntent.blocksRestore('FGHIJ'), isFalse);
  });

  test('방 코드는 대소문자와 공백을 정규화해 비교한다', () {
    RoomLeaveIntent.begin(' abcde ');
    expect(RoomLeaveIntent.isLeaving('ABCDE'), isTrue);
    RoomLeaveIntent.complete('ABCDE');
    expect(RoomLeaveIntent.hasLeft('abcde'), isTrue);
  });
}
