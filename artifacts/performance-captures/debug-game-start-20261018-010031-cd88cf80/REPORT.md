# Debug 게임 시작·재시작 측정

판정: INCOMPLETE_OR_INVALID

- 전체 준비 완료: 미측정
- 사용자 단독 대기 제외: 미측정
- 기기 간 시간은 시계 교환·드리프트 가정을 적용한 추정 범위다. Release 성능으로 사용하지 않는다.
- 논리 명령 시간에는 사전 준비·재시도·정리가 포함된다. 실제 전송 시도 왕복은 별도로 확인한다.
- 태블릿·선공 폰의 자동 작업이 모두 관측상 없고 사용자 탭을 기다리는 구간만 제외한다.

## 수집·판정 문제

- collector_failed_or_incomplete
- failed_phase_collecting

- 실제 조작: initial_start
- 시계 품질 기준: 추정 범위 폭 250ms 이하
- 예비 검증 실제 선택·제출: {'selection_seen': True, 'submission_seen': True, 'submission_succeeded': True}

## 같은 기기의 관측 구간

| 기기 | 시작 → 종료 | 소요(ms) |
| --- | --- | ---: |
| tablet | tablet_deck_tappable_frame → tablet_deck_entry_started | 0.032 |
| tablet | tablet_deck_entry_started → tablet_deck_entry_completed | 652.910 |
| tablet | tablet_deck_entry_completed → tablet_deck_tap_accepted | 505.182 |
| tablet | tablet_deck_tap_accepted → tablet_deal_started | 0.069 |
| tablet | tablet_deal_started → tablet_deal_animation_completed | 2824.108 |
| tablet | tablet_deal_animation_completed → tablet_deal_completed | 0.061 |
| tablet | tablet_deal_completed → tablet_playing_frame | 1395.860 |
| phone_B | pack_entry_started → pack_tappable_frame | 772.605 |
| phone_B | pack_tappable_frame → pack_tap_accepted | 167.558 |
| phone_B | pack_tap_accepted → reveal_completed | 1458.021 |
| tablet | action_accepted → tablet_deck_tappable_frame | 3365.618 |
| tablet | action_accepted → tablet_playing_frame | 8743.840 |
| phone_A | controls_started → controls_completed | 932.118 |
| phone_B | controls_started → controls_completed | 932.294 |

연출·요청은 병행할 수 있다. 위 구간을 합산해 전체 시간으로 사용하지 않는다.

## 논리 명령

| 기기 | 함수 | 요청 | 소요(ms) | 결과 |
| --- | --- | ---: | ---: | --- |
| tablet | game_liars_poker_start_game | 1 | 635.851 | 성공 |
| tablet | game_liars_poker_complete_dealing | 2 | 498.271 | 성공 |
| phone_B | game_liars_poker_ready_turn | 1 | 511.658 | 성공 |
| phone_B | game_liars_poker_submit_cards | 2 | 399.286 | 성공 |

세부 단계·요청별 전송 시도·대기 분류는 summary.json과 events.sanitized.jsonl에 보존한다.
