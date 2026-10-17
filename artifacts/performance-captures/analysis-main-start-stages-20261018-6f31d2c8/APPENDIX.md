# 부록: 계산·검증·파일 대응

## A. 범위와 표본 선택

사용자가 제시한 최초 시작 6·메뉴 5·결과 5에, 추가 포함을 승인한 결과 재시작 015354-ef07417b 1건을 더했다. 총 17건이다. 게임 시작 3번의 복구본은 원본과 같은 시험이며 한 번만 센다. 결과 6번은 추가 식별 번호이고 수집 시각 순서가 아니다. 예비 수집과 실패 시도는 성능 중앙값에서 제외하지만 아래에 보존한다. 실패율 추정은 이번 보고서의 범위가 아니다.

| ID | 원본/분석 폴더 | 선공 | 이벤트 | 조건 |
| --- | --- | --- | --- | --- |
| initial_start-1 | debug-game-start-20261018-005036-0503abb7 | phone_A | 223 | unspecified |
| initial_start-2 | debug-game-start-20261018-005153-def595be | phone_A | 232 | unspecified |
| initial_start-3 | recovered-debug-game-start-20261018-010031-4153e545 | phone_B | 258 | unspecified |
| initial_start-4 | debug-game-start-20261018-011357-b4d246c7 | phone_A | 229 | unspecified |
| initial_start-5 | debug-game-start-20261018-011455-1bb8ff18 | phone_A | 235 | unspecified |
| initial_start-6 | debug-game-start-20261018-011603-364f9072 | phone_B | 231 | unspecified |
| menu_restart-1 | debug-game-start-20261018-013848-20c24974 | phone_A | 254 | repeated |
| menu_restart-2 | debug-game-start-20261018-013939-85fe8948 | phone_B | 311 | repeated |
| menu_restart-3 | debug-game-start-20261018-014055-7e247e0f | phone_A | 230 | repeated |
| menu_restart-4 | debug-game-start-20261018-014137-65719ea8 | phone_A | 230 | repeated |
| menu_restart-5 | debug-game-start-20261018-014211-58bb46e0 | phone_B | 226 | repeated |
| result_restart-1 | debug-game-start-20261018-014548-0f5eb212 | phone_A | 233 | repeated |
| result_restart-2 | debug-game-start-20261018-014747-012542a4 | phone_A | 238 | repeated |
| result_restart-3 | debug-game-start-20261018-015516-37282d37 | phone_B | 237 | repeated |
| result_restart-4 | debug-game-start-20261018-015634-2d282724 | phone_B | 229 | repeated |
| result_restart-5 | debug-game-start-20261018-015802-66b67dab | phone_B | 231 | repeated |
| result_restart-6 | debug-game-start-20261018-015354-ef07417b | phone_A | 239 | repeated |

제외한 예비 수집: 002045-9b6b7c9b / 002756-323a0f5a / 002851-bc6fb4ee. 기존 영상을 기준으로 철회했던 수치는 사용하지 않았다.

| 제외 기록 | 사유 / 근거 |
| --- | --- |
| 005259-48330e9b | 수집 도중 FAILED, 209건. 유효 완료로 복구·검증하지 않아 제외. |
| 005434-e1faa81d | 수집 준비 실패, 0건. 당시 failed_phase_clock_preflight 표기는 원인 분류의 한계가 있었음. |
| 010031-cd88cf80 원본 | 원본 FAILED 보존. 복구본 258건을 같은 시험 1건으로 대체하여 사용. |
| 012816-d5c02b32 | 연결 단계 실패 0건. 사용자 메모: 태블릿 연결하지 않고 실행. |
| 013223-0f3392e4 | 수집 중 시간 초과, 60건. B 종료 실패. 사용자 메모: 네트워크 오류 실패; 게임 서버 오류로 확정하지 않음. |
| 013519-5b2c6e88 | 이전 수집이 남아 arm 거절, 0건. already_armed. |

## B. 측정 경계와 계산식

시작: 태블릿의 action_accepted(최초는 설정 완료, 메뉴/결과는 해당 버튼의 실제 콜백). 종료: 새 게임에서 tablet_playing_frame과 실제 선공 phone_first_turn_playable_frame 중 늦은 것. 이번에는 17건 모두 폰 완료의 가능한 가장 이른 시각이 태블릿 완료의 가장 늦은 시각보다 뒤이므로 “폰이 마지막”이 시계 추정 범위로도 구분된다.

동일 기기 시간은 단조 시계의 종료−시작이다. CSV lower=upper는 저장된 시계 수치의 정확한 차이라는 뜻이며 물리적 계측 오차가 0이라는 뜻은 아니다. 서로 다른 기기는 host_range(가까운 clock 교환 5개, 200ppm 드리프트·기기당 5ms 여유)의 범위를 사용한다. 이벤트 X의 범위가 [XL,XU], Y가 [YL,YU]면 Δ=[YL−XU,YU−XL]. 시작 S, 태블릿 T, 폰 P에 대해 전체=[max(TL,PL)−SU, max(TU,PU)−SL].

보고서 대표값은 각 시험 범위의 중점이며 경로별 중앙값은 중점들의 중앙값이다. 최소~최대도 중점들의 최소~최대이고 신뢰구간·백분위가 아니다. 각 원시 추정 범위와 중앙값 하한·상한은 measurements.json/stage_statistics.csv에 보존한다. 단계 중앙값을 더해 전체 중앙값으로 만들지 않는다.

사용자 단독 대기: tablet/선공의 관측상 자동 작업 없음(명령 없음, 세션·route·foreground 허용)과 탭 대기 조건을 충족하는 시간 교집합을 구한 뒤 합집합으로 중복 제거한다. 태블릿 등장은 제외하지 않고, 폰의 관련 없는 다른 차례 대기는 더하지 않는다. 완전히 다른 기기의 유휴 범위 안에 들어간 동종 시계 대기는 단조 차이와 드리프트로 계산한다. 전체 대기 제외 범위=[max(0,전체L−대기U), 전체U−대기L]. 즉시 탭 가상 시험·CPU 시간·서버 단독 시간으로 해석하지 않는다.

폰 상태 반영 경계는 새 게임 alias의 선공 private_applied 첫 이벤트다. 이번 표본에서는 배분 연출 종료 뒤이면서 GAME START/공개 단계와 카드팩 등장 앞에 있다. 개인 payload나 손패 내용은 읽지 않았다. 초기 경로에서 첫 손패 반영→카드팩 생성 구간은 GAME START 및 기준 카드 안내와 프레임 전환을 포함한다. 기준 카드 안내만의 시작 이벤트는 없으므로 이 전체를 순수 애니메이션 실시간이라고 부르지 않는다. phone_stage=5→pack_entry_started는 안내 구간의 보조 근거다.

요청 논리 시간은 command_start→command_end이며 인증·준비·재시도·정리 등을 포함할 수 있다. attempt_start→attempt_end는 전송 경계이나 네트워크와 서버를 분리하지 못한다. 요청의 끝과 상태 적용의 도착 순서를 강제하지 않는다. 서버 중앙값을 앱 시간에서 빼지 않았다.

## C. 지표 사전

| metric | 쉬운 이름 | 시작→종료 |
| --- | --- | --- |
| action_to_deck | 시작 처리·화면 이동 | 버튼 콜백→태블릿 카드 더미 탭 가능 |
| tablet_entry | 태블릿 카드 더미 등장 | 등장 시작→완료 |
| tablet_after_entry_wait | 태블릿 탭 대기 | 등장 완료→실제 탭 |
| tablet_deal | 카드 배분 | 배분 시작→연출 종료 |
| tablet_after_deal | 태블릿 상태 반영·테이블 안내 | 배분 연출 종료→태블릿 준비 프레임 |
| deal_to_phone_data | 손패 상태 전달·반영 | 배분 연출 종료→선공 폰 새 손패 반영 |
| phone_data_to_pack | 폰 안내 후 카드팩 생성 | 새 손패 반영→카드팩 등장 시작 |
| phone_entry | 폰 카드팩 도착 연출 | 카드팩 등장 시작→탭 가능 |
| phone_wait | 폰 카드팩 탭 대기 | 탭 가능→실제 탭 |
| phone_reveal | 폰 손패 공개 | 탭→공개 연출 종료 |
| phone_reveal_to_ready | 최종 입력 준비 | 공개 연출 종료→선공 입력 준비 프레임 |
| seating_prepare | 자리 저장·이동 전체 | seating_prepare_start→seating_prepare_end; 요청/착석/배경 준비 병행 뒤 줌 |
| phone_controls | 조작부 등장 | controls_started→controls_completed; 입력 준비와 별도 |
| input_human_delay | 완료 후 첫 제출까지 사용자 행동 | 선공 phone_first_turn_playable_frame→첫 submit_handler |
| submit_completion | 첫 제출 처리 성공 | 첫 submit_handler→다음 submit_result=1 |
| ready_response_minus_ready | 입력 준비 대비 준비 응답 도착 | command_end−phone_first_turn_playable_frame(양수는 응답이 나중) |

단계별 CSV에는 시작/종료 이벤트명·기기·seq, 범위, 분류, trial ID가 있다. aggregate 값은 단일 이벤트 쌍이 아니라 전체/교집합 계산이므로 이벤트 칸이 비어 있다. timelines의 target_game=false인 원게임/조작 전 이벤트는 새 게임의 손패 반영 구간에 사용하지 않는다.

## D. 상세 통계와 요청

### 최초 시작

| 지표 | n | 중앙값 | 최소 | 최대 |
| --- | --- | --- | --- | --- |
| action_to_deck | 6 | 3.514928 | 3.242416 | 7.009963 |
| adjusted | 6 | 14.388538 | 13.634958 | 19.453274 |
| assets_phone_A | 4 | 0.010127 | 0.006216 | 0.887973 |
| assets_phone_B | 2 | 0.343784 | 0.007677 | 0.679891 |
| assets_tablet | 6 | 0.387961 | 0.297732 | 0.426281 |
| attempt_complete_dealing | 6 | 1.055546 | 0.475536 | 2.738709 |
| attempt_ready_turn | 6 | 0.524442 | 0.464165 | 3.053685 |
| attempt_start_game | 6 | 0.639760 | 0.578246 | 2.851717 |
| call_complete_dealing | 6 | 1.059502 | 0.478832 | 2.742346 |
| call_ready_turn | 6 | 0.528053 | 0.466647 | 3.056398 |
| call_start_game | 6 | 0.673148 | 0.635102 | 2.868203 |
| deal_to_phone_data | 6 | 0.855340 | 0.365322 | 2.652419 |
| deal_to_phone_entry | 6 | 4.487338 | 3.993950 | 6.296113 |
| exclusive_wait | 6 | 0.616538 | 0.167558 | 0.685906 |
| game_start_intro | 6 | 1.691971 | 1.659127 | 1.707426 |
| input_human_delay | 6 | 1.604338 | 0.820761 | 2.676718 |
| phone_controls | 6 | 0.932211 | 0.920745 | 0.933154 |
| phone_data_to_pack | 6 | 3.640802 | 3.618596 | 3.646542 |
| phone_entry | 6 | 0.753816 | 0.749952 | 0.772605 |
| phone_ready_lag | 6 | 5.459057 | 5.058376 | 5.692382 |
| phone_reveal | 6 | 1.470336 | 1.457564 | 1.474759 |
| phone_reveal_to_ready | 6 | 0.033509 | 0.030245 | 0.069194 |
| phone_stage5_to_pack | 6 | 1.908478 | 1.903572 | 1.910772 |
| phone_wait | 6 | 0.616538 | 0.167558 | 0.685906 |
| ready_response_after_reveal | 6 | 0.000000 | 0.000000 | 1.587976 |
| ready_response_minus_ready | 6 | -0.993703 | -1.037261 | 1.555388 |
| screen_after_assets_phone_A | 4 | 0.008273 | 0.006630 | 0.015608 |
| screen_after_assets_phone_B | 2 | 0.012505 | 0.010353 | 0.014657 |
| screen_after_assets_tablet | 6 | 0.006286 | 0.005811 | 0.013001 |
| seat_save | 6 | 0.723794 | 0.644449 | 2.589373 |
| seating_prepare | 6 | 2.930002 | 2.901930 | 6.503928 |
| submit_completion | 6 | 0.470237 | 0.421716 | 0.975947 |
| tablet_after_deal | 6 | 1.870394 | 1.395921 | 3.644019 |
| tablet_after_entry_wait | 6 | 0.488830 | 0.354629 | 0.946677 |
| tablet_deal | 6 | 2.822493 | 2.816909 | 2.825753 |
| tablet_entry | 6 | 0.647971 | 0.640394 | 0.657630 |
| tablet_raw_wait | 6 | 1.143651 | 1.012305 | 1.587105 |
| tablet_ready | 6 | 9.503674 | 8.743840 | 14.543082 |
| tablet_round_ending | 6 | 0.013466 | 0.012744 | 0.015656 |
| total | 6 | 15.005076 | 13.802516 | 19.961001 |

### 메뉴 재시작

| 지표 | n | 중앙값 | 최소 | 최대 |
| --- | --- | --- | --- | --- |
| action_to_deck | 5 | 0.630224 | 0.556277 | 0.650163 |
| adjusted | 5 | 8.825118 | 8.637149 | 9.338094 |
| attempt_complete_dealing | 5 | 0.412612 | 0.360456 | 0.642698 |
| attempt_ready_turn | 5 | 0.341929 | 0.314480 | 0.370357 |
| attempt_start_game | 5 | 0.546626 | 0.477303 | 0.634049 |
| call_complete_dealing | 5 | 0.419987 | 0.367804 | 0.647461 |
| call_ready_turn | 5 | 0.345816 | 0.321489 | 0.372851 |
| call_start_game | 5 | 0.617028 | 0.525537 | 0.690469 |
| deal_to_phone_data | 5 | 0.396489 | 0.328179 | 0.765018 |
| deal_to_phone_entry | 5 | 2.348864 | 2.258044 | 2.703723 |
| exclusive_wait | 5 | 1.228882 | 1.047353 | 2.116763 |
| input_human_delay | 5 | 2.021811 | 1.807374 | 2.968379 |
| phone_controls | 5 | 0.931027 | 0.914035 | 0.931861 |
| phone_data_to_pack | 5 | 1.939738 | 1.929865 | 1.956459 |
| phone_entry | 5 | 0.756091 | 0.748855 | 0.775472 |
| phone_ready_lag | 5 | 3.819895 | 3.664706 | 3.898049 |
| phone_reveal | 5 | 1.469342 | 1.466713 | 1.476791 |
| phone_reveal_to_ready | 5 | 0.040516 | 0.037601 | 0.131606 |
| phone_stage5_to_pack | 5 | 1.912588 | 1.902153 | 1.922026 |
| phone_wait | 5 | 0.594543 | 0.474678 | 0.687933 |
| ready_response_after_reveal | 5 | 0.000000 | 0.000000 | 0.000000 |
| ready_response_minus_ready | 5 | -1.172920 | -1.276620 | -1.140591 |
| submit_completion | 5 | 0.425208 | 0.421361 | 0.430844 |
| tablet_after_deal | 5 | 1.430269 | 1.387718 | 1.666126 |
| tablet_after_entry_wait | 5 | 0.779132 | 0.572675 | 1.522220 |
| tablet_deal | 5 | 2.823131 | 2.817302 | 2.824611 |
| tablet_entry | 5 | 0.641936 | 0.639302 | 0.650648 |
| tablet_raw_wait | 5 | 1.429042 | 1.212122 | 2.164176 |
| tablet_ready | 5 | 6.264342 | 6.023336 | 7.083179 |
| tablet_round_ending | 5 | 0.018026 | 0.015422 | 0.021431 |
| total | 5 | 10.091665 | 9.686953 | 10.979885 |

### 결과 재시작

| 지표 | n | 중앙값 | 최소 | 최대 |
| --- | --- | --- | --- | --- |
| action_to_deck | 6 | 0.644495 | 0.544277 | 0.760738 |
| adjusted | 6 | 10.923699 | 10.494041 | 11.422180 |
| attempt_complete_dealing | 6 | 0.923766 | 0.443965 | 1.666527 |
| attempt_ready_turn | 6 | 0.369638 | 0.318383 | 0.494712 |
| attempt_start_game | 6 | 0.565247 | 0.523223 | 0.669630 |
| call_complete_dealing | 6 | 0.928584 | 0.448211 | 1.671912 |
| call_ready_turn | 6 | 0.372135 | 0.321586 | 0.497204 |
| call_start_game | 6 | 0.612361 | 0.558812 | 0.715078 |
| deal_to_phone_data | 6 | 0.842941 | 0.317939 | 1.373163 |
| deal_to_phone_entry | 6 | 4.479421 | 3.947731 | 4.996064 |
| exclusive_wait | 6 | 0.795880 | 0.503639 | 2.058969 |
| game_start_intro | 6 | 1.680817 | 1.670466 | 1.693929 |
| input_human_delay | 6 | 2.142772 | 1.932342 | 2.940088 |
| phone_controls | 6 | 0.931551 | 0.920898 | 0.933022 |
| phone_data_to_pack | 6 | 3.628022 | 3.621796 | 3.647974 |
| phone_entry | 6 | 0.757118 | 0.751914 | 0.769033 |
| phone_ready_lag | 6 | 5.074622 | 4.881514 | 5.763827 |
| phone_reveal | 6 | 1.469988 | 1.457578 | 1.474114 |
| phone_reveal_to_ready | 6 | 0.071037 | 0.032733 | 0.109549 |
| phone_stage5_to_pack | 6 | 1.908543 | 1.903990 | 1.916681 |
| phone_wait | 6 | 0.243126 | 0.160645 | 0.847843 |
| ready_response_after_reveal | 6 | 0.000000 | 0.000000 | 0.000000 |
| ready_response_minus_ready | 6 | -1.162482 | -1.256139 | -1.007187 |
| submit_completion | 6 | 0.423876 | 0.421723 | 0.463925 |
| tablet_after_deal | 6 | 1.921644 | 1.350442 | 2.629016 |
| tablet_after_entry_wait | 6 | 0.574439 | 0.342994 | 1.310130 |
| tablet_deal | 6 | 2.819883 | 2.818689 | 2.827422 |
| tablet_entry | 6 | 0.653112 | 0.639032 | 0.676671 |
| tablet_raw_wait | 6 | 1.228399 | 1.019685 | 1.953267 |
| tablet_ready | 6 | 6.894732 | 5.980597 | 7.282252 |
| tablet_round_ending | 6 | 0.017333 | 0.013517 | 0.019751 |
| total | 6 | 11.881149 | 10.997680 | 13.044919 |

## E. 병행·원인 해석과 예외

16/17건의 선공 ready_turn 논리 응답은 손패 공개 및 입력 준비보다 먼저 끝났다. 최초 시작 1번은 반대로 논리 응답이 입력 준비보다 1.555388초 늦게 끝났지만, 실제 선택·제출 성공이 검증됐다. 따라서 이 응답 잔여를 시작 지연에 더하거나 “응답이 느렸으니 그만큼 입력이 막혔다”고 판정할 수 없다. 논리 응답과 상태 반영은 다른 이벤트다. 공개 연출 약 1.47초와 준비 요청 시간을 무조건 직렬로 세지 않는다.

조작부 등장 애니메이션은 약 0.93초지만 폰 입력 준비 프레임 이후에도 이어졌다. 현재 완료 기준은 실제 선택/제출 조건이지 조작부 모양이 완전히 정지한 시점이 아니다. 이를 바꾸면 이전 baseline과 같은 지표가 아니므로 별도 지표를 추가해야 한다.

메뉴 2의 특이사항: 선공 B 입력 준비 후 첫 제출 및 성공, 이후 선택 이벤트와 추가 제출 성공이 기록됐다. 원시 탭과 취소된 탭 전체를 기록한 것이 아니므로 처음 선택 시도가 무반응이었다는 원인을 복원하지 않는다. 선택 기록이 최종적으로 존재하므로 현재 예비 검증 기준은 통과한다. 검증을 통과했다는 사실과 UX 불편 가능성은 별개이며 메모를 보존한다. 최초 시작 3번에도 첫 제출 뒤 선택 이벤트가 있다. 코드상 탭 선택(_toggleSelection)은 card_selection_handler를 남기지만 직접 드래그(_startDragging)의 내부 선택은 이 이벤트를 남기지 않는다. 이런 입력 경로 차이가 있으므로 “선택 로그가 늦음”을 곧바로 수집 누락이나 선택 불능으로 판정하지 않는다.

제출 처리 시간은 순수 네트워크 왕복이 아니다. _submitSelectedCards는 요청과 카드 퇴장 연출을 병행하고, 420ms 퇴장 대기를 마친 뒤 요청 결과까지 확인하여 submit_result를 남긴다. 따라서 약 0.42초의 최솟값을 서버 지연이라고 해석하지 않는다.

최초 시작 1번은 전체 19.961초이고 배경·요청 준비 조건을 통제한 반복 검증 없이 서버 cold start라고 부를 수 없다. 포함/제외를 바꿔 좋은 결과만 고르지 않았다. 메뉴·결과의 차이 중 관측된 추가 GAME START는 구현 흐름과 일치하지만, 네트워크·앱 유지 조건·선공이 달라 경로 간 전체 차이를 연출 하나의 인과 효과로 간주하지 않는다.

무선 ADB는 계측 전송 경로이고 앱 게임 통신과 같은 지표가 아니다. 시계 추정 범위가 기준 이내라는 것과 무선 연결의 게임 처리 부하가 0이라는 것은 다르다. 유선 대 무선 통제 실험·Release frame profile은 없다. 실패 수집의 로컬 통신 오류를 서비스의 운영 실패율로 환산하지 않는다.

## F. 개선 전후 비교 계약

경로별로 본문의 총시간·관측상 대기 제외 시간·단계별 개별값을 비교한다. 최초/메뉴/결과를 합쳐 평균내지 않는다. 최초는 first_after_launch가 확인되지 않은 unspecified 6건이다. 추후는 앱 새 실행/유지, 동일 방/참여자 수·선공, 기기·Debug 구성, 연결 방식·망, 사용자 탭 지연을 기록하고 통제한다. 현재 baseline과 조건이 다르면 같은 조건의 새 baseline부터 확보한다. 서버 시작 조건은 별도 증거 없이 붙이지 않는다.

전체 시간이 줄었는지와 해당 단계가 줄었는지 둘 다 보고한다. 중앙값과 개별값·범위를 함께 남기고 표본이 작으므로 유의성·p95·운영 SLA를 주장하지 않는다. 선택/제출 성공을 유지하고 사용자 대기를 자동 지연으로 바꾸지 않는다. 단축 예상치는 현재 제시하지 않는다. 네트워크 원인 규명 시 요청 alias를 연결할 수 있는 최소 단계 계측/서버 조회를 별도 승인 범위에서 계획하고 이번 자료를 변경하지 않는다.

## G. 재사용 파일

| 파일 | 용도 |
| --- | --- |
| measurements.json | trial·단계·통계·원본 해시를 함께 담은 기준 데이터 |
| stages.csv | 시험별 단계 시간 및 시작/종료 근거 |
| stage_statistics.csv | 경로별 n/중앙값/범위 및 중앙값 하한·상한 |
| trials.csv | 회차·기기 역할·복구·조건·사용자 메모 |
| commands.csv | 개별 논리 요청 시간 및 버튼 상대 시작/종료 |
| timeline.csv | 모든 정제 이벤트의 버튼 상대 시간 추정 범위 |
| input_validation.csv | 선공 선택·제출·성공 이벤트의 입력 준비 이후 시각 |
| analyze.py / build_report.py | 원본 읽기 전용 재계산 및 본문/부록/PDF 생성 |
| validation.json / integrity.json | 검사 결과 및 이번 산출물 자체 해시 |

## H. 실행·보존

Python 표준 라이브러리로 원본 파일별 해시·개수·schema/역할/게임 연결을 재검사하고 현재 strict 분석기를 실행했다. 참여자 커버리지·연속 순번·동일 process·단조 시각·종료 이벤트·실제 선택/제출을 확인했다. 해석에 사용한 phone/screens/game_screen.dart, phone/widgets/hand_card_stack.dart, shared/providers/game_controller.dart, tablet/src/board_state.dart, 공용 player_layout_editor.dart는 17건 모두 수집 당시 PC 소스 해시와 현재 해시가 일치했다. PC 소스 기록이며 설치 APK의 바이너리 동일성 증명은 아니다. 새 출력만 이 고유 폴더에 썼으며 원본·기존 보고서·제품 소스는 수정하지 않았다. 실기기 조작·서버 조회·설치·FULL 검증은 하지 않았다. PDF 작성은 번들 ReportLab/맑은 고딕을 사용했다. 실행과 시각 검사는 validation.json에 기록한다.

본문 수치는 보기 좋게 0.01초로 반올림했지만 인증된 물리 오차가 0.01초라는 뜻은 아니다. 계산 원본의 추정 범위 폭은 최대 0.144996초다.