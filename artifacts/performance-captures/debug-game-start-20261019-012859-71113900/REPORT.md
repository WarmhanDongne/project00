# Debug 게임 시작·재시작 측정

판정: VALID_OBSERVED_TRIAL

- 전체 준비 완료: 21.732~21.787초
- 사용자 단독 대기 제외: 21.384~21.439초
- 기기 간 시간은 시계 교환·드리프트 가정을 적용한 추정 범위다. Release 성능으로 사용하지 않는다.
- 논리 명령 시간에는 사전 준비·재시도·정리가 포함된다. 실제 전송 시도 왕복은 별도로 확인한다.
- 태블릿·선공 폰의 자동 작업이 모두 관측상 없고 사용자 탭을 기다리는 구간만 제외한다.

## 수집·판정 문제

없음

- 실제 조작: initial_start
- 시계 품질 기준: 추정 범위 폭 250ms 이하
- 예비 검증 실제 선택·제출: {'selection_seen': True, 'submission_seen': True, 'submission_succeeded': True}

## 같은 기기의 관측 구간

| 기기 | 시작 → 종료 | 소요(ms) |
| --- | --- | ---: |
| tablet | tablet_deck_tappable_frame → tablet_deck_entry_started | 0.070 |
| tablet | tablet_deck_entry_started → tablet_deck_entry_completed | 685.887 |
| tablet | tablet_deck_entry_completed → tablet_deck_tap_accepted | 563.573 |
| tablet | tablet_deck_tap_accepted → tablet_deal_started | 2.608 |
| tablet | tablet_deal_started → tablet_deal_animation_completed | 2876.253 |
| tablet | tablet_deal_animation_completed → tablet_deal_completed | 6.819 |
| tablet | tablet_deal_completed → tablet_playing_frame | 4588.177 |
| phone_B | pack_entry_started → pack_tappable_frame | 748.496 |
| phone_B | pack_tappable_frame → pack_tap_accepted | 347.955 |
| phone_B | pack_tap_accepted → reveal_completed | 1455.465 |
| tablet | action_accepted → tablet_deck_tappable_frame | 7584.963 |
| tablet | action_accepted → tablet_playing_frame | 16308.350 |
| phone_B | controls_started → controls_completed | 927.706 |
| phone_A | controls_started → controls_completed | 931.539 |

연출·요청은 병행할 수 있다. 위 구간을 합산해 전체 시간으로 사용하지 않는다.

## 논리 명령

| 기기 | 함수 | 요청 | 소요(ms) | 결과 |
| --- | --- | ---: | ---: | --- |
| tablet | game_liars_poker_start_game | 1 | 2897.922 | 성공 |
| tablet | game_liars_poker_complete_dealing | 2 | 3185.484 | 성공 |
| phone_B | game_liars_poker_ready_turn | 1 | 2758.71 | 성공 |
| phone_B | game_liars_poker_submit_cards | 2 | 742.339 | 성공 |

세부 단계·요청별 전송 시도·대기 분류는 summary.json과 events.sanitized.jsonl에 보존한다.


## 보조 작업 관측

| 기기 | 작업 | 소요(ms) | 결과 / pending |
| --- | --- | ---: | --- |
| tablet | cleanup_scope | 1047.339 | 1 / False |
| tablet | cleanup_lookup | 171.605 | 1 / False |