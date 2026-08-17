import 'package:flutter_test/flutter_test.dart';
import 'package:project00/games/shared/game_flow/game_finish.dart';

void main() {
  bool natural({
    bool isFinished = true,
    String? winnerUid = 'winner-uid',
    String? finishReason,
  }) {
    return isNaturalGameResult(
      isFinished: isFinished,
      winnerUid: winnerUid,
      finishReason: finishReason,
    );
  }

  test('진행 중인 게임은 정상 결과가 아니다', () {
    expect(natural(isFinished: false), isFalse);
  });

  //=======================서버가 실제로 만드는 상태==============================
  // 두 게임 서버의 종료 경로를 그대로 옮겨 놓은 표입니다. 서버에서 종료 경로를
  // 바꾸면 이 테스트가 먼저 깨져야 합니다.
  test('마지막 생존자가 정해진 종료만 결과 화면을 유지한다', () {
    // 파이널콜: finishReason 없이 winnerUid만 설정합니다.
    expect(natural(), isTrue);
    // 라이어스포커: finishReason을 'winner'로 남깁니다.
    expect(natural(finishReason: 'winner'), isTrue);
  });

  test('승부가 나지 않은 종료는 모두 퇴장 대상이다', () {
    for (final reason in [
      'manual',
      'insufficientPlayers',
      'interruptionVoteExpired',
    ]) {
      expect(
        natural(winnerUid: null, finishReason: reason),
        isFalse,
        reason: '$reason 종료는 휴대폰이 게임 화면을 닫아야 합니다',
      );
    }
  });

  //=======================사유 목록 방식의 함정==============================
  // 예전 파이널콜은 나가야 할 사유를 나열해서 판단했습니다. 서버에 사유가 하나만
  // 늘어도 휴대폰이 결과 화면에 갇혔습니다. 뒤집어 판단하면 모르는 사유에서도
  // 안전한 쪽으로 동작합니다.
  test('처음 보는 종료 사유에서도 퇴장한다', () {
    expect(natural(winnerUid: null, finishReason: 'somethingNew'), isFalse);
  });

  test('승자 없이 사유도 없는 종료에서도 갇히지 않는다', () {
    expect(natural(winnerUid: null), isFalse);
  });

  test('게임 노드가 지워져 수동 종료로 바뀌면 이전 승자가 남아 있어도 퇴장한다', () {
    // 노드 삭제 시 클라이언트는 finishReason만 manual로 덮어씁니다.
    expect(natural(finishReason: 'manual'), isFalse);
  });
}
