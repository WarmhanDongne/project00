# COST-01

Functions 과금 점검·최적화

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

**Functions 과금 점검·최적화**

- 사용자 보고: 유저 없이 개발하는 과정에서 Firebase 과금 약 1,200원이 발생했고,
  Cloud Functions 관련 점검이 필요하다. 실제 청구 서비스·원인은 아직 확인하지 않았다.
- 조사: 청구 기간·항목과 함수 실행 원인, 호출량, 불필요한 반복 실행 여부를 확인한다.
  과금 발생 자체를 비효율의 확정 근거로 삼지 않는다.
- 추가 조사(2026-10-04): 기존 방·유령 참가자·생성 요청 정리의 부분 실패와 후보 제한,
  게임별 `processedCommands` 크기·수명·transaction 비용을 확인한다. 명령 기록의
  재시도 가능 기간·늦은 요청 거절을 정하기 전에 TTL이나 개수 제한으로 임의 삭제하지 않는다.
  구현 존재와 운영 미확인 범위를 구분하고 최신 코드로 재확인한다.
- 완료 조건: 비용 원인과 필요한 개선을 정리하고, 수정했다면 전후 실행량·비용 등
  확보 가능한 근거와 회귀 검증을 남긴다. 관찰 기간이 부족하면 효과 확인은 검증 대기로 둔다.

## 2026-10-08 newgui 999c3e9 기준 추가 조사

- 조사 기준: `origin/newgui`의 `999c3e99086b9f917ea941cd8f283b8ac40f3f85`를
  checkout 변경 없이 정적으로 확인했다. 운영 청구·실행량·데이터 규모 조회, 새 테스트,
  배포는 하지 않았으며 약 1,200원 과금의 실제 원인은 여전히 미확인이다.
- 정리 처리량: [방 정리](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/room/realtime-room-lifecycle.ts#L659)는
  조회별 후보 500개 제한을 유지한다. [중단 만료 정리](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/game-interruption/expire-scheduler.ts#L52)와
  유령 참가자 정리도 후보 제한을 사용한다. 후보 누적·부분 실패·실행 주기와 처리량을
  구분해 검증하고, waiting 3분·playing 15분을 정확한 삭제 시각으로 표현하지 않는다.
- 방·controller 매핑·생성 예약의 부분 실패 정합성은
  [CORE-REVIEW-01](CORE-REVIEW-01.md) 및 [ROOM-CREATE-REQUEST-01](ROOM-CREATE-REQUEST-01.md)과
  연결한다. 완료된 ROOM-CLEANUP-01의 과거 운영 확인을 현재 처리 규모나 예약 잔류의
  해결 근거로 확대하지 않는다.
- 명령 기록: 기존 3게임에 Holdem을 포함해 `processedCommands` 증가량·수명과 방 전체
  transaction 비용을 조사한다. Holdem은 [새 토너먼트 생성](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/holdem/game.ts#L97)에서
  기록을 초기화하지만 [다음 핸드 생성](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/holdem/game.ts#L281)에서는
  유지한다. 이 코드 사실만으로 과금 원인이나 불필요한 비용을 확정하지 않는다.
- 같은 commandId의 중복 처리 방지, 재시도 가능 기간, 늦은 이전 판·핸드 요청 거절
  계약을 확인하기 전 TTL이나 개수 제한으로 기록을 임의 삭제하지 않는다. 계약 변경과
  운영 조회·정리·배포는 기존 승인 경계를 유지하며 현재 출시 분류도 그대로 둔다.
