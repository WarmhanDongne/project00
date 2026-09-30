# 게임 코드 리뷰 가이드

이 문서는 Mosigame의 게임 코드를 처음부터 검토할 때 **어디서 시작하고 어떤 순서로
연결을 따라가야 하는지** 정리한 안내서다. 개별 파일의 역할과 직접 import/export
관계는 [`GAME_PACKAGE_FILE_REFERENCE.md`](GAME_PACKAGE_FILE_REFERENCE.md)에 있다.

기준은 2026-09-11 현재 working tree다. 구조 설명보다 현재 코드·테스트가 우선이며,
게임 규칙과 persistent data shape를 바꾸기 전에는 client, Functions, RTDB rules와
테스트를 함께 확인한다.

## 1. 먼저 알아야 하는 전체 구조

Mosigame은 플랫폼과 게임이 따로 설치되는 여러 앱이 아니다. 사용자에게 배포되는 것은
루트의 Flutter 앱 하나이고, 게임 구현만 package 경계로 나뉜다.

```text
Mosigame Flutter 앱
├─ lib/platform/                  로그인·방·홈·게임 선택 등 앱 본체
├─ lib/games/game_registry.dart  앱과 게임 package를 연결
├─ lib/game_assets/              다운로드 에셋 구현을 앱에 조립
└─ packages/
   ├─ game_kit/                  모든 게임이 쓰는 계약·흐름·통신·공통 UI
   ├─ game_template/             새 게임을 만들 때 복사할 기준
   ├─ game_liars_poker/          라이어스포커 Flutter 구현
   ├─ game_final_call/           파이널콜 Flutter 구현
   └─ game_mafia/                마피아 Flutter 구현

Firebase
├─ RTDB                          방과 게임 상태 전달
└─ functions/src/<game>/         규칙 검증과 authoritative 상태 변경
```

의존 방향은 다음 한 방향을 지켜야 한다.

```text
플랫폼 앱 ─────▶ game_kit + 각 게임 package
각 게임 package ─▶ game_kit
game_kit ──────▶ Flutter·Firebase 등 외부 package

금지: game_kit ─▶ 특정 게임
금지: 게임 A ───▶ 게임 B
금지: 게임 package ─▶ 루트 앱 또는 lib/platform
```

## 2. 실제 게임 진행 흐름

### 게임 선택에서 화면 진입까지

```text
Firestore 게임 목록
  ↓
GameListService / GameListProvider
  ↓ id로 결합
GameRegistry.find(gameId)
  ↓
TemplateGame 구현체
  ├─ startGame()          서버에 시작 요청
  ├─ watchStatus()        RTDB status 구독
  ├─ buildPhoneScreen()   휴대폰 화면 생성
  └─ buildTabletScreen()  태블릿 화면 생성
```

이 흐름을 검토할 때 가장 중요한 기준은 플랫폼이 `liars_poker`, `final_call`, `mafia`를
직접 분기하지 않고 `TemplateGame` 계약만 사용해야 한다는 점이다. 새 게임 연결 지점은
원칙적으로 `GameRegistry` 한곳이다.

### 서버 상태 읽기

```text
RTDB rooms/{roomCode}/game
  ├─ public                 방 참가자 공통 상태
  ├─ private/{uid}          본인만 읽는 카드·역할 등
  └─ server                 Cloud Functions 전용 비공개 상태
      ↓
<game>_query_service.dart
      ↓
<game>_session_provider.dart
      ↓
<game>_controller.dart / <game>_game_state.dart
      ↓
phone_game.dart 또는 tablet_game.dart
      ↓
세부 screen/widget/animation
```

리뷰할 때 위젯이 RTDB를 따로 구독하지 않는지 확인한다. 서버 상태 구독과 불변 상태의
소유자는 게임 session provider/controller 한곳이어야 한다. 태블릿은 다른 플레이어의
`private/{uid}`를 읽으면 안 된다.

### 서버 상태 변경

```text
버튼·타이머·태블릿 연출 완료
  ↓
<game>_controller.dart
  ↓
<game>_command_service.dart
  ↓ callable 이름 + payload
functions/src/index.ts
  ↓
functions/src/<game>/<action>.ts
  ↓ transaction + validation
RTDB public/private/server 갱신
  ↓
query stream이 새 상태를 다시 전달
```

Flutter가 `rooms/{roomCode}/game`을 직접 쓰면 안 된다. UI는 명령을 요청할 뿐이고,
게임 규칙·턴 검증·승패·비공개 카드/역할 이동은 Functions가 결정한다.

### 번들·다운로드 에셋

```text
packages/<game>/assets/                 실제 이미지·음원
  ↓ FlutterGen
packages/<game>/lib/gen/assets.gen.dart 생성 경로 — 직접 수정 금지
  ↓ extension
packages/<game>/lib/game_assets.dart    AssetGenImage → GameImage
  ↓
game_kit/core/assets/game_asset_store.dart
  ├─ bundle asset
  └─ downloaded cache
      ↑
lib/game_assets/game_asset_bootstrap.dart
lib/game_assets/firebase_game_asset_source.dart
```

현재 앱 시작 시 cache/store만 초기화하며 자동 다운로드하지 않는다. 다운로드 게임은
소유 확인 뒤 버튼이 `downloadGame(gameId)`를 호출하도록 추가할 예정이고, Dart 게임
코드를 Firebase에서 내려받아 동적 실행하는 구조는 아니다.

## 3. 추천 코드 리뷰 순서

아래 순서는 **계약 → 상태 → 통신 → 화면 → 연출** 순서다. 화면부터 읽으면 왜 해당
분기가 존재하는지 알기 어려우므로, 먼저 데이터와 상태 전이의 주인을 확인한다.

### 0단계 — 저장소 계약

1. [`ENGINEERING_CONTRACT.md`](ENGINEERING_CONTRACT.md)
2. [`ARCHITECTURE.md`](ARCHITECTURE.md)
3. [`PACKAGE_MIGRATION.md`](PACKAGE_MIGRATION.md)
4. [`tool/check_package_boundaries.py`](../../tool/check_package_boundaries.py)

확인할 것: server-authoritative 원칙, package 의존 방향, 생성 코드 수정 금지,
Shorebird 코드 패치와 에셋 다운로드의 차이.

### 1단계 — 플랫폼과 게임을 연결하는 계약

1. [`packages/game_kit/lib/template_game.dart`](../../packages/game_kit/lib/template_game.dart)
2. [`packages/game_kit/lib/models/game_room_context.dart`](../../packages/game_kit/lib/models/game_room_context.dart)
3. [`lib/games/game_registry.dart`](../../lib/games/game_registry.dart)
4. [`packages/game_template/lib/game_template.dart`](../../packages/game_template/lib/game_template.dart)
5. [`packages/game_template/lib/game_template.dart`](../../packages/game_template/lib/game_template.dart)

여기서 `TemplateGame`의 id, 화면 방향, 시작·상태 구독, 휴대폰·태블릿 builder 계약을
이해한다. `game_template`은 실행 게임이 아니라 새 package의 기준이다.

### 2단계 — 모든 게임이 공유하는 진행 상태

1. [`game_screen_phase.dart`](../../packages/game_kit/lib/game_flow/game_screen_phase.dart)
2. [`game_flow_config.dart`](../../packages/game_kit/lib/game_flow/game_flow_config.dart)
3. [`phone_game_flow_config.dart`](../../packages/game_kit/lib/game_flow/phone_game_flow_config.dart)
4. [`phone_game_shell.dart`](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)
5. [`game_announcement.dart`](../../packages/game_kit/lib/game_flow/game_announcement.dart)
6. [`game_interruption.dart`](../../packages/game_kit/lib/game_flow/game_interruption.dart)
7. [`game_finish.dart`](../../packages/game_kit/lib/game_flow/game_finish.dart)
8. [`game_flow_auto_complete.dart`](../../packages/game_kit/lib/game_flow/game_flow_auto_complete.dart)
9. [`leave_failure_notice.dart`](../../packages/game_kit/lib/game_flow/leave_failure_notice.dart)

확인할 것: 서버의 `status`, 게임별 `phase`, 공통 `GameScreenPhase`, 태블릿의 로컬 연출
단계를 같은 값처럼 섞지 않았는지. 연출 완료 명령이 중복 호출되지 않는지도 본다.

### 3단계 — 공통 통신·시간·오류 기반

1. [`game_query_service.dart`](../../packages/game_kit/lib/services/game_query_service.dart)
2. [`game_command_service.dart`](../../packages/game_kit/lib/services/game_command_service.dart)
3. [`callable_retry_policy.dart`](../../packages/game_kit/lib/services/callable_retry_policy.dart)
4. [`game_interruption_command_service.dart`](../../packages/game_kit/lib/services/game_interruption_command_service.dart)
5. [`realtime_database_service.dart`](../../packages/game_kit/lib/firebase/services/realtime_database_service.dart)
6. [`realtime_connection_monitor.dart`](../../packages/game_kit/lib/core/network/realtime_connection_monitor.dart)
7. [`server_clock.dart`](../../packages/game_kit/lib/core/time/server_clock.dart)
8. [`controller_room_session_store.dart`](../../packages/game_kit/lib/session/controller_room_session_store.dart)
9. [`game_communication_log.dart`](../../packages/game_kit/lib/core/diagnostics/game_communication_log.dart)
10. [`dev_error_overlay.dart`](../../packages/game_kit/lib/core/diagnostics/dev_error_overlay.dart)

확인할 것:

- 재시도하는 명령에 안정적인 `commandId` 또는 `interruptionId`가 있는가.
- 멱등성이 없는 명령에 `retryTransientFailure: true`가 붙지 않았는가.
- 구독 오류와 null snapshot을 게임 종료로 잘못 해석하지 않는가.
- 제한시간 계산은 기기 시각이 아니라 `ServerClock` 기준인가.
- 오류를 삼키지 않고 오른쪽 아래 통신 패널에서 요청·응답·실패 이유를 볼 수 있는가.

### 4단계 — 에셋 경계

1. [`game_image.dart`](../../packages/game_kit/lib/core/assets/game_image.dart)
2. [`game_asset_manifest.dart`](../../packages/game_kit/lib/core/assets/game_asset_manifest.dart)
3. [`game_asset_source.dart`](../../packages/game_kit/lib/core/assets/game_asset_source.dart)
4. [`game_asset_cache.dart`](../../packages/game_kit/lib/core/assets/game_asset_cache.dart)
5. [`game_asset_store.dart`](../../packages/game_kit/lib/core/assets/game_asset_store.dart)
6. [`game_asset_bootstrap.dart`](../../lib/game_assets/game_asset_bootstrap.dart)
7. [`firebase_game_asset_source.dart`](../../lib/game_assets/firebase_game_asset_source.dart)
8. 각 게임의 `game_assets.dart`
9. 각 package `pubspec.yaml`
10. 각 package `gen/assets.gen.dart`는 생성 결과 확인만 한다.

확인할 것: package 이름 보존, 논리 경로와 실제 번들 경로, SHA-256 검증, 임시 파일의
원자적 설치, 현재 patch와 asset version 호환성.

### 5단계 — 라이어스포커를 처음부터 끝까지

첫 번째 실제 게임으로 라이어스포커를 추천한다. 턴·카드 제출·LIAR 판정·타이머·룰렛
벌칙·휴대폰/태블릿 연출·중단 복구가 모두 있어 공통 구조를 가장 많이 볼 수 있다.

1. `game_copy.dart` → 표시 문구
2. `game_flow_config.dart` → phase를 공통 화면 단계로 변환
3. `models/game_models.dart` → RTDB 공개/개인 상태 모델
4. `services/query_service.dart` → 읽는 RTDB 경로
5. `services/command_service.dart` → callable 이름과 payload
6. `services/game_service.dart` → query/command 묶음
7. `providers/game_state.dart` → 불변 화면 상태
8. `providers/session_provider.dart` → 구독 수명과 상태 결합
9. `controllers/game_controller.dart` → 사용자 동작과 자동 진행
10. `controllers/penalty_coordinator.dart` → 룰렛 준비·연출·결과 반영 순서
11. `game.dart` → 플랫폼 진입 계약
12. `phone/phone_board.dart` → 휴대폰 shell 조립
13. `phone/screens/game_screen.dart` → 휴대폰 본문
14. `tablet/tablet_board.dart` → 태블릿 session/연출 조립
15. `tablet/providers/game_stage.dart` → 태블릿 단계 선택
16. `tablet/screens/game_penalty.dart` → 룰렛 화면과 레버 흐름
17. `widgets/` → 실제 입력·표시 컴포넌트
18. `animations/`, `sound/`, `loading/` → 상태 변경과 분리된 로컬 연출
19. `functions/src/liars-poker/common/types.ts` → 서버 원본 상태 계약
20. `common/validator.ts`, `common/commands.ts` → 검증·멱등 기반
21. `start-game.ts`부터 각 action 파일 → 실제 authoritative 전이

특히 Dart model과 TypeScript type의 필드명·nullable 여부·enum 문자열을 나란히
비교한다. `preparePenalty`는 서버가 결과를 먼저 확정하고, 태블릿 룰렛 연출이 끝난 뒤
`resolvePenalty`가 공개 상태에 반영하는지 확인한다.

### 6단계 — 파이널콜

1. `game_copy.dart`
2. `game_flow_config.dart`
3. `models/game_models.dart`
4. `services/query_service.dart`
5. `services/command_service.dart`
6. `services/game_service.dart`
7. `providers/game_state.dart`
8. `providers/session_provider.dart`
9. `controllers/game_controller.dart`
10. `game.dart`
11. `phone/phone_board.dart` → `phone/screens/game_screen.dart`
12. `tablet/tablet_board.dart` → `tablet/providers/game_stage.dart` → layer/overlay/animation
13. `widgets/phone/` → 카드 뽑기·교체·CALL·최종 제출 입력
14. `widgets/tablet/`, `animations/`, `sound/`, `loading/`
15. `functions/src/final-call/types.ts`, `validation.ts`, `commands.ts`
16. `start-game.ts` → `draw-card.ts` → `complete-turn.ts` → `call.ts` →
    `submit-final-hand.ts` → 결과/다음 라운드/종료 파일

확인할 것: `pendingDraw`, `finalSubmissions`, `processedCommands`가 public/private/server 중
올바른 위치에 있는지, 태블릿 공개 연출 전 개인 카드가 public으로 새지 않는지.

### 7단계 — 마피아

1. `game_copy.dart`
2. `game_flow_config.dart`
3. `models/role.dart` → 역할의 원본 Dart 모델
4. `models/role_catalog.dart`, `game_composition.dart`, `player.dart`
5. `models/state_models.dart`
6. `services/query_service.dart`
7. `services/command_service.dart`
8. `services/game_service.dart`
9. `providers/game_state.dart`
10. `providers/session_provider.dart`
11. `controllers/game_controller.dart`
12. `game.dart`
13. `phone/phone_board.dart` → `phone/screens/game_screen.dart`
14. `widgets/phone/`의 역할 확인·밤 행동·토론·투표·결과 순서
15. `tablet/tablet_board.dart` → `tablet/providers/game_stage.dart`
16. `tablet/screens/*_view.dart`의 각 phase 화면
17. `animations/`, `sound/`, `loading/`, `result_art.dart`
18. `functions/src/mafia/types.ts` → `roles.ts` → `validation.ts` → `game.ts`
19. `start-game.ts` → `role-reveal.ts` → `night.ts` → `morning.ts` → `day.ts` →
    `vote.ts` → `end-game.ts`

마피아는 보안 경계가 핵심이다. 누가 어떤 밤 행동을 했는지, 실제 역할, 투표 대상은
`server` 또는 본인의 `private/{uid}`에만 있어야 한다. `public`에는 공개해도 되는 집계와
연출 신호만 둔다. Dart 역할 표와 TypeScript 역할 표의 parity 테스트도 함께 본다.

### 8단계 — 공통 중단·재접속

1. [`game_interruption.dart`](../../packages/game_kit/lib/game_flow/game_interruption.dart)
2. [`game_interruption_command_service.dart`](../../packages/game_kit/lib/services/game_interruption_command_service.dart)
3. [`game_interruption_layer.dart`](../../packages/game_kit/lib/widgets/game_interruption_layer.dart)
4. [`game_reconnect_screen.dart`](../../packages/game_kit/lib/widgets/game_reconnect_screen.dart)
5. [`critical_network_guard.dart`](../../packages/game_kit/lib/widgets/critical_network_guard.dart)
6. `functions/src/game-interruption/types.ts`
7. `state.ts`, `functions.ts`, `finish-now.ts`
8. `expire-resolution.ts`, `expire-scheduler.ts`, `controller-presence.ts`

각 게임 controller가 공통 중단 상태를 제멋대로 다시 구현하지 않는지, controller 연결이
끊긴 동안 서버 deadline을 멈추고 복귀 시 정확히 되돌리는지 확인한다.

### 9단계 — 테스트로 계약 확인

1. 패키지 경계: `tool/check_package_boundaries_test.py`
2. 진입·선택: `test/tablet_game_selection_test.dart`, `test/setup_mosigame_contract_test.dart`
3. 통신 진단: `test/diagnostics/game_communication_log_test.dart`
4. 에셋: `test/asset_paths_exist_test.dart`, `test/game_asset_*.dart`,
   `test/game_compatibility_test.dart`
5. 공통 흐름: `test/game_connecting_overlay_test.dart`,
   `test/game_interruption_finish_now_test.dart`, `test/game_route_exit_test.dart`,
   `test/game_turn_countdown_test.dart`
6. 라이어스포커: `test/liars_poker_*.dart`
7. 파이널콜: `test/final_call_*.dart`
8. 마피아: `test/mafia_*.dart`
9. Functions 공통: `functions/test/start-game-transaction.test.mjs`,
   `functions/test/game-interruption*.mjs`
10. Functions 게임별: `functions/test/liars-poker-*.mjs`,
    `final-call-game.test.mjs`, `mafia-*.mjs`

테스트를 먼저 읽고 production 코드를 보는 방법도 좋지만, 이 저장소에서는 상태 필드와
callable 이름의 전체 맥락이 중요하므로 1~8단계에서 계약을 파악한 뒤 테스트가 그
계약을 실제로 고정하는지 확인하는 순서를 권장한다.

## 4. callable 연결을 확인하는 법

게임별 `<game>_command_service.dart`의 `invoke('함수명', payload)`와
`functions/src/index.ts`의 export 이름이 완전히 같아야 한다.

| 게임 | Flutter 명령 파일 | 서버 export/구현 |
| --- | --- | --- |
| 라이어스포커 | `packages/game_liars_poker/lib/shared/services/command_service.dart` | `functions/src/index.ts` → `functions/src/liars-poker/` |
| 파이널콜 | `packages/game_final_call/lib/shared/services/command_service.dart` | `functions/src/index.ts` → `functions/src/final-call/` |
| 마피아 | `packages/game_mafia/lib/shared/services/command_service.dart` | `functions/src/index.ts` → `functions/src/mafia/` |
| 공통 중단 | `packages/game_kit/lib/services/game_interruption_command_service.dart` | `functions/src/index.ts` → `functions/src/game-interruption/` |

다음 네 가지를 한 묶음으로 검토한다.

1. callable 문자열이 export 이름과 같은가.
2. Dart payload key가 TypeScript 입력 파서와 같은가.
3. Flutter가 재시도할 경우 서버가 같은 명령을 한 번만 처리하는가.
4. 서버가 바꾼 RTDB 필드를 Dart query/model이 같은 이름과 타입으로 읽는가.

`game_template`의 callable 이름은 복사용 예시이며 실제 배포 export가 아니다. 새 게임을
만들 때 해당 서버 구현과 `functions/src/index.ts` 등록을 함께 추가해야 한다.

## 5. 리뷰 중 특히 위험한 구조

- 화면 위젯에서 Firebase를 직접 호출하거나 RTDB 경로 문자열을 조립하는 구조.
- client가 카드 판정·승패·역할 배정 같은 authoritative 규칙을 결정하는 구조.
- 같은 game public stream을 여러 위젯이 별도로 구독하는 구조.
- `public`, `private/{uid}`, `server` 데이터가 섞이는 구조.
- 서버 `phase`와 화면 애니메이션 단계를 같은 변수로 관리하는 구조.
- `AnimationController` 완료 callback이 rebuild마다 같은 command를 재호출하는 구조.
- `retryTransientFailure: true`인데 `commandId`/`interruptionId`가 없는 구조.
- `DateTime.now()`로 서버 deadline의 남은 시간을 직접 계산하는 구조.
- 한 게임 package가 다른 게임이나 `lib/platform`을 import하는 구조.
- 생성된 `gen/assets.gen.dart`, `firebase_options.dart`를 직접 수정하는 구조.
- `AssetGenImage.provider()`를 package 정보 없이 호출해 잘못된 번들 경로를 만드는 구조.
- 새 게임의 이미지·음원을 Shorebird Dart patch에 포함하려는 구조.

## 6. 오늘 바로 시작한다면

처음 한 번은 다음 12개를 이 순서대로 읽으면 전체 연결이 가장 빨리 보인다.

1. `packages/game_kit/lib/template_game.dart`
2. `lib/games/game_registry.dart`
3. `packages/game_liars_poker/lib/game_liars_poker.dart`
4. `packages/game_kit/lib/services/game_query_service.dart`
5. `packages/game_kit/lib/services/game_command_service.dart`
6. `packages/game_liars_poker/lib/shared/models/game_models.dart`
7. `packages/game_liars_poker/lib/shared/services/query_service.dart`
8. `packages/game_liars_poker/lib/shared/services/command_service.dart`
9. `packages/game_liars_poker/lib/shared/providers/session_provider.dart`
10. `packages/game_liars_poker/lib/shared/providers/game_controller.dart`
11. `packages/game_liars_poker/lib/phone/phone_board.dart`
12. `functions/src/liars-poker/common/types.ts`와 `functions/src/liars-poker/submit-card.ts`

그 다음에는 [`GAME_PACKAGE_FILE_REFERENCE.md`](GAME_PACKAGE_FILE_REFERENCE.md)에서 현재
파일의 `이 파일이 직접 참조`를 아래로 따라가고, 변경 영향은 `이 파일을 직접 참조`를
위로 따라가면 된다.
