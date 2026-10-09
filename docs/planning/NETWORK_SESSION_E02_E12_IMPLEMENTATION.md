# E02~E12 네트워크·세션 구현 후보

2026-10-09 사용자가 E02~E12 순차 구현을 요청했다.
[채택한 A~C와 실행 계획](NETWORK_SESSION_IMPLEMENTATION_PLAN.md),
[현재 구현 계약](../engineering/NETWORK_SESSION_CONTRACT.md)에 따른 로컬 후보다.
관련 검사와 사용자 명시 승인 후 현재 후보 FULL이 모두 PASS다. E13 emulator/CI, E14 기기/성능 및 production 반영은 미실행이다.

## 후보와 기존 변경

시작/현재 branch: codex/e01-validation-wiring.
시작 HEAD: 151eff871e6af36c8cd69d0284ac830b844e2abb.
E01 dirty 43경로(수정 9·untracked 34), staged 0에서 시작했다.
시작 43경로는 모두 존재한다. SHA-256 비교 결과 32경로는 같고 11경로는 의도적으로 수정했다.
원래 작업 기록 6개에 후보/evidence를 추가하고, 기존 테스트 5개를 새 계약과 검증 실행 방식에 맞췄다.
room_leave_state/room_leave_intent는 durable 결과·예산, game_reconnect_screen은 유한 재시도,
auth_gate_stuck_loading은 keyed AnimatedSwitcher의 300ms 전환, test_suites_test는 새 서버 회귀의 정확한 순서를 검증한다.
기존 dirty 파일 전체가 바이트 단위로 같다고 주장하지 않는다.

의도적으로 수정한 시작 경로:

- `docs/planning/NETWORK_SESSION_IMPLEMENTATION_PLAN.md`
- `docs/planning/NETWORK_SESSION_TASKS.md`
- `docs/planning/TASKS.md`
- `docs/planning/logs/2026-10.md`
- `docs/planning/tasks/SESSION-RECONNECT-02.md`
- `docs/planning/tasks/TEST-REGRESSION-01.md`
- `test/auth/auth_gate_stuck_loading_test.dart`
- `test/game_reconnect_screen_test.dart`
- `test/mosigame_cli/test_suites_test.dart`
- `test/room_leave_intent_test.dart`
- `test/room_leave_state_test.dart`

stage/commit/push·배포·migration·production Firebase 접근은 없다.

## 구현 대응

| 단위 | 주요 파일과 결과 |
| --- | --- |
| E02 | room/session-contract.ts, session-functions.ts, realtime-room-functions/lifecycle, database.rules.json: room/member/current connection, CAS/replay, 퇴장/결과 확인 |
| E03 | game-interruption/recovery-state.ts, functions.ts, game-command-transaction.ts, game-mutation.ts, game-adapters.ts: 다중 원인·타이머·준비 barrier·실제 제외 preview·원장 |
| E04 LP→FC→MA→HE | 네 게임 callable/실제 reducer의 공용 transaction/context, private 대응·stale/pause 차단·seeded 난수/시각·Holdem allIn |
| E05 | game_kit GameSessionController/GameCommandService, RoomRecoveryBatch/GameCommandBatch/GameProgressCommand, identity/durable store: 구독/UID·프레임·유한 재시도 |
| E06 | RoomService/RoomProvider, RoomLeaveIntent, AuthGate/OnboardingService: durable intent 선저장·결과 우선·초기 복원/UID/foreground |
| E07 LP→FC→MA→HE | 양 역할 board/controller/preloader: 공개+본인 private·필수 이미지·입력 보호, 실제 명령 재시도·자동 진행·Holdem 비정상 종료 |
| E08 | AppNetworkGuard/GameRecoveryLayer/GameConnectingOverlay/GameInterruptionLayer: 단일 안내·자기 퇴장 즉시/10초 상세·controller 선택/확인 |
| E09 | phone/tablet home/waiting/launcher, game_asset_prepare, room_restore_to_waiting: 복귀 동의·정상 캐시·예외 에셋·game ID route 정리 |
| E10 | fetchRealtimeRoomGroupEntitlements, GameListService/RoomProvider: 요청 방 membership·조회 전후 revision·UID/request cache |
| E11 | create-room.ts, room-allocation.ts, room-cleanup.ts, durable create: 동일 요청 복구·generation CAS·보상·due index/cursor·tombstone |
| E12 | recovery_metrics.dart, game_communication_log.dart, dev_error_overlay.dart와 실제 hook: 단조 episode/batch·단계·N/A·200 event/50 summary·debug 제한 |

## 확인한 실패와 수정

- 기존 메모리 퇴장/무제한 재시도 기대를 새 durable/유한 계약에 맞추고 결과·시간·재시도 assertions를 강화했다.
- RTDB 빈 causes/ready 및 null 생략을 round-trip으로 재현해 빈 집합과 명시 timer kind로 정규화했다.
- 실제 transaction callback 반복 fixture로 시각/난수 및 UID·domain replay를 검증한다.
- 607개 cursor scan을 재현해 100/101 page에서 앞부분에 정리가 머무르지 않도록 수정했다.
- public/private 불일치·에셋 실패·ready ack 지연, 완료 owner Zone 및 소진 request의 추가 전송을 검증한다.
- 이전 close가 교체 controller token을 지우지 않고 phone에는 전체 종료/제외/자동 만료가 없다.
- 불일치의 새 public가 30초 예산을 초기화하지 않고 늦은 private/옛 deadline으로 보호를 임의 해제하지 않음을 검증했다. 구독 onDone도 실패 보고와 입력 보호를 만든다.
- 기존 provider fixture는 Flutter 종료 검사 전에 container를 dispose하도록 고쳤다. 새 스트림 종료 테스트 본문의 두 assertions는 통과했으나 tearDown이 FakeAsync에서 이미 닫은 스트림의 Future를 다시 기다려 멈췄다. 진단으로 정리 위치를 확인하고 중복 대기를 제거했다. 미완료 실행은 이번 테스트 프로세스 트리만 종료했으며 PASS로 사용하지 않는다. 수정 후 provider 14개와 전체 kit 65개가 통과했다.
- dart fix가 요청하지 않은 firebase_core_platform_interface dependency를 추가한 것을 발견해 해당 줄만 제거했다. 최종 pubspec.yaml/pubspec.lock에는 diff가 없다. 새 dependency는 없다.

## 최종 후보 검사

아래 결과는 현재 로컬 후보의 관련 검사다. 과거 E01 FULL을 이 후보의 근거로 사용하지 않는다.
Windows guarded 호출은 외부 PowerShell의 stdout/stderr 파일로 실제 출력을 보존했다.

| 실제 명령·위치 | status | exit code | 확인 범위 |
| --- | --- | --- | --- |
| .\tool\invoke_mosigame.ps1 test session --json (root) | PASS | 0 | Flutter 74·Functions 70; manifest 10/7; snapshot A/B mutation PASS |
| .\tool\invoke_mosigame.ps1 test auth --json (root) | PASS | 0 | Flutter 34·Functions 12; manifest 10/2; snapshot A/B mutation PASS |
| flutter analyze --no-pub (root) | PASS | 0 | No issues found |
| dart format --output=none --set-exit-if-changed bin lib test tool/mosigame_cli | PASS | 0 | FULL의 실제 포맷 범위 148파일·변경 0 |
| npm run lint (functions) | PASS | 0 | 전체 ESLint |
| npm test (functions) | PASS | 0 | TypeScript build + 전체 368개; fail/skipped/cancelled 0 |
| flutter test --no-pub --reporter expanded test (packages/game_kit) | PASS | 0 | 65개 |
| 같은 명령 (packages/game_liars_poker) | PASS | 0 | 2개 |
| 같은 명령 (packages/game_final_call) | PASS | 0 | 14개 |
| 같은 명령 (packages/game_mafia) | PASS | 0 | 55개 |
| 같은 명령 (packages/game_holdem) | PASS | 0 | 31개 |
| flutter test --no-pub --reporter expanded test/mosigame_cli/test_suites_test.dart test/mosigame_cli/package_test_manifest_test.dart test/mosigame_cli/validate_test.dart (root) | PASS | 0 | 42개; manifest·package WD/실패 전파·FULL 회귀 |
| flutter test --no-pub --reporter expanded test/recovery/providers/game_session_controller_test.dart test/recovery/providers/game_readiness_contract_test.dart (game_kit) | PASS | 0 | fixture 수정 후 14개; 전체 kit에도 포함 |
| Python tool/check_package_boundaries_test.py | PASS | 0 | 검사 자체 7개 |
| Python tool/check_package_boundaries.py --max 0 | PASS | 0 | 위반 0건 |
| Python tool/check_command_retry_contract.py | PASS | 0 | 기존 lib/games 스캔. 새 package 범위 검증으로 확대해 표현하지 않음 |
| git diff --check (root) | PASS | 0 | whitespace |
| .\tool\invoke_mosigame.ps1 validate --full --json (root, Windows guarded) | PASS | 0 | 사용자 명시 승인 후 1회, 12단계 PASS; root 334·5 package 167·Functions 368, 전후 mutation PASS |
| E13 emulator/현재 CI, E14 기기/성능 | NOT_RUN | — | 후속 범위; 다른 후보 PASS로 대체하지 않음 |

추가 진단으로 위 루트 포맷 범위와 다섯 package lib/test를 함께 검사했을 때는 FAIL/exit 1,
527파일 중 기존 package 파일 49개의 포맷 차이가 있었다. 49개 모두 이번 수정 경로에 포함되지 않는다.
검사는 output=none으로 실행해 파일을 바꾸지 않았다. 관련 없는 기존 파일을 일괄 포맷하지 않았으며,
현재 FULL은 문서화된 루트 포맷 범위만 검사한다.
경계 검사 옵션을 잘못 지정한 --max-violations 0 실행은 INVALID/exit 2였으며, 올바른 --max 0 결과와 구분한다.

ignored build/network-session에 로그를 보관한다: session/auth-final-captured.log와 *-final-exit.json,
complete-game_*.log, cli-final.log, provider-final.log, analyze-final-evidence.log,
root-format-final.log, final-functions-lint/test.log. 이전 final-session.json/final-auth.json은
직접 PowerShell Console 출력의 redirection으로 빈 파일이었으므로 증거로 사용하지 않는다.
최종 두 guarded suite는 같은 코드에서 다시 실행해 실제 PASS JSON과 exit 0을 파일로 확보했다.

## 2026-10-09 승인 후 FULL

사용자가 현재 후보의 최종 FULL을 명시 승인했다. Windows guarded 경로로 한 번 실행했다.
시작 2026-10-09T04:12:36.650525Z, CLI 전체 261905ms(약 4분 22초), guard startup 5516ms.
status PASS, exit 0, 총 12단계 PASS이며 실패·blocked·invalid·timeout이 없다.
루트 Flutter 334개와 다섯 package 65/2/14/55/31개, Functions 368개가 실제 실행됐다.
루트 포맷·분석·Functions lint 및 working-tree mutation도 PASS다.

| FULL step | status | process exit |
| --- | --- | --- |
| preflight | PASS | — |
| dart-format | PASS | 0 |
| flutter-analyze | PASS | 0 |
| flutter-test | PASS | 0 |
| flutter-test-game-kit | PASS | 0 |
| flutter-test-game-liars-poker | PASS | 0 |
| flutter-test-game-final-call | PASS | 0 |
| flutter-test-game-mafia | PASS | 0 |
| flutter-test-game-holdem | PASS | 0 |
| functions-lint | PASS | 0 |
| functions-test | PASS | 0 |
| working-tree-mutation | PASS | — |

실제 출력/JSON/종료 코드는 ignored build/network-session/full-approved.log,
full-approved-result.json, full-approved-exit.json에 보관한다.
실행 전후 branch/HEAD·staged/unstaged/untracked 경로는 동일했고 CLI가 내용 hash까지 대조해 mutation PASS를 반환했다.
이후에는 아래 증거·작업 목록/상세·월별 기록만 갱신했다. 추가 FULL 재실행은 하지 않았다.
느린 invocation-guard 통합 suite는 PROJECT_CLI.md의 정상 FULL 정책에 따라 제외된다.
이번 변경은 guard/process execution 구현을 수정하지 않아 별도 guard suite 실행 대상이 아니다.

## 최종 working tree와 한계

Branch codex/e01-validation-wiring, HEAD 151eff871e6af36c8cd69d0284ac830b844e2abb는 시작과 같다.
최종 staged 0, unstaged tracked 수정 115, untracked 64, 총 179경로다.
각 공식 검사와 승인 후 FULL 실행 전후 mutation은 PASS다. FULL 종료 후 변경은 검증 결과를 반영한 작업 기록 문서 7개다. 구현 코드는 바뀌지 않았다.
시작 43경로의 비교는 위 보존 기록을 따른다. stage/commit/push·deploy/migration·production 접근은 없다.
E02~E12 구현 후보의 관련 검사와 로컬 FULL 검증을 마쳤다. 전체 태스크 완료·실기기 확인·출시 판정으로 확대하지 않는다.
실제 Firebase callable/구독/rules 경합은 E13 local emulator, OS/기기·물리 단절·성능은 E14에서 확인해야 한다.
현재 상태의 단일 원본은 [TASKS.md](TASKS.md)다.

현재 Git 경로는 E01 기존 변경을 포함한다. M은 tracked 수정, ??는 untracked다.

```text
 M .github/workflows/validate.yml
 M database.rules.json
 M docs/engineering/ARCHITECTURE.md
 M docs/engineering/CLOUD_FUNCTIONS.md
 M docs/engineering/PROJECT_CLI.md
 M docs/operations/AUTH_NETWORK_SESSION_TECHNICAL_REFERENCE.md
 M docs/planning/NETWORK_SESSION_IMPLEMENTATION_PLAN.md
 M docs/planning/NETWORK_SESSION_TASKS.md
 M docs/planning/TASKS.md
 M docs/planning/logs/2026-10.md
 M docs/planning/tasks/SESSION-RECONNECT-02.md
 M docs/planning/tasks/TEST-REGRESSION-01.md
 M functions/src/final-call/call.ts
 M functions/src/final-call/clear-game.ts
 M functions/src/final-call/complete-dealing.ts
 M functions/src/final-call/complete-result-reveal.ts
 M functions/src/final-call/complete-turn.ts
 M functions/src/final-call/draw-card.ts
 M functions/src/final-call/end-game.ts
 M functions/src/final-call/game.ts
 M functions/src/final-call/leave-game.ts
 M functions/src/final-call/next-round.ts
 M functions/src/final-call/start-game.ts
 M functions/src/final-call/submit-final-hand.ts
 M functions/src/final-call/timeout-turn.ts
 M functions/src/game-interruption/controller-presence.ts
 M functions/src/game-interruption/expire-scheduler.ts
 M functions/src/game-interruption/functions.ts
 M functions/src/holdem/act.ts
 M functions/src/holdem/complete-dealing.ts
 M functions/src/holdem/complete-result.ts
 M functions/src/holdem/deck.ts
 M functions/src/holdem/end-game.ts
 M functions/src/holdem/game.ts
 M functions/src/holdem/leave-game.ts
 M functions/src/holdem/start-game.ts
 M functions/src/holdem/timeout-turn.ts
 M functions/src/index.ts
 M functions/src/liars-poker/call-liar.ts
 M functions/src/liars-poker/common/deck.ts
 M functions/src/liars-poker/common/table.ts
 M functions/src/liars-poker/complete-dealing.ts
 M functions/src/liars-poker/end-game.ts
 M functions/src/liars-poker/finish-penalty.ts
 M functions/src/liars-poker/force-timeout.ts
 M functions/src/liars-poker/leave-game.ts
 M functions/src/liars-poker/pass-challenge.ts
 M functions/src/liars-poker/ready-turn.ts
 M functions/src/liars-poker/start-game.ts
 M functions/src/liars-poker/submit-card.ts
 M functions/src/mafia/day.ts
 M functions/src/mafia/end-game.ts
 M functions/src/mafia/game.ts
 M functions/src/mafia/morning.ts
 M functions/src/mafia/night.ts
 M functions/src/mafia/role-reveal.ts
 M functions/src/mafia/start-game.ts
 M functions/src/mafia/vote.ts
 M functions/src/room/realtime-room-functions.ts
 M functions/src/room/realtime-room-lifecycle.ts
 M functions/src/room/room-join-policy.ts
 M functions/test/liars-poker-room-transaction.test.mjs
 M functions/test/room-presence-rules.test.mjs
 M lib/game_assets/game_asset_prepare.dart
 M lib/platform/auth/services/onboarding_service.dart
 M lib/platform/auth/widgets/auth_gate.dart
 M lib/platform/home/gamelist/service/game_list_service.dart
 M lib/platform/home/phone/screens/phone_home.dart
 M lib/platform/home/phone/screens/phone_room_waiting.dart
 M lib/platform/home/phone/widgets/controller_reconnect_guard.dart
 M lib/platform/home/room/models/room_player.dart
 M lib/platform/home/room/providers/room_provider.dart
 M lib/platform/home/room/services/player_presence.dart
 M lib/platform/home/room/services/room_leave_intent.dart
 M lib/platform/home/room/services/room_restore_to_waiting.dart
 M lib/platform/home/room/services/room_service.dart
 M lib/platform/home/tablet/screens/tablet_home.dart
 M lib/platform/home/tablet/tablet_game_launcher.dart
 M packages/game_final_call/lib/phone/src/board_state.dart
 M packages/game_final_call/lib/shared/providers/game_controller.dart
 M packages/game_final_call/lib/shared/services/asset_preloader.dart
 M packages/game_final_call/lib/tablet/src/board_state.dart
 M packages/game_holdem/lib/phone/phone_board.dart
 M packages/game_holdem/lib/shared/services/public_state_mapper.dart
 M packages/game_holdem/lib/tablet/tablet_board.dart
 M packages/game_holdem/test/shared/services/public_state_mapper_test.dart
 M packages/game_kit/lib/core/diagnostics/dev_error_overlay.dart
 M packages/game_kit/lib/core/diagnostics/game_communication_log.dart
 M packages/game_kit/lib/recovery/models/game_interruption.dart
 M packages/game_kit/lib/recovery/providers/game_session_controller.dart
 M packages/game_kit/lib/recovery/services/callable_retry_policy.dart
 M packages/game_kit/lib/recovery/services/controller_room_session_store.dart
 M packages/game_kit/lib/recovery/services/game_interruption_command_service.dart
 M packages/game_kit/lib/recovery/services/game_progress_command.dart
 M packages/game_kit/lib/recovery/widgets/app_network_guard.dart
 M packages/game_kit/lib/recovery/widgets/game_connecting_overlay.dart
 M packages/game_kit/lib/recovery/widgets/game_interruption_layer.dart
 M packages/game_kit/lib/recovery/widgets/game_reconnect_screen.dart
 M packages/game_kit/lib/recovery/widgets/game_recovery_layer.dart
 M packages/game_kit/lib/services/game_command_service.dart
 M packages/game_kit/test/recovery/providers/game_session_controller_test.dart
 M packages/game_kit/test/recovery/services/game_progress_command_test.dart
 M packages/game_kit/test/recovery/widgets/app_network_guard_test.dart
 M packages/game_kit/test/recovery/widgets/game_recovery_layer_test.dart
 M packages/game_liars_poker/lib/phone/src/board_state.dart
 M packages/game_liars_poker/lib/shared/providers/game_controller.dart
 M packages/game_liars_poker/lib/shared/services/asset_preloader.dart
 M packages/game_liars_poker/lib/tablet/src/board_state.dart
 M packages/game_mafia/lib/phone/src/board_state.dart
 M packages/game_mafia/lib/shared/providers/game_controller.dart
 M packages/game_mafia/lib/shared/services/asset_preloader.dart
 M packages/game_mafia/lib/tablet/src/board_state.dart
 M packages/game_mafia/lib/tablet/tablet_board.dart
 M tool/mosigame_cli/test_suites.dart
 M tool/mosigame_cli/validate.dart
?? docs/engineering/NETWORK_SESSION_CONTRACT.md
?? docs/planning/NETWORK_SESSION_E01_VALIDATION.md
?? docs/planning/NETWORK_SESSION_E02_E12_IMPLEMENTATION.md
?? functions/src/common/transaction-random.ts
?? functions/src/game-interruption/game-adapters.ts
?? functions/src/game-interruption/game-command-transaction.ts
?? functions/src/game-interruption/game-mutation.ts
?? functions/src/game-interruption/leave-request.ts
?? functions/src/game-interruption/recovery-state.ts
?? functions/src/room/create-room.ts
?? functions/src/room/room-allocation.ts
?? functions/src/room/room-cleanup.ts
?? functions/src/room/session-contract.ts
?? functions/src/room/session-functions.ts
?? functions/test/game-command-contract.test.mjs
?? functions/test/game-recovery-state.test.mjs
?? functions/test/network-session-boundaries.test.mjs
?? functions/test/room-session-contract.test.mjs
?? packages/game_kit/lib/core/diagnostics/recovery_metrics.dart
?? packages/game_kit/lib/recovery/models/game_recovery_context.dart
?? packages/game_kit/lib/recovery/models/room_session_identity.dart
?? packages/game_kit/lib/recovery/services/durable_room_operation_store.dart
?? packages/game_kit/lib/recovery/services/game_command_batch.dart
?? packages/game_kit/lib/recovery/services/required_image.dart
?? packages/game_kit/lib/recovery/services/room_recovery_batch.dart
?? packages/game_kit/lib/recovery/services/room_session_identity_store.dart
?? packages/game_kit/test/recovery/network_session_contracts_test.dart
?? packages/game_kit/test/recovery/providers/game_readiness_contract_test.dart
?? packages/game_kit/test/recovery/retry_budget_and_notice_test.dart
?? packages/game_kit/test/recovery/room_session_identity_store_test.dart
?? packages/game_kit/test/recovery/widgets/interruption_decision_contract_test.dart
?? test/auth/auth_gate_email_link_test.dart
?? test/auth/auth_gate_rotation_test.dart
?? test/auth/auth_gate_stuck_loading_test.dart
?? test/auth/email_link_error_message_test.dart
?? test/auth/google_login_button_test.dart
?? test/auth/onboarding_parity_test.dart
?? test/auth/register_loading_test.dart
?? test/auth/tablet_auth_parity_test.dart
?? test/controller_presence_test.dart
?? test/controller_reconnect_guard_test.dart
?? test/controller_room_lifecycle_test.dart
?? test/game_reconnect_screen_test.dart
?? test/mosigame_cli/arguments_test.dart
?? test/mosigame_cli/command_runner_test.dart
?? test/mosigame_cli/doctor_test.dart
?? test/mosigame_cli/guard_arguments_test.dart
?? test/mosigame_cli/invocation_guard_test.dart
?? test/mosigame_cli/package_test_manifest_test.dart
?? test/mosigame_cli/process_runner_test.dart
?? test/mosigame_cli/repository_snapshot_test.dart
?? test/mosigame_cli/result_test.dart
?? test/mosigame_cli/test_suites_test.dart
?? test/mosigame_cli/test_support.dart
?? test/mosigame_cli/validate_test.dart
?? test/platform_auth_shell_test.dart
?? test/restorable_player_session_test.dart
?? test/room_join_feedback_test.dart
?? test/room_leave_intent_test.dart
?? test/room_leave_state_test.dart
?? test/room_restore_to_waiting_test.dart
?? test/session_return_prompt_test.dart
?? test/social_login_button_test.dart
?? tool/mosigame_cli/package_test_manifest.dart
```
