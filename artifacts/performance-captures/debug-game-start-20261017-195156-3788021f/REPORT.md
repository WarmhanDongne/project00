# Debug 게임 시작·재시작 측정

판정: INCOMPLETE_OR_INVALID

- 전체 준비 완료: 미측정
- 사용자 단독 대기 제외: 미측정
- 기기 간 시간은 시계 교환·드리프트 가정을 적용한 추정 범위다. Release 성능으로 사용하지 않는다.
- 논리 명령 시간에는 사전 준비·재시도·정리가 포함된다. 실제 전송 시도 왕복은 별도로 확인한다.
- 사용자 대기는 첫 턴 폰의 관측 구간 중 동시 작업·태블릿 준비와 겹치지 않는 구간만 제외한다.

## 수집·판정 문제

- recovery_during_phone_startup

## 논리 명령

| 기기 | 함수 | 요청 | 소요(ms) / 상태 |
| --- | --- | ---: | ---: |
| tablet | game_liars_poker_start_game | 1 | 884.677 |
| tablet | game_liars_poker_complete_dealing | 2 | 646.935 |
| tablet | game_liars_poker_prepare_penalty | 3 | 675.908 |
| tablet | game_liars_poker_resolve_penalty | 4 | 760.648 |
| phone_A | game_liars_poker_ready_turn | 1 | 423.812 |
| phone_A | game_liars_poker_submit_cards | 2 | 436.815 |
| phone_A | game_liars_poker_submit_cards | 3 | 576.323 |
| phone_A | game_liars_poker_submit_cards | 4 | 398.284 |
| phone_A | game_liars_poker_submit_cards | 5 | 414.087 |
| phone_A | game_liars_poker_submit_cards | 6 | 459.248 |

세부 단계·요청별 전송 시도·대기 분류는 summary.json과 events.sanitized.jsonl에 보존한다.
