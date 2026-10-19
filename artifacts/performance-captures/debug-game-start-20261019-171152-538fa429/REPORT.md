# Debug 로비 초기화 측정

판정: VALID_OBSERVED_TRIAL

- 전체 로컬 방 정리: 1.333~1.367초
- 사용자 단독 대기 제외: 미측정
- 기기 간 시간은 시계 교환·드리프트 가정을 적용한 추정 범위다. Release 성능으로 사용하지 않는다.
- 논리 명령 시간에는 사전 준비·재시도·정리가 포함된다. 실제 전송 시도 왕복은 별도로 확인한다.
- 태블릿·선공 폰의 자동 작업이 모두 관측상 없고 사용자 탭을 기다리는 구간만 제외한다.

## 수집·판정 문제

없음

- 실제 조작: room_reset
- 시계 품질 기준: 추정 범위 폭 250ms 이하
- 예비 검증 실제 선택·제출: {}

## 같은 기기의 관측 구간

| 기기 | 시작 → 종료 | 소요(ms) |
| --- | --- | ---: |
| tablet | room_reset_start → room_reset_end | 1364.868 |
| tablet | disconnect_cancel_start → disconnect_cancel_end | 5.351 |
| tablet | close_request_start → close_request_end | 1246.323 |
| tablet | disconnect_registration_start → disconnect_registration_end | 5.791 |

연출·요청은 병행할 수 있다. 위 구간을 합산해 전체 시간으로 사용하지 않는다.

## 논리 명령

| 기기 | 함수 | 요청 | 소요(ms) | 결과 |
| --- | --- | ---: | ---: | --- |

세부 단계·요청별 전송 시도·대기 분류는 summary.json과 events.sanitized.jsonl에 보존한다.

- 새 방 후속 관찰 통과: True
- 방 정리 사건은 화면 프레임·실제 조작 가능 완료를 뜻하지 않는다.

## 보조 작업 관측

| 기기 | 작업 | 소요(ms) | 결과 / pending |
| --- | --- | ---: | --- |
| tablet | room_reset | 1364.868 | 1 / False |
| tablet | disconnect_cancel | 5.351 | 1 / False |
| tablet | close_request | 1246.323 | 1 / False |
| tablet | disconnect_registration | 5.791 | 1 / False |