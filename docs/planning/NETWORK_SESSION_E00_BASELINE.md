# E00 — 네트워크·세션 착수 기준 확인

[실행 계획](NETWORK_SESSION_IMPLEMENTATION_PLAN.md) · [제품 합의](NETWORK_SESSION_DESIGN.md) · [기술 계약](NETWORK_SESSION_TECHNICAL_DESIGN.md) · [작업 목록](TASKS.md)

2026-10-09 사용자가 develop에서 첫 작업을 진행하도록 요청했다. 이 기록은 E00의 코드 대조와
후속 구현 인수인계다. 후속 답변으로 전체 작업을 사용자가 수행한다고 확인했고 사람별 분담은 제거했다. 기능 구현 완료 기록이 아니다.

## 1. 실제 실행 기준

| 항목 | 확인 결과 |
| --- | --- |
| 작업 branch / HEAD | `develop` / `58634d1aee294a6ab4295bb814ae6c168539a7f5` |
| fetch 후 origin/develop | HEAD와 동일 |
| fetch 후 최신 origin/newgui | `fcee643d2dad6337e7ae40504cd8804c77ce2215` |
| 포함 관계 | 최신 newgui는 HEAD의 조상이며 `git diff origin/newgui..HEAD`는 비어 있음 |
| 시작 working tree | staged/unstaged/untracked 변경 없음 |
| 변경 범위 | E00 기록·계획·작업 목록·상세·일지. 제품 코드/테스트/검증 배선은 수정하지 않음 |

기존 정적 분석 기준 `999c3e9`와 계획 채택 당시 `a96097b`는 과거 근거다.
PR #140이 newgui를 develop에 반영했으므로 후속 구현은 위 develop 후보를 기준으로 한다.
다음 채팅에서 HEAD가 바뀌면 이 기록 이후의 관련 diff를 확인하고 새로운 차이만 전달한다.

### 이전 분석 뒤 달라진 것

- 서버 room/auth 파일의 관련 diff는 주석 보충이다. 공용 중단·게임 서버·rules의 준비/퇴장 계약이
  합의한 A~C로 바뀐 것은 아니다. `room_provider.dart` 관련 diff도 주석/포맷이며 기존 동작은 유지된다.
- 로비·로그인·스토어·Holdem 화면과 에셋 표현이 바뀌었다. 옛 화면 줄 번호나 위젯 구조를 그대로 사용하지 않는다.
- `fcee643`은 Holdem의 debug 번들 우회를 제거했다. `HoldemAssets`와 `HoldemGame`은 v2의 검증된
  다운로드 캐시를 사용한다. 로컬 설치 도구와 캐시 재사용/검증 테스트도 추가됐다.
  정상 네트워크 복구는 기존 검증 파일을 사용하는 합의를 유지하며 화면 디코딩 준비와 구분한다.
- 루트 workspace는 `game_kit`, `game_template`, LP/FC/Mafia/Holdem의 **6개**다. registry와
  `functions/src/index.ts`에 4게임이 실제 존재한다. Architecture/Package Migration의 5개 패키지·
  Cloud Functions의 3게임 설명은 과거 기준이므로 현재 파일 목록을 우선한다. 배포 상태는 조회하지 않았다.

## 2. 기존 계약·확인된 공백·미확인 사항·채택 계약

| 구분 | 현재 근거 / 후속 조치 |
| --- | --- |
| 기존 계약 | 서버가 게임 상태 전이를 결정한다. game/public·본인 private·server 경계, controllerSessionId, 명령별 commandId, root app→game_kit/게임 의존 방향을 유지한다 |
| 확인된 공백 | `game-interruption/state.ts`는 public.interruption 한 명만 유지하며 connection true에서 해당 중단을 취소한다. ready barrier와 다중 원인 집합은 없음 → E02/E03 |
| 확인된 공백 | `expire-resolution.ts`/scheduler는 만료 후 제외·종료를 수행한다. 합의한 태블릿의 60초 이후 선택·30초 한 번 연장으로 교체 필요 → E03 |
| 확인된 공백 | `RoomLeaveIntent`는 프로세스의 Set이며 fail에서 복원을 다시 허용한다. 재실행 보존·결과 미확정 중 의도 유지에 맞지 않음 → E06 |
| 확인된 공백 | `GameProgressCommand`는 실패 후 3초 재예약에 횟수/전체 예산 상한이 없다. Holdem 진행 요청은 단일 timer이고 재시도 버튼은 clearError에 연결됨 → E05/E07 |
| 확인된 공백 | 그룹 목록 서버는 요청한 방 대신 controllerRooms 매핑을 사용하고 클라이언트도 해당 callable에 방 식별을 보내지 않음 → E10-S/E10-P |
| 확인된 공백 | 합의한 room/game/member/connection/data/barrier 식별, 준비 보고/작업 조회 callable, terminal/generation/due 정리 저장소는 아직 코드에 없음 → E02/E03/E11-S |
| 확인된 검증 공백 | session/auth Flutter manifest 20개 누락. root FULL/CI에 package tests 명시 실행 없음 → E01 |
| 미확인 가설 | 오프라인 SDK 캐시의 null 이벤트가 실제 게임 삭제로 오인되는 조건, 구독 오류 뒤 실제 재구독 필요 조건, 파일 유실/손상·업데이트 예외의 실기기 재현은 아직 없음 |
| 미확인 측정 | 첫 오프라인 복원·온보딩 회복·상세/스토어 복귀·퇴장 경합의 OS/기기별 결과와 복구 단계별 지연 수치. 정적 확인을 실기기 PASS로 확대하지 않음 |
| 채택한 새 계약 | A 현재 접속/준비 식별, B durable 퇴장 intent, C terminal/generation/due 정리. 구현 전 타입/함수에 연결해야 하며 기존 구현이라고 표현하지 않음 |

준비·대기·시간·퇴장·재시도 정책은 기존 합의를 다시 선택하지 않는다.
기술안의 필드 수명/불변식은 채택됐지만 새 Dart/TypeScript DTO는 아직 없다. E02/E03에서 서버 DTO와
결과 타입을 만들고 E05/E06 소비자가 동일 계약을 사용한다. 이름/배치의 구현 선택과 제품 정책 변경을 구분한다.

## 3. 제공자와 실제 소비자

아래 경로는 저장소 루트 기준이다. `packages/game_<게임>/lib/shared/`는 LP/FC/Mafia/Holdem 각각의
`services/command_service.dart`, `query_service.dart`, `providers/game_controller.dart`를 뜻한다.

| 계약 / 제공 위치 | 현재 소비자 | 후속 단위 |
| --- | --- | --- |
| GameRoomContext / `packages/game_kit/lib/models/game_room_context.dart` | 구현은 `lib/platform/home/room/providers/room_provider.dart` 하나. TemplateGame의 phone/tablet 진입, 4게임 board와 공용 CriticalNetworkGuard가 사용 | E05/E06/E07/E08/E09 |
| GameSessionController·GameSessionState / `packages/game_kit/lib/recovery/` | 4게임의 shared/providers/game_controller.dart. 각 shared state mapper/query service와 phone/tablet 화면이 현재 상태를 소비 | E05 + 게임별 E07 |
| GameCommandService·GameQueryService / `packages/game_kit/lib/services/` | 4게임 shared/services/command_service.dart·query_service.dart 및 GameInterruptionCommandService | E03/E04/E05/E07 |
| GameProgressCommand / `packages/game_kit/lib/recovery/services/game_progress_command.dart` | LP tablet/src/board_state.dart와 shared/providers/game_controller.dart, FC/Mafia tablet/src/board_state.dart. Holdem은 tablet/tablet_board.dart의 별도 timer | E05/E07 |
| join/resume/create/leave/close/presence / `functions/src/room/` | `lib/platform/home/room/services/room_service.dart` → RoomProvider → phone_home·phone_room_waiting·tablet_home·tablet_game_launcher | E02/E06/E09/E11-S |
| 공용 interruption callable / `functions/src/game-interruption/` | game_kit의 recovery/services/game_interruption_command_service.dart → recovery/widgets/game_interruption_layer.dart. stale 신고는 RoomService/RoomProvider | E03/E05/E06/E08 |
| 그룹 목록 / fetchRealtimeRoomGroupEntitlements | `lib/platform/home/gamelist/service/game_list_service.dart` → RoomProvider 및 게임 목록 화면 | E10-S/E10-P |
| 퇴장·저장 세션 / RoomLeaveIntent·PlayerRoomSessionStore·ControllerRoomSessionStore | RoomProvider, phone_home의 저장 방 복원, RoomService의 controller 소유권 첨부, 공용 GameCommandService | E02/E05/E06/E09 |
| 에셋 / `lib/game_assets/` + game_kit/core/assets + 각 게임 asset 정의 | prepareGameAssetsForPlay, tablet_game_launcher, phone_room_waiting, 게임 adapter/화면. Holdem은 캐시 v2 | E07/E09 |
| 안내·route / game_kit/recovery/widgets·mosi_ui/mosi_connection.dart·shared/widgets/game_route_exit.dart·widgets/game_exit_route.dart | 4게임 phone/tablet, phone의 session_return_prompt/controller_reconnect_guard/lobby_reconnect_guard, tablet_game_launcher | E07/E08/E09 |

`game_flow/`, `services/`, `widgets/`, `session/`의 일부 옛 경로는 recovery 구현을 re-export한다.
둘을 별도 구현으로 수정하지 않는다. 모든 게임의 서버 export는 `functions/src/index.ts`에서 확인한다.

### callable·trigger 경계

- 기존 room callable은 RoomService가 `asia-northeast3`로 호출한다. 그룹 목록은 GameService가 같은 리전을 쓴다.
  게임 command 및 interruption service는 GameCommandService의 `functionsRegion='asia-northeast3'`를 사용한다.
- 기존 공용 이름: `game_common_interruption_report_stale_player`, `vote_to_continue`, `exclude_player`,
  `expire`, `finish_now`는 모두 `game_common_interruption_` 접두사다. 게임별 command는 각 command_service의
  `game_liars_poker_*`, `game_final_call_*`, `game_mafia_*`, `game_holdem_*`와 index export를 대조한다.
- 현재 interruption 요청은 roomCode/interruptionId, 서버 stale 요청은 playerUid/관측 lastSeen,
  controller 요청에는 controllerSessionId가 첨부된다. 현재 GameInterruption DTO는 단일 playerUid·deadlineAt·
  투표/계속 가능 필드이며 새 원인 집합 DTO로 바뀔 소비자가 위 표에 포함된다.
- RTDB trigger는 `asia-southeast1`: players/{uid}/isConnected, controllerPresence/connected,
  game/public/status, 방 삭제 경로. 접속별 presence/terminal 변경 때 rules와 trigger의 같은 변경이 필요하다.
- 만료/ghost/방 cleanup scheduler는 `asia-northeast3`. 기존 삭제 trigger만으로 terminal 정리 완료를 처리하지 않는다.
- 새 `game_common_recovery_report`, `game_common_operation_status`는 **채택 계약의 구현 예정 이름**이다.
  현재 export/호출은 없으며 E03 제공 후 E05/E06 소비자를 연결한다. 신규 callable은 기존 서울 리전을 따른다.

ready/failed 요청과 결과·오류·재전송 수명은 [기술안 R11](NETWORK_SESSION_TECHNICAL_DESIGN.md#34-준비-보고-api-제안),
작업 결과 applied/rejected/notApplied/stale/unknown과 최소 context는
[R13](NETWORK_SESSION_TECHNICAL_DESIGN.md#51-명령과-결과-계약)을 따른다.
ready에는 현재 barrier/data 식별이 필요하고 failed에는 최신 데이터 확보를 요구하지 않는다.
두 계약의 카드/역할 비노출·reportSeq/멱등성·unknown 보호를 후속 타입 작성에서 보존한다.

## 4. E01에 넘길 검증 기준

| 대상 | 현재 확인 / E01에서 할 일 |
| --- | --- |
| session Flutter | manifest 10개 모두 없음. 존재하지 않는 경로를 삭제해 통과시키지 말고 각 회귀의 실제 소비자/시나리오를 복원 |
| auth Flutter | manifest 10개 모두 없음. 현재 auth_lobby_entry_test와 새 GUI 테스트는 기존 10개 전체를 대체한다는 근거가 없음 |
| targeted Functions | controller-presence-timer, room-lifecycle, auth-delete-account, auth-onboarding 4파일 존재. manifest 실패 때문에 이번 targeted 실행에서는 실행되지 않음 |
| package tests | game_kit 9, LP 1, FC 4, Mafia 7, Holdem 6파일 존재. package working directory에서 실제 실행·실패 전파 필요. game_template은 test 파일 없음; 무테스트를 PASS로 세지 않음 |
| FULL / CI | FULL은 root flutter test 및 Functions lint/test를 호출. root format에도 packages가 빠짐. workspace 등록만으로 package test 실행을 보장하지 않음 |
| 기존 실제 테스트 | test/auth_lobby_entry_test.dart, test/tablet_room_reset_test.dart, 에셋·로비 테스트와 기존 package 회귀를 보존. 최신 DTO/화면에 맞춰 의미 있는 검증으로 연결 |

E01의 결과는 V00의 실행 manifest·working directory·관련 회귀·실패 전파·FULL/CI 증거다.
이번 E00에서 테스트 파일이나 manifest를 만들거나 바꾸지 않는다. E02/E03 등의 기능 회귀는 각 구현 단위에서 추가한다.

## 5. 전체 사용자 담당 — 사람별 분담 제거

사용자가 모든 작업을 수행한다. 기존 2인 협업을 전제한 분담안은 폐기하고 AI는 각 구현 채팅에서 사용자를 돕는다.

| 작업 영역 | 사용자가 보는 결과 | 작업 위치 |
| --- | --- | --- |
| 패키지 P | 현재 손패/단계로 복귀, 준비 전 입력 보호, 복구/중단 안내와 실제 버튼 | game_kit와 4게임의 화면·조작·공용 복구 기반·package 테스트 |
| 플랫폼/서버/검증 T | 누가 중단 대상인지·언제 재개할지·남은 시간/퇴장 결과를 서버와 앱이 일치시키고 검증 전체 실행 | functions, 플랫폼 방/인증/복귀/저장, root/Functions/CLI 테스트·FULL/CI 배선 |
| 공통 | 양쪽의 호출/데이터 계약이 맞고 실제 기기에서 의도대로 동작 | 계약 인수인계·통합 판정·기기 확인·측정 후 목표 |

P/T는 사람 구분이 아닌 영역 표기다. 같은 사용자가 두 영역을 모두 수행하므로 다른 담당의 승인을 기다릴 조건은 없다.
채팅 범위는 선행 계약을 받아 구현·검증하고 완료 결과를 다음 단위에 남기기 위해 유지한다.
제품 정책·기술안 A~C·E/V 의존 순서와 각 단위의 실제 완료 조건은 바뀌지 않는다.

E00 기준 확인과 인수인계는 정리됐으며 다음 구현 단위는 E01이다. E01 구현은 아직 시작하지 않았다.

## 6. 실행 evidence와 한계

- `git fetch origin develop newgui`: PASS, process exit 0. 새 제품 merge 없이 원격 기준 확인.
- `git merge-base --is-ancestor origin/newgui HEAD`, `git diff origin/newgui..HEAD`: PASS, exit 0.
- PowerShell manifest 24경로/6개 package test 파일 존재 대조: PASS, exit 0. 20개 누락 확인은 검사 결과이지 제품 테스트 통과가 아님.
- `.\tool\invoke_mosigame.ps1 test session`: INVALID, controller_presence_test.dart 누락으로 실행 전 종료.
  호출 도구가 관찰한 PowerShell process exit는 1이며 CLI의 INVALID 계약 exit 2와 구분한다.
- `.\tool\invoke_mosigame.ps1 test auth --json`: INVALID, errorCount 10, JSON CLI exitCode 2 / 관찰 process exit 1.
  auth_gate_email_link_test.dart 누락. root/package/Functions 테스트는 이 두 명령에서 미실행.
- 검증 실행 전후 tree는 위 문서 작성 전까지 clean이었다. 문서 검사와 최종 tree는 월별 기록에 남긴다.
- FULL/CI/emulator/실기기/production은 이번 E00에서 실행하지 않았다. 과거 PR 후보의 PASS를 현재 네트워크 계약 구현 완료로 사용하지 않는다.

E00 기준 리뷰 결과를 기능 구현 완료·FULL PASS로 표현하지 않는다. 기술안 A~C와 제품 정책은 재합의 대상이 아니다.
