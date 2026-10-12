# RTDB 정리 기능 검토 — 2026-10-12

검토 기준: `9fb4462`. 코드·관련 회귀 테스트와 저장된 배포 기록을 확인했다.
이번 검토에서는 운영 RTDB 조회·삭제·배포를 하지 않았다. 최근 운영 로그 조회는
별도 범위·권한 확인을 요청한 상태이며, 실제 누적량과 현재 실행 성공 여부는 미확인이다.

## 평가

현재 구현은 종료된 방의 큰 데이터를 제거하고, 지연 요청이 새 방을 훼손하지 않도록
방 식별자와 할당 세대 등의 최소 종료 기록을 남긴다. 방 생성 요청을 보존 기간에 따라
일괄 삭제하는 구현은 없다. 따라서 방 정리와 요청 기록의 장기 보관 관리를 구분해야 한다.

| 대상 | 현재 동작 | 한계 |
| --- | --- | --- |
| `rooms` | 5분 주기. 대기 방은 마지막 controller heartbeat 후 3분, 진행 방은 15분 기준. 종료 상태는 `cleanupAt`/`retainUntil` 등의 기한 사용 | 큰 payload를 정리해도 최소 `terminal` 기록은 남음. 신원·세대·시간 근거가 없는 옛 데이터는 정리 보장이 없음 |
| `roomCleanupQueue` | 기한 인덱스로 회당 최대 300건 처리. 실패 시 최대 30분까지 재시도 간격 증가 | 처리 실패·기한 초과 잔량의 운영 관찰 필요 |
| 방 누락 보완 순회 | 저장 cursor로 회당 100개 방 확인 | 방 기록이 늘수록 전체 순회에 오래 걸림 |
| `roomCreateRequests` | 방 종료 시 같은 방·세대의 요청을 `terminal`로 변경 | 요청 자체를 삭제하거나 최소 형태로 축약하지 않음. 방이 생성되지 않은 예약은 방 순회로 발견 못 함 |
| `roomCreateSlots` | 같은 생성 작업의 슬롯을 `terminal`로 변경 | 슬롯 예약 직후 중단되어 방·요청이 없는 경우 별도 복구 순회 없음. 슬롯 예약에 시각 필드도 없음 |
| `controllerRooms` | 같은 방·세대의 종료 매핑 제거 | 방이 없는 고아 매핑의 별도 순회 없음 |
| 유령 참가자 | 5분 주기. 게임 진행 중이 아닌 방에서 명시적 연결 끊김·5분 초과 조건으로 제거 | 매번 앞 500개 방만 확인하고 cursor가 없음. 뒤쪽 방이 계속 제외될 수 있음 |
| 게임 중단 기한 | 1분 주기로 만료 시 사용자 판단 대기 상태로 전환 | 데이터 삭제 기능이 아님 |

종료 방 정리는 `roomInstanceId`·`allocationGeneration`을 비교하므로 옛 정리 작업이
새 방을 삭제하지 않도록 보호한다. 실패 후 재처리도 구현되어 있다. 다만 로그의
`completed`는 처리한 작업 수이며 실제 물리 삭제된 방 수나 확보된 용량이 아니다.

## 추가 관리 후보와 우선순위

1. **방 없는 생성 예약·매핑의 조건부 복구:** 예약 상태에서 함수가 중단되면 방 순회가
   발견하지 못할 수 있다. 이미 처리된 요청인지, 지연 실행이 가능한 미확정 요청인지
   판별한 뒤 같은 작업·세대에 대해서만 종료·정리해야 한다. 나이만으로 삭제하면 안 된다.
2. **유령 참가자 순회 누락 해소:** cursor나 기한 인덱스로 전체 대상이 순회되도록 한다.
   종료 기록도 앞 500개에 포함되어 활성 방의 정리를 밀어낼 수 있다.
3. **확정 종료된 생성 요청의 축약·보존 정책:** 현재 종료 요청에도 원래 연결·세션 정보가
   남는다. 필요한 재시도 방지 정보를 정하고 최소 기록으로 축약하는 방안을 검토한다.
   삭제 기한은 재시도 계약을 먼저 정한 후 결정한다.
4. **장기간 유지되는 방의 접속·작업 이력:** `connections`의 이전 접속과
   `sessionOperations`의 참가·복구·퇴장·게임 명령 결과가 방 종료까지 누적될 수 있다.
   현재 접속과 미확정 결과는 보존하고, 확정된 이전 이력만 정리해야 한다.
   게임별 `processedCommands`도 중복 실행 방지 소비자를 확인한 뒤 함께 검토한다.
5. **계정 탈퇴 정리의 매핑 형식 대응:** 현재 `controllerRooms`는 객체인데
   `delete-account.ts`는 문자열일 때만 방 종료·매핑 삭제를 한다. 생성 슬롯도 해당 경로에서
   정리하지 않는다. 계정 탈퇴와 주기 정리의 책임을 맞춰야 한다.
6. **운영 지표:** 처리 실패, 가장 오래된 미처리 기한, 생성 예약의 정체, 전체 순회 소요,
   종료 기록·작업 이력의 증가 추이를 관찰한다. 함수 실행 성공만으로 잔류 해결을 판정하지 않는다.

최소 종료 방 기록을 무조건 삭제하면 할당 세대가 사라져 옛 예약의 재실행을 막는 근거를
잃을 수 있다. 이를 삭제하려면 별도 세대 보존과 재시도 차단 계약이 먼저 필요하다.
활성 게임의 private 데이터·미확정 작업 결과·현재 접속·정리 큐는 단순 TTL 삭제 대상이 아니다.
`roomCleanupScan/cursor`는 크기가 고정된 관리 값이므로 주기 삭제할 필요가 없다.

## 근거와 검증

- 코드: `functions/src/room/room-cleanup.ts`, `room-allocation.ts`, `create-room.ts`,
  `ghost-player-policy.ts`, `functions/src/game-interruption/expire-scheduler.ts`,
  `functions/src/auth/delete-account.ts`.
- 저장된 2026-10-10 배포 inventory에서 `syncRoomCleanupQueue`,
  `cleanupStaleRealtimeRooms`, `cleanupGhostRoomPlayers`,
  `cleanupExpiredGameInterruptions`의 `ACTIVE` 상태 확인. 현재 시점 실행의 증거는 아니다.
- 과거 문서의 `cleanupDeletedRoomCreationRequest` 설명은 현재 export와 다르다.
  현재 코드의 정리는 `reconcileTerminal`을 기준으로 판단했다.
- `functions`에서 `npm run build`: PASS, exit 0.
- `node --test test/room-allocation-sdk-cache.test.mjs test/network-session-boundaries.test.mjs test/room-lifecycle.test.mjs test/ghost-player-policy.test.mjs`:
  44개 PASS, exit 0. 운영 실행·운영 잔류량을 검증하는 테스트는 아니다.
- 시작 working tree는 clean. 제품 코드 변경 없이 검토 문서만 추가했다.
  `validate --full`은 실행하지 않았다.

운영 로그 요청 범위는 2026-10-11 03:50~2026-10-12 03:50 KST,
위 네 함수와 기존 `cleanupDeletedRoomCreationRequest`, 함수별 최근 최대 100건이다.
사람의 조회 계정 역할 확인·범위 승인 전에는 조회하지 않는다.

## 2026-10-12 계획 재검토: 위험과 수정된 순서

이 절은 구현 계획의 재검토이며 함수 수정·운영 삭제의 실행 승인을 뜻하지 않는다.
위 추가 관리 후보 목록의 번호는 구현 순서가 아니다. 고아 예약 자동 해제는 아래
차단 계약을 먼저 설계한 뒤 진행한다.

### 주요 위험

| 변경 | 가능한 실패 | 안전 조건 |
| --- | --- | --- |
| `reserved` 요청·슬롯 만료 해제 | 중단된 것으로 판단한 생성 함수가 나중에 allocation·매핑을 완료해 중복 방 또는 고아 방 생성 | 실행 중 함수가 가진 옛 예약까지 allocation 시점에 차단. 삭제 전 재조회나 예약 시각 추가만으로는 부족 |
| `terminal` 생성 요청·방 기록 삭제 | 같은 operationId 재생이 새로운 생성이 되거나, 세대 근거를 잃어 옛 예약이 방을 되살림 | 최소 종료 요청과 할당 세대 보존. 물리 삭제는 별도 재생 차단 설계 후 진행 |
| `sessionOperations`·`processedCommands` TTL | 결과 유실 후 `notApplied` 판정·재전송, 같은 단계에서 중복 행동·시작 발생 가능 | 미확정 결과의 보존 계약 유지. 결과 없는 applied 표식만으로 기존 응답 재생을 대체하지 않음 |
| 옛 connection 삭제 | 같은 UID의 controller 또는 player 현재 접속 제거, 복구·ready 실패 | 같은 방 transaction에서 양쪽 현재 connectionId, membership, sequence를 확인하고 제외. 늦은 onDisconnect·삭제 trigger가 현재 접속에 무효임을 검증 |
| 유령 참가자 전체 순회 | 기존에 누락되던 참가자에게 실제 정리가 적용됨. 재접속·게임 시작과 경합하면 정상 참가자 제거 가능 | transaction의 최신 연결·lastSeen·방과 게임 상태로 재판정. 기존 5분 유예 유지, 현재 게임 진행 중 제거 금지 |
| 계정 탈퇴의 객체 매핑 대응 | 읽은 뒤 방 코드가 재사용되거나 새 매핑이 생긴 경우 다른 방 종료·새 매핑 삭제 | 현재 controllerUid·roomInstanceId·allocationGeneration을 조건부 비교. 오래된 문자열 매핑은 소유권·세대 확인 없이 종료하지 않음 |
| 순회·정리 확대 | 많은 방 전체 읽기·큰 room transaction·추가 trigger로 지연/비용 증가 | 페이지·처리량·동시 실행 상한, 부분 실패 재처리, 로그에 payload 미포함. 검토 단계에서 용량 절감 수치는 확정하지 않음 |
| 부분 배포·실패 후 롤백 | 삭제된 기록은 옛 코드 배포로 복원되지 않음. 구·신 버전이 서로 다른 차단 계약으로 동작 | 관찰 → 조건부 제한 적용 → 확대 순서. 파괴적 삭제는 뒤로 미룸. 새 기록을 구 코드도 안전하게 취급해야 함 |

실제 근거: `game_common_operation_status`는 같은 방에서 결과 기록이 없고 현재 자격이
유효하면 `notApplied`를 반환한다. 클라이언트 계약은 원래 ID/domain 재전송이다.
`allocateRoom`은 전달받은 예약과 방의 세대를 비교하며, allocation transaction 안에서
생성 슬롯이나 생성 요청을 다시 읽지 않는다. 따라서 다른 경로의 예약을 `terminal`로
바꾸기만 해서는 이미 예약을 읽은 실행 중 함수가 반드시 차단된다고 볼 수 없다.

### 수정된 실행 계획

1. **관찰과 기준선:** 승인된 운영 범위에서 정리 실행·실패·기한 초과 상태를 확인한다.
   새 계측은 개수·시간·상태만 기록한다. 전체 DB 덤프나 모든 room 크기 계산을 정기
   작업으로 추가하지 않는다. 기존 방 유예는 그대로 둔다.
2. **정리 누락과 생명주기 정합성:** 유령 참가자에 제한된 페이지 순회를 적용한다.
   현재 값 재판정·멱등 처리·실패 후 다음 실행·cursor 경합을 검증한다. 계정 탈퇴의
   객체/문자열 매핑 지원은 별도 변경으로 분리해 조건부 종료·매핑 정리 경로를 맞춘다.
3. **확정 종료 요청 축약:** 같은 방·세대의 종료가 확정된 요청만 최소 종료 기록으로
   축약한다. operationId 재생에 필요한 상태와 식별·세대 근거를 보존한다. `reserved`
   요청, 살아 있는 방, 종료 기록 자체의 물리 삭제는 제외한다. 필드 계약 변경은 승인 후 진행한다.
4. **고아 예약 해제 설계·검증:** 슬롯만 존재, 요청 예약 후 중단, 방 allocation 후
   매핑 전 중단을 구분한다. cancellation과 allocation의 경합을 막는 공통 조건을
   설계하고 구·신 실행의 호환성을 검증한다. 안전한 차단을 증명하기 전에는 관찰·복구만 한다.
5. **이력 GC는 별도 단계:** 옛 connection 정리는 양쪽 현재 접속 제외를 검증한 뒤
   제한 적용한다. 작업 결과·게임 명령 결과·최소 종료 방의 TTL 삭제는 재시도 계약
   변경과 소비자 대응이 필요한 별도 작업으로 남긴다.

1~3단계만으로 생성 요청의 종료 후 크기를 줄이고 순회 누락을 개선할 수 있다.
다만 전체 기록 개수의 무한 증가나 고아 예약 차단 문제가 모두 해결됐다고 보고하지 않는다.
관찰 결과에 따라 후보의 우선순위·처리 상한을 결정한다.

### 구현 시 반드시 추가할 검증

- 방 종료 직후 같은 코드의 새 세대 생성 후 옛 cleanup·생성 응답 도착: 새 방·매핑 유지.
- 결과 기록 축약 뒤 같은 생성 ID 재생: `terminal` 유지, 새로운 방 생성 없음.
- 슬롯/예약/방/매핑/종료 축약 각 단계의 실패 후 재실행: 한 방만 존재하며 작업 정체가 판별됨.
- 예약 취소 직전·직후 옛 함수 allocation: 금지된 생성과 매핑 완료가 불가능함.
- 500개 초과 방, 종료 기록이 앞에 몰림, 순회 도중 키 삽입·삭제, 중복 schedule·부분 실패:
  정리 대상이 다음 순회에서 결국 처리되고 실패 대상이 영구 누락되지 않음.
- 유령 참가자 제거와 재접속·게임 시작 동시 실행: 최신 상태가 보호 조건이면 참가 유지.
- 같은 UID의 태블릿·휴대폰 및 이전 connection 정리 후 늦은 onDisconnect:
  두 역할의 현재 접속·ready·방 유지.
- 계정 탈퇴의 객체/옛 문자열 매핑, 방 코드 재사용, 매핑 교체, 부분 실패: 다른 방에 영향 없음.
- 응답 유실·오프라인 퇴장·앱 재실행의 기존 회귀, 관련 suite와 정해진 FULL validation.

이번 재검토에서는 테스트를 새로 실행하지 않았다. 이전 44개 통과는 현재 구현의
일부 회귀 근거이며 새 GC·취소 경합·500개 초과 순회의 안전성 증거를 대신하지 않는다.
제품 코드·배포·운영 데이터는 변경하지 않고 이 검토 문서만 갱신했다.

## 2026-10-12 승인된 1~4단계 구현 후보

사용자는 운영 관찰·유령 참가자 순회·계정 탈퇴 정합성·확정 종료 요청 축약을 진행하고,
고아 예약 해제와 접속/작업 이력 GC는 나중에 진행하도록 지정했다. 이 절 이후의 구현
사실은 위 최초 읽기 전용 검토 기록과 구분한다. 새 함수 배포·운영 삭제·migration은 실행하지 않았다.

### 운영 관찰

사용자의 조회 진행 응답 후 기존 조회용 configuration과 고정 project를 사용했다.
IAM 권한을 AI가 직접 조회한 것은 아니다. 요청한 24시간 범위에서 최초 metadata 1건과
함수별 최근 최대 100건을 확인했다. 최대 건수에 도달한 결과는 24시간 전체 실행을 뜻하지 않는다.

| 함수 | 관찰 결과 | 한계 |
| --- | --- | --- |
| `cleanupStaleRealtimeRooms` | metadata 1건 + 최근 99건. 요약 50회, `completed` 합계 7, `failed` 합계 0. HTTP 200 기록 49건 | 최근 요약 구간은 10/11 23:41~10/12 03:46 KST. completed는 물리 삭제 수가 아님 |
| `syncRoomCleanupQueue` | 최근 100건 모두 HTTP 204 | 약 03:47~03:50 KST의 표본. 큐 잔량·24시간 전체 성공은 미확인 |
| `cleanupGhostRoomPlayers` | 최근 100건 모두 HTTP 200 | 기존 제거 건수 로그가 없어 실제 제거 효과는 미확인 |
| `cleanupExpiredGameInterruptions` | 최근 100건 모두 HTTP 200 | 실행 성공과 개별 상태 처리 결과는 구분 |
| `cleanupDeletedRoomCreationRequest` | 지정 범위 기록 0건 | 배포되지 않았다는 증거가 아님 |

조회 스크립트와 정제 evidence는 ignored `build/device-test/rtdb-retention-20261012/`에 있다.
명령은 bundled Python의 `-S .../lib/gcloud.py --configuration=mosigame-logs-readonly logging read`,
UTC 범위 `2026-10-10T18:50:00Z` 이상 `2026-10-11T18:50:00Z` 미만, 함수 label·두 관련 리전으로 제한했다.
probe/review 모두 exit 0. RTDB 직접 조회와 Auth 접근은 하지 않았다.

### 구현 범위

- 유령 참가자: `roomCleanupScan/ghostCursor`에 별도 순회 위치를 저장한다. 5분 주기,
  회당 500개 처리·최대 501개 조회, transaction 동시 실행 최대 10개다. 현재 상태를
  다시 판정하며 5분 유예와 게임 진행 중 제거 금지는 유지한다. 부분 실패는 기록하고
  다음 전체 순회에서 다시 처리한다. 방 수가 많으면 재방문 간격이 5분보다 길어진다.
- 두 순회 cursor는 읽은 값과 같을 때만 갱신해 겹친 실행의 늦은 덮어쓰기를 막는다.
- 정리 요약에는 실패·실제 참가자 제거·확인 건수, 처리 상한 도달 여부, 처리 시간 등을
  추가했다. 방 정리의 `terminalReconciliations`는 종료 정합성 처리를 마친 횟수이고
  `staleJobs`에는 방 없음/이전 세대/유효 기한 없음이 포함된다. `oldestDueAgeMs`는 조회한
  최대 300개 due 작업의 지연이지 DB 전체 잔량 지표가 아니다. UID·방 코드·private payload는 기록하지 않는다.
- 같은 allocation의 실패 backoff를 큐 갱신이 앞당기지 않도록 보존한다. 새 allocation은
  실패 횟수와 기한을 새로 계산한다. 기존 1~30분 backoff 정책 자체는 바꾸지 않았다.
- 계정 탈퇴: 객체 매핑과 문자열 매핑을 지원한다. 현재 소유자·방 instance·세대를
  transaction 안에서 확인하고 같은 방만 닫는다. 이미 닫힌 방의 기한을 연장하지 않는다.
  matching 요청·슬롯 정리 후 매핑을 제거하므로 슬롯 정리 실패 시 재시도 위치가 남는다.
  문자열 매핑의 방 신원/세대가 없거나, 방이 없거나 소유권이 다르면 추측 정리하지 않는다.
  새 매핑·새 슬롯·다른 예약은 보존한다. 기존 UID 전체 생성 요청 삭제는 제거했다.
- 생성 요청: 현재 방에서 같은 instance·세대의 `terminal` 상태가 확인되고 요청이
  `created` 또는 `terminal`이면 `roomCode`, `roomInstanceId`, `allocationGeneration`,
  `status=terminal`, 원래 숫자 `createdAt`만 보존한다. controllerSessionId·connectionId 등은
  축약한다. 기존 terminal marker와 세대는 지우지 않으며 재생은 계속 terminal을 반환한다.
  예약 상태를 직접 축약하지 않는다. 기존 known-allocation 종료 정합성 처리는 유지한다.

새 필드 삭제가 포함된 최소 종료 요청은 현재 및 이전 create 함수의 terminal 조기 반환과
호환된다. 이미 controllerUid 등을 잃은 과거 최소 종료 방에 연결된 큰 요청을 일괄
축약하는 backfill은 하지 않는다. 이번 변경은 전체 기록 개수를 제한하는 TTL 기능이 아니다.

### 변경과 검증 기록

제품 변경은 `functions/src/room/room-cleanup.ts`, `room-allocation.ts`, `create-room.ts`,
`functions/src/game-interruption/expire-scheduler.ts`, `functions/src/auth/delete-account.ts`,
새 `account-room-cleanup.ts`다. 새 RTDB regression과 Auth regression으로 경합·부분 실패를 검증한다.

- 초기 build에서 추가 helper의 presence 타입 불일치를 수정했고 이후 `npm run build`: PASS, exit 0.
- 초기 회귀에서 슬롯 정리 실패 뒤 매핑이 먼저 사라지는 문제가 드러나 정리 순서를 수정했다.
  logger mock의 참조 위치도 수정했다. 최종 관련 5개 파일 57개 PASS, exit 0.
- `npm run lint`: PASS, exit 0.
- guarded `test session` 첫 실행: Flutter 212/Functions 123 PASS(exit 0), 전체 exit 1.
  실행 중 별도 로비 지연 문서 변경으로 working-tree mutation FAIL이었다. 이 변경은 보존했다.
- 최종 session/auth 및 FULL 결과는 아래 후속 기록에서 확정한다. FULL은 별도 명시 승인 전 실행하지 않는다.

후속 guarded `test auth`: Flutter52/Functions25 단계 PASS(exit0), 전체 exit1.
별도 문서 편집이 계속되어 mutation FAIL이었다. 같은 동시 변경 감지가 반복돼
추가 검증 실행은 중단했다. 두 suite의 제품 테스트 성공과 CLI 전체 FAIL을 구분한다.
`validate --full`은 실행하지 않았고 후보 완료/배포 성공으로 표시하지 않는다.
CLI manifest는 변경하지 않았다. 새 RTDB 회귀는 위 standalone 검증과 기존 FULL의
Functions 전체 테스트에 포함된다.

배포 시 검토할 기존 함수는 `cleanupStaleRealtimeRooms`, `syncRoomCleanupQueue`,
`cleanupGhostRoomPlayers`, `deleteAccount`, `createRealtimeRoom`이다. 새 callable·schedule
export는 없다. `createRealtimeRoom`은 종료 요청 최소 형태와 shared 보상 정리를 사용한다.
배포 후 최소 두 순회와 실패 건수, 명시 종료 후 새 방 생성·옛 요청 재생,
테스트 계정 탈퇴 정리를 별도 관찰해야 한다. 운영 검증은 로컬 통과로 대체하지 않는다.

### 2026-10-12 04:41 KST — 승인 후 FULL 실행

사용자의 `풀 실행해` 승인으로 `tool/invoke_mosigame.ps1 validate --full --json`을
한 번 실행했다. 전체 FAIL(exit1, 약 8초), preflight PASS, dart-format FAIL(exit1),
working-tree-mutation PASS다. 기존 미수정 파일 `lib/platform/home/tablet/screens/tablet_home.dart`와
`test/lobby_music_test.dart`가 포맷 기준에 맞지 않아 이후 분석·테스트 단계는 실행되지 않았다.
`--output=none --set-exit-if-changed` 검사이므로 두 파일을 포함한 실제 소스 변경은 없다.
실행 전후 branch `codex/e01-validation-wiring`, HEAD `9fb4462`와 tracked/untracked 상태가 같고
staged 변경은 없다. 결과는 ignored `build/device-test/rtdb-retention-20261012/full-validation.json`에 저장했다.
이 기록 추가는 검증 종료 후 문서 편집이다. FULL 통과·배포 완료로 판정하지 않는다.

### 2026-10-12 04:56 KST — 실패 요소 수정과 최종 FULL PASS

사용자가 실패 분석·수정·재실행을 지시했다. 초기 실패 두 곳은 기존 Dart 줄바꿈 차이로,
`tablet_home.dart`와 `lobby_music_test.dart`를 포맷했으며 실행 동작은 바꾸지 않았다.
restricted 실행에서 Pub cache 읽기·telemetry 접근이 거절됐지만 권한을 확보한 재검사는
`dart format --output=none --set-exit-if-changed bin lib test tool/mosigame_cli` 173파일
변경0/PASS(exit0)였다. SDK·cache ACL이나 검증 설정을 바꾸지 않았다.

첫 재실행(`full-validation-retry1.json`, 04:46~04:49 KST)은 포맷·분석·mutation PASS,
Flutter448 PASS/1 FAIL, 전체 FAIL(exit1)이었다. `test/mosigame_cli/test_suites_test.dart`가
4bbd31e/9fb4462 커밋에서 이미 manifest에 추가된 다음 테스트를 기대값에 반영하지 않았다:
`table_background_transition_test.dart`, `room_session_identity_store_test.dart`,
`final_call_dealing_readiness_test.dart`, `room-session-context.test.mjs`.
실제 manifest를 보존하고 독립적인 exact-order 기대 목록에 네 항목을 추가했다.
`flutter test --no-pub test/mosigame_cli/test_suites_test.dart` 20 PASS(exit0).
테스트 제거·skip·assertion 약화·CLI 실행 정책 변경은 없다.

최종 명령 `tool/invoke_mosigame.ps1 validate --full --json`은 04:50~04:56 KST,
PASS(exit0, 342530ms), 12단계 모두 PASS다. 루트 Flutter449, game_kit117, LP15,
Final Call16, Mafia58, Holdem32, Functions454 PASS(skip0), 분석·lint·mutation PASS.
ignored evidence는 `build/device-test/rtdb-retention-20261012/full-validation-retry2.json`과
`full-validation-retry2-progress.log`다. 이번 추가 소스 diff는 포맷2파일과 목록 검증1파일이다.
실행 전후 branch codex/e01-validation-wiring/HEAD9fb4462, tracked/untracked 상태는 같고
기존 변경을 보존했다. staged 없음. 문서 결과는 실행 종료 후 갱신했다.
로컬 최종 검증은 통과했으며 배포·운영 관찰은 별도 남아 있다. 이번에도 배포·migration·
운영 DB 쓰기·commit/push는 하지 않았다.
