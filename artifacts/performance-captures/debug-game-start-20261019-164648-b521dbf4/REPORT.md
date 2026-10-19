# Debug 게임 시작·재시작 측정

판정: VALID_OBSERVED_TRIAL

- 전체 준비 완료: 11.144~11.177초
- 사용자 단독 대기 제외: 10.077~10.111초
- 기기 간 시간은 시계 교환·드리프트 가정을 적용한 추정 범위다. Release 성능으로 사용하지 않는다.
- 논리 명령 시간에는 사전 준비·재시도·정리가 포함된다. 실제 전송 시도 왕복은 별도로 확인한다.
- 태블릿·선공 폰의 자동 작업이 모두 관측상 없고 사용자 탭을 기다리는 구간만 제외한다.

## 수집·판정 문제

없음

- 실제 조작: menu_restart
- 시계 품질 기준: 추정 범위 폭 250ms 이하
- 예비 검증 실제 선택·제출: {'selection_seen': True, 'submission_seen': True, 'submission_succeeded': True}

## 같은 기기의 관측 구간

| 기기 | 시작 → 종료 | 소요(ms) |
| --- | --- | ---: |
| tablet | tablet_deck_tappable_frame → tablet_deck_entry_started | 0.019 |
| tablet | tablet_deck_entry_started → tablet_deck_entry_completed | 644.862 |
| tablet | tablet_deck_entry_completed → tablet_deck_tap_accepted | 719.670 |
| tablet | tablet_deck_tap_accepted → tablet_deal_started | 0.100 |
| tablet | tablet_deal_started → tablet_deal_animation_completed | 2810.788 |
| tablet | tablet_deal_animation_completed → tablet_deal_completed | 0.063 |
| tablet | tablet_deal_completed → tablet_playing_frame | 2743.744 |
| phone_A | pack_entry_started → pack_tappable_frame | 752.227 |
| phone_A | pack_tappable_frame → pack_tap_accepted | 417.888 |
| phone_A | pack_tap_accepted → reveal_completed | 1474.423 |
| tablet | action_accepted → tablet_deck_tappable_frame | 809.162 |
| tablet | action_accepted → tablet_playing_frame | 7728.408 |
| phone_A | controls_started → controls_completed | 932.076 |
| phone_B | controls_started → controls_completed | 921.375 |

연출·요청은 병행할 수 있다. 위 구간을 합산해 전체 시간으로 사용하지 않는다.

## 논리 명령

| 기기 | 함수 | 요청 | 소요(ms) | 결과 |
| --- | --- | ---: | ---: | --- |
| tablet | game_liars_poker_start_game | 1 | 943.992 | 성공 |
| tablet | game_liars_poker_complete_dealing | 2 | 1977.069 | 성공 |
| phone_A | game_liars_poker_ready_turn | 1 | 505.409 | 성공 |
| phone_A | game_liars_poker_submit_cards | 2 | 422.235 | 성공 |

세부 단계·요청별 전송 시도·대기 분류는 summary.json과 events.sanitized.jsonl에 보존한다.


## 보조 작업 관측

| 기기 | 작업 | 소요(ms) | 결과 / pending |
| --- | --- | ---: | --- |