# 출시 전 필수 수정과 확인 현황

이 문서는 2026-08-30 점검·제한된 production 관찰과 2026-08-31에 전달받은 실기기
결과를 관리하는 출시 차단 항목의 단일 원본이다. 기록일과 실제 테스트일은 구분한다.
코드가 존재하거나 자동 테스트가 통과한 사실만으로 항목을
완료 처리하지 않는다. 각 항목의 완료 조건과 최종 실기기 확인을 모두 충족해야 한다.

2026-08-31 후속 구현·FULL 자동 검증·관련 함수 13개와 rules 지정 배포·설치 APK 생성은
완료했다(Flutter 643개, Functions 274개, exit 0). 이후 사용자가 수정본의
[최종 세 시나리오](../operations/REAL_DEVICE_AUTH_NETWORK_SESSION_CHECKLIST.md)를 모두
통과로 명시했다. **라이어스포커 / Android Medium Tablet 에뮬레이터 + A32·A35**의
보고 환경에서 남아 있던 다섯 수정 항목의 검증을 완료하고 해당 출시 차단을 해제한다.
이전 실패 기록은 이력으로 보존한다. 물리 태블릿·iOS·다른 게임의 새 수동 검증이나
스토어 출시 완료까지 뜻하지 않는다.

## 신규 미해결 항목 — 기존 해결 항목과 별도

### ROOM-CREATE-REQUEST-01 — 방 생성 요청 기록 잔류

- **등록일·상태:** 2026-08-31 사용자 전달 사항. 미해결·수정 방향 검토 대기.
  기존 항목의 통과·차단 해제와 별도로 관리하며, 앞선 FULL PASS나 배포·실기기 결과로
  이 항목까지 해결됐다고 판단하지 않는다.
- **목적:** 방은 생성됐지만 앱이 응답을 받지 못해 재시도할 때, 요청 기록으로 중복 방
  생성을 막는다. 중복 방지 자체는 필요한 동작이다.
- **현재 문제:** 방과 요청 기록을 따로 삭제하므로 중간에 실패하면 요청 기록만 남을
  수 있다는 사용자 보고다.
- **누적 원인:** 방 없이 남은 요청 기록을 다시 찾아 정리하는 처리가 없다는 보고다.
- **검토할 점:** 방 생성·재시도 정책을 기준으로 별도 요청 기록을 유지하는 방식이
  꼭 필요한지 재검토한다. 유지한다면 부분 실패 뒤 정리·재처리 방안도 함께 검토한다.
  요청 기록 삭제나 대체 방식은 아직 결정하지 않았다.
- **확인 범위·다음 작업:** 이번에는 문서에만 기록했다. 코드 원인 확인, 운영 데이터의
  잔류·누적 규모 조회, 재현 테스트, 수정·배포는 수행하지 않았다. 사용자가 다음에
  전달할 추가 수정 사항과 함께 정리하고, 중복 방지 유지와 잔류 기록 처리의 검증
  조건을 정한다.

기존 `ROOM-CLEANUP-01`의 종료·유령 방 정리 문제와 구분한다. 해당 항목의 해결 기록과
통과 판정은 유지한다.

## 기존 출시 차단 항목 — 해결·검증 이력

| ID | 항목 | 현재 근거 | 상태 |
| --- | --- | --- | --- |
| SESSION-RECONNECT-01 | 반복 단절 후 세션·방 유실 | 수정 APK의 시나리오 1 전체 통과. 반복 단절·복구 후 게임 진행과 종료·그룹 복귀 정상 보고 | 통과·차단 해제(보고 환경 범위) |
| SESSION-TIMER-01 | 단절 중 남은 턴 시간 보존 | 태블릿 중단 화면 이후 30초 기다려 복구했을 때 6초 남음. 사용자가 정상 동작·전체 통과로 명시 | 통과·차단 해제. 재개 방식 이해도는 출시 후 관찰 |
| CONTROLLER-RECOVERY-01 | 태블릿 단독 단절 후 복구 | 시나리오 2의 태블릿 단절 복구·게임 조작 모두 통과 보고 | 통과·차단 해제(태블릿 역할은 에뮬레이터) |
| LEAVE-CONSISTENCY-01 | 퇴장 참가자 잔류 | 시나리오 2 전체 통과. 퇴장 뒤 명단 재등장 없음·남은 휴대폰 그룹 복귀 확인 보고 | 통과·차단 해제(보고 환경 범위) |
| AUTH-BACK-01 | 회원가입 이메일 입력 화면 뒤로가기 | 사용자가 회원가입 체크를 성공적으로 마쳐 메모를 남기지 않았다고 추가 확인 | 실기기 통과(사용자 확인). 설치 빌드 식별은 별도 미확인 |
| FINISH-SYNC-01 | 종료 후 winner 잔류·대기실 복귀 | 시나리오 1의 종료·그룹 복귀와 시나리오 3의 winner 직후 태블릿 재시작 모두 통과. winner 아래 안내 겹침은 사용자 요청대로 후속 개선 | 통과·차단 해제(보고 환경 범위) |
| NET-UI-01 | 네트워크 오류와 태블릿 재연결 화면 전환 | 2026-08-31 사용자 추가 확인으로 휴대폰/태블릿 단절 안내 구분·불필요한 교대 표시 없음의 통과 확정 | 기존 실기기 통과 유지. winner 아래 안내 겹침은 별도 출시 후 항목 |
| ROOM-CLEANUP-01 | 종료된 방과 유령 방 정리 정체 | `cleanupAt` 별도 후보, 구형 finished fallback, 건수 로그와 회귀 테스트 구현 | 코드·자동 검증·rules·지정 함수 배포·Scheduler 운영 확인 완료 |

## 2026-08-31 수정 APK 최종 사용자 테스트 — 세 시나리오 통과

### 빌드와 환경

- 테스트일·게임: 2026-08-31, 라이어스포커.
- 태블릿 역할: Android 에뮬레이터 `Medium Tablet`. 물리 태블릿 테스트로 기록하지 않는다.
- 휴대폰 A: Galaxy A32, 휴대폰 B: Galaxy A35. 각 Android OS 버전은 미제공이다.
- 사용자 보고 APK: `mosigame-sessionfix-20260831.apk`,
  `1.0.0-sessionfix.20260831+1` debug, 패키지 `com.warmhandongne.msg`.
- 사용자 제공 SHA256: `A5328AE0AF2DCC6844FB8477F850DAF95B72A32AC94E00E479CA3FA422D9987A`.
  앞선 생성·검증 APK와 같은 식별자다. 기기 설치 상태를 에이전트가 직접 조회한 것은 아니다.
- 서버 기준: 2026-08-31 01:52 KST 관련 함수 13개 및 presence 규칙 배포본.

### 결과와 메모 판정

| 시나리오 | 판정 | 사용자 보고와 해석 |
| --- | --- | --- |
| 1. 같은 게임 두 번 단절·복구·종료 | 통과 | 사용자가 전체 통과이며 오류 때문에 메모한 것이 아니라고 명시. 태블릿 중단 화면 뒤 30초 기다렸다가 복구해 6초가 남았고, 반복 단절·복구에도 게임 진행 정상. 마지막 종료·그룹 복귀도 전체 통과 범위에 포함 |
| 2. 태블릿 단절 복구·퇴장 참가자 잔류 | 통과 | 사용자가 모든 항목 통과로 명시. 복구, 명시적 게임·그룹 퇴장, 명단 잔류 없음, 남은 휴대폰 복귀 포함 |
| 3. winner 직후 태블릿 강제 종료·재시작 | 통과 | 사용자가 통과로 명시. winner 표시 아래 태블릿 오류 화면이 나타나는 것은 오류 판정이 아니라 출시 후 개선 요청으로 분리 |

타이머의 중단 직전 숫자와 서버 pause 시각을 추정해서 채우지 않는다. 사용자가 정상
재개로 판단해 통과시킨 기능 판정은 유지한다. 사용자가 그 남은 시간을 납득할지에 대한
우려는 [GAME-PAUSE-UX-01](POST_LAUNCH_IMPROVEMENTS.md#game-pause-ux-01--단절-후-남은-시간-재개-안내)에
기록한다. winner 아래 화면은 사용자 표현인 `태블릿 오류 화면`을 보존하며 정확한 문구나
route를 추정하지 않는다. [WINNER-CONNECTION-LAYER-01](POST_LAUNCH_IMPROVEMENTS.md#winner-connection-layer-01--winner-아래-태블릿-연결-안내-겹침)로
별도 추적한다. 두 메모를 실패로 바꾸거나 이미 통과한 시나리오의 재검사를 요구하지 않는다.

이번 보고의 범위는 위 게임·기기 조합이다. 물리 태블릿의 OS/백그라운드 제약, iOS와
마피아·파이널콜의 새 수동 테스트까지 통과했다고 확대하지 않는다. 이 범위 차이는 기록상
검증 한계이며 사용자가 통과로 확인한 세 시나리오를 보류로 되돌리는 근거가 아니다.

이번 결과 반영은 문서 4개만 수정했다. 구현 스킬·Project CLI 재실행·추가 production
조회·배포는 수행하지 않았으며 앞선 FULL PASS와 배포 근거를 유지한다. 전후 1,011개
경로의 SHA256 비교에서 이 문서, `POST_LAUNCH_IMPROVEMENTS.md`, 최종 체크리스트와
기술 참조만 변경됐고 추가·제거 경로는 없었다(exit 0). `git diff --check`와 Markdown
4개의 로컬 링크·줄 끝 공백·충돌 마커 검사도 PASS(exit 0)다. branch
`feat/session-integrity-batch`, HEAD `71659f31867cd666c73d817544d08920af4d0448`,
staged 없음과 기존 dirty tree를 유지했다. 아래 구현·초기 실패 기록의 '재확인 대기'
등은 당시 시점의 기록이다.

## 2026-08-31 승인 후 수정·검증·배포 기록

사용자는 수정 계획의 구현과 필요한 권한을 사전 승인했으며, 완료할 때까지 RTDB 조회와
Functions 배포 횟수 제한도 두지 않았다. 이에 따라
`mosigame-implement-and-validate`를 적용하고 targeted/FULL 검증을 실행했다.
아래 결과는 앞선 **문서·조사 단계의 미구현/미실행 기록 이후**의 작업이다.
기존 실패 보고를 삭제하거나 수정 빌드 실기기 통과로 소급하지 않는다.

### 적용한 수정과 자동 재현 근거

| 항목 | 적용 내용 | 자동 검증 |
| --- | --- | --- |
| 반복 단절·방 오판정 | 방 삭제 확인의 응답 시 세션·연결 세대와 방 존재 이벤트를 다시 대조한다. 연결이 끊긴 동안 참가자 제거를 확정하지 않고, 살아 있는 서버 참가자 근거를 우선한다. | 느린 방 조회 중 마커 복구·새 연결, 빈 players 반복과 서버 참가자 보존 |
| 반복 복구·퇴장 경합 | 복구 중 새 단절·재연결이 겹치면 최신 연결을 다시 복구한다. 퇴장 시작 시 기존 복구를 무효화하고, 늦은 응답으로 heartbeat를 재시작하지 않는다. 오프라인 heartbeat 쓰기도 예약하지 않는다. | 두 복구가 겹친 경우와 퇴장 뒤 복구 완료 |
| 타이머·늦은 presence | 최신 참가자/태블릿 presence와 맞지 않는 이벤트를 무시한다. 중첩 중단은 먼저 복구된 쪽이 남은 시간을 다른 중단으로 넘기고 마지막 중단 해제 때만 재개한다. | 단절 순서 2 × 복구 순서 2, 두 번째 단절 뒤 도착한 첫 복구 이벤트 |
| RTDB pause 보존 | 서버 전용 `controllerPause.startedAt?: number`를 보조 값으로 둬, 남은 시간이 null이어도 RTDB가 pause 객체 전체를 제거하지 않게 한다. 기존 값에는 필드가 없어도 동작하며 migration은 없다. controller trigger는 기존 primed transaction을 사용한다. | RTDB의 null 제거를 모사한 pause 보존 |
| 퇴장 참가자 재생성 | 기존 `preserveProfile: true` 자동 복구는 참가자가 사라졌을 때 신규 가입하지 않는다. presence rules는 기존 유효 참가자만 쓰게 하여 늦은 heartbeat/onDisconnect의 유령 노드 생성을 막는다. 수동 신규 참가는 유지한다. | 자동 복구/수동 참가 경계, 실제 rules 표현식의 소유자·active·legacy·삭제·closed 조건 |
| 검정 화면·winner 종료 | 비활성 게임 route에는 재차 pop하지 않는다. 라이어스포커·마피아의 비정상 종료도 같은 멱등 종료 함수를 사용한다. | 같은 프레임 두 종료, 다른 경로가 먼저 pop, 다중 다이얼로그. 수정 전 새 테스트 2개 실패 → 수정 후 통과 |
| 늦은 게임 상태 동기화 | `syncRealtimeRoomGameStatus`가 최신 방·게임을 transaction으로 확인한다. 종료된 게임의 지연 이벤트로 waiting/closed/삭제 방을 덮어쓰지 않고, 중복 finished로 보존 기한을 연장하지 않는다. playing 전환은 오래된 cleanupAt도 제거한다. | 지연 finished·삭제/closed 방·중복 종료 기한·현재 상태 전환 |

타이머 중첩/지연 이벤트 테스트는 수정 전 3개 실패로 경로를 재현했다.
이는 현재 코드 결함의 재현 근거이며, 식별되지 않은 이전 설치 APK에서 모든 증상의
원인이 이것뿐이었다는 의미는 아니다. 기존 10초 heartbeat, onDisconnect, lastSeen
20초 초과 서버 재검증, 게임과 그룹 동시 퇴장, 새 다음 게임 대기 상태 없음은 유지한다.
새 dependency, Auth 공급자 설정 변경은 없다.

### 실행 결과

| 명령 (Windows 저장소 루트 기준, 별도 표기 시 functions/) | 결과 | exit |
| --- | --- | --- |
| `.\tool\invoke_mosigame.ps1 test session` | PASS — 수정 후 Flutter 74개, Functions 32개. 실행 전후 snapshot 동일 | 0 |
| `flutter test --no-pub test/game_route_exit_test.dart test/controller_room_lifecycle_test.dart test/room_leave_state_test.dart test/controller_reconnect_guard_test.dart test/room_restore_to_waiting_test.dart test/mafia_room_gone_test.dart test/phone_room_waiting_test.dart` | PASS — 55개 | 0 |
| functions/: `node --test test/controller-presence-timer.test.mjs test/game-interruption.test.mjs test/room-lifecycle.test.mjs test/room-presence-rules.test.mjs` | PASS — 최종 수정 후 49개 | 0 |
| `flutter analyze --no-pub` | PASS — 지적 없음 | 0 |
| `.\tool\invoke_mosigame.ps1 validate --full` | **PASS** — Flutter 643개, Functions 274개; preflight·412개 Dart format·analyze·lint·build·snapshot 포함 7 단계 PASS, 실패/blocked 0 | **0** |
| `flutter build apk --debug --no-pub --build-name=1.0.0-sessionfix.20260831` | PASS — 설치용 APK 생성 | 0 |
| `aapt dump badging` 및 `Get-FileHash -Algorithm SHA256` | PASS — 패키지·버전·파일 해시 확인 | 0 |

Flutter/Dart는 `C:\flutter\bin`의 기존 SDK를 사용했다. Windows guarded invocation은
SDK cache 접근이 가능한 승인된 실행 환경에서 수행했고 최종 FULL startup은 5,180ms였다.
별도 `test auth`는 이번 변경 범위에 필요하지 않아 반복하지 않았으며 auth 자동 테스트는
최종 FULL에 포함됐다.

첫 FULL은 기존 `lib/platform/widgets/platform_components.dart`와
`test/setup_mosigame_contract_test.dart`의 포맷 차이로 FAIL(exit 1)이었다.
내용을 보존한 formatter 수정 후 새 후보를 검증했다. 별도 분석에서 발견한 새 코드의
중괄호 스타일 경고도 수정했다. 테스트 삭제·약화나 제외 확대는 하지 않았다.
Windows invocation-guard 통합 테스트 제외는 기존 FULL 정책 그대로이며 guard 구현은
변경하지 않았다. 이전 세션의 startup marker 60초 BLOCKED는 과거 기록으로 남긴다.

### 배포·빌드와 검증 한계

- Firebase 프로젝트 `project0000-ec01e / mosigame / ACTIVE`를 확인했다.
- 기존 설치된 firebase-tools의 정상 계정 선택 옵션으로 배포 권한 계정을 **호출별**
  지정했다. 저장된 기본 CLI 계정은 전후 동일하다. 계정 식별자·토큰은 문서에 남기지 않는다.
- 실행: `node (Join-Path $env:TEMP 'mosigame-release-operation-20260831.cjs') deploy`로
  임시 helper를 실행했다. 내부 명령은
  `firebase deploy --project project0000-ec01e --only database,functions:<아래 13개>`
  와 같은 지정 범위다. **DEPLOY_COMPLETE, exit 0**. predeploy ESLint/TypeScript와
  RTDB 서버 rules dry-run 컴파일 후 실제 rules release까지 성공했다.
- 후속 metadata 조회로 아래 13개 모두 새 revision·ACTIVE를 확인했다.
  updateTime은 2026-08-30 16:52:44~51 UTC, 즉 **2026-08-31 01:52:44~51 KST**다.
- `node (Join-Path $env:TEMP 'mosigame-release-rules-20260831.cjs')` helper는
  **규칙 경로 `/.settings/rules`만 GET**하여 로컬 전체 rules와 의미 구조가 동일함을
  확인했다(`RULES_MATCH`, exit 0). 정규화 SHA256:
  `5b92f1d0947002142ba88a408c1857ba37553a2f9fcb5a51869d2f2eba30d6ac`.
- 방·참가자 RTDB 데이터 조회, 테스트 데이터 생성, 수동 삭제, migration, Auth/Hosting/
  Firestore 배포는 하지 않았다. 배포 후 실제 게임 실행은 기기 체크로 남긴다.
- 최초 기본 계정의 함수 목록 조회는 권한 문제로 exit 1, 임시 helper의 옵션 객체 재사용도
  TypeError로 exit 1이었다. 호출별 계정 선택과 독립 옵션 객체로 보완한 조회·배포·검증은
  모두 exit 0이다. 이 두 실패는 배포 실행 전 진단 단계이며 앱 코드 실패가 아니다.

| 지정 함수 | 확인한 새 revision |
| --- | --- |
| `joinRealtimeRoom` | `joinrealtimeroom-00032-roc` |
| `syncRealtimeRoomGameStatus` | `syncrealtimeroomgamestatus-00019-kig` |
| `game_common_controller_presence_changed` | `game-common-controller-presence-changed-00002-qoy` |
| `game_common_interruption_on_connection_changed` | `game-common-interruption-on-connection-changed-00017-neh` |
| `game_common_interruption_report_stale_player` | `game-common-interruption-report-stale-player-00002-waz` |
| `game_common_interruption_exclude_player` | `game-common-interruption-exclude-player-00017-vam` |
| `game_common_interruption_expire` | `game-common-interruption-expire-00017-xaq` |
| `game_common_interruption_vote_to_continue` | `game-common-interruption-vote-to-continue-00017-tav` |
| `game_common_interruption_finish_now` | `game-common-interruption-finish-now-00003-mif` |
| `cleanupExpiredGameInterruptions` | `cleanupexpiredgameinterruptions-00002-fax` |
| `game_liars_poker_leave_game` | `game-liars-poker-leave-game-00017-daz` |
| `game_final_call_leave_game` | `game-final-call-leave-game-00017-kop` |
| `game_mafia_leave_game` | `game-mafia-leave-game-00014-rug` |

설치본은 [mosigame-sessionfix-20260831.apk](../../build/app/outputs/flutter-apk/mosigame-sessionfix-20260831.apk).
패키지 `com.warmhandongne.msg`, versionName `1.0.0-sessionfix.20260831`, versionCode `1`,
debug APK 223,022,776 bytes이며 arm64-v8a/armeabi-v7a/x86_64를 포함한다.
SHA256은 `A5328AE0AF2DCC6844FB8477F850DAF95B72A32AC94E00E479CA3FA422D9987A`다.
현재 HEAD와 아래 미커밋 수정들을 포함한 빌드이며 스토어 출시 artifact가 아니다.
APK는 ignored build 경로에만 보존하고 pubspec 버전·dependency는 바꾸지 않았다.
빌드에는 일부 Firebase·scanner·Apple 플러그인의 향후 Built-in Kotlin 이행 경고가
있었으나 현재 빌드는 성공했다. 이번 수정에서 dependency 업그레이드는 하지 않는다.

에뮬레이터는 실행하지 않았다. presence rules의 Node 검사는 실제 규칙 문자열을
mock snapshot으로 평가한 것이며 Firebase Rules 엔진 통합 테스트를 대체하지 않는다.
배포 시 서버의 규칙 컴파일 검사도 통과했다. 실제 Firebase 단절 판정 시간,
Android 재연결과 여러 기기의 실제 화면 복귀는
[최종 세 시나리오](../operations/REAL_DEVICE_AUTH_NETWORK_SESSION_CHECKLIST.md)로 남긴다.
회원가입·네트워크 안내·개발 오류 미노출의 사용자 확정 통과는 유지한다.

### 기존 변경 보존

- 시작/종료 branch: `feat/session-integrity-batch`, HEAD:
  `71659f31867cd666c73d817544d08920af4d0448` 동일. staged 없음, 기존 dirty tree 유지.
- 시작 1,010개 경로와 종료 1,011개 경로를 SHA256으로 비교했다(PASS, exit 0).
  본 작업의 기존 파일 수정 22개와 신규 테스트
  `functions/test/room-presence-rules.test.mjs` 1개 이외의 경로 내용은 동일했다.
  기존 경로 제거 없음. 두 format-only 파일도 위에서 별도로 밝혔다.
- 변경 범위는 database rules, 위 표에 연결된 Functions source 6개, Flutter source 4개,
  기존 회귀 테스트 6개, 신규 rules 테스트 1개, format-only 2개, 문서 3개다.
- `git diff --check`, 변경 Markdown 3개의 로컬 링크·줄 끝 공백·충돌 마커
  검사를 통과했다(각 exit 0).
  문서 기록은 FULL 뒤 갱신했으며 이후 앱/Functions 구현 변경은 없다.
- stash/reset/restore/checkout/삭제/stage/commit/push를 하지 않았다. 기존 문서 이동,
  로그인·진단 수정과 미추적 파일은 보존했고 테스트를 삭제하거나 약화하지 않았다.
- 파일 비교는 실제 열거된 tracked/unignored 경로 범위다. Git의 기존 전역 ignore 읽기
  권한 경고와 CRLF 정규화 예고는 설정을 바꾸지 않고 보존했다.

## 2026-08-31 최초 실기기 결과 반영 — 수정 APK 재검증 이전 이력

최초 결과 반영 단계는 기록과 코드의 읽기 전용 조사·수정 계획까지 수행했다. 아래는
그 시점의 근거다. 사용자의 후속 구현·권한 사전 승인에 따라 구현 단계에는
`mosigame-implement-and-validate` 스킬을 적용했다.
사용자는 추가 설명에서 **메모하지 않은 항목은 테스트 중 이상이 없었음**을 확인했다.
처음에 메모가 없다는 이유만으로 보류했던 판정을 정정한다. 회원가입은 명시적 성공
확인을 받아 통과로 기록한다. 나머지 기존 보류 항목인 네트워크 안내 구분·교대 표시
없음과 DevErrorLog 배지·오류 원문·stack trace 미노출도 개별 확인 질문 뒤 사용자가
통과로 확정했다. 메모에 적힌 실패와 미제공 빌드 정보까지 통과로 바꾸지는 않으며,
**남은 실패로 인한 출시 차단은 유지한다.**

### 기기·빌드와 근거 한계

- 이번 사용 휴대폰: Galaxy A32, A35. 단절한 A와 정상 연결 기기의 모델 대응은 미제공.
- 태블릿 사용은 확인되지만 모델·OS는 미제공. 휴대폰 OS, 게임 이름, 실제 테스트일,
  앱 버전·빌드 번호·APK 식별자와 빌드 원본도 미제공이다.
- 따라서 아래 통과·실패는 실제 사용 보고로 반영하지만, 현재 working tree의 수정이 설치
  앱에 포함됐는지 또는 배포된 세션 관련 Functions와 일치하는지는 확정할 수 없다.
- Galaxy S20+는 이번 테스트 이전 UT에서 화면이 깨지지 않았다는 사용자 확인이 있다.
  기존 깨짐은 기기의 글씨/화면 확대 설정 때문이었다는 사용자 설명도 별도 보존한다.
  당시 설정값·빌드는 미제공이며 이번 수정 빌드 검증으로 소급하지 않는다. A32·A35로
  S20+ 확인을 대체한 것이 아니다. 확대 설정 대응은 사용자 요청대로
  [출시 후 접근성 개선](POST_LAUNCH_IMPROVEMENTS.md#accessibility-scale-01--글씨화면-확대-설정-대응)에 기록한다.

### 항목별 판정

| 시나리오 | 판정 | 직접 전달된 관찰 / 남은 확인 |
| --- | --- | --- |
| 첫 휴대폰 단절 감지·복구 | 부분 통과 | 첫 시도는 잘 감지하고 회복함. 감지까지 30초·복구까지 30초 기준의 측정값과 같은 방/게임 식별 근거는 없음. 타이머까지 통과한 것은 아님 |
| 중단 중 타이머 보존 | 실패 | 표시값은 단절 24초 / 팝업 15초 / 복구 10초. 팝업 약 5초 후 네트워크를 복구했는데 그 5초가 차감됨 |
| 같은 게임 두 번째 단절·복구 | 실패 | 감지는 되나 복구하지 못함. 두 번째 팝업 약 5초 후 네트워크가 정상인 휴대폰부터 순차 이탈. 사용자 기록 문구는 `방을 찾지 못했습니다` |
| 두 번째 단절 후 태블릿 종료 | 실패 | 60초가 지나도 종료되지 않고 종료 버튼도 동작하지 않음. 60초의 정확한 기산점·버튼 종류는 추가 확인 필요 |
| 태블릿 종료 후 휴대폰 대기실 복귀 | 실패 | 게임 종료 후 `홈으로 나가기`를 누르면 어떤 휴대폰은 그룹으로 돌아오고 다른 휴대폰은 돌아오지 못함. 두 대 모두 검정 화면에 머무는 경우도 있음. 앞선 보고의 앱 재실행·그룹 재참여 회복은 정상 복귀 성공으로 보지 않음 |
| 태블릿만 단절 후 복구 | 실패 | 네트워크 복구 후에도 게임으로 돌아오지 못함. 복구 후 기다린 시간과 각 기기의 화면 문구는 미제공 |
| 휴대폰 게임·그룹 퇴장 반영 | 실패 | 위 태블릿 단절 시나리오에서 휴대폰이 나갔는데 태블릿이 게임을 종료한 뒤에도 나간 그룹원이 보임. 퇴장 성공 응답·서버 노드 삭제 여부는 미확인 |
| 회원가입 앱·Android 뒤로가기 | 통과 | 사용자가 회원가입 체크를 성공적으로 마쳤기 때문에 메모하지 않았다고 명시적으로 확인. 앱/시스템 확인창·계속하기·중단하기·태블릿 버튼을 포함한 회원가입 체크의 성공 보고로 반영 |
| 네트워크 안내 종류·교대 표시 | 통과 | 2026-08-31 개별 확인 질문에 사용자가 통과로 확정. 휴대폰/태블릿 단절에 맞는 안내가 표시되고 불필요하게 교대 표시되지 않음. 세션 복구 성공과는 별도 판정 |
| 종료가 겹치는 경우 — winner 이후 대기실 복귀 | 실패 | 사용자가 이 시나리오에 `홈으로 나가기` 후 일부 또는 모든 휴대폰의 그룹 복귀 실패·검정 화면을 추가 기록. 버튼을 누른 기기와 강제 종료·재시작 전후의 세부 순서는 미제공이나 시나리오 실패는 명확함 |
| DevErrorLog 배지·원문·stack trace 미노출 | 통과 | 2026-08-31 개별 확인 질문에 사용자가 통과로 확정. 테스트 중 개발 오류 배지·오류 원문·stack trace가 사용자 화면에 나타나지 않음 |
| S20+ 홈 화면 | 이전 UT 통과 보고(최신 빌드 검증과 구분) | 사용자가 실제 S20+에서 이전 UT 성공을 확인. 확대 설정 대응은 별도 출시 후 항목이며 이번 필수 세 시나리오에 추가하지 않음 |

타이머의 `24 → 15`는 단절 감지 전 경과일 수 있으므로 전부 중단 실패로 단정하지 않는다.
`15 → 10`은 보존 실패 보고로 추적한다. 다만 팝업이 휴대폰의 로컬 네트워크 안내인지
태블릿의 서버 게임 중단 화면인지 미확인이므로, 서버 중단이 시작된 뒤에도 감소했는지는
다음 점검에서 구분한다. 기기의 단절·팝업·중단·복구 시각을 추정해서 채우지 않는다.

### 최초 코드 조사와 수정 계획 — 후속 구현 전 기록

아래는 최초 조사 당시 소스에서 확인한 경로와 검증할 가설이다. 이 조사 시점에는 설치
빌드·배포 revision 대조와 자동 테스트 재실행 전이므로 실기기 실패의 확정 원인은 아니다.

| 우선순위 | 코드 근거와 원인 후보 | 다음 수정·검증 범위 |
| --- | --- | --- |
| 1. 반복 단절과 잘못된 방 종료 판정 | `RoomProvider._performRoomDeletionConfirmation`은 비동기 조회 전의 연결/삭제 후보 검사 뒤, 응답 시 방 코드만 다시 검사한다. `_verifyCurrentPlayerRemoval`은 참가자 재조회 방어가 있으나 별도 방 마커 삭제 판정 경로까지 보호하지 않는다. 현재 UI의 삭제 분기 문구는 `방을 찾을 수 없습니다`로 사용자 기록과 유사하나 동일 경로라고 확정할 수 없음 | 재확인 도중 재단절·새 복구·마커 회복이 겹치는 순서를 재현한다. 실제 방 삭제와 늦은 읽기 결과를 구분하고 현재 세션·연결 상태에서 유효한 결과만 적용한다. 방이 실제 삭제됐다는 근거 없이 cleanup 원인으로 단정하지 않는다 |
| 2. 타이머와 접속 이벤트 순서 | `state.ts`의 복구 분기는 이벤트의 true만 보고 현재 중단을 취소하며 최신 참가자 presence를 재검사하지 않는다. `controller-presence.ts`도 이벤트 값으로 타이머를 복원한다. 두 중단의 복원 함수는 서로의 중단이 남았는지 보지 않고 각각 deadline을 쓴다 | 늦은 첫 복구 이벤트가 두 번째 중단을 취소하는 경우와 참가자/태블릿의 모든 단절·복구 순서, 중복 이벤트를 회귀 테스트로 재현한다. 남은 시간 소유·복원 규칙을 기존 계약 안에서 보완한다. 로컬 팝업과 서버 pause 시각은 따로 관찰한다 |
| 3. 태블릿 복구와 퇴장 경합 | `_performConnectionRecovery`는 진행 중인 Future를 공유하며, controller 쓰기 후 방/퇴장 상태를 재확인하지 않고 heartbeat를 시작한다. 휴대폰 복구는 join을 호출한 뒤에야 방/퇴장 상태를 다시 검사한다. `_runLeave`의 타이머 취소만으로 이미 시작한 복구·쓰기 완료까지 취소되지는 않는다 | 느린 복구 중 두 번째 단절, 복구와 명시적 퇴장 교차를 재현한다. 오래된 작업이 세션·참가자를 복원하지 않도록 생명주기를 보완하고, 퇴장 성공 응답·최신 참가자 구독·종료 후 명단을 함께 확인한다 |
| 4. 종료·검정 화면 | `PhoneRoomWaiting`의 강제 종료, 게임별 route 종료, `restoreRoomToWaiting`의 finished 확인은 서로 다른 비동기 경로다. 게임 데이터·선택 해제·방 상태의 수신 순서와 열린 다이얼로그에 따라 경로를 검증해야 한다 | 실제 게임과 `홈으로 나가기`를 누른 기기를 확인한 뒤, 한 대만 그룹 복귀/두 대 모두 검정 화면인 경우를 각각 재현한다. 종료 버튼/중단 만료, winner 다이얼로그, `waiting + selectedGame 없음`, 퇴장을 교차 검증한다. 게임 route는 한 번만 닫고 그룹 대기 화면을 보존하며, 게임과 그룹 퇴장은 홈 복귀를 유지한다 |

기존 `test/room_leave_state_test.dart`의 두 번 반복 검사는 빈 players 이벤트를 반복하며
서버 참가자 노드가 살아 있는 조건을 확인한다. 실제 연결 단절·복구 작업의 겹침까지
검사한 것은 아니다. `functions/test/controller-presence-timer.test.mjs`의 중첩 검사는
나중에 끊긴 쪽이 먼저 복구되는 순서만 확인한다. 먼저 끊긴 쪽이 먼저 복구되면 다른
중단 중 deadline이 살아나거나 마지막 복구가 null을 다시 쓰는 경로가 소스에 남아 있다.

구현 시 기존 10초 heartbeat, `onDisconnect`, 참가자 lastSeen 20초 초과 시 서버 재검증,
게임과 그룹의 동시 퇴장 계약을 유지한다. 새 다음 게임 대기 상태는 추가하지 않는다.
새 dependency·public API·persistent data·중요 상태 계약 변경이 필요하면 영향과
구체안을 먼저 설명하고 별도 승인을 받는다. 로컬 수정과 관련 회귀 검증 뒤 설치 빌드 및
실기기 체크를 다시 연결한다. Project CLI 재실행은 사용자에게 먼저 요청한다.

### 최초 문서·조사 작업의 상태·검증 경계

- 시작 branch: `feat/session-integrity-batch`
- 시작 HEAD: `71659f31867cd666c73d817544d08920af4d0448`
- staged 변경은 없고 다수의 unstaged 수정·삭제와 untracked 파일이 있는 dirty tree다.
  `docs/` 전체가 untracked이며 루트 문서 이동, 로그인·세션·진단 기존 변경을 보존한다.
- 문서 반영과 읽기 전용 조사만 수행한다. stash/reset/restore/checkout/삭제,
  stage/commit/push는 수행하지 않는다.
- 이전 Flutter 72개, Functions 262개, 분석·lint 성공(exit 0)은 이전 실행 근거다.
  이번 소스·설치 앱의 전체 PASS 근거로 갱신하지 않는다.
- 이전 Windows Project CLI `test session`, `test auth`: startup marker 60초 timeout,
  BLOCKED(exit 1). FULL 미실행. 이번 Project CLI·raw 테스트 재실행 없음(exit code 해당 없음).
  에뮬레이터는 사용할 수 없다는 전제를 유지한다.
- production 조회·배포·migration 없음. 이전 배포 확인 범위는 rules와
  `cleanupStaleRealtimeRooms`뿐이며 세션 관련 함수의 최신 배포 상태는 미확인이다.
  이전 배포 후 Firebase CLI 계정을 열람 계정으로 복원했다는 인계만 보존한다.
  현재 계정·권한은 재확인하지 않았으며 production 사용 전 별도 승인·확인이 필요하다.

최초 결과 반영 작업의 검증 기록(아래 문서 4개 변경):

| 실행 명령·검사 | 상태 | exit code / 근거 |
| --- | --- | --- |
| `git branch --show-current`, `git rev-parse HEAD`, `git status --short`, `git diff --cached --name-only` | 확인 | 0. 전후 branch·HEAD 동일, staged 없음, 기존 dirty 상태 유지 |
| `git ls-files --cached --others --exclude-standard` 및 `Get-FileHash -Algorithm SHA256` 전후 비교 | PASS | 0. 열거된 1,010개 경로에서 아래 문서 4개만 변경, 경로 추가·제거 없음 |
| `git diff --check` | PASS | 0. tracked diff의 공백 검사이며 untracked docs 검증을 대신하지 않음 |
| PowerShell로 변경 Markdown 4개의 링크 대상·줄 끝 공백·충돌 마커 검사 | PASS | 0. 로컬 파일 링크 모두 존재, 줄 끝 공백·충돌 마커 없음 |
| Project CLI targeted / FULL, Flutter·Functions 테스트 | 미실행 | 해당 없음. 사용자 요청 전 재실행하지 않음 |

변경 파일은 이 문서, `POST_LAUNCH_IMPROVEMENTS.md`,
`../operations/REAL_DEVICE_AUTH_NETWORK_SESSION_CHECKLIST.md`,
`../operations/AUTH_NETWORK_SESSION_TECHNICAL_REFERENCE.md`뿐이다. 위 Git 명령은 사용자
전역 ignore 파일 읽기 권한 경고와 기존 파일의 CRLF 정규화 예고를 출력했지만 exit 0이었다.
파일 보존 확인은 실제 열거된 경로 범위이며 전역 ignore 설정을 변경하지 않았다.

## 2026-08-30 구현 기록

이번 코드 수정은 다섯 항목의 자동 검증 가능한 범위를 완료했지만 출시 차단을 해제하지
않는다. Project CLI 검증과 수정 빌드의 실제 기기 확인이 남아 있다. RTDB 인덱스와 정리
함수는 지정 배포와 운영 Scheduler 확인까지 마쳤다.

| ID | 확인한 원인 | 적용한 처리 |
| --- | --- | --- |
| SESSION-RECONNECT-01 | RTDB 재연결 직후 `players` 구독이 빈 캐시를 먼저 내보내면 방 존재만 확인하고 현재 사용자를 강퇴로 확정했다. | 방 존재와 서버의 현재 사용자 participant 노드를 함께 재확인하고, 실제 노드가 없을 때만 로컬 세션을 지운다. |
| AUTH-BACK-01 | 인증 화면의 스크롤 레이어가 뒤로가기 버튼 위에서 hit test를 가로챘고, 시스템 뒤로가기는 `PopScope`가 막은 뒤 다시 차단된 `maybePop`을 호출했다. | 뒤로가기 버튼을 Stack 최상단에 배치하고 이메일 입력부터 앱·시스템 뒤로가기가 같은 중단 확인창을 사용하도록 했다. |
| FINISH-SYNC-01 | 게임 public 노드의 일시적 `null`을 견디기 위해 마지막 winner 상태를 보존하지만, 서버가 실제 대기실 정리를 끝낸 뒤 route를 닫는 공통 신호가 없었다. | 게임 세션을 관찰한 뒤 방이 `waiting`이고 `selectedGame`이 없어진 경우를 권위 있는 종료 신호로 사용해 열린 다이얼로그와 게임 route를 함께 닫는다. |
| NET-UI-01 | 대기실에는 로컬 네트워크 guard가 있었지만 그 위에 push한 게임 route에는 없었고, 태블릿 안내가 휴대폰 자체 연결 상태를 확인하지 않았다. | 게임 route에도 네트워크 guard를 적용하고 휴대폰 RTDB 연결이 정상일 때만 태블릿 재연결 안내를 허용한다. |
| ROOM-CLEANUP-01 | `lastSeen` 단일 500개 batch와 `retainUntil` 없는 구형 finished 방이 뒤 후보를 계속 막을 수 있었다. | 만료 `cleanupAt`을 별도 500개 쿼리로 합치고, 구형 finished는 lastSeen 15분 기준으로 판단하며, transaction 재검증과 식별자 없는 건수 로그를 남긴다. |

로컬 검증 결과:

- 관련 Flutter 위젯·상태 회귀 테스트 72개 통과, exit code 0
- 변경 Dart 파일 정적 분석 통과, exit code 0
- Functions TypeScript build와 Node 테스트 262개 통과, exit code 0
- Functions ESLint 통과, exit code 0
- Project CLI `test session`, `test auth`는 승인 후 실행했으나 둘 다 startup marker
  60초 제한으로 BLOCKED(exit 1). 같은 시작 차단이 반복되어 FULL은 실행하지 않음
- production RTDB 쓰기·수동 삭제·migration 없음. 승인된 rules와 지정 함수만 배포했고,
  배포 후 승인된 단일 상태 경로를 read-only로 한 번 확인함

배포 기록:

- `database.rules.json`의 `rooms/.indexOn`에 `cleanupAt`을 추가했고 로컬 JSON 구문
  검사를 통과했다.
- RTDB rules 지정 배포를 시도했으나 현재 Firebase CLI 계정에 필요한 배포 권한이 없어
  처음 두 번 거부됐다(exit 1). 프로젝트 계정을 배포 권한 계정으로 전환한 뒤
  `cleanupAt` 인덱스가 포함된 rules 지정 배포가 성공했다(exit 0).
- predeploy lint·TypeScript build를 다시 통과한 뒤 `cleanupStaleRealtimeRooms`만 지정
  배포했고 성공했다(exit 0). 다른 함수, migration, 수동 RTDB 삭제는 실행하지 않았다.
- 함수 상태 `ACTIVE`와 새 revision 시작은 확인했다. 첫 배포 후 Scheduler 실행의
  구조화 요약은 후보 28개, 삭제 0개, 보존 28개, 실패 0개였다. 이 결과로 cleanup
  transaction도 Admin SDK의 최초 로컬 null에서 조기 취소되는 기존 결함을 확인했다.
- cleanup transaction을 저장소의 `runPrimedTransaction`으로 변경해 서버 스냅샷을
  먼저 받은 뒤 최신 상태를 판정하도록 보완했다. Functions build·Node 테스트 262개와
  lint를 다시 통과한 뒤 같은 함수 하나만 재배포했다(exit 0).
- 보완 revision의 Scheduler 요약은 만료 cleanupAt 후보 26개, stale presence 후보
  28개, 중복 제거 후보 28개, 삭제 28개, 보존 0개, 실패 0개였다. 방 코드와 UID는
  기록하지 않았다.
- 승인된 단일 경로 `/rooms/ZCWYB/status`를 read-only로 한 번 조회한 결과 `null`이었다.
  수동 RTDB 삭제 없이 Scheduler가 기존 테스트 방을 정리한 결과와 일치한다.

ROOM-CLEANUP-01의 `cleanupAt` 쿼리와 인덱스, 지정 함수는 production에 배포됐다. 기존
방을 수동 삭제하지 않았으며 Scheduler가 transaction으로 최신 상태를 재확인한 뒤에만
정리한다. 위 구조화 요약과 단일 경로 결과는 해당 배포의 운영 확인 근거다. 이번에
보고된 게임 중 이탈·참가자 잔류가 같은 cleanup 원인이라는 근거는 아직 없다.

### SESSION-RECONNECT-01 — 반복 단절 후 세션·방 유실

첫 단절은 30초 안에 같은 게임으로 복귀했지만 같은 세션에서 두 번째 단절·복구 후
휴대폰과 태블릿의 방 상태가 갈라졌다. 단순한 “복구가 느림”이 아니라 세션 무결성과
사용 가능성 문제이므로 체감 지연 개선과 분리해 출시 전에 처리한다.

완료 조건:

- 같은 게임에서 두 번 연속 단절·복구해도 휴대폰이 같은 방과 게임으로 돌아온다.
- 복구 중 `게임을 찾을 수 없음`으로 로비에 강제 이동하지 않는다.
- 태블릿에서 게임 종료가 가능하고 앱 재시작 뒤 controller 방 세션이 복원된다.
- 중단한 턴의 남은 시간이 보존되고 중복 interruption/revision 전이가 생기지 않는다.
- 관련 Flutter·Functions 회귀 테스트와 최종 실기기 반복 단절 점검이 통과한다.

### 추가 분리한 차단 항목의 완료 조건

- **SESSION-TIMER-01:** 서버 중단 이후 남은 시간이 감소하지 않고, 모든 단절/복구
  순서에서 마지막 중단이 해소될 때 보존한 시간으로 한 번만 재개한다. 감지 전 경과와
  서버 pause 이후 경과를 분리 기록한다.
- **CONTROLLER-RECOVERY-01:** 태블릿만 단절·복구해도 같은 방·게임으로 돌아오고,
  안내 해제·게임 조작·종료가 가능하다. 복구 진행 중 재단절도 확인한다.
- **LEAVE-CONSISTENCY-01:** 퇴장 성공 뒤 게임과 그룹 양쪽에서 참가자가 제거되고,
  늦은 복구·heartbeat·onDisconnect가 다시 참가시키지 않는다. 태블릿 종료 후 명단도
  일치하며 실패한 퇴장을 성공 화면으로 처리하지 않는다.

### AUTH-BACK-01 — 회원가입 이메일 입력 화면 뒤로가기

이메일 링크, Google, Apple 인증 성공 여부와 별개의 화면 이동 문제다. 휴대폰과 태블릿이
공유하는 회원가입 흐름에서 앱 버튼과 Android 시스템 뒤로가기를 같은 안전한 중단
처리로 모아야 한다.

2026-08-31 추가 확인: 사용자는 회원가입 체크를 성공적으로 마쳤다고 명시적으로
설명했다. 메모가 없어 보류했던 실기기 판정을 통과로 정정한다. 앱 빌드 식별 미제공은
별도 증빙 한계이며 회원가입 테스트 자체를 미확인으로 되돌리는 근거로 사용하지 않는다.

완료 조건:

- 이메일 입력 단계의 앱 내 뒤로가기와 시스템 뒤로가기가 모두 중단 확인창을 띄운다.
- 계속하기를 선택하면 입력 화면과 입력값이 유지된다.
- 중단을 선택하면 인증·온보딩 상태를 손상시키지 않고 이전 화면으로 돌아간다.
- Android 앱 정지·ANR이 없고 휴대폰·태블릿 회귀 테스트가 통과한다.

### FINISH-SYNC-01 — 정상 종료 후 winner 화면 잔류

저장소에는 `finished` 방을 대기 상태로 복원하는 경로와 자동 테스트가 있지만,
2026-08-30 기록에는 태블릿 재시작 뒤 휴대폰 winner 잔류가 있다. 2026-08-31 추가
메모에서 사용자는 종료가 겹치는 경우에 게임 종료 후 `홈으로 나가기`를 누르면 일부만
그룹으로 돌아오거나 휴대폰 두 대 모두 검정 화면에 남는다고 확인했다. 따라서 이
시나리오를 보류에서 실패로 정정한다. 버튼을 누른 기기와 강제 종료·재시작과의 상세
순서는 아직 특정하지 않으며 현재 구현만으로 해결됐다고 판단하지 않는다.

완료 조건:

- 정상 결과 직후 태블릿을 종료·재시작해도 태블릿은 그룹 대기실로 복귀한다.
- 모든 휴대폰에서 winner 화면이 닫히고 이전 `finished` 화면이 다시 나타나지 않는다.
- 방의 `selectedGame`과 종료 필드가 정리되고 다음 게임을 선택할 수 있다.
- 종료 trigger, 태블릿 복원, 휴대폰 route 구독의 순서가 달라도 같은 결과가 된다.
- 단절·복구 후 태블릿에서 종료해도 휴대폰이 검정 화면 없이 그룹 대기실로 돌아온다.
  명시적으로 게임과 그룹을 나간 휴대폰은 그룹으로 복귀시키지 않는다.

### NET-UI-01 — 네트워크 오류와 태블릿 재연결 화면 전환

휴대폰 자신의 RTDB 연결이 끊긴 경우와, 휴대폰은 연결됐지만 태블릿 controller
heartbeat가 오래된 경우를 구분해야 한다. 로컬 네트워크가 끊긴 동안 캐시된 controller
`lastSeen`만 늙었다는 이유로 태블릿 장애 안내로 바뀌지 않도록 표시 우선순위와 복구
전이를 SESSION-RECONNECT-01과 함께 조사한다.

2026-08-31 사용자 추가 확인으로 안내 구분과 불필요한 교대 표시 없음은 실기기 통과로
확정했다. 이 판정은 화면 안내에 한정하며 반복 단절·태블릿 복구 실패를 해소하지 않는다.

완료 조건:

- 휴대폰 자체 네트워크 단절에는 네트워크 안내만 표시한다.
- 로컬 연결이 정상이고 태블릿만 stale인 경우에만 태블릿 재연결 안내를 표시한다.
- 복구 과정에서 두 화면이 불필요하게 번갈아 나타나지 않는다.
- 단일 단절과 반복 단절을 모두 자동 테스트와 실기기에서 확인한다.

### ROOM-CLEANUP-01 — 종료된 방과 유령 방 정리 정체

production에서 확인한 테스트 방 `ZCWYB`는 `closed`였고 controller `lastSeen`은
2026-08-27 01:57 KST, `cleanupAt`은 01:58 KST였지만 2026-08-30에도 남아 있었다.
세 Scheduler가 예약 주기로 호출되는 로그는 확인했으므로 “함수가 비활성”인 문제와
“후보를 조회했지만 삭제하지 못함”을 구분한다.

보완 배포 전 코드에서 확인했던 정체 가능성은 다음과 같다. 처리와 배포 후 확인은
위 2026-08-30 기록을 따른다.

- stale 후보를 `limitToFirst(500)`으로 제한한다.
- 구형 `finished` 방에 `retainUntil`이 없으면 삭제하지 않는다.
- 삭제할 수 없는 앞쪽 후보가 매 실행마다 같은 batch를 차지하면 뒤의 종료 방이 계속
  처리되지 않을 수 있다.
- 당시 로그에는 방 식별자 없는 조회·삭제 건수도 없어 정체를 운영 중 확인하기 어려웠다.

구현 방향과 완료 조건:

- 구형 `finished` 방은 오래된 controller `lastSeen`을 기준으로 15분 보존 후 정리한다.
- 만료된 `cleanupAt` 방을 별도 후보로 가져와 하나의 500개 batch 정체를 피한다.
- transaction에서 최신 상태를 다시 검사하고 활성 방이나 복구 유예 중인 방은 지우지
  않는다.
- 방 코드·UID 없이 후보·삭제·보존·실패 건수만 구조화 로그로 남긴다.
- 구형 방, batch 정체, 중복 Scheduler 실행, 활성 게임 보존 회귀 테스트를 추가한다.
- 로컬 검증 뒤 `cleanupStaleRealtimeRooms`만 지정 배포하고, 별도 승인 없는 수동 RTDB
  삭제나 migration은 하지 않는다.

## 확인됐거나 현재 계약으로 유지하는 항목

| 항목 | 판정과 근거 |
| --- | --- |
| 초기 상태 비상 탈출 UI | 초기 상태가 20초 넘게 오지 않을 때의 안전 경로다. 정상 카드 배부에서는 나타나지 않음을 확인했으므로 현재 문제로 분류하지 않는다. |
| 이메일 링크 로그인 | 이전 실기기 점검에서 성공했다. 인증 설정이나 관련 코드를 바꾸면 다시 확인한다. |
| Google 로그인 | 실기기에서 성공했다. |
| Apple 로그인 | 팀원의 실기기 확인에서 성공했다. 출시 증빙에는 확인자·기기·빌드를 별도로 기록한다. |
| 게임 나가기 | 현재 계약대로 게임과 그룹에서 함께 나간다. 다음 게임 대기 상태나 새 persistent state는 이번 출시 범위에 넣지 않는다. |
| 단절·복구 | 최초 단일 복구 보고와 별도로, 수정 APK의 최종 사용자 테스트에서 라이어스포커 반복 단절·복구도 통과했다. 범위는 Medium Tablet 에뮬레이터 + A32·A35다. |
| A32·A35 홈 레이아웃 | 화면 폭에 따라 문장과 단락이 내려가며 overflow가 없음을 확인했다. |
| DevErrorLog 사용자 화면 | 개발 오류 배지·원문·stack trace를 렌더링하지 않는 구현과 자동 테스트가 있으며, 2026-08-31 사용자 확인으로 실기기 미노출도 통과 확정했다. |

## 구현 외 출시 전 확인

- 실제 Galaxy S20+의 이전 UT 성공 보고를 보존한다. 당시 빌드·확대 설정값이 없으므로
  최신 수정 빌드의 최종 결과로 소급하지 않는다. 글씨/화면 확대 대응은 출시 후 개선이며
  A32·A35 결과는 S20+ 직접 확인을 대체하지 않는다.
- Apple 로그인 성공은 팀원 전달 근거이므로 정식 출시 기록에는 기기, OS, 빌드와 날짜를
  남긴다.
- 수정·자동 검증·지정 배포 뒤 생성한 APK로 최종 세 시나리오를 실행했고 사용자가 모두
  통과로 확인했다. 위 테스트 환경 범위를 보존하며 스토어 출시 여부와는 구분한다.
- Project CLI targeted/FULL 검증을 실행하지 않았다면 저장소 전체 PASS 또는 출시 준비
  완료로 표현하지 않는다.

## 출시 판정 기준

다음 조건을 모두 만족해야 이 문서의 출시 차단을 해제한다.

1. 신규 미해결 항목을 포함한 모든 차단 항목에 필요한 코드 수정과 관련 회귀 테스트가
   완료된다.
2. 관련 Flutter 분석·테스트와 Functions build·테스트가 통과한다.
3. Project CLI targeted suite와 `validate --full`이 통과한다.
4. 필요한 Functions만 승인된 절차로 배포하고 배포 후 동작을 확인한다.
5. 수정 완료 뒤 작성한 최종 실제 기기 체크리스트가 통과한다.
6. 실행 명령, exit code, 배포 함수, 실기기와 production 관찰 근거를 출시 기록에 남긴다.
