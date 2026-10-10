# LP 룰렛·미확정 시작 요청 수정 설계

2026-10-10 KST. [작업 목록](TASKS.md)의 SESSION-RECONNECT-02와
TEST-REGRESSION-01 후속이다. [인계](NETWORK_SESSION_REPAIR_HANDOFF.md)와
[실기기·서버 근거](NETWORK_SESSION_STARTUP_INVESTIGATION.md#roulette-restart-investigation)를 따른다.
2026-10-10 사용자가 계약 변경 설계를 승인했다. 구현과 관련 검사는 통과했으며
최종 후보도 별도 사용자 승인 후 FULL 12/12 PASS/exit 0이다. 배포·실기기 수정 검증 완료를 뜻하지 않는다.

## 재확인한 원인과 한계

- LP prepare의 commandId를 resolve에도 사용한다. 공통 ledger는 같은 ID에 다른
  kind/payload를 허용하지 않으며 서버 resolve도 두 ID의 일치를 강제한다.
- 공통 시작 fingerprint가 players 전체를 비교하므로 lastSeen·접속 갱신도 aborted가 된다.
- runPrimedTransaction이 update 예외를 SDK callback 밖으로 그대로 던진다.
  SDK 비동기 재실행에서는 정상 abort·rollback·완료 경로를 빠져나갈 수 있다.
- 네 게임의 TemplateGame.startGame은 호출마다 서비스를 생성한다. 인스턴스의 미확정
  ID를 다음 설정 완료 요청이 이어받지 못한다. 자리 저장부터 다시 하는 것도 이미
  시작된 게임에서는 거절될 수 있다.
- 공통 operation_status의 applied를 현재 클라이언트는 결과 없는 success로 바꾼다.
  응답을 잃은 추첨에는 resolutionId/result가 필요하므로 원래 명령 결과를 재생해야 한다.

실기기 종료 성공과 서버 60초 504·후속 409는 확보됐다. production DB의 실제 commit
여부와 로그 비동기 예외의 정확한 실행 귀속은 미확정이며 새 조회 없이 유지한다.

## 승인한 계약과 구현

1. **추첨 ID와 확정 요청 ID를 분리한다.** 기존 pendingPenaltyResolution 구조와
   prepare 응답의 resolutionId는 유지한다. resolve는 별도 commandId를 쓰고 서버는
   현재 pending의 resolutionId/대상과 일치하는지만 검사한다. 확정 재시도는 같은
   commandId와 원래 envelope를 보존한다. 다른 kind의 같은 ID를 허용하는 ledger 예외는
   만들지 않는다. 같은 추첨의 새 prepare는 보관 결과를 반환하고 재추첨하지 않는다.
2. **시작 비교를 게임 준비 입력으로 한정한다.** selectedGame·방 status 및 UID별
   role/status/membershipId/seatIndex/nickname/characterId/profileImageUrl을 정규화해 비교한다.
   lastSeen/isConnected/currentConnectionId/connectionSeq는 비교에서 제외한다.
   실제 참가 자격·좌석·표시 정보 변경은 거절하고 현재 접속/권한 검사는 공통 경계에
   남긴다. 준비 barrier가 실제 연결 단절을 계속 다룬다.
3. **update 예외는 안전하게 abort한 뒤 전파한다.** 첫 예외와 stack을 저장하고 callback은
   undefined를 반환한다. 이후 callback도 abort한다. SDK transaction의 완료를 await한
   뒤 저장한 원래 예외를 호출자에게 전달하고 value listener는 finally에서 제거한다.
   SDK 소스·timeout·게임 진행 규칙은 변경하지 않는다.
4. **시작 의도는 UID/role/roomInstance 단위로 저장한다.** 기존 직렬 identity 저장소에
   pendingGameStart(functionName와 원래 payload)를 추가한다. 전송 전에 저장하며 저장
   실패 시 전송하지 않는다. 새로운 서비스·UI 재시도·앱 재실행도 이 값을 이어받는다.
   timeout/internal/unknown 등의 미확정 결과에서 삭제하지 않고 TTL도 두지 않는다.
   성공·stale 또는 최초 요청의 확정 거절 뒤 해당 ID만 제거한다. 이미 미확정인 시작의
   후속 거절은 최초 완료를 입증하지 못하므로 원래 ID를 유지한다. 자동 반복 전송 없이
   수동 확인/재생한다. identity 갱신은 같은 방의 의도를
   보존하며 다른 roomInstance와 방 퇴장에서는 이어받지 않는다.
5. **재시도는 원래 결과 확인을 먼저 한다.** 새 context/ID/좌석 저장으로 덮기 전에
   operation_status를 조회한다. applied면 원래 payload의 callable을 재생해 실제 응답을
   받는다. notApplied도 원래 ID/payload를 다시 보낸다. 다른 시작 옵션·게임을 요청하면
   미확정 의도를 교체하지 않고 기존 요청 확인을 요구한다. stale은 명시 실패로 처리한다.
   현재 연결 envelope만 갱신하며 서버 domain fingerprint는 유지한다.
6. **자리 설정 재시도는 저장을 반복하지 않는다.** pending 시작이 있으면 기존 명령의
   결과 확인/재생으로 바로 이어간다. 새로운 시작은 기존 좌석 저장→start 흐름을 유지한다.
   정상 로딩·기존 메뉴·canSend·준비 barrier UI는 보존한다.

## 소비자와 반영 영향

- LP command/coordinator, 공통 GameCommandService·identity 저장소, tablet launcher를
  연결하고 Final Call·Mafia(역할/규칙 옵션)·Holdem의 시작/재시작 소비자를 점검한다.
- 공통 서버 transaction 수정은 방 lifecycle·네 게임 명령에 영향을 준다. callback
  오류의 종료 방식만 바꾸며 성공 ledger·멱등·권한 검사는 유지한다.
- callable 이름·리전·RTDB pendingPenaltyResolution shape·rules는 유지한다.
  LP resolve의 ID 관계와 로컬 저장 shape/API가 명시 승인 경계다.
- 새 서버를 먼저 반영한 뒤 수정 앱을 적용하면 새 ID resolve를 수락한다. 기존 앱의
  충돌 요청을 성공으로 바꾸지는 않는다. 이전 사용자 결정대로 구버전 앱 지원은 완료
  조건이 아니다. 실제 배포·production 조회·migration·commit/push는 이번 범위에 없다.

## 회귀와 검증 계획

- 실제 callable .run과 메모리 RTDB: prepare→resolve, 추첨/확정 응답 유실과 동일 요청
  재생, 새 prepare의 재추첨 금지, 잘못된 resolution/UID/ID 재사용 거절, 한 번만 반영.
- 네 게임 callable 시작→종료→재시작, 정상 heartbeat 경합 성공, 실제 roster/seat/자격
  변경 거절, 원래 start 재생은 동일 gameInstanceId, 새 ID는 기존 진행 게임을 덮지 않음.
- 설치 RTDB SDK의 실제 rerun/abort 본문을 고립 실행해 예외 시 완료 callback·rollback·
  queue 정리 및 후속 transaction 진행을 확인한다. emulator/실기기 검증과 구분한다.
- Flutter 실제 command와 채널 harness: 새 서비스와 context 변경 뒤 원래 ID 재사용,
  applied 응답 재생, pending 저장 실패 시 미전송, UID/roomInstance/옵션 경계, 시작
  재시도의 좌석 재저장 방지와 LP 두 단계 연결을 확인한다.
- 기존 Windows guarded session에 관련 회귀를 연결하고 필요한 package/Functions 검사,
  분석·포맷·lint를 실행한다. 최종 후보에 사용자 명시 승인을 받은 뒤 guarded FULL을
  한 번 실행한다. 미실행 APK·기기·배포는 별도 한계로 남긴다.

## 작업 시작 상태

branch `codex/e01-validation-wiring`, HEAD `e787a10de8723d66b08c84b173a07ddbf267b113`.
staged 없음. 기존 unstaged 문서 NETWORK_SESSION_REAL_DEVICE_HANDOFF.md,
TASKS.md, logs/2026-10.md와 untracked NETWORK_SESSION_REPAIR_HANDOFF.md를 보존한다.

## 2026-10-10 승인 전 회귀 재현

제품 소스는 수정하지 않았다. 기존 조사 자료를 읽고 정식 회귀를 추가했다.

| command | status / exit | 확인 범위 |
| --- | --- | --- |
| `node functions/node_modules/typescript/bin/tsc --project functions/tsconfig.json` | PASS / 0 | 현재 후보 서버 소스를 ignored lib에 컴파일 |
| `node --test functions/test/roulette-restart-integration.test.mjs functions/test/room-transaction-rerun.test.mjs functions/test/start-game-transaction.test.mjs` | FAIL / 1 | 16개 중 7 PASS / 9 FAIL / skip 0 |

실패 9개는 LP 분리된 ID 확정/거절 분기 2개, 네 게임의 정상 heartbeat 경합 4개,
SDK 예외의 완료·rollback 2개, heartbeat/접속 교체 fingerprint 1개다.
실제 좌석 변경 거절 4개와 기존 fingerprint/보호 검사 3개는 통과했다.
이는 수정 전 결함 재현이며 수정 완료 판정이 아니다.
출력은 ignored `build/network-session-investigation/roulette-restart-repair-before.tap`에 저장했다.

첫 SDK harness는 package exports가 막은 subpath resolve로 실행되지 않았다. 설치 SDK의
실제 파일을 URL로 읽도록 harness만 수정한 뒤 위 결함을 재현했다.
Firebase 앱·emulator·production·새 로그 조회는 실행하지 않았다.

승인 전 변경 파일은 이 설계 문서, 기존 start-game-transaction.test.mjs 및 새
roulette-restart-integration.test.mjs, room-transaction-rerun.test.mjs다.
기존 사용자 문서 4개는 편집하지 않았고 staged/branch/HEAD도 유지했다.
계약 변경 승인 질문을 제시했으며 응답 전 제품 구현은 시작하지 않는다.
targeted session과 최종 FULL은 미실행이며 이번 회귀는 구현 후 session에 연결한다.

## 2026-10-10 승인 후 구현 후보와 관련 검증

사용자의 “승인할게”를 위 계약 변경·구현 승인으로 확인하고 제품 수정을 진행했다.
최종 후보 FULL은 관련 검사 후 별도 승인을 받는 절차로 안내했다.

| 변경 파일 | 구현/회귀 |
| --- | --- |
| functions/src/liars-poker/finish-penalty.ts, packages/game_liars_poker/lib/shared/services/command_service.dart | 추첨과 확정 ID 분리, 같은 확정 ID 재시도 |
| functions/src/common/start-game-transaction.ts, functions/src/room/room-transaction.ts | 의미 있는 시작 입력 비교, 예외 abort 완료 뒤 원래 예외 전달 |
| packages/game_kit/lib/recovery/services/room_session_identity_store.dart | pendingGameStart 직렬 영속화, 동일 방/참가 보존, 실패 시 저장소·native cache 복원 |
| packages/game_kit/lib/services/game_command_service.dart | 원래 결과 재생, UID/방/참가 확인, 시작 단일 전송·미확정 의도 유지, 늦은 응답의 새 ID 정리 방지 |
| lib/platform/home/tablet/tablet_game_start.dart, tablet_game_launcher.dart | pending 시작은 좌석 재저장 생략, 취소/명단 정리로 덮어쓰지 않음 |
| functions/test/roulette-restart-integration.test.mjs, room-transaction-rerun.test.mjs, start-game-transaction.test.mjs | 실제 네 게임 start/end 및 LP callable, 설치 SDK rerun/abort 본문, fingerprint 회귀 |
| test/game_command_response_loss_test.dart, packages/game_kit/test/recovery/pending_game_start_test.dart | 실제 네 TemplateGame·LP command/coordinator·Functions 채널, timeout/응답 유실, process reload·저장 실패·옵션·UID·방 경계 |
| tool/mosigame_cli/test_suites.dart, test/mosigame_cli/test_suites_test.dart | 기존 session manifest에 관련 회귀 연결과 정확한 목록 검사 |

정상 로딩·메뉴·canSend·준비 barrier UI 계약은 유지했다. 호출 중 태블릿 선택이
정상 해제되는 기존 흐름을 확인해 설정 callback의 유효성은 layout 수명/방 코드로 검사한다.
이전 미확정 시작의 후속 already-exists는 최초 완료를 확정하지 않으므로 ID를 유지한다.
최초 확정 aborted는 정리해 실제 좌석 변경 수정 후 새 시작을 허용한다.

| 실제 command | status / exit | 범위 |
| --- | --- | --- |
| `node functions/node_modules/typescript/bin/tsc --project functions/tsconfig.json` | PASS / 0 | 서버 컴파일 |
| `node --test functions/test/roulette-restart-integration.test.mjs functions/test/room-transaction-rerun.test.mjs functions/test/start-game-transaction.test.mjs` | PASS / 0 | 16/16, skip 0 |
| `C:/flutter/bin/flutter.bat test --no-pub test/game_command_response_loss_test.dart packages/game_kit/test/recovery/pending_game_start_test.dart` | PASS / 0 | 15/15; 이후 최종 source는 guarded session에서도 통과 |
| `C:/flutter/bin/flutter.bat analyze --no-pub lib/platform/home/tablet/tablet_game_start.dart lib/platform/home/tablet/tablet_game_launcher.dart packages/game_kit/lib/services/game_command_service.dart packages/game_kit/lib/recovery/services/room_session_identity_store.dart packages/game_liars_poker/lib/shared/services/command_service.dart test/game_command_response_loss_test.dart packages/game_kit/test/recovery/pending_game_start_test.dart tool/mosigame_cli/test_suites.dart test/mosigame_cli/test_suites_test.dart` | PASS / 0 | 9개 변경 파일, 문제 없음 |
| `C:/flutter/bin/cache/dart-sdk/bin/dart.exe format --output=none --set-exit-if-changed lib/platform/home/tablet/tablet_game_start.dart lib/platform/home/tablet/tablet_game_launcher.dart packages/game_kit/lib/services/game_command_service.dart packages/game_kit/lib/recovery/services/room_session_identity_store.dart packages/game_liars_poker/lib/shared/services/command_service.dart test/game_command_response_loss_test.dart packages/game_kit/test/recovery/pending_game_start_test.dart tool/mosigame_cli/test_suites.dart test/mosigame_cli/test_suites_test.dart` | PASS / 0 | 9개 파일, 변경 0 |
| `node node_modules/eslint/bin/eslint.js --ext .js,.ts .` (functions) | PASS / 0 | Functions lint |
| `npm --prefix functions test` | PASS / 0 | 385/385, skip 0 |
| `.\tool\invoke_mosigame.ps1 test session --json` | PASS / 0 | 5/5 steps, Flutter 127/Functions 89, mutation PASS |
| `C:/flutter/bin/flutter.bat test --no-pub test/mosigame_cli/test_suites_test.dart packages/game_kit/test/recovery/room_session_identity_store_test.dart packages/game_kit/test/recovery/pending_game_start_test.dart` | PASS / 0 | 31/31, 기존 저장·방·계정 경계 및 manifest |
| `git diff --check` | PASS / 0 | whitespace 오류 없음 |

guarded session 시작은 2026-10-10 06:36:06 KST, 75075ms, 전후 tracked/untracked
mutation 없음이다. 결과 JSON과 Functions TAP은 ignored build/network-session-investigation/
roulette-restart-repair-session.json, roulette-restart-repair-functions.tap에 보존했다.

중간 실행 문제는 최종 PASS와 구분한다. 서버 compile 완료를 기다리기 전 테스트를
시작한 한 실행은 이전 lib를 포함해 13/16이었다. compile 완료 후 재실행은 16/16이다.
Flutter 채널 mock의 error details 형식 오류로 1개 실패했으며 실제 SDK 형식으로 harness를
고친 뒤 통과했다. native 파일 잠금으로 포맷 쓰기가 일부 실패해 출력 파일을 반영하고
최종 무변경 포맷 검사를 통과했다. SDK 소스를 수정하거나 테스트를 약화하지 않았다.

실행 전후 branch/HEAD는 위 작업 시작 값과 같고 staged 없음이다. 기존 사용자 문서
NETWORK_SESSION_REAL_DEVICE_HANDOFF.md와 NETWORK_SESSION_REPAIR_HANDOFF.md는 편집하지
않았다. 기존 TASKS.md·logs/2026-10.md 내용은 보존하고 이번 후보 근거만 갱신/추가한다.
추가 파일은 위 제품·회귀·계약·작업 기록의 의도한 변경이다.

관련 검사 종료 당시 `validate --full`은 최종 후보의 새 승인 전이므로 NOT_RUN이었다. 설치 SDK 본문 고립
실행은 emulator/production 검증이 아니다. 수정 APK·실기기·CI·production commit 확인,
배포·migration·commit/push는 실행하지 않았다. SESSION/TEST 전체 완료나 출시 ACCEPT를 선언하지 않는다.

## 2026-10-10 최종 후보 승인 FULL

관련 PASS와 최종 후보를 요약하고 FULL 승인을 요청했다. 사용자 “승인할게” 응답 후
같은 제품 후보에 `.\tool\invoke_mosigame.ps1 validate --full --json`을 한 번 실행했다.
2026-10-10 07:05:11 KST 시작, 239473ms, status PASS, exit 0, 12/12 steps이다.

| 단계 | 결과 |
| --- | --- |
| preflight, 루트 포맷·분석 | PASS, 포맷 151개/변경 0, 분석 문제 없음 |
| 루트 Flutter | 346 PASS |
| game_kit / liars_poker / final_call / mafia / holdem | 83 / 5 / 14 / 55 / 31 PASS, 합계 188 |
| Functions lint / 전체 test | PASS / 385 PASS, fail 0, skip 0 |
| working-tree-mutation | PASS, 실행 전후 tracked/untracked 상태 동일 |

모든 process 단계 exit 0, timeout 없음이다. 포맷·분석·루트/다섯 package 테스트·서버
검사를 포함한다. guard/process/환경 코드는 변경하지 않았으므로 별도 invocation-guard
통합 검사는 이번 후보 범위에 해당하지 않는다.

guard 출력은 실행 도구에 전달됐지만 PowerShell redirect 파일은 0바이트였다. 재실행하지
않고 도구가 받은 원래 단일 결과 JSON을 그대로 ignored
build/network-session-investigation/roulette-restart-repair-full-approved.json에 보존했다.

검증 전후 branch codex/e01-validation-wiring, HEAD e787a10de8723d66b08c84b173a07ddbf267b113,
staged 없음, 의도한 modified 16/untracked 7개로 동일하다. 기존 사용자 변경은 유지했다.
FULL 종료 후 이 결과·TASKS·상세·일지만 갱신했으며 제품 소스는 변경하지 않았다.
수정 APK/실기기·실제 CI·production commit 확인과 배포는 미실행이다.

