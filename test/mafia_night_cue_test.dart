import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/mafia/animations/role_deal_toss_animation.dart';
import 'package:project00/games/mafia/models/mafia_role.dart';
import 'package:project00/games/mafia/models/mafia_state_models.dart';
import 'package:project00/games/mafia/sound/mafia_night_cue_speaker.dart';
import 'package:project00/games/mafia/sound/mafia_sounds.dart';

//=======================직업 효과음·분배 시간표==============================
// 확정(2026-08):
//   1. 총성 등 직업 소리는 밤이 시작될 때 자동으로 울리지 않고, 그 직업이
//      **선택을 완료한 순간** 태블릿에서 울립니다.
//   2. 휴대폰의 신분 카드는 태블릿 **분배 연출이 끝난 뒤에** 들어옵니다.
void main() {
  group('밤 행동 소리 신호', () {
    test('서버가 보낸 신호를 읽는다', () {
      final cue = MafiaNightActionCue.fromMap(<Object?, Object?>{
        'id': 3,
        'action': 'eliminate',
      });
      expect(cue?.id, 3);
      expect(cue?.action, 'eliminate');
    });

    test('신호가 없거나 깨져 있으면 소리를 내지 않는다', () {
      // 아직 아무도 제출하지 않은 밤입니다.
      expect(MafiaNightActionCue.fromMap(null), isNull);
      // 번호가 0이면 신호가 아닙니다(구버전 서버·초기값).
      expect(
        MafiaNightActionCue.fromMap(<Object?, Object?>{
          'id': 0,
          'action': 'eliminate',
        }),
        isNull,
      );
      expect(MafiaNightActionCue.fromMap(<Object?, Object?>{'id': 1}), isNull);
    });

    test('제거 행동에는 총성을 냅니다', () {
      // 서버는 행동 종류를 [MafiaNightAction]의 이름 그대로 보냅니다. 이름을
      // 바꾸면 소리가 조용히 사라지므로 함께 확인합니다.
      expect(MafiaNightAction.eliminate.name, 'eliminate');
      expect(
        MafiaSounds.nightActionSound(MafiaNightAction.eliminate.name),
        MafiaSounds.gunshot,
      );
    });

    test('소리 파일이 없는 행동은 조용히 지나간다', () {
      // 파일이 들어오면 이 목록이 하나씩 줄어듭니다.
      expect(MafiaSounds.nightActionSound('protect'), isNull);
      expect(MafiaSounds.nightActionSound('investigate'), isNull);
      // 이 빌드가 모르는 행동(서버가 먼저 배포된 경우)도 깨지지 않습니다.
      expect(MafiaSounds.nightActionSound('teleport'), isNull);
    });
  });

  group('소리를 낼 순간', () {
    MafiaNightActionCue cue(int id, [String action = 'eliminate']) =>
        MafiaNightActionCue(id: id, action: action);

    test('첫 제출에 총성을 낸다', () {
      final speaker = MafiaNightCueSpeaker();
      // 밤이 시작될 때는 신호가 없습니다.
      expect(speaker.soundFor(null), isNull);
      // 마피아가 선택을 완료한 순간입니다.
      expect(speaker.soundFor(cue(1)), MafiaSounds.gunshot);
    });

    test('같은 신호로는 두 번 울리지 않는다', () {
      final speaker = MafiaNightCueSpeaker();
      speaker.soundFor(null);
      expect(speaker.soundFor(cue(1)), MafiaSounds.gunshot);
      // 타이머·인원수 때문에 상태가 다시 와도 조용합니다.
      expect(speaker.soundFor(cue(1)), isNull);
      expect(speaker.soundFor(cue(1)), isNull);
      // 다음 사람이 제출하면 다시 울립니다.
      expect(speaker.soundFor(cue(2)), MafiaSounds.gunshot);
    });

    test('재접속으로 이미 있던 신호는 울리지 않는다', () {
      // 붙는 순간의 신호는 이미 지나간 선택입니다.
      final speaker = MafiaNightCueSpeaker();
      expect(speaker.soundFor(cue(3)), isNull);
      // 그 뒤에 새로 온 신호는 울립니다.
      expect(speaker.soundFor(cue(4)), MafiaSounds.gunshot);
    });

    test('신호가 지워져도(게임 재시작) 울리지 않는다', () {
      final speaker = MafiaNightCueSpeaker();
      speaker.soundFor(null);
      speaker.soundFor(cue(1));
      expect(speaker.soundFor(null), isNull);
      // 새 게임의 첫 제출은 다시 1번이지만, 지워진 뒤라 울립니다.
      expect(speaker.soundFor(cue(1)), MafiaSounds.gunshot);
    });

    test('소리 파일이 없는 행동은 조용히 지나가고 신호는 소비된다', () {
      final speaker = MafiaNightCueSpeaker();
      speaker.soundFor(null);
      expect(speaker.soundFor(cue(1, 'protect')), isNull);
      // 그 신호를 다시 봐도 아무 일도 없습니다.
      expect(speaker.soundFor(cue(1, 'protect')), isNull);
      expect(speaker.soundFor(cue(2)), MafiaSounds.gunshot);
    });
  });

  group('분배 시간표', () {
    test('휴대폰이 기다리는 시간은 태블릿 분배 시간과 같다', () {
      // 더미 등장 0.62 + 발사 간격 0.24 × (인원−1) + 비행 0.56
      expect(MafiaRoleDealTossAnimation.totalDuration(6).inMilliseconds, 2380);
      expect(MafiaRoleDealTossAnimation.totalDuration(12).inMilliseconds, 3820);
      expect(MafiaRoleDealTossAnimation.totalDuration(1).inMilliseconds, 1180);
      // 인원이 0이어도 음수가 되지 않습니다.
      expect(MafiaRoleDealTossAnimation.totalDuration(0).inMilliseconds, 1180);
    });
  });
}
