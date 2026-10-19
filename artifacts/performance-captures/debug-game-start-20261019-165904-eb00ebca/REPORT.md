# Debug 게임 시작·재시작 측정

판정: INCOMPLETE_OR_INVALID

- 전체 준비 완료: 미측정
- 사용자 단독 대기 제외: 미측정
- 기기 간 시간은 시계 교환·드리프트 가정을 적용한 추정 범위다. Release 성능으로 사용하지 않는다.
- 논리 명령 시간에는 사전 준비·재시도·정리가 포함된다. 실제 전송 시도 왕복은 별도로 확인한다.
- 태블릿·선공 폰의 자동 작업이 모두 관측상 없고 사용자 탭을 기다리는 구간만 제외한다.

## 수집·판정 문제

- ambiguous_root_start_command
- collector_failed_or_incomplete
- device_finalization_failed_tablet
- device_missing_target_game
- expected_one_action
- failed_phase_collecting
- local_http_connection_state
- missing_actual_action_source
- missing_or_ambiguous_completion
- missing_or_duplicate_capture_stopped_tablet
- missing_or_duplicate_tablet_deal_animation_completed
- missing_or_duplicate_tablet_deal_completed
- missing_or_duplicate_tablet_deal_started
- missing_or_duplicate_tablet_deck_entry_completed
- missing_or_duplicate_tablet_deck_entry_started
- missing_or_duplicate_tablet_deck_tap_accepted
- missing_or_duplicate_tablet_deck_tappable_frame
- missing_or_duplicate_tablet_playing_frame
- missing_successful_game_liars_poker_complete_dealing
- missing_successful_game_liars_poker_start_game
- participant_phone_coverage_unconfirmed
- unmatched_or_multiple_games

- 실제 조작: None
- 시계 품질 기준: 추정 범위 폭 250ms 이하
- 예비 검증 실제 선택·제출: {'selection_seen': False, 'submission_seen': False, 'submission_succeeded': False}
- 수집기 진단: {"phase": "finalizing", "role": "tablet", "operation": "stop", "attempt": 1, "code": "local_http_connection_state"}
- 수집기 진단: {"phase": "finalizing", "role": "tablet", "operation": "stop", "attempt": 2, "code": "local_http_connection_state"}
- 수집기 진단: {"phase": "collecting", "code": "local_http_connection_state"}

## 같은 기기의 관측 구간

| 기기 | 시작 → 종료 | 소요(ms) |
| --- | --- | ---: |

연출·요청은 병행할 수 있다. 위 구간을 합산해 전체 시간으로 사용하지 않는다.

## 논리 명령

| 기기 | 함수 | 요청 | 소요(ms) | 결과 |
| --- | --- | ---: | ---: | --- |
| tablet | game_liars_poker_start_game | 1 | 8028.705 | 예외 |
| tablet | game_liars_poker_start_game | 2 | 8008.26 | 예외 |
| tablet | game_liars_poker_start_game | 3 | 8031.866 | 예외 |

세부 단계·요청별 전송 시도·대기 분류는 summary.json과 events.sanitized.jsonl에 보존한다.


## 보조 작업 관측

| 기기 | 작업 | 소요(ms) | 결과 / pending |
| --- | --- | ---: | --- |