/// 게임이 '정상적으로 승부가 나서' 끝났는지 판단하는 공용 규칙입니다.
///
/// 휴대폰은 이 판단으로 결과 화면을 유지할지, 게임 화면을 닫고 방으로 돌아갈지
/// 정합니다. 두 게임 서버가 모두 지키는 불변 조건은 하나입니다.
///
/// > **승부가 나지 않은 모든 종료는 `winnerUid`를 null로 만들고 `finishReason`을
/// > 남긴다.**
///
/// | 종료 경로 | finishReason | winnerUid |
/// | --- | --- | --- |
/// | 마지막 생존자 확정 | 없음 또는 `winner` | 생존자 uid |
/// | 태블릿 수동 종료 | `manual` | null |
/// | 인원 부족 | `insufficientPlayers` | null |
/// | 계속 진행 투표 만료 | `interruptionVoteExpired` | null |
///
/// 그래서 "나가야 하는 상황"을 사유 목록으로 나열하지 않고, **정상 결과가
/// 아니면 나간다**로 뒤집어 판단합니다. 목록 방식은 서버에 새 종료 사유가
/// 하나만 늘어도 휴대폰이 결과 화면에 갇힙니다. 실제로 파이널콜이 사유 목록을
/// 쓰다가 이 문제를 안고 있었습니다.
///
/// 새 게임을 추가할 때도 위 불변 조건만 지키면 이 함수를 그대로 쓸 수 있습니다.
bool isNaturalGameResult({
  required bool isFinished,
  required String? winnerUid,
  required String? finishReason,
}) {
  if (!isFinished) return false;
  if (winnerUid == null) return false;
  return finishReason == null || finishReason == 'winner';
}
