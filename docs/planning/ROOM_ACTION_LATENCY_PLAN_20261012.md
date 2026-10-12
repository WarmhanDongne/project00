# 방 생성·그룹 탈퇴·방 초기화 지연 개선 계획

2026-10-12. 사용자 요청에 따른 조사·설계 문서다. 제품 구현·배포·성능 목표 승인을 뜻하지 않는다.
[NET-RECOVERY-01](tasks/NET-RECOVERY-01.md)에서 관리하며 기존 준비·재참여 문제도 계속 남긴다.

## 1. 판단과 범위

현재 정상 경로는 세 작업 모두 변경 callable 한 번이다. 최초 생성 뒤 resume,
최초 탈퇴/초기화 앞의 operation status 제거는 이미 구현되어 있어 재구현하지 않는다.
첫 변경은 **서버의 느린 실행 원인 분리와 앱 단계 계측**이다. 결과에 따라 실행 준비,
DB 읽기/경합 또는 접속 예약 취소 대기를 줄이는 변경을 선택한다.
실측 없이 리전 이동, 모든 함수의 상시 실행, ledger 삭제를 먼저 적용하지 않는다.
10/12 후속 안정성 검토에서 참가자·방 정리의 현재 접속 보호 누락을 재현했다.
정리 후보 배포 전에 두 경합을 보완하고, 성능 측정에서는 정리 실행 여부를 구분한다.
근거와 수정 순서는 [후속 Functions 검토](#7-2026-10-12-functions-안정성-검토와-계획-수정)를 따른다.

- 방 생성: controller가 새 초대 방을 만드는 작업. 복구·같은 생성 ID 재생은 별도 표본이다.
- 사용자 그룹 탈퇴: 휴대폰의 `leaveRealtimeRoom`과 게임 중 각 `*_leave_game`.
  계정 삭제인 `deleteAccount`와 구분한다.
- 방 초기화: 태블릿 `closeRoom`으로 현재 방을 종료하고 빈 로비로 돌아가는 작업.
  참가자를 한 명씩 퇴장시키거나 새 방을 생성하는 작업이 아니다.
- 유지할 경계: 서버 권위, 원래 operation ID/domain, 전송 전 durable 저장,
  방·참가·접속 세대 검증, applied/stale 결과 확인 후 정리, 8초 요청/30초 복구 예산.

조사 시작 기준은 `codex/e01-validation-wiring`, HEAD
`9fb446262f3f0ce34c06c7030d2304dbf52490c4`이다. 시작 시 사용자 문서
`docs/operations/RTDB_RETENTION_REVIEW.md`가 untracked였다. 조사 중 다른 작업의
정리 함수·계정 삭제·회귀 파일 변경이 추가되었다. 해당 변경은 보존했고 이 계획에서 구현하거나
검증한 것으로 취급하지 않는다. `room-cleanup.ts`의 현재 cursor CAS/종료 요청 축약 후보와
이번 성능 계획이 겹치는 부분은 구현 착수 시 최종 diff로 다시 확인한다.

## 2. 실제 기록에서 확인한 것

### 이번에 승인받아 조회한 서버 로그

사용자가 2026-10-11 15:00~17:00 KST와 조회 진행을 승인하고 사람이 조회 계정의 두 허용
역할을 확인했다. `project0000-ec01e`, `mosigame-logs-readonly`, 서울 함수만 조회했다.
UTC 범위는 `[2026-10-11T06:00:00Z, 2026-10-11T08:00:00Z)`다.
생성·초기화·그룹/네 게임 탈퇴·operation status·controller resume의 HTTP metadata와
고정 `room_action_timing` 수치만 대상으로 삼았다. 요청 URL/본문, 오류 원문, 계정,
사용자/방 식별자, 게임 private payload를 수집·저장하지 않았다.

| KST | 함수 | HTTP | 서버 HTTP 지연 |
| --- | --- | ---: | ---: |
| 15:01:42 | leaveRealtimeRoom | 200 | 2,817.688ms |
| 15:03:49 | leaveRealtimeRoom | 200 | 184.248ms |
| 15:04:15 | leaveRealtimeRoom | 200 | 170.012ms |
| 15:11:24 | leaveRealtimeRoom | 200 | 180.302ms |
| 15:44:34 | leaveRealtimeRoom | 200 | 2,894.017ms |
| 16:58:02 | leaveRealtimeRoom | 200 | 3,265.019ms |

모두 `leaverealtimeroom-00020-sic` revision이다. 짧은 3건은 170~184ms, 긴 3건은
2.82~3.27초다. 이는 HTTP 응답 구간이며 버튼→홈 복귀 시간이나 신규 탈퇴의 실제 적용 여부를
보장하지 않는다. 동일 작업의 재생 여부·방 상태·인원도 metadata만으로 구분하지 못한다.
6건으로 평균적인 서비스 성능·p95를 확정하지 않는다.

controller resume은 HTTP 200 두 건 441.462/3,273.828ms와 HTTP 403 한 건 149.014ms였다.
오류·복구 대기는 정상 작업 성능과 분리한다. 이번 필터의 생성·초기화·operation status·
네 게임 탈퇴 및 `room_action_timing` 표본은 **미발견**이다. 함수 미배포·미실행·정상 동작의
증거로 바꾸지 않는다.

연결 확인 `limit=1`과 본 조회 `limit=99`, 반환은 각각 1/9건이다. 같은 probe가 본 조회에도
포함되어 고유 기록은 9건이다. 두 조회 모두 PASS/exit 0이며 최대 조회 예산을 넘지 않았다.
SDK 실행은 sandbox에서 접근 거부(exit 1)였고 승인된 escalation 경로로 성공했다.
조회만 했으며 운영 데이터 변경·실제 생성/탈퇴/초기화 재시험은 하지 않았다.
정제 결과와 정확한 filter/fields/명령을 재구성하는 script는 ignored
`build/device-test/room-action-plan-20261012/{probe.json,records.json,query_logs.py}`에 있다.

**현재 우선 가설:** 긴 간격 뒤의 실행 준비/인스턴스 초기화 또는 Admin DB 연결 재수립이
긴 탈퇴 응답에 기여할 수 있다. 동일 revision의 짧은 응답은 이 경로가 항상 수초를 요구하지는
않음을 보여준다. 인스턴스 시작·handler·transaction 계측이 없으므로 cold start, DB 경합,
게임 상태 차이 중 하나로 확정할 수 없다.

### 이전 기록의 사용 범위

| 근거 | 확인한 값 | 한계 |
| --- | --- | --- |
| [10/10 로비 실측](../operations/ROOM_ACTION_LATENCY.md) | Simulator 초기화 7,418ms = status 3,706 + close 3,598 + 취소 83ms 등 | 최초 status 제거 전. 현재 초기화 기준선으로 쓰지 않음 |
| 같은 기록의 생성 | 3,901/761ms 모두 실패 | 정상 생성·resume/presence까지 완료한 값이 아님 |
| 기존 정제 서버 `network-9-20-20261011/server-room-close-create-requests.json` | 10/11 02:40 KST create HTTP 200 5건, 1.331~3.869초 | 신규/재생 및 사용자 시험 대응 미확정. UI 시간 아님 |
| `lp-b-identity-20261012/leaveRealtimeRoom-requests.json` | 10/12 02:20 KST leave HTTP 200 1건, 2.276초 | 이번 시간대와 별도 표본, 완료 프레임·상태 미확인 |
| `network-0615-20261011/server-timing.json` | 생성 거절 handler 673/196ms, onboarding 267/36ms, mapping 309/72ms | 실패 앞부분만 측정. 정상 생성의 전체 단계 비용 아님 |
| [06:15~06:20 조사](tasks/NETWORK_SESSION_20261011_IMPLEMENTATION.md) | leave HTTP 500 12건, 약 70~109ms. null-private TypeError | 오류·재시도 원인. 정상 탈퇴 성능 근거로 합치지 않음 |

위 JSON은 `build/device-test/` 아래 기존 정제 기록이다. 10/10 create 단독 배포와 10/11
실제 14개 배포의 명단은 서로 다르다. 특히 같은 상세 문서의 **leave 포함 수정 후보14개**와
**실제 배포14개**를 혼동하면 안 된다. 최신 앱·함수 소스 일치는 아직 확인하지 않았다.
[Cloud Functions 배포 기록](../engineering/CLOUD_FUNCTIONS.md)과 해당 상세의 배포 명단을
각 함수별로 대조한 뒤 기준선을 만든다.

## 3. 현재 코드의 임계 경로

| 작업 | 앱의 정상 순서 | 서버의 정상 순서 |
| --- | --- | --- |
| 생성 | intent 저장 → create → identity 저장 → presence write → confirmed → 구독/화면 | onboarding → 이전 매핑 → slot → 후보 → 예약 → allocation → 예약 확정 → live room → 매핑 확인/CAS → final room → slot 확정 |
| 탈퇴 | 원래 identity/intent → awaitingResult 저장 → onDisconnect cancel → leave → confirmed/로컬 정리 → 홈 | 방 루트 primed transaction 한 번. 게임 중이면 제외 reducer/게임 context도 같은 원자 변경 |
| 초기화 | identity → onDisconnect cancel → awaitingResult 저장 → close → confirmed/로컬 정리 → 빈 로비 | 방 get → 같은 방 primed transaction 한 번. 이후 physical cleanup을 기다리지 않음 |

새 생성은 응답의 초기 `connectionSeq=1`을 사용한다. 결과 유실·presence 실패·실제 복구는
resume을 유지한다. 미확정 탈퇴/초기화는 status→필요 시 같은 ID의 원래 명령을 사용한다.

생성의 기존 매핑 없는 정상 경우는 Firestore get 2개 병행, RTDB 명시적 get 5개,
primed transaction 6개다. 이전 방이나 다른 매핑이 있으면 get이 추가된다.
`runPrimedTransaction`은 value listener로 서버 snapshot을 받은 뒤 transaction한다.
이 숫자는 코드 호출 수다. SDK 캐시·연결·재실행 때문에 정확한 네트워크 RTT 수와 같지 않다.

근거 코드:

- [앱 서비스](../../lib/platform/home/room/services/room_service.dart): 생성 L140,
  초기화 L305, 탈퇴 L1059, controller/player 예약 등록 L278/L791.
- [앱 provider](../../lib/platform/home/room/providers/room_provider.dart): 생성 L232,
  초기화 L275, 그룹/게임 탈퇴 L1843/L1858, 공통 탈퇴 L1880.
- [생성 서버](../../functions/src/room/create-room.ts) L26,
  [온보딩](../../functions/src/auth/require-complete-onboarding.ts) L17,
  [초기화 서버](../../functions/src/room/realtime-room-lifecycle.ts) L316,
  [공용 탈퇴 서버](../../functions/src/game-interruption/leave-request.ts) L12.
- [transaction priming](../../functions/src/room/room-transaction.ts) L14,
  [실제 callback 재실행 회귀](../../functions/test/room-transaction-rerun.test.mjs),
  [cold SDK cache 회귀](../../functions/test/room-allocation-sdk-cache.test.mjs).

별도 구간도 구분한다. 그룹 게임 목록은 화면 갱신 뒤 비동기 refresh이므로 직접 await 병목이
아니다. QR 연출 760ms는 생성 응답 뒤 표시 시간이며 처음 약 440ms 동안 QR이 보이지 않는다.
게임 중 퇴장 route wipe는 960ms, 로비 탈퇴는 일반 route pop이다. 연출 시간을 서버 처리에
합산하거나 병행하는 코드/QR 시간을 서로 합산하지 않는다.

## 4. 실행 순서와 설계

### A. 계측·버전 확인 — 첫 변경

앱 commit/build/APK hash와 함수 revision/source 대응을 먼저 남긴다. 신규 정상 작업,
미확정 재시도, 저장 세션 복구를 분리하고 실패 종류·호출 수를 함께 기록한다.

1. 앱 `RoomTimedAction`에 leave를 추가한다. identity cache hit/miss, durable intent,
   disconnect cancel, callable, confirmed, identity/저장 세션 정리, 첫 완료 프레임을 분리한다.
   기존 create/close에도 완료 후 로컬 정리·첫 프레임 측정을 보완한다.
2. 서버 공용 leave에 단계 계측을 추가해 로비/게임별 callable을 고정 action으로 구분한다.
   room priming 대기, transaction 전체, callback 실행 시간·횟수, reducer 시간을 기록한다.
   create/close/status에도 같은 transaction 계측을 붙인다.
3. 방 크기·connection/ledger 수는 요청이 이미 읽은 snapshot에서 수치/크기 구간만 산출한다.
   추가 DB 조회·payload 저장 없이 제한된 sampling으로 계측 비용을 억제한다.
4. HTTP 지연, handler 시간, DB 대기, 인스턴스 시작 metadata를 비교한다. 사용자와 합의한
   시간·함수·최대 건수 안에서만 조회한다. 현재 로그 marker가 없다는 이유로 범위를 확대하지 않는다.

`client − handler`에는 네트워크·SDK 인증·runtime 준비 등 여러 구간이 있어 cold start
수치라고 부르지 않는다. 병행한 stage 시간 합은 전체 wall time과 다를 수 있다.
서버 trace의 success는 예외 없이 반환했다는 뜻이므로 created/terminal/applied/stale의
고정 outcome도 구분한다. public 응답에 진단 ID를 추가하지 않고 직렬 수동 시험의 시간·함수로
대조하며, 확실히 연결 못 한 표본은 상관 미확정으로 남긴다.

### B. 앱 취소 대기를 임계 경로에서 분리 — 취소 지연이 확인될 때

현재 cancel은 raw Future이고 명령 앞에서 await한다. 과거 표본에서는 83ms에 불과했으므로
항상 수초의 원인이라고 단정하지 않는다. 계측에서 지연·미완료 cancel이 실제 명령을 막는 경우
이 변경을 먼저 선택한다. **단순 unawaited 전환은 하지 않는다.** 등록도 이미 비동기라 늦은 등록이
취소 뒤 예약을 다시 만들 수 있다.

목표 순서: 정확한 target 캡처 → leaving/heartbeat 중지 → durable awaitingResult 저장 성공
→ 접속별 예약 coordinator에 정리 위임 → 첫 callable 즉시 전송 → 결과 확정 후 같은 target만 정리.

- coordinator는 UID/role/room instance/membership/connection ID·seq별 old reference를 소유한다.
  등록 완료 뒤 leaving이면 그 reference의 예약을 다시 취소한다. 신규 접속에 옛 취소를 붙이지 않는다.
- close의 durable 저장을 cancel보다 먼저 옮겨 취소 중 앱 종료 때 종료 의도가 사라지는 구간을 없앤다.
- cancel 실패가 서버 결과를 바꾸지 않게 한다. 실제 단절은 서버의 현재 접속 검증으로 처리하고
  미확정 동안 leaving·입력 보호·퇴장 의도를 유지한다.
- 모든 await 뒤와 전송/confirmed/clear 직전에 attempt 세대·active·UID·target을 확인한다.
  `Future.timeout`은 원래 Future를 취소하지 않으므로 만료된 continuation이 새 요청을 시작하거나
  새로운 참가 신원을 지우지 못하게 한다. 이미 전송한 요청의 늦은 결과는 원래 ID 조회로 해결한다.
- 로컬 정리는 room instance만 같다는 이유로 새 membership/connection을 삭제하지 않도록
  관찰한 identity와 CAS한다. 미확정 intent에는 TTL을 도입하지 않는다.

기존 서버 `applyRoomPresence`와 rules의 방/현재 접속/membership 검증이 안전성 근거다.
저장 실패 시 무전송, 응답 유실 후 원래 ID 유지가 회귀에서 증명되어야 다음 단계로 진행한다.

### C. 서버 읽기 축소 — 초기화·생성

**초기화:** 사전 `room.get`과 primed transaction listener를 통합한다. 첫 서버 snapshot으로
부재·controller·instance를 검사하고 같은 listener를 transaction 종료까지 유지한다.
callback의 현재 자격·instance·ledger 재검증과 finally listener 해제는 유지한다.
기대 효과는 중복 get 단계의 대기 제거이며 실제 SDK 캐시에서 한 RTT 절감과 같다고 보장하지 않는다.

함께 방어할 사항: 현재 close는 transaction 결과를 버려 raw-null abort 뒤에도 `success:true`를
반환할 수 있다. 코드 가능성은 확인했지만 운영 발생은 확인하지 않았다. committed 또는 동일
UID/kind/domain의 저장 결과를 확인하기 전에는 성공으로 정리하지 않는 회귀를 추가한다.
방 부재를 새로운 applied 의미로 바꾸는 설계는 이 최적화에 넣지 않는다.

**생성:** onboarding과 previous_mapping의 독립 읽기를 병행한다. mapping은 speculative
read만 시작하며 모든 생성 write는 onboarding/legacy backfill 성공 뒤에 둔다. 결과를 settle해
기존 오류 우선순위(onboarding → operationId parse → mapping)를 유지한다. 두 대기가 F/M이면
`F+M → max(F,M)` 후보이며 실제 절감 상한은 짧은 대기 쪽이다.

6개 transaction은 소유권·예약·allocation·receipt·mapping·최종 slot 의존성이 있어 초기
단계에서는 삭제/병행하지 않는다. live_room/mapping_read의 추가 병행과 완료 요청 재생의
불필요한 후보 조회는 계측 후 별도 변경으로 검토한다. 종료 직후 재생성 CAS 보호는 유지한다.

### D. 느린 실행·경합의 증거에 따른 후속 실험

| 관찰 결과 | 선택할 후속 변경 | 판단 조건 |
| --- | --- | --- |
| 짧은 handler인데 일부 HTTP가 수초이고 인스턴스 기동과 대응 | 우선 leave 핵심 함수의 `minInstances=1` 제한 실험·초기화/import 비용 축소 | 실제 설정 확인, 비용 상한·원복 방법 승인, 같은 조건의 지연 비교. 생성/close는 각각 측정 뒤 선택 |
| priming/transaction이 대부분이고 callback 재실행이 많음 | cleanup 불필요 enqueue와 같은 root 쓰기 감소 | deadline/instance/generation이 안 바뀐 event만 생략. 현재 allocation 재조회·역전 이벤트 보호·주기 보완 순회 유지 |
| callback CPU나 방 크기가 지배 | clone/fingerprint의 반복 계산 축소, 확정된 이력의 안전한 축약 검토 | 결과 replay·private/context 원자성 유지. GC/상태 계약 변경은 별도 승인 |
| onboarding 또는 지역 간 DB 대기가 지배 | 독립 읽기 병행 이후 서울/싱가포르 함수 배치 A/B | 사용자→함수와 함수→RTDB/Firestore의 전체 시간·비용·기존 앱 endpoint 호환 비교 |
| local 저장이 유의미 | begin+awaitingResult를 동일 JSON shape의 저장 한 번으로 합침 | 최초 전송 판정 스냅샷, 저장 실패 무전송, 원래 ID/재시도 유지 |
| 서버/로컬 완료 뒤 화면 대기만 큼 | QR의 즉시 노출·게임 퇴장 연출 단축 | 제품 연출 판단 후 별도 적용. 서버 속도 개선과 구분 |

현재 root cleanup trigger는 방 하위 변경마다 전체 room 재조회와 queue transaction을 한다.
presence trigger도 같은 room root transaction을 하므로 부하·경합 후보지만 원 callable의 직접
await는 아니다. cleanup 주기/종료 보존 기간을 줄이는 것만으로 버튼 완료가 빨라진다는 근거는 없다.

Firebase 공식 문서는 minInstances의 유휴 비용과 기준을 넘는 scale-out의 cold start 가능성을
설명한다. 전체 함수를 warm하게 하거나 ping/warmup을 버튼 선행 조건으로 추가하지 않는다.
[Functions 인스턴스 설정](https://firebase.google.com/docs/functions/manage-functions#keep_a_minimum_number_of_instances_warm).
함수·DB 위치가 다르면 지연/비용이 증가할 수 있지만 callable만 이동하면 사용자 RTT가 바뀐다.
[Functions 위치](https://firebase.google.com/docs/functions/locations).
현재 RTDB는 싱가포르 endpoint이며 생성 후 위치 변경이 불가능하다. DB 이전은 새 인스턴스와
migration이 필요한 후순위 결정이다. [RTDB 위치](https://firebase.google.com/docs/database/locations).

## 5. 측정과 합격 기준

시간을 `입력 확인 → 서버 결과 확인 → 로컬 정리 → 첫 완료 프레임 → 다음 입력 가능`으로 나눈다.
다른 기기의 명단/종료 표시 지연도 별도 측정한다. optimistic 성공 처리로 버튼만 빨라지게 하지 않는다.

첫 비교는 기기/빌드/Wi-Fi/배포 revision을 고정한 최대 5회 수동 pilot다. 생성·초기화는 빈 방과
2/6/최대12명, 탈퇴는 로비와 게임 중·동일 계정 controller/player를 대표 조건으로 나눈다.
연속 실행, 긴 유휴 뒤 실행, 실제 인스턴스 기동이 확인된 실행을 따로 기록한다. 유휴 표본을
자동으로 cold 표본이라 부르지 않는다. 정상/거절/응답 유실·복구 표본도 섞지 않는다.

제안 목표는 안정된 네트워크의 반복 정상 작업에서 create p50 1.5초 이하,
leave/close p50 1초 이하, 로컬 완료 후 주요 상태/홈 첫 프레임 추가 대기 200ms 이하이다.
QR/route 연출의 완료 시간은 별도 지표로 유지한다. 이는 기존 합의나
달성한 값이 아니라 구현 우선순위를 위한 제안이며 baseline 후 제품 목표로 확정한다.
유휴 뒤 2.8~3.3초 탈퇴군의 빈도·최대값도 줄여야 한다. 반복값만 개선해 합격시키지 않는다.
5회로 p95를 판정하지 않는다. pilot 후 별도 승인된 충분한 표본(동일 주요 조건에서 최소100건을
출발점으로 반복·변동성 확인)으로 p95·실패율을 평가하며 비용과 시험 범위를 함께 정한다.
응답 유실/오프라인은 기존 제한 예산과 같은 ID의 결과 확인이 합격 기준이다.

필수 정확성 회귀:

- 최초 create의 resume 0회, 최초 leave/close의 status 0회. 미확정 시 원래 ID와 domain 유지.
- cancel 실패/미완료와 늦은 등록 완료, 앱 종료, timeout 이후 continuation, UID 변경,
  같은 코드 새 방·같은 방 새 membership·connection에서도 새 신원/방 보호.
- cold Admin SDK cache, callback 재실행·예외, listener 해제, close committed=false 거짓 성공 방지.
- create→close→create, 동시 생성 단일 승자, 옛 close/cleanup/예약 재생이 새 generation에 무효.
- 네 게임 중 자기 퇴장의 인원/턴/종료 reducer, public/private/context/ledger 원자성.
- 일반 부재 조회를 정확한 퇴장 완료로 바꾸지 않음, 저장 실패 무전송, applied/stale/notApplied 처리.
- 고정 stage/오류 코드만 기록하고 늦은 Future가 다음 sample을 오염시키지 않음.

기존 `room_action_fast_path`, `room_action_timing`, `room_leave_state`, `room_leave_intent`,
`tablet_room_reset`, game_kit retry/identity 회귀와 서버 allocation/session/presence/rerun 회귀를
확장한다. 합성 지연·emulator 부하 시간은 로직/경합 검증이며 운영 성능 실측으로 쓰지 않는다.
구현 착수 후 Mosigame Implement and Validate skill을 적용한다. Windows에서는 관련
session suite와 최종 FULL을 아래 guarded 경로로 실행하고 실제 status/exit·working tree를 남긴다.

```powershell
.\tool\invoke_mosigame.ps1 test session
.\tool\invoke_mosigame.ps1 validate --full
```

## 6. 변경 단위와 승인 경계

구현은 A 계측을 먼저 수행한다. 현재 leave의 긴 표본은 서버 HTTP 구간에 있으므로
실행 준비/DB 연결 재수립이 확인되면 D의 핵심 함수 제한 실험을 먼저 선택한다. DB 대기가
크면 C1 close 단일 읽기/C2 create 읽기 병행, 앱 cancel이 명령을 막으면 B를 선택한다.
각 변경을 작게 나누고 회귀와 같은 조건 측정 후 유지 여부를 판단한다. B의 durable 저장 순서와
늦은 continuation 방어는 성능 효과와 별도로 정확성 근거를 검증한다.
함수 설정·배포는 필요한 함수만 승인된 범위로 수행하고 앱 설치와 서버 revision을
기록한다. 기존 서버·앱 후보의 배포와 현재 문제 수정 완료를 혼동하지 않는다.

새 dependency/public API/persistent data/state-machine/architecture, minInstances 비용,
리전·운영 접근·배포·migration·제품 연출 변경은 Engineering Contract의 승인 경계를 따른다.
ledger TTL, 미확정 예약의 나이만으로 취소, terminal 기록 무조건 삭제, presence/게임 원자성
분리는 별도 계약 설계가 필요하다. 진행 중인 retention 작업에 성능 개선 명목으로 합치지 않는다.

이번 작업은 코드·테스트·canonical 문서·배포 기록·기존 정제 기록과 승인된 로그 조회를 조사했다.
제품 소스 변경·테스트/`validate --full`·배포·실기기 재시험은 하지 않았다. 따라서 계획 작성과
로그 조회 결과를 제품 구현 검증 PASS 또는 1초대 달성으로 표현하지 않는다.

문서 검사는 `git diff --check -- docs/planning/TASKS.md docs/planning/logs/2026-10.md
docs/planning/tasks/NET-RECOVERY-01.md` PASS/exit0, 새 계획의 로컬 Markdown 링크·trailing
whitespace 검사 PASS/exit0다. 시작·종료 branch/HEAD는 같고 staged 변경은 없었다.
기존 사용자 문서 및 조사 중 추가된 Functions 변경을 되돌리지 않았다.

## 7. 2026-10-12 Functions 안정성 검토와 계획 수정

사용자가 인계 당시 `LP 네트워크 복구 실기기 검증` 채팅의 변경을 재검토하도록 요청했다.
인계 기록의 thread ID `01a12676-5497-7912-8af4-718069c6ae41`을 대조했다. 검토 시 현재
제목은 `5개 함수 배포했던 것 같은데 확인하는 방법 알려줘.`다. 해당 채팅의 요청·결과,
현재 diff·관련 소비자·테스트·기존 정제 운영 관찰·FULL evidence를 확인했다.
기준 branch/HEAD는 위와 같고 staged 변경은 없다. 이번에는 새 운영 조회·배포를 하지 않았다.

### 검토 판정

현재 정리 후보 전체를 안전하다고 판정할 수는 없다. **참가자 제거와 방 전체 종료의 현재
접속 경합을 보완한 뒤 배포하는 것이 필요하다.** 이 경합들은 이전 정책에도 있었다. 참가자 페이지 순회로
기존에 누락되던 방까지 제거 대상이 확대된다. 최신 room을 읽는 것만으로 보호가 완성되지 않는다.

| 변경 | 확인한 보호와 한계 | 성능 계획 영향 |
| --- | --- | --- |
| 유령 참가자 cursor·10개씩 병행 처리 | 페이지·cursor CAS·부분 실패 재방문·게임 시작 재판정은 검증됨. 현재 connection leaf 보호는 누락 | 배포 전 정확성 보완. 실행당 10개 제한과 겹친 schedule 전체 동시량을 구분하여 측정 |
| 방 만료 정리 | instance·generation 재판정은 있으나 기존 controller 요약 기한만 사용. 현재 connection의 최근 heartbeat 보호 누락 | 기다림/진행 중 방의 만료 재판정을 보완. 명시 close/finished 기한과 구분 |
| 계정 삭제의 소유 방 정리 | 객체/문자열 mapping, 소유자·instance·generation 조건부 종료, 새 mapping/slot 보존, 실패 후 재시도 위치 보존 | `deleteAccount` 경로 개선이며 휴대폰 그룹 탈퇴의 직접 단축이 아님 |
| terminal 생성 요청 축약 | terminal 조기 반환 소비자와 호환. 종료 marker·generation 유지, reserved 필드 직접 축약·UID 전체 삭제 없음 | 정상 신규 create의 5개 명시 RTDB get/6개 primed transaction은 그대로. 종료 요청 축약을 버튼 지연 절감으로 계산하지 않음 |
| 공용 종료 정합성 처리 | 같은 target의 receipt→slot→mapping 순서와 pending 보존, 새 generation 보호 | `reconcileTerminal`의 추가 room.get은 보상/정리/계정 삭제 경로에 존재. 정상 create와 실패·재생 표본을 분리 |
| queue backoff·집계 로그 | 같은 allocation의 실패 backoff 보존, 새 allocation에서 초기화. UID·방·private payload 없는 집계 | handler timing과 별도로 cleanup 시간·제거량·실패·due 지연을 관찰할 근거 추가 |

계정 삭제와 요청 축약 자체의 검토 범위에서 새로 재현한 차단 결함은 없다. 이는 모든 운영 경합·
실기기 동작의 안전성 보장이 아니다. 고아 예약 해제와 connection/작업 결과 TTL 보류는 유지한다.

### P1: 요약 갱신 전 재접속을 유령으로 제거

`cleanupGhostRoomPlayers` transaction은 `findGhostPlayers`에 `room.status`,
`game.public.status`, `players`만 전달한다. 같은 snapshot의 `connections`는 확인하지 않는다.
클라이언트는 현재 connection leaf의 `connected`/`lastSeen`을 먼저 쓰며,
`syncRealtimeRoomConnection`이 나중에 `applyRoomPresence`로 player 요약을 갱신한다.
이 사이 정리가 실행되면 유효한 현재 connection이 연결돼 있어도 옛 `isConnected=false`와
5분 초과 `lastSeen` 때문에 membership을 제거한다. 이후 요약 trigger는 이미 없는 player를
복구하지 않는다. 정상 사용자의 방 자격이 사라질 수 있다. 운영 발생은 확인하지 않았다.

기존 retention의 `reconnect` 테스트는 요약을 직접 true/현재 시각으로 바꾸므로 이 구간을
검증하지 않는다. ignored 로컬 probe에서 현재 방·membership·connectionId·sequence가 모두
일치하는 leaf만 true/현재 시각으로 갱신했다. 첫 callback 전 쓰기와 callback 재실행 전 쓰기
두 경우 모두 leaf는 정상인데 player가 삭제되고 membershipRevision이 증가했다.

보완 설계는 삭제 transaction 안에서 해당 player의 **현재** connection을 확인하는 것이다.
roomInstanceId·membershipId·currentConnectionId·connectionSeq가 일치하는 leaf가 연결 중이거나
유예 내 heartbeat를 갖고 있으면 제거하지 않는다. 옛 connection이나 같은 UID의 controller
connection으로 phone을 보호하지 않는다. 기존 요약 기준과 5분 유예·playing 보호는 유지하며,
미확정/누락 값의 취급은 기존 호환 계약에 맞춰 회귀로 명시한다. 별도 get을 추가하지 않고
이미 읽는 root snapshot을 사용하므로 정확성 보완에 추가 조회가 필수는 아니다.

필수 보강은 leaf만 갱신된 재접속/heartbeat, callback 재실행 중 갱신, 옛 connection이
true인 경우, membership/sequence/방 세대 불일치, 같은 UID의 controller/player 동시 접속이다.
실제 trigger와 정리의 순서를 연결한 emulator 검증도 추가한다. 게임 중/게임 시작 경합,
500개 초과 순회·부분 실패·cursor 경합의 기존 회귀는 유지한다.

### P1: controller 요약 지연으로 정상 대기 방 전체 종료

`cleanupStaleRealtimeRooms`의 transaction은 최신 room의 `roomCleanupDeadline`을
재계산하지만, waiting/playing의 controller 기한은 `controllerPresence.lastSeen`만 사용한다.
유효한 `controllerCurrentConnectionId` leaf에 최근 heartbeat가 이미 반영돼도 요약 trigger가
늦으면 예전 기한으로 terminal 전환하고 players/connections/game을 제거할 수 있다.
로컬 probe에서 같은 roomInstanceId·controller connectionId·sequence의 leaf는 true/현재
시각이고 요약은 3분 초과인 waiting 방을 실행해 terminal 및 참가자/접속 제거를 확인했다.
이 기한 판정은 이번 diff에서 새로 생긴 것이 아니며 과거 방 소실의 원인으로 확정하지 않는다.

waiting/playing의 만료 transaction 안에서 현재 controller connection의 instance·ID·sequence를
검증하고, 유효한 최신 heartbeat를 요약 시각과 함께 기한 판정에 사용하도록 보완한다.
connected=true만으로 만료를 영구 면제하지 않고 기존 3분/15분 유예를 유지한다.
closed의 cleanupAt, finished의 retainUntil 등 명시 종료 보존 기한은 재접속으로 연장하지 않는다.
옛 connection/새 generation은 보호 근거로 사용하지 않는다. leaf-only 갱신, transaction
재실행 중 heartbeat, 오래된 true leaf, 명시 close 직후 heartbeat 경합을 회귀로 분리한다.
이미 읽는 room root를 사용하므로 이 보완 역시 별도 get이 필수는 아니다.

### 수정된 진행 순서

1. 위 참가자·controller 현재 접속 보호와 회귀를 정리 후보 배포의 선행 조건으로 둔다. 기존 성능 계획의
   close 거짓 성공·늦은 onDisconnect 등록/취소 보호도 유지한다. 조사·계측 설계는 병행 가능하다.
2. 수정한 정리 후보의 관련 검증과 새 FULL을 통과시킨다. 승인된 함수별 배포와 앱/서버
   revision 일치 확인 뒤 성능 기준선을 다시 만든다. 정리 전 revision의 기존 leave 6건은
   비교 참고값이며 새 후보의 성능 증거가 아니다.
3. 기존 A 단계 계측에 cleanup 활성 구간/비활성 구간의 callable·transaction 시간,
   callback 재실행 수, 페이지 상한·처리 시간·실패·due 지연을 함께 비교한다. 방 크기를
   확인할 필요가 있으면 식별자/payload 대신 제한된 시험 데이터의 크기·건수만 측정한다.
4. 조건을 맞춘 빈 방/2·6·12명과 이력이 적은/많은 방을 비교한다. 정리 순회 확대는
   root 읽기와 쓰기 경합을 늘릴 수 있으므로 측정 전 지연 개선으로 간주하지 않는다.
   500방/100방은 회당 상한이다. 최소 두 번 실행만으로 전체 방 순회가 끝났다고 판정하지
   않고 cursor의 실제 wrap을 확인한다. 실패 방은 다음 전체 순회까지 재시도가 늦어질 수 있다.
5. 이후 기존 조건부 순서대로 실행 준비, close 읽기 통합, create 독립 읽기 병행,
   앱 취소 대기 개선 중 측정된 병목을 선택한다. cleanup 주기·유예 단축이나 TTL 삭제는
   세 작업의 성능 개선 방법으로 추가하지 않는다. p50 제안 목표와 충분한 표본 조건은 유지한다.

### 이번 검토의 실행 근거

- 해당 채팅의 `.\tool\invoke_mosigame.ps1 validate --full --json` 결과 파일
  `build/device-test/rtdb-retention-20261012/full-validation-retry2.json`을 확인했다.
  PASS/exit0, 12단계이며 mutation도 PASS다. 이 검토에서 FULL을 재실행한 것은 아니다.
  해당 결과에는 위 두 종류의 leaf-only 경합 회귀가 없다.
- `node --test build/device-test/room-action-review-20261012/ghost-current-connection-probe.mjs`:
  최종 결함 재현 3/3 PASS/exit0(참가자 2개·방 전체 종료 1개). 정상 연결의 제거를 확인하는 assertion이므로 제품 안전성
  PASS나 수정 완료를 뜻하지 않는다. 초기 probe는 require 상대 경로 오류로 exit1이었고
  probe 경로만 수정해 재실행했다. fixture는 모두 합성 값이며 운영 데이터는 사용하지 않았다.
- probe는 그 채팅의 FULL build 산출물을 사용했다. 검토한 scheduler source SHA256은
  `33F71115511D472B88F2DCD7E6A658DDBE46235179F6EE306E21040F3342E69B`, 산출물은
  `8FB08AF35C311135787442E007341810983DF6943C0749DA7D01C09B1563C6A1`이다.
- 제품 코드·기존 테스트는 수정하지 않았다. FULL 실행 중 tracked 문서 편집을 피했고,
  FULL 완료 확인 뒤 이 계획에 검토 결과를 반영했다. 기존 사용자 변경을 보존했다.

문서 범위 git diff --check, 계획의 로컬 링크13개·공백 검사와 검토 섹션 중복 검사는 PASS/exit0다.
