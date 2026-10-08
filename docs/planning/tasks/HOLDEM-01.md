# HOLDEM-01

다운로드형 텍사스 홀덤·복구 흐름 보완

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 구현·검증
기록은 해당 후보의 근거이며, 다른 브랜치나 후속 후보의 통과로 확대하지 않는다.

## 원격 구현 후보와 이관 근거

- 원래 등록일: 2026-10-06. `origin/newgui`에 이미 있는 HOLDEM-01 ID를 유지해
  2026-10-08 현재 작업 목록에도 연결했다. 새 게임을 다시 구현하라는 요청이 아니다.
- 분류 결정(2026-10-08): 사용자가 HOLDEM-01을 **출시 전 필수**로 지정했다.
  현재 분류·상태·다음 행동의 단일 원본은 TASKS.md에 유지한다. 이 결정은 원격 후보의
  병합·복구 검증 완료 또는 담당 범위·계약 변경·production 접근·배포 승인을 뜻하지 않는다.
- 근거: [newgui 작업 기록과 계획](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/docs/planning/TASKS.md#holdem-01),
  [MVP 계획](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/docs/planning/HOLDEM_MVP_PLAN.md).
  가상 칩 단일 테이블, 태블릿 공용 화면·휴대폰 개인 패/행동, 서버 권위와 원격 에셋
  구조의 구현 후보가 있다. 제품 조건과 기존 배포·검증 이력은 해당 tracked 기록에 보존한다.
- 비교 기준: newgui `999c3e99086b9f917ea941cd8f283b8ac40f3f85`. 현재 checkout `02669c7`에는
  홀덤 코드가 없고 이번 작업에서도 병합하지 않았다. 원격 기록의 과거 FULL·배포 성공을
  이번 복구 문제의 해결이나 최신 후보의 검증으로 해석하지 않는다. 운영 조회·배포는 미실행이다.

## 2026-10-08 복구·진행 누락의 정적 확인

- [휴대폰 재시도](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_holdem/lib/phone/phone_board.dart#L121)와
  [태블릿 재시도](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_holdem/lib/tablet/tablet_board.dart#L147)는
  `clearError`만 연결해 서버 요청을 재실행하지 않는다.
- [태블릿 자동 진행](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_holdem/lib/tablet/tablet_board.dart#L80)은
  분배·결과·턴 마감 요청의 bool 결과를 처리하지 않고 같은 phase/hand/deadline에서 타이머를
  다시 예약하지 않는다. 공용 요청 재시도도 실패하고 서버 상태가 유지되는 경우의 정지 경로를 검증한다.
- [태블릿 종료 화면](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_holdem/lib/tablet/tablet_board.dart#L170)은
  정상 우승만 결과를 표시하며 finished에서는 메뉴를 숨긴다. 휴대폰은 비정상 finished에
  closing 단계만 선택하고, 상위 공용 경로도 해당 서버 종료만으로 route를 닫지 않는다.
  인원 부족·서버 종료 뒤 자동 대기실 복귀가 누락된다. 로컬 설정 종료는 직접 pop하므로
  이 문제와 구분하며 OS 뒤로가기 등 다른 탈출 경로까지 불가능하다고 표현하지 않는다.
- [턴 만료](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/holdem/game.ts#L188)는
  deadline을 null만 검사하고, [진행 요청 검증](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/holdem/validation.ts#L47)은
  public interruption만 확인한다. controller pause 및 RTDB에서 누락된 deadline을 포함해 검증한다.
- [분배 완료](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/holdem/complete-dealing.ts#L10)와
  [결과 완료](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/holdem/complete-result.ts#L10)는
  기대 핸드·진행 버전 식별자가 없다. 이전 핸드의 지연 요청이 새 핸드의 같은 단계에 도착하는 경계를 검증한다.

이 내용은 코드 확인이며 새 자동 테스트·실기기 재현 결과는 아니다. 최소 인원에서
alive와 stack > 0 판정의 차이는 CORE-REVIEW-01, 퇴장 응답 유실과 중단·옛 요청의
공용 계약은 SESSION-RECONNECT-02, processedCommands 수명은 COST-01과 연결한다.

## 예정 작업·승인 경계·완료 조건

- [ ] 실패한 명령 종류와 재시도 가능 상태를 보존해 실제 요청을 다시 실행한다.
  중복 행동·응답 유실·같은 commandId 처리와 새 핸드 전환을 함께 검증한다.
- [ ] 분배·결과·턴 마감 자동 요청의 실패와 진행 중 요청 충돌을 처리하고, 같은 상태에서도
  합의한 정책으로 다시 진행한다. 오래된 단계의 후속 요청은 무효화한다.
- [ ] 서버발 비정상 종료에서 양 기기 게임 route를 한 번 닫고 대기실을 일관되게 복원한다.
  직접 종료·방 삭제·강퇴·최소 인원 미달과 정상 우승·재시작 경로의 회귀를 확인한다.
- [ ] 다중 단절, controller pause 중 타임아웃, deadline 누락, 이전 핸드 요청,
  올인·제외 시 인원 판정과 퇴장 성공 응답 유실을 재현한다.
- [ ] 홀덤 package·Functions 테스트가 공식 targeted/FULL/CI 경로에서 실행되게 하고,
  실제 양 기기 토너먼트와 단절·재실행·에셋 실패를 검증한다.
- 제품 규칙, API·persistent data·중요 상태 머신 변경, 패키지 밖 구현과 배포는 기존
  담당·승인 경계를 따른다. 이번 등록만으로 게임 정책이나 배포 필요성을 확정하지 않는다.
- 완료 조건: 위 복구 누락과 원격 HOLDEM-01의 남은 구현·검증 조건을 모두 확인하고,
  현재 후보의 테스트·FULL 및 필요한 기기 결과를 남긴다. 과거 다른 후보의 PASS는 대체 근거가 아니다.

관련 작업: [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md),
[NEWGUI-RECOVERY-01](NEWGUI-RECOVERY-01.md), [TEST-REGRESSION-01](TEST-REGRESSION-01.md),
[CORE-REVIEW-01](CORE-REVIEW-01.md), [COST-01](COST-01.md).

관련 기록: [2026-10-08 네트워크·newgui 작업 등록](../logs/2026-10.md#2026-10-08--네트워크newgui-작업-등록).
