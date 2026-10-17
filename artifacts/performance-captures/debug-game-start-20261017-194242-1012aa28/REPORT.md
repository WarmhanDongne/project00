# Debug 게임 시작·재시작 측정

판정: INCOMPLETE_OR_INVALID

- 전체 준비 완료: 미측정
- 사용자 단독 대기 제외: 미측정
- 기기 간 시간은 시계 교환·드리프트 가정을 적용한 추정 범위다. Release 성능으로 사용하지 않는다.
- 논리 명령 시간에는 사전 준비·재시도·정리가 포함된다. 실제 전송 시도 왕복은 별도로 확인한다.
- 사용자 대기는 첫 턴 폰의 관측 구간 중 동시 작업·태블릿 준비와 겹치지 않는 구간만 제외한다.

## 수집·판정 문제

- missing_or_ambiguous_completion

## 논리 명령

| 기기 | 함수 | 요청 | 소요(ms) / 상태 |
| --- | --- | ---: | ---: |
| tablet | game_liars_poker_start_game | 1 | 3085.935 |
| tablet | game_liars_poker_complete_dealing | 2 | 2773.344 |
| tablet | game_liars_poker_prepare_penalty | 3 | 2811.82 |
| tablet | game_liars_poker_resolve_penalty | 4 | 2620.988 |
| tablet | game_liars_poker_complete_dealing | 5 | 712.676 |
| tablet | game_liars_poker_prepare_penalty | 6 | 445.279 |
| tablet | game_liars_poker_resolve_penalty | 7 | 478.228 |
| tablet | game_liars_poker_complete_dealing | 8 | 907.356 |
| tablet | game_liars_poker_prepare_penalty | 9 | 480.482 |
| tablet | game_liars_poker_resolve_penalty | 10 | 452.957 |
| phone_A | game_liars_poker_submit_cards | 1 | 323.434 |
| phone_A | game_liars_poker_submit_cards | 2 | 339.794 |
| phone_A | game_liars_poker_submit_cards | 3 | 356.694 |
| phone_A | game_liars_poker_submit_cards | 4 | 358.948 |
| phone_A | game_liars_poker_pass_challenge | 5 | 2717.978 |
| phone_A | game_liars_poker_ready_turn | 6 | 396.207 |
| phone_A | game_liars_poker_submit_cards | 7 | 377.879 |
| phone_A | game_liars_poker_submit_cards | 8 | 363.581 |
| phone_A | game_liars_poker_call_liar | 9 | 769.575 |
| phone_A | game_liars_poker_submit_cards | 10 | 377.695 |
| phone_A | game_liars_poker_submit_cards | 11 | 379.471 |

세부 단계·요청별 전송 시도·대기 분류는 summary.json과 events.sanitized.jsonl에 보존한다.
