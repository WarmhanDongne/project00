# Debug 게임 시작·재시작 측정

판정: INCOMPLETE_OR_INVALID

- 전체 준비 완료: 미측정
- 사용자 단독 대기 제외: 미측정
- 기기 간 시간은 시계 교환·드리프트 가정을 적용한 추정 범위다. Release 성능으로 사용하지 않는다.
- 논리 명령 시간에는 사전 준비·재시도·정리가 포함된다. 실제 전송 시도 왕복은 별도로 확인한다.
- 태블릿·선공 폰의 자동 작업이 모두 관측상 없고 사용자 탭을 기다리는 구간만 제외한다.

## 수집·판정 문제

- missing_or_duplicate_tablet_deal_started

- 실제 조작: result_restart
- 시계 품질 기준: 추정 범위 폭 250ms 이하
- 예비 검증 실제 선택·제출: {'selection_seen': True, 'submission_seen': True, 'submission_succeeded': True}

## 같은 기기의 관측 구간

| 기기 | 시작 → 종료 | 소요(ms) |
| --- | --- | ---: |
| tablet | tablet_deck_tappable_frame → tablet_deck_entry_started | 0.020 |
| tablet | tablet_deck_entry_started → tablet_deck_entry_completed | 640.562 |
| tablet | tablet_deck_entry_completed → tablet_deck_tap_accepted | 627.790 |
| tablet | tablet_deal_animation_completed → tablet_deal_completed | 0.065 |
| tablet | tablet_deal_completed → tablet_playing_frame | 2560.229 |
| phone_B | pack_entry_started → pack_tappable_frame | 823.684 |
| phone_B | pack_tappable_frame → pack_tap_accepted | 828.635 |
| phone_B | pack_tap_accepted → reveal_completed | 1466.254 |
| tablet | action_accepted → tablet_deck_tappable_frame | 734.765 |
| tablet | action_accepted → tablet_playing_frame | 7382.903 |
| phone_A | controls_started → controls_completed | 932.763 |
| phone_B | controls_started → controls_completed | 920.557 |

연출·요청은 병행할 수 있다. 위 구간을 합산해 전체 시간으로 사용하지 않는다.

## 논리 명령

| 기기 | 함수 | 요청 | 소요(ms) | 결과 |
| --- | --- | ---: | ---: | --- |
| phone_A | game_liars_poker_call_liar | 1 | 478.635 | 성공 |
| phone_A | game_liars_poker_ready_turn | 2 | 533.418 | 성공 |
| phone_A | game_liars_poker_submit_cards | 3 | 525.235 | 성공 |
| phone_A | game_liars_poker_ready_turn | 4 | 453.645 | 성공 |
| phone_A | game_liars_poker_submit_cards | 5 | 550.735 | 성공 |
| tablet | game_liars_poker_start_game | 1 | 712.01 | 성공 |
| tablet | game_liars_poker_complete_dealing | 2 | 1561.756 | 성공 |
| tablet | game_liars_poker_prepare_penalty | 3 | 818.989 | 성공 |
| tablet | game_liars_poker_resolve_penalty | 4 | 594.343 | 성공 |
| tablet | game_liars_poker_complete_dealing | 5 | 1864.426 | 성공 |
| tablet | game_liars_poker_prepare_penalty | 6 | 629.155 | 성공 |
| tablet | game_liars_poker_resolve_penalty | 7 | 862.997 | 성공 |
| tablet | game_liars_poker_complete_dealing | 8 | 2687.668 | 성공 |
| tablet | game_liars_poker_prepare_penalty | 9 | 548.256 | 성공 |
| tablet | game_liars_poker_resolve_penalty | 10 | 3638.068 | 성공 |
| phone_B | game_liars_poker_ready_turn | 1 | 395.501 | 성공 |
| phone_B | game_liars_poker_submit_cards | 2 | 416.614 | 성공 |
| phone_B | game_liars_poker_call_liar | 3 | 437.899 | 성공 |
| phone_B | game_liars_poker_call_liar | 4 | 569.39 | 성공 |

세부 단계·요청별 전송 시도·대기 분류는 summary.json과 events.sanitized.jsonl에 보존한다.


## 보조 작업 관측

| 기기 | 작업 | 소요(ms) | 결과 / pending |
| --- | --- | ---: | --- |