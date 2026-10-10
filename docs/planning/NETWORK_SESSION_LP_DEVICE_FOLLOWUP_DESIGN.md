# LP 실기기 후속 오류 분석·해결 설계

2026-10-10 KST. SESSION-RECONNECT-02 / TEST-REGRESSION-01 후속.
[작업 목록](TASKS.md), [직전 수정·FULL](NETWORK_SESSION_ROULETTE_RESTART_REPAIR.md),
[현재 세션 계약](../engineering/NETWORK_SESSION_CONTRACT.md)을 따른다.
아래는 착수 전 분석·해결 설계 기록이다. 이후 사용자 작업 진행 요청에 따른
[구현·검증 후보](NETWORK_SESSION_LP_DEVICE_FOLLOWUP_IMPLEMENTATION.md)는 별도로 관리한다.

## 근거의 범위

사용자는 새 APK를 설치했지만 Functions는 배포하지 않았다고 확인했다.
테스트 시각은 약 2026-10-10 12:30~12:40 KST로 합의했다. 여러 판을 진행했으며,
현재 로그에서 해당 구간의 start는 세 번이다. 사용자 목록의 모든 판이 이 구간 안에
있었다고 단정하지 않는다. 기존 2026-10-09 디바이스 로그는 이번 사건의 증거로 사용하지 않았다.

현재 연결한 기기의 기존 logcat buffer를 새로 읽었다. 앱 재실행/데이터 삭제/logcat clear는
하지 않았다. 사용자가 A→태블릿→B의 연결 역할을 각각 확인했다.

| 기기 | 새 추출 시각 KST | 설치 시각 KST | 12:30~12:40 구조화 기록 |
| --- | --- | --- | --- |
| A | 12:49:35 | 12:09:25 | 282줄 |
| 태블릿 | 13:03:42 | 12:06:22 | 192줄 |
| B | 13:07:26 | 12:07:54 | 149줄 |

세 기기 모두 1.0.0+2 debug APK다. 설치 APK SHA-256은 로컬 새 APK와 모두 같다.
`4271063565F4A952831C2CE03E6D3A63374DC4BC56BDC413C96A9BC10DA01F15`.
기기/서버 대응 요청 시각에는 약 0~2초 차이가 있어 millisecond 일치를 주장하지 않는다.

사람이 기존 조회용 계정의 Database Viewer/Logs Viewer 두 역할만 유지된다고 확인한 뒤,
[서버 로그 절차](../operations/FIREBASE_SERVER_LOGS.md)에 따라 조회했다.
project0000-ec01e, mosigame-logs-readonly, UTC 03:30:00 이상~03:40:00 미만,
관련 함수만 읽었다. 실제 service/region을 metadata로 확인한 서비스는 13개다.
반환 81건/고유 insertId 74개로 100건 한도를 지켰다. 요청 URL/본문/private payload,
계정·credential·token은 출력·저장하지 않았다. RTDB는 조회하지 않았다.

정제 근거는 ignored `build/device-test/lp-followup-20261010-124930/`에 있다.

## 판정

| 현상 | 현재 판정 | 근거·남은 한계 |
| --- | --- | --- |
| 룰렛 결과 반영 실패 두 번 | 앱/서버 ID 계약 불일치가 직접 원인으로 확인됨 | 태블릿 invalid-argument, 서버 resolve HTTP 400, 이전 서버의 동일 ID 검사와 새 앱의 별도 resolve ID가 일치 |
| 복구 후 A 권한 오류·복구중 지속 | 접속 권한이 복구 완료 표시 이후에도 회복되지 않았음 확인 | A ready/LIAR permission-denied, 접속 노드 heartbeat 권한 거절 24건. 정확히 어떤 접속/참가 조건이 틀렸는지는 현재 로그에 없음 |
| A가 B와 같은 pause 안내로 바뀜 | 방 복구 callback 성공과 게임 준비 확인의 분리·실패 처리가 문제 | guard 성공 뒤 재접속/ready 경합, 실패한 ready의 독립 재시도·소진 누락, 공통 pause 안내가 자신의 미확인 상태를 구분하지 못함 |
| 세 기기 ready 시간초과 | 실제 서버 응답 지연 확인 | 12:35:43대의 여러 보고가 8.75~9.36초 뒤 종료. 지연의 내부 원인은 미확정 |
| 룰렛 회전 중 상태 수신 시 확정 누락 | 별도 클라이언트 결함 재현 | 실제 controller probe에서 public 수신 뒤 resolveCalls=0. 위 두 invalid-argument 사건에는 확정 RPC가 실제 존재하므로 귀속을 구분 |
| 남은 5/6/11초·타이머 소실 | 현재 pause 정책으로 설명 가능한 부분, 정확한 수치 유실 미판정 | 첫 서버 pause 때 남은 값 보존. 현재 로그에는 deadline/저장 remaining/pauseId가 없음 |
| 첫 룰렛부터 두 번째 원판 | 기존 1대1 truthful/lastCardChallenge 규칙으로 가능, 이번 판 귀속 미판정 | 당시 penaltyCount/증가 사유는 로그에 없음. 무조건 초기화 결함으로 판정하지 않음 |

## 1. 룰렛 실패의 직접 원인과 반영 단위

태블릿 12:31:22.620 추첨 성공 → 12:31:28.614 확정 invalid-argument.
서버 대응 resolve는 12:31:27.248 HTTP 400, latency 0.00846초다.
다음 판도 태블릿 12:34:01.596 추첨 성공 → 12:34:07.290 확정 invalid-argument,
서버 12:34:05.971 HTTP 400/0.00782초다. 네트워크 시간초과가 아니다.

새 앱은 prepare resolutionId와 resolve commandId를 분리한다. HEAD의 이전 서버는
두 값이 다르면 `invalid-argument: 벌칙 처리 식별자가 일치하지 않습니다.`를 반환한다.
직전 후보는 이 검사를 제거했지만 사용자가 Functions 미배포를 확인했다.
준비 단계에서 예상했던 failed-precondition 분류는 실제 코드·로그 확인 후 위처럼 정정했다.
이전 앱의 동일 ID 재사용으로 발생하던 ledger permission-denied와도 다른 분기다.

해결 순서:

1. 서버·앱을 같은 후보로 맞춘다. 최소 ID 계약 반영 함수는 game_liars_poker_resolve_penalty다.
   같은 파일의 prepare도 함께 검토한다. 직전 후보에는 네 게임 시작 fingerprint와 공통
   runPrimedTransaction 예외 처리도 있어 resolve 하나만 반영하면 후보 전체 반영은 아니다.
2. index export/상대 module 의존성의 보수적 영향 계산은 69개(방/session 17, 네 게임 43,
   공통 9; auth 10 제외)다. 이것은 확정 배포 manifest가 아니다. 함수별 실제 공유 코드
   의존성과 현재 배포 목록을 대조해 필요한 함수 목록을 확정한다.
3. 아래 추가 클라이언트 결함을 포함한 최종 후보를 검증하고, 별도 승인된 배포로 반영한다.
   반영 함수/빌드와 세 기기 APK hash를 기록하고 새 방에서 실기기를 다시 시험한다.
   현재 설계에 rules 변경이나 권한 완화는 필요하지 않다.

## 2. A 복구의 실제 순서와 접속 소유권

마지막 판의 시간축(각 기기 로컬 시각과 서버 KST를 구분):

| 시각 | 관찰 |
| --- | --- |
| A 12:34:44.309 | Firebase 연결 false. network_guard 같은 이벤트 2회 |
| A 12:34:45.458 | 앱 foreground 복귀, 방 복구 시작 |
| A 12:34:55.463 | 네트워크 모달 표시 2회 |
| A 12:35:39.491 | 연결 true, 두 guard의 recovery_started |
| 서버 12:35:39.976~40.309 | join 한 요청 HTTP 200, 바로 옆 join 요청 HTTP 409 |
| A 12:35:40.421 | ready permission-denied |
| A 12:35:41.146 | 후속 ready 응답, barrier/input 완료 표시 |
| 서버 12:35:42.259~43.151 | join HTTP 409 한 번과 200 두 번 |
| A 12:35:42.943 | 두 guard recovery_succeeded. 이후 identity/subscriptions 재준비 |
| A 12:35:43.104~43.742 | ready 요청 3개 시작 |
| A 12:35:51.110~51.745 | 세 요청의 8초 시간초과 |
| B 12:35:51.142 / 태블릿 12:35:52.476 | 같은 준비 보고의 8초 시간초과 |
| 서버 12:35:43.037~52.402 | ready 5개가 8.75~9.36초 지연 후 404 한 개/200 네 개로 종료 |
| A 12:35:53.001 | 후속 ready/barrier/input 완료 표시 |
| A 12:35:53.473~39:53.480 | heartbeat RoomCommandException 반복 |
| A 12:35:53.872 / 서버 12:35:53.549 | LIAR permission-denied / 대응 HTTP 403 |
| 태블릿 12:35:56.246 | force_timeout은 forcedLiar 성공. 서버 진행 자체가 전부 멈춘 것은 아님 |
| A 12:36:03.958, 04.612 | ready permission-denied 재발 |
| B 12:36:04.329 / 태블릿 12:36:05.414 | 같은 구간의 후속 ready 응답 성공 |
| 태블릿 12:37:05.580, 25.532 | expire / wait_more 응답 성공 |
| 태블릿 12:37:37.922 | 수동 게임 종료 응답 성공 |

A의 새 native warning 수집에서는 12:36:03~12:39:53 접속 노드 쓰기의
permission-denied 24건을 확인했다. 실제 room/UID/connection 경로는 삭제하고
시각/오류 분류/room-connections라는 경로 종류만 보관했다.

B는 이번 구간에 연결 false/모달/방 identity 복구 실패 기록이 없고 공통 pause에 반응해
ready를 보고했다. B와 태블릿의 후속 ready는 성공했지만 A의 권한 오류가 지속됐다.
따라서 A가 단순히 B의 화면을 잘못 복사한 문제보다, A 자신이 서버 준비 집합으로
돌아가지 못한 상태와 이를 공통 안내만으로 표시하는 문제가 우선이다.

현재 code에서 확인한 복구 경계:

- RoomProvider는 같은 인스턴스의 in-flight 복구 Future를 공유한다. 두 guard 로그만으로
  join 두 개가 동시에 실행됐다고 단정하지 않는다. 대기실과 게임의 별도 Navigator route에는
  각각 guard가 살아 있고 부모 guard scope가 route 사이 중복을 막지는 못한다.
- 방 복구가 끝나기 전에 RTDB true와 기존 identity로 ready가 실행될 수 있다. 12:35:41의
  준비 완료 후 42~43초의 접속/identity 변경이 이 순서와 맞는다.
- RoomService._joinRoomWithRetry는 pending join replay 성공 후에도 반환하지 않고 새 join
  할당으로 이어진다. 논리 복구 한 번에서 연결 교체가 추가될 수 있는 코드다.
- heartbeat 권한 오류는 오류 타입을 기록한 뒤 종료하며 현재 접속 재확인으로 이어지지 않는다.
  방 모달은 room callback 성공으로 닫혀도 이후 접속 권한 손실이 자동 해소되지 않을 수 있다.
- native heartbeat rules는 연결이 false라는 이유만으로 connected=true 복원을 거절하지 않는다.
  계속된 쓰기 거절은 단순한 false 표시에 더해 현재 connection/room/membership/UID 조건 문제를
  의심할 근거다. 이번 로그에는 비교 값이 없어 특정 조건이나 접속 교체 주체는 확정하지 않는다.

해결 설계:

- UID/role/roomInstance/membership/복구 세대로 복구 한 번의 소유자를 정한다. route의 guard,
  lifecycle, SDK true, 명시 재시도가 같은 작업을 공유하고 이미 완료한 episode를 새 join으로
  다시 시작하지 않게 한다. foreground route만 안내를 소유하고 기존 메뉴/나가기를 유지한다.
- 방 접속 복구 완료 → 현재 identity 확인/저장 → 해당 identity의 heartbeat 확인/구독 재준비 →
  ready 확인 순서로 진행한다. 이전 identity로 준비 완료를 보고하거나 입력을 열지 않는다.
- pending join은 먼저 원래 operation의 결과를 확인한다. 수락된 접속이 현재인지 확인해서
  채택하며, 같은 논리 복구의 성공 replay 뒤 무조건 새 접속을 할당하지 않는다. stale 응답은
  현재 참가 자격 확인을 통해 처리하며 과거 결과가 새 접속/예산을 덮지 못하게 한다.
- heartbeat 또는 ready의 staleConnection 거절은 같은 제한 묶음의 접속 재확인으로 보낸다.
  현재 참가 자격이 사라졌으면 새 참가자를 생성하지 않는다. generic permission-denied를
  무조건 자동 재시도하거나 rules를 완화하지 않는다.
- 늦은 callable/identity save/구독/ready ack는 캡처한 복구 세대와 현재 접속을 확인한다.
  새로운 연결이 생긴 뒤 이전 세대가 준비 완료·오류·retry 소유권을 바꾸지 못하게 한다.

## 3. 준비 보고 실패와 안내의 끝 조건

[GameSessionController](../../packages/game_kit/lib/recovery/providers/game_session_controller.dart)
_updateReadiness는 localUsable이 되면 deadline/refresh 감시를 취소한다. _report의 최종
오류는 _reportedKey만 비운다. 새 public/private 이벤트가 없으면 보고/소진의 주체가 없다.
실제 controller probe에서 localUsable=true/serverConfirmed=false, 31초 후 보고 횟수 1,
canSend=false/error=null을 확인했다. 실제 A의 마지막 ready 권한 오류와 공통 pause 지속을
설명할 수 있는 경로다. probe는 고립 controller 관찰이며 전체 실기기 사건의 재현은 아니다.

[GameRecoveryLayer](../../packages/game_kit/lib/recovery/widgets/game_recovery_layer.dart)는
중단 중 player 화면에 공통 문구를 쓰고, 재시도는 localUsable=false이면서 오류가 있어야
나온다. 화면 데이터가 준비됐지만 서버 확인만 실패한 A는 명시 재시도를 잃을 수 있다.

해결 설계:

- 데이터 준비와 ready 확인을 별도로 추적한다. localUsable만으로 ready 확인 감시를 종료하지 않는다.
- 최종 일시 오류/응답 유실은 새 RTDB 이벤트 없이도 같은 RoomRecoveryBatch에서 원래
  operationId/reportSeq로 결과 확인과 재전송을 이어간다. 기존 6회/요청 8초/전체 30초를 유지하고
  중첩 retry나 public 이벤트마다 새 예산을 만들지 않는다.
- 접속/게임 context가 바뀌면 이전 보고를 무효화하고 새 identity/context의 보고로 교체한다.
  accepted/ignored/operation-status applied를 현재 준비 수락과 혼동하지 않는다.
  자신의 확인 이후 다른 참가자 barrier 대기는 자신의 실패 deadline으로 취급하지 않는다.
- 자기 연결/화면/ready 확인이 실패했을 때는 기존 오류 안내 안에서 미완료 단계를 알려주고
  재시도를 제공한다. 다른 참가자를 기다리는 B의 공통 pause 안내와 구분한다.
  정상 준비에는 별도 새 화면을 추가하지 않으며 메뉴·나가기는 계속 접근 가능하게 한다.
- 임시 구조화 로그에 복구 세대, 접속 seq 변경/현재 일치 여부, ready 결과 분류,
  localUsable/serverConfirmed/paused, 최초 pause remaining을 추가한다. UID/손패/실제 세션 ID는
  출력하지 않는다. 서버 403은 현재 로그에 details.reason이 없어 정확한 조건 분류를 보강해야 한다.

여러 기기 ready가 서버에서 동시에 지연된 사실은 확인했지만 HTTP 200의 내부 status,
RTDB transaction 대기 원인과 어떤 invocation이 A인지 모두 알 수는 없다. ERROR 전용 조회는
0건이었다. Oct9의 finished-function/504 근거를 이번 시간대의 사건으로 재사용하지 않는다.
공통 transaction 안전 abort 수정은 기존 확인 결함으로 반영하되, 이번 9초 지연까지 그 수정이
해결했다고 주장하지 않는다. 최종 후보에서 동시 ready 및 join 경합을 별도로 검증한다.

## 4. 룰렛 회전 작업의 수명

[LP controller](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)의
hasChanged는 isResolvingPenalty만 true여도 true가 되고, public 수신은 이를 false로 발행한다.
resolveRoulette는 false면 서버 확정을 보내지 않는다. 준비/연결 갱신이 같은 penalty의
회전 작업을 중간에 취소할 수 있다. prepare→command/coordinator 회귀는 이 controller
수명을 검증하지 않았으므로 직전 FULL PASS가 이 경로의 보장은 아니다.

해결 설계:

- pending 추첨/회전/확정을 gameInstanceId/penalty phase/대상/resolutionId와 로컬 세대로 소유한다.
  같은 penalty의 public/ready/recovery 갱신에서는 소유권을 보존한다.
- 새 게임·새 penalty·대상 변경·종료 때만 해당 작업을 무효화한다. 회전 완료는 캡처한
  추첨의 현재 소유권을 검사해 한 번만 확정한다. 오래된 Future/위젯 callback은 새 게임의
  pending, 오류, rouletteRetry를 변경하지 못한다.
- 일시 중단 시 추첨과 원래 resolve commandId를 보존한다. 복구 후 operation status와
  원래 응답으로 처리 결과를 확인한다. 다시 추첨하거나 paused 서버 규칙을 우회하지 않는다.
- public revision 수신만으로 확정 성공이라고 처리하지 않는다.

## 5. 타이머와 첫 원판

현재 A의 타이머는 내 턴/초기 데이터 준비 완료/dealing·penalty가 아님/deadline 존재 때만
표시한다. 서버 pause는 turnDeadlineAt=null로 내려보내므로 pause 중 타이머 소실은 현재
코드와 일치한다. 재개 뒤 내 턴인데도 안 보이는 경우는 deadline·대응 private·준비 조건을
함께 기록해야 판정할 수 있다.

서버는 인터넷 차단 시점이 아닌 최초 pause commit 시점의 deadline-now를 보존한다.
10초 heartbeat/20초 stale 유예/태블릿 1초 재평가 동안 시간은 흐를 수 있다.
실제 첫 단절은 A 12:32:09.965 false, 서버 stale 보고는 12:32:24.589에 기록돼 있다.
태블릿 revision 11 수신은 12:32:26.120이다. 이번 로그에는 pause 값이 없어 이를 정확한
pause commit으로 단정하지 않지만 감지까지 시간 간격이 존재한다. 5/6/11초를 모두 원래
25초로 돌리는 것은 현재 계약 변경이며 이번 해결안으로 확정하지 않는다.

3초 작은 안내/10초 네트워크 모달 차이는 기본 UI 정책과 일치한다. 인터넷 차단/앱 foreground/
SDK false/모달 시각이 다르므로 표시된 남은 숫자만으로 감지 지연을 확정하지 않는다.

1대1 또는 lastCardChallenge에서 truthful LIAR 실패는 penaltyCount를 해당 룰렛 전에 올린다.
safe 확정 때 이중 증가하지 않는다. 이 조건이면 첫 원판이 두 번째 확률인 것은 기존 규칙이다.
각 start가 revision 1, 정상 dealing/ready 후 진행된 기록은 있지만 penaltyCount 초기화 값과
당시 증가 사유가 없어 사용자 보고의 해당 판은 미판정이다. 새로운 gameId에서 초기값 0,
일반 첫 벌칙, 1대1 truthful/강제 LIAR 증가와 화면 attemptCount를 함께 검증한다.

## 구현 순서와 검증

1. 접속 복구·ready 확인 소유권/실패 처리와 기존 서버 반영 범위를 확정한다.
2. 룰렛 controller의 동일 penalty 소유권을 보완한다.
3. 아래 회귀를 기존 session suite와 실제 함수 경로에 추가해 검증한다.
4. 최종 후보 요약·새 승인 FULL 후 필요한 Functions 반영, 동일 APK 설치, 새 방 실기기 재시험한다.

| 회귀 | 필요한 판정 |
| --- | --- |
| 새 앱/이전 서버, 새 앱/새 서버 | 이전 계약 거절과 새 계약 수락을 구분 |
| lifecycle/두 route guard/SDK true 경합 | 논리 episode당 현재 접속 복구 한 번, 추가 접속 교체 없음 |
| pending join replay·late response | 현재 접속 확인 후 채택, 이전 세대가 새 identity를 변경하지 못함 |
| 복구 중 기존 identity로 ready/heartbeat | 입력 차단, 최종 현재 접속의 ready로만 확인 |
| 접속 권한 거절/참가 자격 소실 | 제한된 재확인 또는 종료 처리, 무한 heartbeat 실패·참가자 재생성 없음 |
| ready 최종 실패·ack 유실, 이후 이벤트 없음 | 30초 안 확인/명시 소진·재시도, 기존 메뉴 유지 |
| A/B/태블릿 동시 ready·late ack | 하나의 예산/보고 소유권, 타인 barrier를 조기 해제하지 않음 |
| 룰렛 prepare→동일 public→회전 완료 | 정확히 한 resolve, 추첨 유지 |
| 회전 중 pause/end/new game와 이전 Future | 이전 작업 무효화·새 판 오류/추첨 독립 |
| timer·첫 원판 | 최초 pause remaining 보존, 새 game 초기값과 정상 규칙 증가 구분 |

공통 복구는 LP 외 세 게임도 소비하므로 session 회귀와 FULL 범위를 유지한다.
public API/persistent data/중요 상태 계약 변경·배포는 Engineering Contract의 승인 경계다.
이번 설계는 제품 의도에 없는 확률 변경·전체 타이머 초기화·권한 완화를 전제로 하지 않는다.

## 이번 조사 실행 기록

branch codex/e01-validation-wiring, HEAD e787a10de8723d66b08c84b173a07ddbf267b113,
staged 없음. 시작 시 직전 후보 modified 16/untracked 7개를 보존했다. 제품 소스는 바꾸지 않았다.
이번 tracked/unignored 변경은 이 설계와 TASKS/두 상세/월별 일지의 조사 기록뿐이다.

| command / 범위 | status / exit | 결과·한계 |
| --- | --- | --- |
| `C:/flutter/bin/flutter.bat test --no-pub build/network-session-investigation/lp_followup_probe_test.dart` | PASS / 0 | 실제 controller 결함 관찰 2/2. 수정 완료 테스트가 아님 |
| `node build/network-session-investigation/lp_server_impact.cjs` | PASS / 0 | export 69개 보수적 module 영향. 배포 manifest 아님 |
| `adb -d logcat -d -v time flutter:I *:S` + 설치 metadata/hash | PASS / 0 | A/태블릿/B 새 수집, 세 APK 일치, 합의 시간 623줄 |
| `adb -d logcat -d -v time *:W` 메모리 정제 | PASS / 0 | A 접속 쓰기 permission-denied 24건, 원문 경로 제거 |
| gcloud known start metadata | PASS / 0 | 1+1건, actual service/region/function label 확인 |
| gcloud 함수별 label metadata | PASS / 0 | 16회/각 limit 1, 반환 11건 |
| gcloud 제한 이름 metadata | PASS / 0 | 5회/각 limit 1, 반환 2건, exact service 확인 |
| gcloud 실패 요청 metadata | PASS / 0 | limit 35/반환 11건 |
| gcloud 필요한 오류 필드 메모리 분류 | PASS / 0 | limit 40/반환 40건. Error substring에 매칭한 warning이며 오류 원인으로 판정하지 않음 |
| gcloud ERROR 전용 | PASS / 0 | limit 20/반환 0. 정상 동작의 증거로 바꾸지 않음 |
| gcloud 마지막 복구 15초 metadata | PASS / 0 | limit 30/반환 15건. 전체 반환 81/고유 74 |

최초 probe의 mock 반환 형식은 compile FAIL/exit 1이었다가 실제 API 형식으로 수정했다.
제한 환경의 native gcloud/추가 ADB 실행은 process-start 오류로 원격 조회 전에 실패했다.
이미 승인된 같은 읽기를 권한 있는 실행 경로로 수행해 위 결과를 얻었다. 계정 로그인/IAM
변경·SDK 수정은 없었다. 최초 시간 표시의 JSON 날짜 자동 변환도 수정해 KST를 재확인했다.
새 session/FULL·제품 구현·배포/migration·stage/commit/push는 실행하지 않았다.
직전 FULL 12/12 PASS는 이전 후보의 결과이며 이번에 발견한 결함의 해결 판정이 아니다.

조사 종료 상태는 modified 16/untracked 8, branch/HEAD 동일, staged 없음이다.
위 네 기존 문서의 git diff --check PASS/exit 0과 새 설계 링크/공백 검사 PASS를 확인했다.
기존 사용자 파일을 삭제·복원·정리하지 않았다.
