import 'package:flutter_test/flutter_test.dart';
import 'package:project00/platform/home/phone/models/room_join_feedback.dart';

void main() {
  group('roomJoinFeedbackFor', () {
    test('maps a missing room to the invalid-code state', () {
      final feedback = roomJoinFeedbackFor('방을 찾을 수 없습니다.');

      expect(feedback.message, '존재하지 않는 참여 코드입니다.');
      expect(feedback.tone, RoomJoinFeedbackTone.danger);
    });

    test('maps capacity errors to the warning state', () {
      final feedback = roomJoinFeedbackFor('방 인원이 초과되었습니다.');

      expect(feedback.message, '이 그룹은 정원을 초과했습니다.');
      expect(feedback.tone, RoomJoinFeedbackTone.warning);
    });

    test('maps closed and playing rooms to dedicated messages', () {
      expect(roomJoinFeedbackFor('종료된 방입니다.').message, '이미 종료된 그룹입니다.');
      expect(
        roomJoinFeedbackFor('이미 진행 중인 게임에는 새로 참가할 수 없습니다.').message,
        '이미 게임이 진행 중인 그룹입니다.',
      );
    });

    test('does not expose unknown server details', () {
      final feedback = roomJoinFeedbackFor('sensitive internal detail');

      expect(feedback.message, '그룹에 참여하지 못했습니다. 잠시 후 다시 시도해 주세요.');
      expect(feedback.tone, RoomJoinFeedbackTone.danger);
    });
  });
}
