# 인계 메모 · 홀덤/파이널콜 수정 (2026-10-11)

브랜치 `디벨럽1`, **커밋하지 않은 상태**입니다. 같은 작업 트리에서 다른 세션이 라이어스 포커를
이전 GUI로 롤백하는 중이라, 아래 "내 변경" 밖의 수정(라이어스 포커 패키지 전체, 파이널콜
`game_assets`·`session_provider`·`command_service`·`query_service`, 홀덤 `config.ts` 행동 제한 1분 등)은
건드리지 마세요.

## 끝난 작업

### 로비
- 라이어스 포커 미리보기: 롤백된 GUI에 맞춰 `999c3e9` 시점의 `_LiarPlayScene`과 `_miniCard`를
  `game_detail_previews.dart`에 복원했습니다. `noir_ui.dart` import를 제거했습니다.
- 구성품 판 `game_detail_parts.dart`: 휴대폰 버튼 칸을 버튼 이미지(`button_liar`·`button_submit`·
  `button_fold`)로 바꿨습니다.
- 휴대폰 참여자 목록과 게임 선택 화면의 참가자 줄에 **'나' 표시**를 붙였습니다
  (`phone_room_participant_list.dart`, `phone_room_waiting.dart`).

### 홀덤
- 레이즈 시트에서 빠른 금액(최소·½ 팟·팟·올인, 사용자 표현으로 삥·쿼터·하프·올인)을 제거했습니다(`raise_sheet.dart`).
- 휴대폰 플레이 화면 '내 칩' 줄을 프로필(캐릭터·닉네임·칩)로 바꿨습니다(`phone/screens/game_screen.dart`).
- 휴대폰 결과 화면을 다시 디자인했습니다(`hand_result_view.dart`).
  - 위쪽: 내 얼굴 + WIN/LOSE 도장 + 닉네임
  - 진 판: 이긴 사람 얼굴 + 이름
  - 족보 이름은 기존 테스트 계약대로 표시하지 않습니다.
- 태블릿 체크: 가운데로 날아가던 CHECK 퍽을 없애고, 좌석 프로필 오른쪽 아래에 `체크` 배지를 띄웁니다.
- 태블릿 올인: 금빛 충격파, 불꽃, 'ALL IN' 띠 연출을 넣고 2.1초로 늘렸습니다(`action_motion.dart`).
- 쇼다운 결과를 순차 공개로 바꿨습니다.
  - 공개 손패는 모두 뒷면에서 시작해 자리 순서대로 한 사람씩 뒤집습니다.
  - 다 뒤집은 뒤 승자(WIN, 강조, 결과 문구)를 알립니다.
  - 타이밍은 `presentation_timing.dart`의 `showdownRevealAt`·`showdownWinnerAt`에 있습니다. 8명이어도 8초(팟 지급) 전에 끝납니다.
  - 휴대폰도 같은 시각까지 "SHOWDOWN · 태블릿에서 카드를 공개하고 있어요"만 보여 줍니다.

### 파이널콜
- 대기 패널의 내 줄에 붙던 'N번째 뒤'를 제거했습니다(`turnsLater` 문구도 삭제).
- 교체 패널의 긴 안내와 '…이랑 바꾸기' 버튼이 엉뚱하게 줄바꿈되지 않도록 FittedBox와 한 줄 처리를 했습니다.
- **CALL 뒤 제출 오류 추정 원인 수정**
  - 원인: 제출 단계(phase)가 바뀐 손패보다 먼저 도착하면, 버린 카드가 미리 고른 조합에 남아 서버가 거절했습니다.
  - 수정: `phone/providers/final_selection.dart`의 `syncFinalCallSelection`이 이런 선택을 비우고 다시 고릅니다. 제출할 때도 손패에 있는 카드만 보냅니다.
  - 실제 오류 메시지는 확인하지 못했습니다.
- 카드 앞면 10의 좌우 여백을 늘렸습니다(룰북 카드 포함, `card_view.dart`).
- 카드 뒷면을 다시 디자인했습니다: 보라 바탕, 물방울 창, 노란 별 'FC' 배지.
- 태블릿 CALL 선언 연출을 다시 만들었습니다(`call_and_discard_animation.dart`).
  - 약 2.2초 동안 어두운 화면 위로 햇살이 퍼지고, 선언자 얼굴과 이름이 나온 뒤 큰 CALL!이 쾅 내려앉습니다.
  - 그다음 기존 별 배지로 줄어듭니다.
- 태블릿 공개 중 휴대폰 상단 가운데에 뜨던 **빈 흰 상자**를 제거했습니다(`top_bar.dart`의 `_pill`, 내용이 없으면 그리지 않음).

### 추가·수정한 테스트
- 홀덤: `test/phone/game_screen_test.dart`, `test/tablet/table_screen_test.dart`
- 파이널콜: 새 파일 `test/phone/final_selection_test.dart`, `test/phone/top_bar_test.dart`. `party_pop_panel_test.dart`는 수정했습니다.
- 앱: `test/phone_waiting_players_test.dart`('나' 표시)

마지막 확인 결과는 홀덤 패키지 32개 통과, 파이널콜 패키지 통과(제거한 임시 테스트 제외)입니다.
라이어스 포커 롤백 이후 앱 전체 `flutter test --no-pub`는 다시 돌리지 않았습니다.

## 남은 작업

1. **홀덤 태블릿 좌석 회전 (완료)**
   - 사용자가 오른쪽 시안(모든 좌석이 중앙을 바라봄)을 승인했습니다.
   - `table_screen.dart`의 `_seatRotation`을 화면 픽셀 기준 `atan2(-dx, dy)`로 바꿨습니다.
2. **파이널콜 자리 배치 테이블·의자 그림 (완료)**
   - Party Pop 스타일로 코드로 그려 1254×1254 PNG로 넣었습니다
     (`packages/game_final_call/assets/games/final_call/images/layout/table.png`·`chair.png`).
   - `pubspec.yaml` assets에 추가하고 `assets.gen.dart`를 build_runner로 다시 생성했으며,
     `game_final_call.dart`에 `layoutTableImage`·`layoutChairImage`를 override했습니다.
   - 확인 그림: `build/design/final_call_seating_table_chair.png`
3. **파이널콜 휴대폰 규칙 화면 (완료)**
   - 공용 `game_kit/phone/widgets/rulebook_dialog.dart`(`PhoneGameRulebookDialog`)를 추가했습니다.
     왼쪽에 항목을 세로로 쌓고 오른쪽에 본문을 보여 줍니다.
   - `showFinalCallRules`가 `FinalCallCopy.tabletRules`로 이 화면을 엽니다. `phoneRules`는 삭제했습니다.
   - 테스트: 파이널콜 `test/phone/rules_dialog_test.dart`, `game_kit` `test/overflow_sweep_test.dart`(룰북 추가)
   - 확인 그림: `build/design/final_call_phone_rules.png`
4. 마무리
   - `dart run :mosigame validate --full`을 실행합니다. Node 22가 필요하므로 `PATH="$HOME/.nvm/versions/node/v22.23.1/bin:$PATH"`로 실행하고, 실행 전에 사용자 승인을 받아야 합니다.
   - `docs/planning/NEWGUI_FEATURE_GAP.md`를 갱신합니다.
   - 커밋은 사용자가 요청할 때만 합니다.

## 참고
- 작업 트리의 `flutter_01.png`(0바이트)는 출처를 모르는 파일이라 그대로 두었습니다.
- 이전 미결 질문: 상점의 "곧 나올 게임" 자리를 홀덤으로 바꿀지 여부.
