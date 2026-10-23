# 그룹 생성·추방·방 초기화 효율 점검 및 개발 보고

작성일: 2026-10-22 (Asia/Seoul). 관련 작업: [NET-RECOVERY-01](tasks/NET-RECOVERY-01.md).

**최종 판정: 요청한 점검·설계·개발·자동 검증 완료. FULL 2차에서 13단계 PASS/exit 0.**
최대 3회 한도 안에서 총 2회 실행했으며 develop에는 머지하지 않았다.

## 기준과 범위

- 원격 `develop` fetch 후 기준 HEAD: `cc293dffc35111e0b65ea2aa87e46d7c2347a3eb`.
- 작업 브랜치: `codex/room-action-efficiency-20261022`. develop 병합·commit·push·배포·운영 조회는 하지 않는다.
- 시작 시 staged/unstaged 변경 없음. 기존 미추적 파일 `artifacts/patent-review/mosigame-patent-review-2026-10-21.ko.md`, `docs/planning/HANDOFF_20261022_ANDROID_AUDIO_FOCUS.md`는 보존한다.
- 사용자 요청의 6개 점검 항목을 세 동작에 각각 적용했다. 코드·테스트로 확인한 대기 의존성만 개선하며, 실측하지 않은 전체 시간·요금 절감량은 단정하지 않는다.
- FULL 검증은 이번 사용자 요청에 따라 최대 3회 실행한다. 실패 시 원인 확인 → 범위 안 수정 → 해당 검사 → 다음 FULL 순서로 진행하고, 3회 내 성공하지 못하면 중단·기록한다. 환경 BLOCKED/내부 오류/안전한 수정 근거 부족도 별도로 중단 사유다.

## 1. 그룹 생성

| 점검 항목 | 발생 위치 | 필요한 이유 | 전체 완료에 미치는 영향 | 변경 방향 | 기능 보존 검증 |
| --- | --- | --- | --- | --- | --- |
| 중복·불필요한 확인 | `room_provider.dart`의 createRoom 기존 방/로딩/복구 가드, 서버 create-room.ts의 slot·generation CAS | 중복 방 생성·옛 작업의 새 방 침범 방지 | 필수 비용이며 제거 근거 없음 | 유지 | 연타·저장 방 우선 복구·동시 생성 단일 승자 |
| 불필요한 초기화·모듈 로딩 | RoomService 생성자와 서버 정적 import | 공유 SDK·서비스 재사용 | 동작마다 재로딩하는 코드 없음. cold start 기여량은 미측정 | dependency·배포 설정 유지 | export·리전·dependency 변화 없음 |
| 중복·과다 조회 | 서버 previous/live/mapping/final room 조회, 클라이언트 최초 생성 연결 채택 | 종료 allocation 증명, 생성 중 종료·매핑 교체 경합 방어. 최초 확정 생성은 이미 resume 생략 | 조회 횟수만 보고 제거하면 정합성 훼손 가능 | 유지. 독립 조회 대기만 G1에서 병행 | cold cache, create→close→create, 옛 정리의 새 세대 보존 |
| 불필요한 직렬 대기 | **G1** `functions/src/room/create-room.ts`: onboarding 후 previous_mapping 조회 | onboarding 확인(legacy Firestore backfill 포함)과 매핑 읽기 사이 데이터 의존성 없음 | 정상 경로에서 두 준비 시간이 합산 | 두 준비 병행, 방 생성 관련 RTDB 쓰기는 선행 조건 성공 뒤 수행. 기존 backfill·오류 우선순위 보존 | 지연 제어 Promise로 동시 시작·RTDB 쓰기 차단·실패 전파 확인 |
| 중복 실행·과도한 재시도 | 클라이언트 durable 생성 ID, 서버 slot/reservation·최대 12회 코드 충돌 처리 | 응답 유실 재생·코드 충돌 대응 | 이미 멱등 처리. 이 반복은 FULL 재시도 한도와 별개 | 유지. 재생 시 후보 조회 추가 축소는 보류 | 동일 ID 같은 방, terminal 부활 없음, 미확정 slot 보존 |
| 불필요한 데이터 처리·화면 갱신 | RoomProvider 로딩/방 채택 알림, 그룹 게임 UID/membership 캐시 | 버튼 잠금·구독 시작·구성 변화 반영 | 연속 알림은 있지만 과다 frame 비용 증거 없음. 그룹 게임 중복 조회는 이미 캐시 | UI 상태 소유권·알림 순서 유지 | 로비 생성/복구·목록 기존 회귀 |

## 2. 그룹 내 추방

| 점검 항목 | 발생 위치 | 필요한 이유 | 전체 완료에 미치는 영향 | 변경 방향 | 기능 보존 검증 |
| --- | --- | --- | --- | --- | --- |
| 중복·불필요한 확인 | 서버 removeRealtimeRoomPlayer의 controller·room instance·protocol·playing 검사 | 서버 권위, 현재 방에서만 추방, 게임 중 로비 추방 차단 | 필수 검증 | transaction 안 최신 검증 유지 | 잘못된 진행자·세대·protocol 및 playing 거절 |
| 불필요한 초기화·모듈 로딩 | **K2** 서버 추방 외부 value listener와 runPrimedTransaction 내부 listener | cold SDK 캐시 보호는 하나의 listener로 충족 | 중복 listener 등록·준비·해제. SDK 공유 가능성이 있어 DB 왕복 2회로 단정 불가 | 외부 wrapper 제거, 기존 helper 하나가 prime·transaction·해제 소유 | cold cache 성공, listener 1회 등록/해제, 예외 후 누수 없음 |
| 중복·과다 조회 | **K1** `room_service.dart`: removePlayer → _controllerEnvelope → game/public.get | 추방에는 controller 신원이 필요하지만 게임 문맥은 서버가 요구하지 않음 | 게임 없는 로비에서도 사전 조회를 기다림. 관련 읽기 실패가 추방 자체를 막을 수 있음 | 추방 전용으로 identity.envelope·controller token·operationId만 구성. 게임 명령용 helper는 유지 | 캐시 유무와 무관하게 game/public 읽기 0회, 신원 조회 필요 시 유지, 정확한 callable/payload |
| 불필요한 직렬 대기 | K1의 사전 게임 조회 후 callable, K2의 이중 준비 | identity 확보는 필요, 게임 문맥 확보는 불필요 | 추방 필수 요청 시작 지연 | K1·K2에서 제거 | DB 게임 읽기가 불가능해도 정상 추방 callable 도달 |
| 중복 실행·과도한 재시도 | RoomProvider의 대상 UID별 _removingPlayerUids | 같은 대상 연타 중복 요청 방지, 다른 대상은 독립 처리 | 현재 중복 실행 방지 존재 | 유지. 자동 재시도 정책 확대 없음 | 같은 UID 한 번, 다른 UID 독립, 실패 후 사용자 재시도 |
| 불필요한 데이터 처리·화면 갱신 | 대상 행 로딩 알림, players 스트림 | 처리 중 버튼 상태·서버 참가자 삭제 반영 | 서버 최신 목록 반영에 필요. 별도 전체 목록 재조회는 없음 | 유지 | 대상 행 상태·실패 안내·명단 갱신 기존 회귀 |

## 3. 방 초기화

초기화는 현재 방을 close하고 로컬 상태를 비우는 동작이다. 새 방 생성과 결합하지 않는다.

| 점검 항목 | 발생 위치 | 필요한 이유 | 전체 완료에 미치는 영향 | 변경 방향 | 기능 보존 검증 |
| --- | --- | --- | --- | --- | --- |
| 중복·불필요한 확인 | **R1** 서버 closeRoom의 사전 root get·자격 확인 후 primed transaction에서 같은 자격 재검증 | 최신 자격 재검증은 필요, 사전 root get은 helper의 priming과 통합 가능 | 중복 읽기·직렬 준비 | 사전 get 제거. 단일 primed transaction 안 부재·권한·세대·operation 검사 | 부재 not-found, 권한·세대 거절, transaction 재실행 시 최신 검증 |
| 불필요한 초기화·모듈 로딩 | closeControllerRoom의 intent/신원 저장소, clearRoom 구독 해제 | 재실행 복구와 확정 이후 자원 해제 | 동작별 동적 로딩 없음. 저장소 삭제 병행은 효과·부분 실패 근거 부족 | 유지 | 실패 시 신원 보존·재시작 복구 |
| 중복·과다 조회 | R1 사전 get, 클라이언트 최초 close/status 분기 | 미확정 작업만 결과 조회 필요 | 클라이언트 최초 status 생략은 이미 구현됨 | 서버 중복 get만 제거, 미확정 status 조회 유지 | fresh close 1회, 응답 유실은 같은 ID 조회·필요 시 재전송 |
| 불필요한 직렬 대기 | onDisconnect.cancel과 close, UI 덮개와 close | 옛 예약 취소는 보조 처리, 서버 확정은 필수 | 기존 develop에서 이미 병행됨 | 현재 병행과 정확한 옛 연결 캡처 보존 | 취소 지연/실패 중 close 진행, 늦은 옛 취소가 새 연결 보존 |
| 중복 실행·과도한 재시도 | UI _isResetting·Provider loading·durable close ID, **R2** 서버가 transaction 결과를 버리고 success 반환 | 중복 방지·불확실 결과 보존에 필요. 미적용 성공은 근거 없음 | abort가 성공으로 처리되면 클라이언트가 신원을 조기에 삭제할 위험 | 기존 중복 방지 유지. committed=false는 성공 반환 금지 | abort/삭제 경합 성공 금지, 같은 close 재생의 revision·cleanupAt 불변 |
| 불필요한 데이터 처리·화면 갱신 | 성공 후 clearRoom와 로딩 알림 | 구독·게임·명단·오류 상태 해제 | 필요한 정리. 중복 알림의 큰 비용 근거 없음 | UI 변경 보류, 서버 확정 후 정리 유지 | reset 후 새 방 생성 0회, 실패 시 기존 방·복구 신원 보존 |

## 4. 개발 계획 (구현 전 확정)

1. **K1** 추방만 게임 문맥 없는 controller envelope를 사용한다. 다른 게임/자리 배치 명령의 문맥 조회는 건드리지 않는다.
2. **G1** onboarding·기존 매핑 읽기를 병행한다. 선행 실패의 쓰기 차단과 오류 우선순위를 테스트한다.
3. **K2/R1/R2** 기존 runPrimedTransaction 하나로 준비·최신 검증을 처리한다. close의 미적용 성공을 차단한다. helper API·데이터 형식·상태 전이는 바꾸지 않는다.
4. 지연·실패·재실행·차가운 캐시 회귀를 추가하고 직접 검사 및 session suite를 실행한다.
5. 최대 3회 안에서 Windows guarded FULL 성공을 확인한다. 실패·수정·명령·exit code·실행 전후 트리 상태를 아래 기록하고 작업 목록/상세/월별 기록을 연결한다.

신규 dependency, 공개 API/DB shape/Rules/주요 상태 전이 변경은 계획에 없다. 운영 데이터·실기기 시간 측정·배포는 이번 범위 밖이다. 기존 10/20 실기기 후속 미확인 항목은 완료로 바꾸지 않는다.

## 5. 실행·검증 기록

- 초기 환경 audit: `powershell.exe -NoProfile -NonInteractive -OutputFormat Text -ExecutionPolicy Bypass -File tool/setup_mosigame.ps1` → BLOCKED, exit 1. sandbox의 LOCALAPPDATA가 실제 Android SDK 경로와 달라 ADB 탐색 실패. 기존 `C:\Users\USER\AppData\Local\Android\Sdk\platform-tools\adb.exe` 존재를 확인하고 해당 프로세스의 ANDROID_SDK_ROOT만 지정해 재점검한다. 설치·SDK/ACL 변경 없음.
- 공식 guarded `doctor --json` → PASS, exit 0 (9개 capability). FULL 실행 횟수에는 포함하지 않는다.
- SDK 경로 지정 뒤 제한 환경 audit는 doctor startup timeout(BLOCKED/내부 exit 3, setup exit 1)이었다. 공식 guard를 SDK 캐시 접근이 가능한 승인 환경에서 실행한 audit 재검사는 READY/exit 0, working tree preserved였다. timeout 프로세스는 guard가 정리했다. SDK/ACL·dependency 변경은 없었다.
- `npm.cmd --prefix functions run build` → PASS, exit 0.
- `node --test test/room-allocation-sdk-cache.test.mjs test/room-transaction-rerun.test.mjs test/room-session-contract.test.mjs test/room-session-context.test.mjs test/room-lifecycle.test.mjs test/rtdb-retention.test.mjs` (cwd `functions`) → 78개 PASS, exit 0. 새 서버 회귀 19개 포함.
- `flutter test --no-pub test/room_player_removal_fast_path_test.dart test/room_action_fast_path_test.dart test/tablet_room_reset_test.dart test/controller_room_lobby_recovery_test.dart test/room_action_timing_test.dart` → FAIL, exit 1. 기존 45개는 PASS, 새 테스트 파일은 예외 생성자의 필수 `message` 인자 2곳 누락으로 컴파일 실패. 테스트 fixture에 message를 추가했으며 제품 코드는 바꾸지 않았다. 실패 파일만 재실행해 결과를 기록한다. FULL 시도에는 포함하지 않는다.
- 실패 파일 재검사 `flutter test --no-pub test/room_player_removal_fast_path_test.dart` → 7개 PASS, exit 0. 기존 45개와 함께 직접 회귀 52개가 통과했다.
- `dart format lib/platform/home/room/services/room_service.dart test/room_player_removal_fast_path_test.dart` → PASS, exit 0 (새 테스트 파일 포맷 정리). 이후 테스트 fixture 인자 수정도 FULL 포맷 단계에서 재확인한다.
- `powershell.exe -NoProfile -NonInteractive -OutputFormat Text -ExecutionPolicy Bypass -File tool/invoke_mosigame.ps1 test session --json` → PASS, exit 0, 73.729초. Flutter 29파일/Functions 15파일, preflight·테스트·working-tree-mutation 모두 PASS. 실행 전후 `git status --porcelain=v1` 동일. ignored 근거: `build/room_action_efficiency_20261022/session.json` (PowerShell stderr의 CLIXML 표시 경고와 CLI의 PASS 결과는 구분).
- FULL **1/3회**: `powershell.exe -NoProfile -NonInteractive -OutputFormat Text -ExecutionPolicy Bypass -File tool/invoke_mosigame.ps1 validate --full --json` → **FAIL, exit 1**, 307.244초. preflight·포맷·분석·앱575개·6개 패키지261개·Functions lint·작업 트리 보존 등 12단계 PASS, Functions test 단계만 FAIL (531개 중530 PASS/1 FAIL). 실행 전후 status 동일, 기존 사용자 파일 해시 동일. ignored 근거: `build/room_action_efficiency_20261022/full-1.json`.
- 1차 실패 원인: `guest-onboarding.test.mjs:33`은 DB 설정이 없는 격리 환경에서도 가입 미완료/잘못된 입력 오류가 먼저 나오는 기존 계약을 검증한다. 새 병행 코드에서 `getDatabase()`를 Promise 결과 처리 밖에서 먼저 호출하여 동기 초기화 예외가 그 계약을 우회했다. 제품 회귀로 판정했다. DB 초기화도 measured 병행 작업 안에서 수행하여 동기 예외를 결과로 모으고 onboarding → operation ID → mapping 오류 순서를 유지하도록 수정한다. 기존 guest 테스트는 약화하지 않는다. 동기 초기화 실패 회귀도 추가하고 관련 검사 후 FULL 2차로 검증한다.
- 후보2: 위 수정과 동기 초기화 실패 3개 회귀를 추가했다. `npm.cmd --prefix functions run build` → PASS/exit0, `node --test test/room-allocation-sdk-cache.test.mjs test/guest-onboarding.test.mjs` (cwd `functions`) → 34개 PASS/exit0. 기존 실패한 guest 테스트와 onboarding 지연 중 unhandled rejection 없음까지 확인했다. 독립 재검토에서도 추가 결함을 찾지 못했다. 이 후보로 FULL 2차를 실행한다.
- FULL **2/3회**: 위와 같은 guarded `validate --full --json` 명령 → **PASS, exit 0**, 296.981초. preflight·포맷·분석·앱·6개 패키지·Functions lint/test·작업 트리 보존 등 **13단계 전부 PASS**. 앱575 + 패키지261 + Functions534 = **총1,370개 테스트 통과**. 실패0·BLOCKED0·timeout0. ignored 근거: `build/room_action_efficiency_20261022/full-2.json`. 3차는 필요 없어 실행하지 않았다.

| FULL2 테스트 대상 | 통과 수 |
| --- | ---: |
| 루트 Flutter 앱 | 575 |
| game_kit | 120 |
| game_liars_poker | 17 |
| game_final_call | 26 |
| game_mafia | 58 |
| game_holdem | 32 |
| game_yut | 8 |
| Functions | 534 |

### 실행 전후 작업 트리

- 시작: develop/HEAD `cc293dffc35111e0b65ea2aa87e46d7c2347a3eb`, staged0·unstaged0·기존 미추적2파일.
- FULL2 직전/직후: 작업 브랜치와 HEAD 동일, staged0·변경 tracked8파일·미추적4파일(기존2 + 본 작업 보고서/테스트2)로 동일. CLI working-tree-mutation PASS와 별도 status 비교를 모두 확인했다.
- 기존 사용자 파일의 Git blob 해시도 시작과 동일하다: 특허 검토 `e8c84dec40c4743b345b62a003ba5507bef7d2c4`, 오디오 인수인계 `1271e814dd36426bea30e6064f0eb5274975df13`.
- 검증 후에는 결과를 남기는 본 보고서·TASKS·작업 상세·월별 기록만 갱신했다. 제품3파일·테스트2파일의 SHA-256은 FULL2 실행 전과 동일하다. 예상하지 못한 tracked/unignored 변경 없음.
- 최종 변경은 **제품3 + 테스트2 + 문서5 = 10파일**, 미커밋·미스테이징 상태다. 기존 미추적2파일은 작업에 포함하지 않는다. `git diff --check` PASS/exit0. commit·push·develop 병합·배포·production 접근 없음.

## 6. 최종 개발 보고

| 변경 파일 | 변경 사항 |
| --- | --- |
| [room_service.dart](../../lib/platform/home/room/services/room_service.dart) | 추방 전 game/public 조회와 game context 전송 제거. 방·controller 신원 및 operation ID 유지 |
| [create-room.ts](../../functions/src/room/create-room.ts) | onboarding 확인과 기존 매핑 읽기 병행. 선행 조건·오류 우선순위 유지 |
| [realtime-room-lifecycle.ts](../../functions/src/room/realtime-room-lifecycle.ts) | close 사전 get·kick 외부 중복 listener 제거, close commit 결과 확인 |
| [room_player_removal_fast_path_test.dart](../../test/room_player_removal_fast_path_test.dart) | 신원 cache/조회·게임 context 유무·인증 실패·서버 거절 등 신규 7개 회귀 |
| [room-allocation-sdk-cache.test.mjs](../../functions/test/room-allocation-sdk-cache.test.mjs) | 병행·실패 우선순위·cold cache·단일 listener·abort·재실행 경합·멱등성 및 동기 초기화 오류 신규 22개 회귀 |
| [NETWORK_SESSION_CONTRACT.md](../engineering/NETWORK_SESSION_CONTRACT.md) | 현재 효율 개선 후보의 신원·priming·쓰기 선행 조건 설명 |
| 본 보고서·[TASKS](TASKS.md)·[작업 상세](tasks/NET-RECOVERY-01.md)·[월별 기록](logs/2026-10.md) | 점검 18항목·개발 설계·실패/검증·후속 연결 |

| 동작 | 요청 처리 전 → 후 | 기능상 예상 변화 |
| --- | --- | --- |
| 그룹 생성 | onboarding → 기존 매핑 읽기 → 생성 절차 → onboarding/기존 매핑 병행 → 둘 다 성공 후 같은 생성 절차 | 정상 경로의 독립 준비 대기 중첩. 생성 조건·멱등성·충돌 보호 유지 |
| 그룹 내 추방 | identity → 필요 시 game/public 읽기 → 추방, 서버 이중 listener → identity → 추방, 서버 단일 listener | 게임 없는 로비의 불필요한 조회·그 조회 실패 의존성 제거. 게임 중 추방 차단과 권한 검증 유지 |
| 방 초기화 | root get/검증 → priming/재검증 → 결과 무관 성공 → 단일 priming/최신 검증 → committed 확인 후 성공 | 중복 준비 축소. 서버 미적용 시 실패로 남겨 조기 로컬 성공 정리를 방지 |

후보2 독립 재검토에서 추가 코드 결함은 발견하지 못했다. onboarding이 legacy 계정의
Firestore backfill도 수행한다는 점을 보고서·코드 주석에 명확히 했다. 새 dependency,
공개 API·DB shape·Rules·리전·게임 규칙 변경은 없다. 기존 UI·초기화 후 새 방 생성
분리·불확실 결과 복구·옛 연결 예약 취소 보호를 유지한다.

전체 체감 시간·비용 절감량은 실측하지 않았다. 서버 개선의 사용자 적용에는 별도 승인
배포가 필요하다. 실기기·운영 조회·배포는 수행하지 않았으며 10/20의 후속 확인도 유지한다.
이번 요청의 개발·자동 검증은 완료했지만, NET-RECOVERY-01의 기존 실기기·출시 후속
전체를 완료 처리한 것은 아니다.

## 7. 10/22 후속 사용자 승인 — 배포·측정용 release

개발 완료 보고 후 사용자가 세 함수 배포·release APK 생성과 영상 개선도 측정 지시문을
요청했다. 이에 createRealtimeRoom·removeRealtimeRoomPlayer·closeRoom을 선택 배포해
CLI exit0 및 세 함수 ACTIVE를 확인했다. FULL PASS 제품 소스는 추가 변경하지 않았다.
Android `1.0.0+6` release APK 생성·서명/버전 검증도 PASS/exit0이다.
빌드 입력1,076개 해시 동일이며, 기존 측정 APK와 인증서도 같다.
[배포·APK·해시·보관 기록](../operations/ROOM_ACTION_RELEASE_20261022.md)과
[사용자 촬영 및 AI 비교 지시문](../operations/PERFORMANCE_CAPTURE_CHECKLIST_20261022.md)에
근거를 남겼다. 앞선 10파일 상태는 개발 검증 완료 시점이며 이 후속에서는 문서·산출물이
추가됐다. 기기 설치·촬영·개선율 산출은 아직 미실행이다. develop 병합·commit·push는 없다.
