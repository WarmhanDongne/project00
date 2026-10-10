# LP 18:41 종료·태블릿 연결 후속 분석과 설계

2026-10-10 KST. SESSION-RECONNECT-02 / TEST-REGRESSION-01 후속.
사용자는 18:41 테스트 시작을 확인했고 종료 시각은 제공하지 않았다. 마지막 카드 LIAR
실패 2단계→생존→FOLD 3단계는 실기기 통과 보고다. 종료 후 휴대폰은 그룹으로 돌아갔지만
태블릿은 종료 실패/위너 화면에 남았고, 그룹의 휴대폰에 태블릿 단절이 표시됐다. 태블릿도
뒤늦게 복귀했으나 다음 시작이 실패했고, 앱 재실행 후 같은 그룹에서 시작이 성공했다.

## 이번에 새로 수집한 근거

이전 로그를 현재 테스트의 근거로 재사용하지 않았다. 정제 기록은 ignored
`build/device-test/lp-followup-20261010-1841/`에만 저장했다.

| 시각 KST | 관찰 |
| --- | --- |
| 18:46:09.701 | A 공개 상태 revision 27 / finished 수신 |
| 18:46:10.452 | 태블릿 같은 revision 27 / finished 수신 |
| 18:46:16.490 | 태블릿 end_game 전송 |
| 18:46:24.498 | 태블릿 end_game 8,008ms / 1회 시도 / TimeoutException |
| 18:46:25.363 | A 공개 상태 revision 28 / finished 수신 |
| 18:46:36.224, 46.571, 59.148 | 태블릿 liars_poker/tablet TimeoutException 추가 기록 |
| 18:47:02.485 | 태블릿 revision 28 / finished 수신: A보다 37.122초 늦음 |
| 18:47:12~18:50:47 | 태블릿 room/command TimeoutException 반복 |
| 18:52:08.870 | 재실행한 태블릿의 새 프로세스에서 RTDB 연결됨 기록 |
| 18:52:42.044 | 재실행 후 start_game 응답 665ms |
| 18:52:55.441 | 이후 end_game 응답 1,036ms |

태블릿 첫 수집은 18:54:29, 통신 기록 237줄; A는 18:55:44, 196줄이다. 태블릿 예외
metadata 보완 수집은 19:01:28, 18줄이다. 예외 원문/사용자 식별자/게임 private payload는
저장하거나 출력하지 않았다. 태블릿 앱은 debug, 마지막 설치 15:43:24로 확인했다.

사용자 승인 범위 18:41~18:53 KST의 관련 서버 metadata를 기존 조회용 gcloud configuration으로
100건 조회했다. heartbeat 기록이 한도에 먼저 도달해 18:43:23까지만 관찰했다. 이 최초
100건을 종료 시점의 서버 정상/이상 근거로 쓰지 않는다. 사용자 추가 승인으로 heartbeat를
제외한 start_game/end_game HTTP 기록 최대 20건을 조회했고 실제 7건이다(총 107건).
두 조회 모두 PASS / exit 0이며, payload/Auth/IAM/RTDB 조회·쓰기는 하지 않았다.

시간상 대응하는 18:46 종료 HTTP 기록은 200 / 실행 latency 2.568초다. 재실행 뒤 시작은
200 / 0.438초, 종료는 200 / 0.368초다. HTTP 200만으로 business 성공을 단정하지 않는다.
A와 태블릿의 revision 변경, 사용자 그룹 복귀 보고를 합치면 종료 반영 뒤 태블릿의
응답·RTDB 상태 확인이 지연된 흐름이라는 근거가 된다. 18:47~18:51에는 조회된 LP
start_game HTTP 기록이 없고 태블릿에도 start_game 전송 기록이 없어, 다음 시작 실패는
게임 시작 함수 이전의 방 명령 단계로 좁힌다. 방 명령의 정확한 함수는 예외 metadata에 없다.

## 확인된 처리와 미확인 원인

- `CallableRetryPolicy`는 요청을 8초로 제한한다. LP `endGame`은 자동 재시도 없이 단일
  요청이며, 시간초과 후 원래 commandId/domain과 재확인 callback은 유지한다.
- LP `_runMenuCommand`는 시간초과를 false/종료 실패 문구로 바꾼다. 태블릿 board는
  false면 위너 화면을 유지하며 최신 수동 종료 상태가 도착해야 자동 퇴장한다.
- 미확정 요청의 수동 재시도는 operation_status부터 읽는다. 위 추가 TimeoutException은
  이 재확인 지연과 양립하지만 원문/함수별 로그가 없어 각 건의 요청을 단정하지 않는다.
- controller heartbeat는 10초마다 RTDB write를 시도한다. 일반 `_writeWithRetry` 경로는
  write Future 자체에 timeout이 없다. `_heartbeatControllerSafely`는 실패 기록만 남기고
  연결 복구 확인을 무효화하지 않는다. `.info/connected`가 true로 유지되고 identity/접속
  scope가 같으면 `retryConnectionRecovery`는 캐시된 성공을 반환할 수 있다.
- 이번 태블릿 통신 기록에는 `.info/connected=false`가 없다. 이는 인터넷 정상이라는
  증거가 아니다. OS/Wi-Fi 경로 문제, native SDK 연결 정체, 실제 write 정체/복구 cache
  경로 중 무엇이 시작점인지는 현재 로그로 구별할 수 없다. 앱 재실행 후 성공도 특정
  SDK 버그를 입증하지 않는다. 실제 휴대폰의 단절 표시 원인(connected=false인지 lastSeen
  20초 초과인지)은 이번 개인정보 없는 기록에 없어 구분하지 못했다.

### 후속 Wi-Fi / Firebase 구분 조사

사용자가 추가 구분을 요청해 연결된 태블릿의 이번 시간대 native main/system 로그를
새로 읽었다(PASS / exit 0). 과거부터 남아 있는 buffer 전체 원문은 저장하지 않고,
18:41~18:53의 필요한 신호만 개인정보 없이 정리했다.

| 시각 KST | Android 시스템 관찰 |
| --- | --- |
| 18:46:37.171 | 현재 Wi-Fi network의 연결이 좋지 않다는 보고로 인터넷 재검사 시작 |
| 18:46:42.280 / .284 | 일반 인터넷 검사의 DNS 두 건 5,093ms / 5,099ms, 최종 성공 |
| 18:46:42.477 / .678 | 이후 HTTP / HTTPS 검사 191ms / 394ms, HTTP 204 |
| 18:46:45.326 | OS Wi-Fi 인터넷 validation passed |

이 기록은 앱의 Firebase 호출과 별개인 OS 인터넷 검사에서도 DNS 지연이 있었다는
추가 근거다. DNS 검사는 첫 종료 timeout 뒤에 실행됐으므로 첫 종료 실패의 DNS 원인을
직접 측정한 것으로 단정하지 않는다. 공유기/ISP/기기 DNS·무선 품질 중 어느 부분인지는
구분되지 않았다. 해당 시간대 wpa_supplicant의 명시적 AP 분리/재연결 이벤트는 선택한
기록에서 발견되지 않아 Wi-Fi 접속 자체가 끊겼다고 표현하지 않는다.

인터넷 검사가 통과한 18:46:45 이후에도 앱의 방 명령 timeout은 18:50:47까지 이어졌다.
따라서 일반 인터넷 검사 정상과 현재 앱의 Firebase 통신 정상은 분리해서 판단해야 한다.
[Android 공식 문서](https://developer.android.com/develop/connectivity/network-ops/reading-network-state)는
validation이 검사 시점의 public Internet 접속 확인이며 특정 IP 필터링/후속 단절을 모두
배제하지 못한다고 설명한다. [Firebase 공식 문서](https://firebase.google.com/docs/database/android/offline-capabilities)는
`.info/connected`를 해당 클라이언트의 RTDB 연결 관찰로 설명한다. 이를 Cloud Functions
응답이나 실제 현재 heartbeat write 완료의 보장으로 확장하지 않는다.

현재 판단: **네트워크/DNS 경로 지연은 관찰됨; Cloud Functions 규칙/처리 실패 증거는
없음; 지연 후 앱/Firebase client 연결 복구 정체 또는 Firebase 경로만의 지속 장애는
서로 구분되지 않음.** Firebase 전체 서비스 장애나 특정 SDK 버그로 확정할 근거는 없다.
앱 재실행 효과만으로 공유기 원인도 배제하지 않는다.

`tablet-native-network-metadata.json`과 최소 이벤트 기록에 정제 근거를 저장했다. 최초
키워드 분류에서 INTERNET 요청과 관계없는 false, WifiProfileShare의 qosData:false가
오탐이어서 해당 분류를 폐기하고 실제 OS 재검사/validation/probe 기록으로 교체했다.
선택된 앱 프로세스의 명시적 DNS/Socket/TLS native 예외는 없었다. 로그 수준에 따라
native 예외가 기록되지 않을 수 있어 이를 해당 장애의 부재 증거로 쓰지 않는다.

더 확실한 구분은 아래 방식으로 한다(아직 실행하지 않음).

1. 현재 APK를 유지하고 같은 절차를 기존 Wi-Fi와 다른 인터넷 경로에서 각각 새 앱 실행
   조건으로 반복한다. 실패 중 네트워크 전환만으로 회복되는 것은 연결 재생성 효과도
   섞이므로 그것만으로 공유기 원인이라고 판정하지 않는다.
2. 재발 시 같은 시각의 OS validation/DNS, 앱의 RTDB write 확인, callable 전송/응답,
   원래 operation_status를 함께 남긴다. 일반 인터넷도 지연되면 네트워크 쪽 증거이며,
   같은 경로에서 일반 인터넷 정상/실제 앱 요청 정체라면 endpoint/SDK/앱 수명 경로를
   좁힌다. 로컬 8초 timeout만으로 서버 거절이라고 결론 내리지 않는다.

따라서 서버 룰렛 규칙 변경이 아니라 **종료 응답 미확정 처리와 태블릿 연결 복구**를
다음 수정 범위로 제안한다. 네트워크 기저 원인을 확정한 것으로 표현하지 않는다.

## 수정 설계 — 아직 구현하지 않음

### 19:35 / 19:45 두 Wi-Fi 비교 결과

사용자는 같은 APK로 새 네트워크(eduroam)에서 19:35·19:38, 기존 네트워크(HAN_WLAN)에서
앱을 새로 실행한 뒤 19:45 언저리·19:48 게임을 각각 정상 종료했다고 보고했다. 방 코드는
기록하지 않는다. 연결된 태블릿에서 19:35 이후의 새 앱/시스템 로그를 19:52:25 수집했다
(PASS / exit 0). 정제 기록은 ignored `build/device-test/lp-network-compare-20261010-1935/`다.
앱 마지막 설치 시각은 이전과 같은 15:43:24다. 이번 추가 운영 로그 조회는 없다.

| 네트워크 / 회차 | 실제 시작 시각 / 응답 | 종료 시각 / 응답 |
| --- | --- | --- |
| 새 Wi-Fi / 1 | 19:35:26 / 3,095ms | 19:37:48 / 3,280ms, gameEnded |
| 새 Wi-Fi / 2 | 19:38:01 / 720ms | 19:40:28 / 549ms, gameEnded |
| 기존 Wi-Fi / 1 | 19:46:27 / 572ms | 19:48:29 / 424ms, gameEnded |
| 기존 Wi-Fi / 2 | 19:48:50 / 560ms | 19:50:01 / 481ms, gameEnded |

네 번 모두 시작/종료 1회 시도에서 성공했다. 통신 기록 450줄에서 TimeoutException,
시간초과 문구, dev_error, heartbeat_failed는 없다. 19:42:57 Wi-Fi link disconnect,
19:42:58 RTDB false, 19:43:00 link reconnect와 후속 인터넷 validation passed가 있다.
두 테스트 사이의 네트워크 전환과 양립하는 기록이며, 사용자의 정상 게임 종료에 실패가
있었다고 해석하지 않는다. 이때 OS DNS 검사는 238/245ms, HTTP/HTTPS는 167/206ms로 성공했다.

결론: 이번 조건에서는 두 네트워크 모두 정상이며 **기존 Wi-Fi에만 재현되는 문제라는
가설은 지지되지 않는다.** 이는 18:46의 DNS 5초 지연 기록을 무효화하지 않으며, 간헐적
네트워크 지연·Firebase 경로/SDK·앱 복구 문제를 확정 분리하지도 못한다. 같은 정상 반복을
무제한 늘리지 않고 다음 실패 시 OS DNS/validation과 실제 현재 접속 write/callable를
함께 비교한다. 기존 복구 설계 승인은 아직 없고 이번 결과로 구현 완료를 선언하지 않는다.

### 제안하는 구현

1. **종료 결과 확인.** 8초 응답 시간초과를 서버의 확정 거절과 구분한다. 같은 방/게임의
   원래 ID/domain으로 operation_status 확인→applied면 원래 callable의 저장 결과 재생,
   notApplied면 원래 요청 재전송을 기존 총예산 안에서 수행한다. 같은 gameInstanceId의
   서버 수동 종료 상태도 관찰해 화면 복귀를 맞춘다. 자연 우승의 finished만으로 종료
   요청 성공을 판단하거나 로컬에서 서버 종료를 만들지 않는다. 예산 소진 후에도 새 ID를
   만들지 않고 사용자의 재시도에서 원래 요청을 확인한다.
2. **태블릿 접속 건강 확인.** heartbeat write 확인을 기존 요청별 8초로 제한하고 중복
   실행을 막는다. 1회 일시 실패만으로 새 접속을 할당하지 않는다. 2회 연속 확인 실패면
   로컬 복구 확인 cache를 무효화하고 기존 방/UID/참가/접속 범위의 새 제한된 복구 묶음을
   시작한다. `.info/connected=true`만으로 완료하지 않고 실제 현재 접속 heartbeat 확인을
   성공 조건으로 쓴다. 한 묶음 종료 후 무한 자동 반복하지 않고 기존 수동 재시도를 유지한다.
   앱 재실행·로그아웃·방 삭제·강제 전체 퇴장으로 해결하지 않는다.
3. **관찰과 경합 보호.** 개인정보 없는 방 명령 이름·시도·예산·오류 종류, heartbeat
   확인/실패·복구 이유를 기록한다. 종료 정리와 다음 게임 시작은 캡처한 game ID로 보호한다.
   늦은 이전 종료/cleanup/heartbeat Future가 새 게임·접속의 성공을 지우지 못하게 한다.

2번은 `.info` 단절 없이 heartbeat 확인 실패로 복구를 시작하는 조건 추가다. 현재 게임
입력 보호/준비 barrier와 연결되므로 Engineering Contract의 중요한 state-machine 변경
조건에 따라 이 구체적 설계의 사용자 승인을 받은 뒤 구현한다. public callable 이름,
persistent schema, 보안 rules, 인증 방식 변경은 제안하지 않는다.

## 구현 후 필요한 관련 검증

- 서버 적용 뒤 callable 응답만 유실되고 RTDB 수신이 늦어지는 종료 흐름.
- 자연 우승/다른 game ID를 종료 요청 성공으로 오인하지 않음.
- `.info=true`에서 heartbeat 두 번 확인 실패→한 번의 현재 접속 복구, 단일 실패는 유지.
- 늦은 old connection write/종료 응답/cleanup이 새 접속·게임을 되돌리지 않음.
- 앱 재실행 없이 종료→그룹→다음 시작, 이어서 네트워크/세션 변경 실기기.

세션 코드 변경이므로 Windows guarded `test session`과 해당 실제 회귀를 실행한다.
FULL은 사용자 보류를 유지한다. 후보 APK 빌드/설치 및 필요한 Functions 배포는 사용자 담당이다.
설계상 서버 규칙 수정은 필요하지 않으며, 실제 diff가 확정되기 전 배포 대상을 늘리지 않는다.

## 20:22~20:34 태블릿 단절 실기기 후속

2026-10-10 이번 테스트에서 새로 추출한 태블릿 173줄, A 81줄, B 70줄의 정제 기록만
근거로 사용했다. 저장 위치는 ignored `build/device-test/lp-network-20261010-2022/`다.
기존 조회 계정의 승인된 같은 시간대 관련 HTTP metadata 조회는 최대 30건 중 19건,
PASS/exit 0이다. 승인 총 40건 중 19건만 읽었고 heartbeat·private payload는 제외했다.
HTTP 결과는 방/command ID를 조회하지 않은 관련 시간대 후보이며 업무 성공으로 단정하지 않는다.

| KST | 새 기기 기록 | 판정 |
| --- | --- | --- |
| 20:23:11.736~12.150 | A 제출 성공, revision 9/playing | 복구 전 마지막 확인된 제출 |
| 20:23:15.224 | 태블릿 `.info/connected=false` | 실제 태블릿 Firebase 연결 단절 |
| 20:23:41.871~42.293 | B LIAR 성공, revision 10/penalty; A도 42.560 수신 | 태블릿 단절 후에도 서버가 진행 요청을 수락 |
| 20:25:30.115~37.047 | 태블릿 연결 true, 접속 복구·ready 수락; 이미 penalty | 복구 때 새로 생긴 룰렛 UI 오류가 아님 |
| 20:27:53.299~20:28:01.312 | complete_dealing 8,013ms timeout | 요청 결과 미확정 |
| 20:28:01.212 / 04.664 | A / 태블릿 revision 24/playing 수신 | 분배 전이는 진행됐고 태블릿 상태 수신은 A보다 늦음 |
| 20:29:50.827~20:30:17.861 | 태블릿 복구 묶음 timeout, 이후 ready=false, connectionSeq 8 | 후속 복구 완료/준비를 확인하지 못함 |
| 20:31:58.642~20:32:06.657 | end_game 8,015ms timeout | 종료 성공/실패를 이 시점에 단정할 수 없음 |
| 20:32:38.391 | end_game permission-denied/reason=staleConnection | 현재 접속 검증 실패; 일반 IAM 권한 부족으로 해석하지 않음 |
| 20:33:30.245 | 태블릿 revision 29/finished 수신 | 사용자 보고의 참가자 퇴장 후 종료와 양립 |

B LIAR는 제출 후 약 30초여서 `_handleTurnTimeout`의 LIAR 경로와 맞는다. 현재 로그가
자동/수동 호출을 구분하지 않으므로 자동이라고 확정하지 않는다. 공개 phase는
lastCardChallenge가 아닌 playing에서 penalty로 바뀌었다. 따라서 모든 패 소진을
필수 조건으로 삼는 전환이 아니며, 카드의 실제 잔여 수는 이번 정제 기록에 없다.

### 화면·서버 중단의 차이와 테스트 수정

`ControllerReconnectGuard`는 휴대폰에 대기 안내를 덮어 씌운다. 이 표시만으로 하위
타이머나 `GameRecoverySession.canSend`를 중단시키지 않는다. 서버는 실제
`public.recovery.paused`가 설정되어야 진행 명령을 거절한다. 현재 접속 presence를
방 요약에 반영하는 trigger와 controller 요약 단절을 게임 pause로 반영하는 trigger가
분리되어 있다. 이번 자료는 단절 감지부터 pause까지 정확히 어느 구간이 지연됐는지
보여주지 않지만, 단절 뒤 B 명령이 수락됐다는 틈은 확인한다.

휴대폰 interruption UI는 안내만 제공하며 태블릿 중단을 풀기 위한 진행 버튼은 없다.
제외·연장·종료 선택은 태블릿 controller 화면의 기능이다. 기존 제품 결정도 태블릿
자체 단절 때 기다리기/본인 퇴장이다. 따라서 새 버튼을 추가하지 않고 실기기 체크리스트의
존재하지 않는 버튼 테스트를 행동 차단·차례/시간 보존 비교로 수정했다.

### 수정 후보와 아직 필요한 승인

1. **접속 복구 완료의 현재성 보호:** `restoreControllerRoom`은 resume 호출 이후 UID만
   검사하고 identity를 저장한다. 요청의 owner deadline·방/접속 세대가 끝난 뒤 늦게
   도착한 결과도 저장될 수 있다. 외부 8초 timeout은 내부 실행을 취소하지 않으며,
   retry는 새 resume operationId를 만든다. pending 재생 후 최신 접속 채택, 실제 새
   할당이 필요한 경우 구분, 저장·presence 쓰기 전 owner/방/세대 검사로 보완한다.
   서버에서 현재 접속이 더 앞서간 경우 최신 context를 확인한 후 준비를 다시 보고한다.
   여러 resume 실행 자체와 staleConnection이 한 원인이라고 확정하는 것은 아니다.
2. **단절 안내와 자동 행동 보호 일치:** 휴대폰 안내 뒤 타이머 콜백도 진행 요청을
   보내지 않게 연결하고, 서버에는 현재 controller 단절/heartbeat 노후를 검증해 pause와
   남은 시간을 원자적으로 보존하는 경로를 설계한다. 로컬 표시만으로 서버 권위를
   대체하지 않는다. 정확한 pause 시작 기준과 감지 유예는 승인할 제품/상태 전이 결정이다.
3. **미확정 완료/종료 결과:** 기존 ID의 결과 확인을 우선하고 timeout을 미적용으로
   처리하지 않는다. 준비 실패와 transport 회복을 구분하고 늦은 성공으로 새 실패나
   새 게임을 지우지 않는다. 자동/수동 타임아웃 구분과 복구 현재성의 안전한 로그를 추가한다.

Wi-Fi를 끈 것이 첫 단절의 원인인 것은 사용자 테스트 조건이다. 이후 timeout과 접속 검증
실패가 공유기·Firebase SDK·앱 중 어느 하나만의 문제라는 근거는 없다. 관련 서버 HTTP
후보는 complete_dealing 약 0.49초/200, end_game 약 0.11초/403이다. Firebase 전반의
장애를 확정하거나 서버 처리 속도만으로 일반 인터넷 문제를 배제하지 않는다.

이번 변경은 체크리스트·분석 문서뿐이다. 새 서버 중단 조건은 Engineering Contract의
중요한 state-machine 승인 경계에 해당한다. 제품 코드 수정/테스트/FULL/빌드/배포는
실행하지 않았고 FULL 보류 및 사용자 APK·배포 담당을 유지한다.

## 20:22 오류 해결 구현 결과 — 실기기 검증 대기

사용자 승인 뒤 아래 설계를 구현했다. 새 persistent 필드·Auth/IAM·보안 규칙·룰렛/승패
규칙은 바꾸지 않았다. 기존 명령 결과 ledger와 복구 barrier는 유지하고, 관찰된 단절 틈과
늦은 controller 복구 저장 및 분배 응답 유실에 필요한 경로만 보완했다.

### 1. 현재 접속 확정과 늦은 복구 결과 보호

수정 위치: `RoomService.restoreControllerRoom`, `RoomProvider.retryConnectionRecovery`,
`RoomSessionIdentityStore`의 조건부 저장, `GameRecoverySession`의 준비 무효화.

- 방/UID/역할별 복구 owner를 하나만 둔다. 화면 재진입·네트워크 가드·수동 재시도가
  같은 진행 중 owner를 공유한다. 기존 30초 묶음/요청당 8초 한도를 유지한다.
- owner 시작에 방 instance, 세션 epoch, 접속 epoch, 기존 identity와 pending operation을
  캡처한다. await 이후 및 저장/정리/presence 쓰기 직전에 현재성·남은 예산을 검사한다.
  동일 복구 owner가 채택한 새 접속은 owner의 기준으로 갱신해 자기 성공을 stale로 보지 않는다.
- pending resume 결과를 재생한 뒤 최신 접속을 조회한다. 같은 논리 요청의 재시도는
  operationId를 유지한다. 성공한 pending 요청 뒤 무조건 새 resume를 만들지 않는다.
  조회한 현재 접속이 유효하고 연결돼 있으면 채택하며, 실제 단절 접속이면 확인한
  connectionSeq로 새 CAS resume를 수행한다. 무조건적인 fetch만으로 복구를 대체하지 않는다.
- timeout은 내부 Future를 취소하지 않는다. 늦은 결과는 완료 로그만 남기고 현재 identity,
  pending, 준비 상태, heartbeat를 변경하지 못한다. pending은 결과를 확인할 때까지 보존한다.
- staleConnection 수신 시 참가 자격을 바로 지우지 않는다. 기존 room/controller 세션으로
  현재 접속을 조회하고 연결/준비를 다시 확인한다. 실제 방 종료·참가 자격 상실과 구분한다.
- 접속 채택 후 heartbeat ack, 현재 public/private 대응, 화면 준비, 서버 ready 수락까지
  끝나야 입력을 허용한다. `.info=true`만으로 복구 성공을 선언하지 않는다.

### 2. heartbeat 확인 실패로 정체 복구

수정 위치: `RoomProvider._heartbeatControllerSafely`, controller heartbeat의 bounded write.

- 주기 10초는 유지한다. heartbeat 요청은 8초 안에 결과를 확인하고 동시에 하나만 기다린다.
  timeout 뒤 native write가 늦게 끝날 수 있으므로 이전 접속 쓰기는 현재 접속을 변경할 수 없게 보호한다.
- 한 번의 확인 실패는 다음 주기에 다시 확인한다. 두 번 연속 실패 또는 명시적인
  staleConnection은 기존 복구 확인 cache를 무효화하고 입력을 보호한다.
- 같은 장애 동안 자동 복구 묶음은 한 번만 실행한다. 30초를 소진하면 보호를 유지하고
  기존 수동 재시도를 제공한다. 늦은 데이터나 매 heartbeat 주기로 예산을 다시 만들지 않는다.
  확인된 heartbeat 성공·새 실제 재연결은 장애 회차를 구분한다.
- 일반 RTDB 쓰기 전체의 timeout 정책을 바꾸지 않고 controller heartbeat와 복구 경로를 한정한다.

### 3. 연결 대기 화면·자동 행동·서버 중단 일치

수정 위치: 플랫폼 `ControllerReconnectGuard`/room provider, 공용 recovery session의
입력 보호, LP 휴대폰 timeout 콜백, 공용 서버 command transaction/presence 처리.

- 휴대폰의 controller 재연결 판정을 공용 recovery session에 전달한다. 안내가 보이는
  동안 터치뿐 아니라 타이머의 자동 LIAR/FOLD/제출도 보호한다. 게임 패키지가 플랫폼
  provider를 직접 참조하지 않게 공용 session을 통해 연결한다.
- 서버 판정은 현재 controller connection 노드가 `connected=false`이거나 마지막 ack가
  **20초 초과**로 오래됐을 때 단절 의심을 확정한다. 휴대폰 기기 시각은 권위로 사용하지 않는다.
  이는 기존 표시/참가자 stale 보고 기준을 재사용하는 제안이며 임의로 배포하지 않는다.
- `syncRealtimeRoomConnection`이 현재 controller 단절을 반영할 때 같은 transaction에서
  기존 recovery cause와 pause를 등록해 두 trigger 사이의 틈을 줄인다. 기존 controller
  presence trigger는 중복 안전한 보조 경로로 유지한다. 옛 connection 이벤트는 무시한다.
- heartbeat가 노후했지만 presence trigger가 아직 실행되지 않은 경우를 위해
  `game_common_interruption_report_stale_controller` callable을 추가했다.
  현재 참가자/접속과 방/game instance를 인증하고, 관찰한 controller connectionId/Seq/lastSeen을
  최신 서버 값과 대조한다. 새 heartbeat/새 접속이면 무해하게 무시하며 휴대폰에 제외·종료 권한을
  부여하지 않는다. 같은 관찰값은 한 번만 보고하고 무제한 반복 호출하지 않는다.
- 공용 진행 command transaction도 현재 controller 접속의 신선함을 검사한다. 이미
  적용된 command의 결과 재생은 기존대로 우선한다. 새 진행 요청에서 단절을 발견하면
  pause 저장과 요청 미적용을 함께 처리한다. transaction 안에서 예외를 던져 pause 쓰기를
  취소하지 않도록, pause를 commit한 뒤 기존 `paused` 오류를 반환한다.
  종료·본인 퇴장 등 기존 pause 중 허용 명령은 그대로 현재 자격을 검증해 처리한다.
- 최초 서버 pause 시점의 남은 시간만 기존 recovery timer에 보존한다. 추가 단절·보고는
  덮어쓰지 않는다. 전원 현재 접속의 ready가 확인된 뒤 서버가 새 deadline을 계산한다.
  화면만 풀렸다는 이유로 타이머를 다시 시작하거나 로컬 저장 시간으로 서버를 덮어쓰지 않는다.
- 실제 Wi-Fi 단절부터 서버 확인까지 감지 지연이 존재한다. 그 전에 이미 수락된 LIAR나
  룰렛은 소급 취소하지 않는다. 20초 지연 자체를 줄이는 제품 결정은 별도이며 이번 안에서
  단절 순간의 시간을 완벽히 보존한다고 약속하지 않는다.

### 4. 카드 배분·종료의 요청 결과 미확정 처리

수정 위치: `GameCommandService`의 기존 미확정 ID/결과 조회 경로, LP controller/태블릿 board.

- timeout 시 원래 commandId·게임 instance·입력을 유지하고 실패가 확정됐다고 표시하지 않는다.
  접속 복구가 필요하면 먼저 같은 owner 예산 안에서 확인한다.
- 기존 operation_status의 applied는 원래 callable 재생으로 응답을 회수한다. notApplied는
  현재 접속 envelope로 같은 논리 요청을 재전송한다. stale는 이전 요청을 정리하고 현재
  게임으로 재전송하지 않는다. 모든 단계는 남은 예산을 공유하며 소진 시 명시 재시도를 기다린다.
- complete_dealing은 같은 game instance의 분배 단계 종료가 서버 데이터로 확인되면 연출을
  다시 시작하지 않는다. 전체 준비 실패는 별도로 유지한다. 자연 승리의 finished는 수동
  end_game 적용 증거로 쓰지 않으며 종료 응답/저장 결과로 확인한다.
- 결과 조회·cleanup·라우트 이동은 캡처한 게임을 대상으로 한다. 늦은 종료 응답이 새 게임을
  닫거나 새 요청의 오류/버튼 상태를 지우지 않게 한다.
- 기존 안내를 재사용한다. 휴대폰 게임 진행 버튼, 새 방 자동 생성, 앱 강제 재시작은 추가하지 않는다.

### 구현 순서·검증·배포 영향

1. 복구 현재성/CAS/pending 보호와 heartbeat ack를 먼저 수정하고 해당 client 회귀를 실행한다.
2. 공용 controller 가용성 보호와 서버 pause 경로를 함께 수정한다. 서버만 또는 화면만
   수정한 상태를 최종 후보로 전달하지 않는다.
3. LP 분배/종료 결과 확인을 연결하고 관련 회귀를 실행한 뒤 같은 실기기 단절 시나리오를 반복한다.

구현 회귀: timeout 뒤 늦은 resume/새 방 보호, `.info=true` heartbeat 2회 실패의
단일 복구, 중단 안내 뒤 자동 LIAR/FOLD/제출 금지, 서버 stale controller 검사/pause commit,
옛 presence·새 heartbeat와 stale 보고의 경합, 최초 남은 시간 보존/중복 보고/전원 ready 후 재개,
분배 적용 후 응답 유실, 종료 applied/notApplied/stale, 새 게임을 늦은 응답에서 보호.
공용 transaction 변경은 LP뿐 아니라 소비하는 다른 게임의 pause·종료·퇴장 회귀도 확인한다.
Windows guarded `test session`과 관련 Functions 테스트/build/lint를 사용한다. FULL은 보류한다.

클라이언트 수정에는 새 APK가 필요하다. 최종 서버 배포 대상은
`game_common_interruption_report_stale_controller`, `game_common_interruption_report_stale_player`,
`syncRealtimeRoomConnection`, `game_common_interruption_on_connection_changed`,
`game_common_controller_presence_changed` 다섯 개다. 현재 접속 단절과 pause를 같은 transaction에
반영하고 모든 감지 경로가 마지막 성공 heartbeat 기준 타이머를 사용한다. APK 빌드·설치와
배포는 사용자 담당이다.

새 callable과 heartbeat 노후에 의한 서버 pause 조건은 사용자 승인을 받아 구현했다.
Functions build/lint, 관련 서버 34건, guarded session의 Flutter 160건·Functions 97건이
통과했다. FULL은 사용자 지시로 보류했으며 APK·배포·실기기 확인은 수행하지 않았다.

2026-10-11 보완 뒤 최종 targeted 결과는 guarded session Flutter 161·Functions 99,
Functions 전체 396, 관련 UI·stale tracker 10, analyze/lint PASS다. 정상 경로에는 새 대기를
추가하지 않았고 stale 보조 보고만 요청당 8초·같은 관측 최대 2회로 제한한다.

## 18:41 조사 당시 작업 상태

착수 clean / staged 0, branch `codex/e01-validation-wiring`,
HEAD `3429711afaa7232e806091cfc277526c5530ef09`. 이번에는 새 기기 로그·승인 서버 metadata
조회와 설계/작업 기록만 갱신했다. 제품 코드·테스트 변경, FULL, APK 빌드, deploy, commit/push는 없다.
이전 45개 서버 테스트 통과를 이번 통신 수정 검증으로 재사용하지 않는다.
