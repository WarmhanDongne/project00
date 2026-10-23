# 네트워크·세션 구현 계약

2026-10-09 E02~E12 및 2026-10-10 룰렛·시작 재시도 로컬 구현 후보의 계약이다. 배포 여부를 뜻하지 않는다.
[채택한 A~C와 실행 계획](../planning/NETWORK_SESSION_IMPLEMENTATION_PLAN.md),
[현재 검증과 한계](../planning/NETWORK_SESSION_E02_E12_IMPLEMENTATION.md),
[Engineering Contract](ENGINEERING_CONTRACT.md)를 함께 따른다.

## 식별자와 권위

| 경계 | 서버가 부여·확인하는 값 | 소비자 |
| --- | --- | --- |
| 방 | roomInstanceId, allocationGeneration | 생성·참가·종료·정리, 같은 코드 재사용 보호 |
| 참가 | membershipId, membershipRevision | 재참가·퇴장, 그룹 조회 전후 검사 |
| 접속 | connectionId, connectionSeq | join/resume CAS, presence, 준비 보고 |
| 게임 데이터 | gameInstanceId, phaseSeq, turnSeq, dataSeq | 의미 변경과 공개/본인 private._context 대응 |
| 준비 barrier | resumeEpoch | 최초 pause·중단 중 의미 상태/필수 집합 변경, ready 보고 대응 |
| 요청 | operationId 또는 commandId, UID·종류·정규화 domain fingerprint | 서버 sessionOperations, 재전송과 결과 조회 |

B1-C 신규 방은 presenceProtocol=2다. 정상 10초 heartbeat는 현재 connection의 lastSeen만
서버 timestamp로 덮어쓴다. connected=true와 현재 접속 seed/요약은 서버 CAS만 갱신한다.
현재 false에서 heartbeat·client true 복원은 Rules가 거절한다. background는 false+timestamp
일회 update, onDisconnect는 false만 예약한다. room/member/current id·seq 검증을 유지한다.
로컬 connectionSeq 역행 방지는 같은 roomInstanceId와 membershipId 안에서만 적용한다.
새 membership은 순번이 작아도 저장한다. 같은 membership의 옛 성공 결과는 최신 접속을
유지하면서 해당 completedOperationId의 pending만 정리한다. 미확정 결과는 유지한다.
pending join 재생 후 현재 참가 조회에서 자격 상실이 확정되면 직접 join만 새 요청을
만들 수 있다. 자동 복구·프로필 편집·통신 오류는 새 참가를 생성하지 않는다.
옛 onDisconnect와 늦은 presence 이벤트는 현재 접속을 끊지 않는다.
controllerSessionId는 UID별 controller identity에 보존하며 기존 저장소는 호환 조회에 사용한다.

## 방 callable

기존 이름과 서울 리전을 유지한다. RTDB 트리거는 싱가포르 리전이다.

| callable | 요청·판정 | 성공/재조회 |
| --- | --- | --- |
| createRealtimeRoom | 전송 전 저장한 operationId, UID별 생성 slot, 예약·allocation CAS | success와 room/connection/controller context; 종료된 이전 작업은 terminal |
| joinRealtimeRoom | roomInstanceId, 기존 membershipId, expectedConnectionSeq, operationId와 프로필 | 같은 작업은 원래 결과 재생; CAS 불일치는 aborted/staleConnection |
| resumeRealtimeControllerRoom | roomInstanceId, controllerSessionId, expectedConnectionSeq, operationId | 같은 작업 재생; 새 복구 작업은 다음 접속 할당 |
| fetchRealtimeRoomSession | roomCode, controller는 session token | 현재 room/member/connection context |
| game_common_operation_status | roomInstanceId, operationId, 필요 시 membership/controller token | applied / stale / notApplied; 게임의 비공개 결과는 반환하지 않음 |
| leaveRealtimeRoom 및 게임별 leave | 원래 roomInstanceId·membershipId·operationId | 최초 requested는 직접 전송, awaitingResult는 결과 조회 우선. 원래 자격만 제거하고 applied/stale 확인 후 intent/identity 정리 |
| closeRoom | 원래 roomInstanceId, controller token, operationId | 최초 requested는 직접 전송, awaitingResult 재시도는 결과 조회 우선. 같은 방만 close |
| fetchRealtimeRoomGroupEntitlements | roomInstanceId, 현재 방 참가 자격 | 구매 조회 전후 revision/자격 검사. 다른 방 controller라도 현재 참가자는 조회 가능 |

UID/역할별 identity와 미확정 transport/durable 작업은 직렬 저장한다.
저장 실패면 전송하지 않으며 결과 미확정 기록은 TTL로 버리지 않는다.
퇴장 의도가 남으면 자동 참가·heartbeat보다 결과 확인을 먼저 한다.
join/resume 재생은 최신 접속을 되돌리지 않는다. 현재 sequence를 읽어 새 복구 작업을 만든다.
2026-10-10 로비 지연 후보: 최초 requested 생성의 응답 connectionSeq=1은 서버가 할당한
초기 접속을 저장하고 presence/단절 예약을 설정한다. 생성 재생·미확정 결과·진행된 접속
세대·실제 재접속은 resume을 유지한다. 복구가 실패하면 생성 성공으로 반환하지 않는다.

2026-10-10 후속 지연 후보: join 준비의 roomInstanceId와 본인 player 조회는 병행하며
최종 membership/sequence 판정은 기존 join transaction이 수행한다. 최초 leave도 close와
같이 사전 status 조회를 생략한다. 게임 시작 서버 준비는 공용 착석 연출과 병행하지만
화면 전환은 준비/연출/배경이 모두 끝난 후다. [개발팀 공유 문서](NETWORK_LATENCY_IMPROVEMENTS.md)에
원인, 변경 전후, 회귀 및 배포·실측 한계를 정리한다.

### 2026-10-22 로비 요청 효율 개선 후보

방 생성의 onboarding 확인과 기존 controller 매핑 읽기는 병행하되 두 선행 조건이
성공하기 전에는 방 생성 관련 RTDB 쓰기를 시작하지 않는다. 기존 onboarding 내부의
legacy 계정 Firestore backfill은 유지한다. onboarding·작업 ID·매핑의 기존 오류
우선순위를 유지한다. 로비 추방은 방/controller 신원만 보내고 게임 public 문맥을
사전 조회하지 않는다. 서버는 transaction에서 최신 권한·방 세대·protocol·게임 중
추방 금지를 계속 검증한다.

추방·명시 초기화의 서버 준비는 기존 runPrimedTransaction의 value listener 하나가
소유한다. 초기화의 별도 root get과 추방의 중복 listener를 제거하되 cold cache 보호와
callback 재실행 시 검증을 유지한다. close 미적용은 성공으로 반환하지 않는다.
공개 callable·데이터 형식·보존 기한·재시도 계약은 유지하며 배포 완료를 뜻하지 않는다.
[점검·설계·검증 보고](../planning/ROOM_ACTION_EFFICIENCY_20261022.md)를 따른다.

후속 사용자 승인으로 createRealtimeRoom·removeRealtimeRoomPlayer·closeRoom의 위
개선은10/22 선택 배포를 완료했다. 세 함수 ACTIVE를 확인했으며 앱의 설치·실측은 별도다.
[배포 및 APK 기록](../operations/ROOM_ACTION_RELEASE_20261022.md)을 참조한다.

## 공용 게임 중단과 명령

네 게임 실제 reducer를 game-command-transaction과 game-mutation에 연결한다.
callback 재실행은 동일 수락 시각과 난수 seed를 사용한다. 공개 변경과 필수 private._context를
같은 gameInstanceId/phaseSeq/turnSeq/dataSeq 네 값으로 저장한다.
resumeEpoch는 공개 barrier와 준비 보고에만 사용하며 private 대응 조건에 넣지 않는다. 시작은 새 gameInstanceId,
단계·라운드·핸드·재판 변화는 phaseSeq, 턴 변화는 turnSeq를 갱신한다.

현재 방·자격·접속·game/phase/turn을 검증하고 paused 진행을 거절한다.
중복 명령은 UID·종류·domain이 같아야 기존 결과를 반환한다.
저장한 domain/ID는 자동·수동 재시도에서 유지한다. 종료·자기 퇴장·복구 선택은 pause 중에도 서버 검증을 거친다.

LP 추첨의 resolutionId와 확정의 commandId는 별개다. 확정은 현재 pending 추첨 ID와
대상을 검증하고 같은 확정 재시도는 원래 commandId/domain을 유지한다. 같은 추첨의
prepare 재호출은 저장 결과를 반환한다. 다른 kind에 같은 ID를 재사용하는 것은 거절한다.

시작 fingerprint는 selectedGame/status와 UID별 role/status/membershipId/seatIndex/
nickname/characterId/profileImageUrl을 비교한다. heartbeat·접속 갱신은 준비 입력 변경이
아니며 실제 명단·자격·좌석·표시 정보 변경은 거절한다. 접속 권한과 준비 barrier 검사는 유지한다.

최초 실패만 public.recovery.paused/pauseId/pausedAt 및 server.recovery.timer를 만든다.
timer는 kind=none 또는 kind=remaining으로 저장해 RTDB의 null 생략에도 마감 없음과 0ms 남음을 구분한다.
pausedAt은 서버 감지 시각이다. 타이머는 서버가 검증한 현재 접속의 마지막 성공 heartbeat부터
멈추며, 유효한 heartbeat가 없을 때만 감지 시각을 사용한다. onDisconnect는 connected만 false로
바꿔 마지막 성공 lastSeen을 보존한다.
heartbeat가 현재 턴 시작보다 이르면 남은 시간을 해당 턴 제한까지만 보존한다.
LP playing은 30초, lastCardChallenge는 10초, Final Call은 30초이며 서버 턴 상수를
사용한다. Mafia/Holdem의 단계 시간에는 이 상한을 적용하지 않는다. 0ms와 마감 없음의
구분, 추가 단절이 최초 보관 시간을 덮어쓰지 않는 조건은 유지한다.
추가 원인은 최초 남은 시간을 덮어쓰지 않는다. 생략된 빈 causes/ready는 빈 집합으로 처리한다.

| 공용 callable | 역할과 결과 |
| --- | --- |
| game_common_recovery_report | 현재 접속 ready/failed와 reportSeq. failed에는 알려진 game ID만으로 보고 가능 |
| game_common_interruption_report_stale_player | controller가 관찰한 접속·sequence·lastSeen이 현재와 같을 때 실패 원인 추가 |
| game_common_interruption_report_stale_controller | player가 관찰한 controller 접속·sequence·lastSeen이 현재와 같을 때 실패 원인 추가 |
| game_common_interruption_expire | 만료를 awaitingDecision으로 표시; 자동 제외/종료 없음 |
| game_common_interruption_wait_more | controller가 만료된 현재 incident를 한 번 수락 시각부터 30초 연장 |
| game_common_interruption_exclude_player | controller의 현재 incident/pause 선택. 실제 reducer preview 뒤 제외 |

ready는 public/본인 private 대응, 필수 이미지 디코딩, 실제 프레임 준비를 뜻한다.
connected=true는 ready가 아니다. required controller와 active·alive phone이 같은 barrier에
준비되어야 원인을 해제하고 저장한 타이머로 재개한다. 추가 단절은 다른 유효 ready를 보존한다.
pause 중 의미 상태/필수 집합 변화는 barrier를 갱신한다. 정상 변경마다 전체 보고를 반복하지 않는다.

LP/FC dealing 미생성 private, 정상 빈 hand/미선택은 실패가 아니다.
Mafia 사망 phone은 서버 필수 private barrier에서 빠지지만 로컬 보호는 유지한다.
네트워크 제외 투표와 phone 전체 종료를 제거하고 Mafia 고유 투표는 유지한다.
Holdem allIn·stack=0은 현재 핸드 정산까지 생존이다. 다음 핸드 인원 판정과 구분한다.

## Flutter 수명과 재시도

GameSessionController가 구독 세대·디코딩·프레임·보고를 소유한다.
입력은 localUsable + serverConfirmed + 연결 + 비중단 + 비퇴장을 모두 확인한다.
접속 교체 뒤에는 서버 준비 확인이 다시 필요하다. 낮은 dataSeq·이전 game/watcher/Future는 현재 화면을 되돌리지 않는다.

public/private 불일치는 하나의 최대 30초 준비 묶음에서 현재 공개 조회와 필요한 재구독으로 확인한다.
새 dataSeq만으로 남은 예산을 초기화하지 않으며, 일치하면 대기/조회 타이머를 취소한다.
구독 종료·권한/파싱·필수 에셋 실패는 즉시 로컬 입력을 보호하고 failed를 보고한다.
소진 시 failed도 같은 잔여 예산을 공유해 전송 미확정일 수 있다. 로컬 보호를 유지하며
수동 재시도/실제 재연결의 새 제한 묶음에서 확인한다. 소진 뒤 늦은 데이터만으로 보호를 해제하지 않는다.
이전 구독의 onDone/Future와 취소된 deadline은 현재 준비를 실패로 바꾸지 않는다.

| 작업 | 단일 소유자와 예산 |
| --- | --- |
| 방/세션/준비 복구 | RoomRecoveryBatch: 최초 포함 6회, 1/2/4/8/8초, 요청별 8초, 전체 30초 |
| 게임 행동·진행 | GameCommandBatch/CallableRetryPolicy: 최초 포함 4회, 0.25/0.5/1초, 요청별 8초, 전체 12초 |
| 게임 시작 | 자동 반복 전송 없이 단일 요청; 미확정이면 저장한 시작을 수동 확인/재생 |
| 소진 뒤 | 미확정 ID/domain 유지, 결과 확인 후 실제 수동 재시도 |
| 재연결/foreground | UID·방·수명 확인 후 새 제한 묶음; 중첩 소유자 없음 |

시작은 기존 UID/role identity에 pendingGameStart(functionName/input/payload)를 전송 전에
직렬 저장한다. 같은 roomInstanceId/membershipId의 접속 교체·새 서비스·앱 재실행은
원래 ID와 옵션을 이어받는다. 저장 실패면 전송하지 않으며 TTL로 버리지 않는다.
성공·stale 또는 최초 요청의 확정 거절은 해당 ID만 정리한다. 이미 미확정인 시작의
후속 already-exists 등은 최초 요청의 완료를 입증하지 못하므로 의도를 유지한다.
다른 게임/옵션으로 교체하지 않으며 방·참가 교체나 명시 방 정리는 원래 의도를 제거한다.

미확정 재시도는 operation_status부터 조회한다. applied는 결과 없는 success로 변환하지
않고 원래 callable/domain/ID를 재생해 저장 응답을 받는다. notApplied도 원래 요청을
재전송한다. 전송 시 현재 UID·방·참가를 확인하고 접속 envelope만 갱신한다. applied
재생은 이후 phase/pause 변경에도 가능하다. 늦은 응답은 새로운 ID/재시도 owner를 정리하지 않는다.
태블릿 설정 완료는 pending 시작이 있으면 좌석 저장을 반복하지 않고 결과 확인부터 한다.
미확정 중 설정 취소·명단 변경에 의한 선택 정리도 원래 시작을 덮어쓰지 않는다.

완료된 owner를 긴 구독이 상속하지 않는다. 늦은 operation의 이어 실행은 원래 deadline을 유지한다.
복구 후 heartbeat timer와 완료 알림은 bounded 작업을 await한 바깥에서 시작한다.
신원 변경 알림이 bounded 요청 내부에서 발생해도 게임의 재구독과 주기 heartbeat는
각 controller/provider의 세션 zone에서 시작한다. player의 즉시 heartbeat도 같은
세션 zone을 사용한다. 복구 결과를 확인하는 첫 heartbeat는 원래 요청 owner 안에 둔다.
재구독은 이전 준비 frame을 무효화하며 같은 context를 다시 받아도 현재 subscription
generation의 frame을 예약해 준비 보고를 다시 수행한다.
pending controller resume은 먼저 현재 identity를 조회한다. 같은 방 instance의 접속
sequence가 이미 증가했다면 채택하고, 미적용이면 저장한 operationId로 재전송 후 다시
조회한다. 종료된 방 또는 바뀐 방 instance는 기존 종료 정리 경로로 처리한다.
복구가 null이고 controller session도 제거됐을 때만 provider의 같은 기존 방을 정리한다.
첫 게임 준비는 대기실의 오래된 owner를 재사용하지 않는다. 이미 준비된 게임의 새 pause는
새 준비 묶음을 사용하되 같은 pause의 barrier/dataSeq 갱신이나 진행 중인 준비 대기는
기존 deadline을 유지한다. 준비 실패 뒤 도착한 pause/데이터만으로 보호를 해제하지 않는다.
소진된 request는 새 호출을 시작하지 않는다. AppNetworkGuard는 실제 네트워크 오류를 기존 연결 UI로 보호한다.
팝업이 게임 라우트 위에 올라와도 가드의 wrapper와 child 위치를 유지한다. 가려진 라우트의
안내와 입력 차단만 비활성화하며 게임 State·구독을 폐기하거나 중첩 가드 소유권을 교체하지 않는다.
2026-10-09 사용자 UI 결정: 정상 진입·카드 분배·public/private/에셋/프레임의 최초 준비는
기존 게임 배경·연출을 유지하며 별도 문구·안내창·퇴장 버튼을 띄우지 않는다.
2026-10-10 복구 결정: 실제 pause가 시작된 뒤 원인이 먼저 해소된 ready barrier는 모든 필수 기기의
준비가 끝날 때까지 일반 중단 안내를 유지하되 별도 퇴장·결정 버튼은 만들지 않는다.
실제 recovery pause/기존 플레이어 이탈 또는 로컬 준비 실패가 있을 때만 기존 오류 UI를 사용한다.
GameRecoveryLayer는 휴대폰의 GameRequestNotice 한 곳에 중단/실패와 필요한 재시도를 표시한다.
준비 실패 안내는 늦은 데이터로 지우지 않으며 명시 재시도가 시작되면 닫는다.
휴대폰 나가기는 기존 상단바·퇴장 모달을 사용한다. 준비 실패/실제 중단 중에도 기존 메뉴를 사용할 수 있다.
PhoneGameShell의 content 보호와 LP 카드 선택·제출/LIAR/FOLD 조건, 명령 서비스의 canSend 검사는
로컬 준비·서버 확인·pause·연결·퇴장 상태를 계속 반영한다. UI를 숨겨도 서버 준비/입력 제한은 풀지 않는다.
controller의 실제 중단에는 기존 제외·한 번 연장·확인 후 종료 UI를 유지한다.
정상 캐시는 재다운로드하지 않는다. 누락/손상 파일만 동의 후 복구하고 디코딩·프레임을 다시 준비한다.
route 완료와 게임 정리는 캡처한 game ID로 처리한다.

2026-10-18 최초 자리 배치 후속: 자리 저장과 게임 시작 성공 뒤 퇴장 정리 대상 조회를
남은 착석·줌 연출과 병행한다. 조회는 해당 launch/route가 소유하며 rebuild로 초기화하지
않는다. UID·방 인스턴스·진행자/접속 신원이 달라지거나 새로운 게임 문맥의 불일치가
관측되면 옛 전환을 폐기한다. 시작 전의 이전 게임 캐시를 새 시작의 문맥으로 간주하지
않는다. 신원을 모르면 기존 전환 시 조회를 사용하고, 미리 조회 실패 때는 같은 유효
시도에서만 한 번 재확인한다. 메뉴/결과 재시작·복구 진입과 연출 순서는 변경하지 않는다.
정리는 게임 route 퇴장 뒤 기존 서버의 방·게임 세대와 종료 상태 검사를 계속 따른다.

명시 방 종료는 옛 신원·접속 참조·payload를 고정하고 durable close 의도/awaitingResult를
저장한 뒤 옛 onDisconnect 취소와 기존 close/status 처리를 병행한다. 보조 취소 실패나
미완료가 서버 종료를 막지 않으며, 서버 결과 미확정 때 원 operation ID와 복구 신원을
유지한다. 저장 중 교체된 새 세션은 invalidate하지 않는다. 늦은 옛 예약 등록 완료는
그 옛 경로만 다시 취소한다. 새 신원·접속 예약·진행자 세션은 건드리지 않고 서버 확인
전 성공 처리/신원 정리를 하지 않는다. 새 API·영속 필드·서버 규칙 변경은 없다.

## 2026-10-10 LP 후속 후보

transportRecovering 동안 ready와 입력은 막는다. 현재 identity 저장과 해당 접속 heartbeat 확인
뒤 구독/ready를 다시 준비한다. 진행 Future와 완료된 UID/방/세션·접속 세대/connection scope를
공유한다. pending join은 원래 결과 재생 뒤 현재 참가·접속을 확인해 채택한다. 별도 명시 프로필
수정은 새 요청이다. 만료·이전 참가 owner의 identity/pending 저장과 새 접속에 대한 늦은 disconnect를
막는다. 현재 Navigator route만 네트워크 안내를 맡고 퇴장/dispose는 자신의 callback만 해제한다.
heartbeat 권한 거절은 episode당 한 번 제한 재확인, ready staleConnection은 같은 준비 예산을 쓴다.

localUsable과 현재 ready accepted는 별개다. 자신의 ack까지 같은 30초 owner와 기존 최대 6회/8초
요청을 유지한다. 같은 ID/reportSeq/domain을 재전송하고 원래 응답을 확인한다. ignored/reconciled/
operation_status applied만으로 serverConfirmed를 설정하지 않는다. 실패/소진은 기존 오류와
명시 재시도이며 자신의 accepted 뒤 타인 pause는 자기 실패가 아니다. 보고 순서는 프로세스 시간
seed와 공용 단조 증가로 controller 재생성의 1부터 재사용을 막는다. persistent JSON은 유지한다.
방/참가/접속 전체 변경은 이전 ack를 무효화한다. 정상 준비에는 새 안내 화면을 만들지 않는다.

LP draw는 gameInstance/phaseSeq/대상과 개별 coordinator가 소유한다. 동일 penalty public/ready/
pause에서 보존하고 회전 callback은 scope를 캡처한다. 중단 중 완료는 현재 ready까지 보관하며,
실패 재시도는 원래 draw/resolve ID다. 새 penalty/종료/새 게임의 이전 Future는 새 pending·오류를
바꾸지 못한다. 서버 권위·pause 검사를 유지한다. [후속 반영 기록](../planning/NETWORK_SESSION_LP_DEVICE_FOLLOWUP_IMPLEMENTATION.md)에 따라 기존 Functions 63개 반영은 완료했다. FULL은 사용자 지시로 보류했고 새 APK의 실기기 결과는 아직 미확인이다.
## 생성·정리·debug 기록

### B1-C 생존 관찰·정리 신호 (2026-10-13 로컬 후보)

태블릿은 playing일 때 현재 참가자 N개의 connected/lastSeen scalar leaf를 구독한다.
휴대폰은 controller 현재 tuple metadata와 그 leaf, 본인 현재 leaf를 구독한다.
players는 profile·membership·접속 상태 전환용이고 정상 heartbeat 시각은 복제하지 않는다.
room/member/id/seq 변경 시 기존 scope를 취소하고 시각을 unknown으로 비운다.
peer 권한 오류는 unknown과 한 번의 10초 재구독으로 처리하며 본인 transport 복구로 승격하지 않는다.
본인 current false는 foreground에서 한 회차 CAS 복구를 시작하지만 의도적으로 paused/detached한
동안에는 자동 복구·heartbeat를 시작하지 않는다. 로비 heartbeat는 계속 10초다.
playing player의 1초 검사, controller의 10초 검사와 age > 20초 조건을 유지한다.
신고는 관찰 당시 current id/seq/lastSeen을 함께 보내고 서버가 같은 root CAS에서 재검증한다.
presence true 자체는 ready가 아니다. timer의 last-normal/first pause/none/0/턴 상한과 ready barrier를 유지한다.

room root runPrimedTransaction은 room parent가 rooms인 경우에만 cleanupSignal을 함께 갱신한다.
신호 계획은 instance/generation/status/current controller tuple·connected/명시 기한/terminal pending이다.
lastSeen·카드·ready·profile 변화는 계획 revision을 바꾸지 않는다. 신호는 advisory index다.
큐는 동일 세대에서 낮은 signal revision을 거절하고, due callback은 자신이 읽은 job의 revision·due·
failure를 비교해 더 새 작업과 backoff를 덮어쓰지 않는다. 최종 삭제는 현재 root CAS에서 판정한다.
현재 leaf만 fresh인 참가자·controller를 frozen 요약 때문에 삭제하지 않는다.
B1 canonical이 없으면 파괴적 정리는 보류하며 legacy 방만 요약 fallback을 사용한다.
controller true라도 3/15분 시각 기한은 적용하고 closed cleanupAt/finished retainUntil을 우선한다.
100개 cursor 순회는 누락된 false projection을 현재 root CAS로 보완한다.

신규 create는 capability 2를 요구하고 room presenceProtocol=2를 server seed한다.
이 방의 join/resume/leave/게임·ready·stale/방 변경은 capability 2가 없으면 upgradeRequired다.
capability는 보안 신원의 증명이 아니며 기존 인증·소유·membership·세대 CAS가 별도로 적용된다.
operation domain fingerprint에서 capability를 제외해 미확정 요청의 의미를 유지한다.
legacy 활성 방을 강제 전환하지 않는다. 기존 APK 호환은 보장하지 않으며 배포 전 drain과
서버·Rules·새 APK의 순서를 별도 승인한다. 정상 HB 호출 0은 두 broad trigger 제거/retarget 후의 계약이다.

roomCreateSlots/roomCreateRequests의 reserved/created/terminal, generation CAS와 tombstone이
늦은 생성 부활과 새 generation의 삭제를 막는다. 부분 매핑 실패는 자신의 방만 terminal로 보상한다.
syncRoomCleanupQueue는 현재 cleanupSignal만 재조회한다. cleanupStaleRealtimeRooms는 due index 최대 300개와
지속 key cursor 100개를 함께 처리한다. waiting 유예는 heartbeat 후 3분, playing/finished는 15분,
명시 close의 물리 정리는 cleanupAt을 따른다. 매핑·예약·slot은 원래 room/generation일 때만 정리한다.
새 생성은 기존 controller 매핑/방의 UID·instance·generation·closed/terminal을 확인한 경우
그 방의 creationOperationId/generation과 일치하는 created 슬롯만 기존 슬롯 CAS에서 교체한다.
미확정 reserved 슬롯과 다른 generation은 유지한다. 종료 방의 보존 기간은 줄이지 않는다.
실패는 backoff/cleanupPending, 최종 tombstone은 최소 식별·generation·종료 정보로 남긴다.
조건부 생성·정리 CAS는 기존 runPrimedTransaction으로 value listener의 서버 값을 받은 뒤 실행한다.
단독 get() 뒤의 초기 빈 SDK 캐시를 실제 부재로 판정하지 않는다. mapping 비교는 key 순서와 무관하며,
정리 첫 key page에는 빈 문자열 경계를 넣지 않고 저장된 cursor가 있을 때만 startAt을 적용한다.
transaction update 예외는 첫 예외를 보관하고 undefined로 abort한다. SDK의 완료·rollback
경로를 await한 뒤 원래 예외를 전파하며 listener는 finally에서 제거한다.

2026-10-12 정리 후보: 같은 allocation의 실패 backoff를 trigger/순회가 앞당기지 않는다.
두 순회 cursor는 읽은 값과 같을 때만 갱신한다. 유령 참가자는 별도
`roomCleanupScan/ghostCursor`로 회당 500개 방을 순회하고 최대 10개 transaction을 병행한다.
기존 5분 주기·유예와 playing 보호는 유지하고 transaction에서 최신 연결·게임 상태를
재판정한다. 일부 실패는 요약하고 다음 전체 순회에서 재처리한다.

같은 terminal allocation이 확인된 created/terminal 생성 요청은 roomCode·instance·generation·
terminal 상태·기존 createdAt만 남긴다. 예약 상태의 직접 축약과 terminal marker 삭제는 하지 않는다.
계정 탈퇴는 신원·세대가 확인된 현재 소유 방을 조건부로 닫고 해당 요청·슬롯을 정리한다.
새 매핑·새 슬롯과 미확정 다른 예약은 보존하며, UID 전체 요청 삭제는 하지 않는다.
고아 예약 해제와 접속/명령 결과 TTL은 보류다. 과거 기록 일괄 축약·배포는 별도 범위이며
[관찰·검증 기록](../operations/RTDB_RETENTION_REVIEW.md)을 따른다.

RecoveryMetrics는 단조 episode/batch와 연결·인증·identity·구독·public/private·에셋·프레임·
ready·barrier·입력 단계를 기록한다. debug event 200개와 독립 요약 50개로 제한한다.
N/A/미완료 및 버퍼 유실을 구분한다. 실제 UID·방/게임/명령 ID·카드·역할·토큰은 기록하지 않는다.
입력 단계는 실제 canSend가 true인 시점에 기록해 서버 ready 수락보다 앞선 성공으로 집계하지 않는다.
release 기록은 비활성이다. 성능 판정은 E14 실기기 측정과 목표 합의가 필요하다.


로비 계측 후보의 debug 클라이언트는 단계별 시간·허용 목록의 오류 코드만 기록한다.
서버 create/close/operation_status는 handler 내부의 고정 단계·시간·성공 여부를
`room_action_timing`으로 기록하며 사용자 식별자나 오류 원문을 포함하지 않는다.
[실측과 개선 범위](../operations/ROOM_ACTION_LATENCY.md)를 따른다. 이는 배포 완료를 뜻하지 않는다.


### 2026-10-10 준비 보고 최초 전송 후속 후보

공용 명령은 Map 예약 전 미확정 여부를 판정한다. 최초 ready/failed 보고는 status 조회
없이 전송하고, 이미 전송한 요청의 응답 유실 재시도만 같은 ID/domain으로 조회·재생한다.
서버 ready 승인 실패 안내는 로컬 화면 준비 실패와 구분하며 늦은 데이터에도 원래 실패
종류를 유지한다. debug 진단은 고정 단계/허용 오류 코드만 기록한다. 모든 필수 기기의
ready 수락 전 pause/입력 보호와 기존 예산은 유지한다. 앱 반영·최종 검증 현황은
[개발팀 공유](NETWORK_LATENCY_IMPROVEMENTS.md#2026-10-10-게임-준비-보고-수정-후보)를 따른다.

### 2026-10-11 LP 분배·로비 복구 후속 후보

LP 분배 중 빈 private map은 RTDB read-back에서 생략될 수 있다. 제외 reducer는
필드 부재에도 pendingHands와 참가자 상태를 정상 정리한다. 직접 퇴장 및 recovery
preview/장식에서 같은 reducer를 사용하고 preview는 원본을 변경하지 않는다.

초기 controller 복구가 미확정이면 로비 생성 조작은 기존 방 복구를 재시도한다.
복구 internal/timeout은 저장 신원·미확정 ID를 유지한다. 저장된 controller 방은
로비에서 명시 종료할 수 있으며 close 확정 뒤에만 로컬 복구 상태를 정리한다.
생성 guard/종료 조건/서버 권한을 우회하지 않는다.

방을 채택하지 않은 휴대폰·태블릿 홈은 로비 연결 띠를 구독하지 않는다. Android의
유휴 RTDB 중단을 인터넷 장애로 오인하지 않기 위한 화면 범위이며, 방 생성/참가/
복구 실패는 기존 작업 오류로 표시한다. 참가 중인 대기실과 게임의 실제 연결·pause·
ready 보호는 유지한다. 띠의 연결 소스가 해제/교체되면 이전 안내 타이머와 상태도
해제하고 이전 소스의 늦은 이벤트는 무시한다. 이는 native 단절 원인 확정이나 배포
완료를 뜻하지 않는다. 검증/반영 현황은 [후속 기록](../planning/tasks/NETWORK_SESSION_20261011_IMPLEMENTATION.md)을 따른다.

LP 정상 시작은 로비 책 위의 `게임 준비 중` 표시를 생략하고, 게임 진입 후 첫 서버 상태는
기존 게임 배경에서 기다린다. 시작 중 입력 잠금·책의 전환 시작 위치 계산과 실제 단절/
준비 실패 안내는 유지한다. 다른 게임의 로비 준비 표시는 변경하지 않는다.

controller는 같은 UID의 player가 방에 참가해 있어도 자신의 phone membership로
채택하지 않는다. player 삭제 확인은 player 역할에만 적용하며, 늦은 확인 결과는
역할·UID·방/session epoch가 유지될 때만 반영한다. controller의 방은 실제 종료/삭제
확인으로 정리한다. 로컬 roomCode가 없더라도 저장된 controller 세션이 남아 있으면
새 생성보다 기존 방 복구를 먼저 시도한다. 서버 활성 방 생성 guard는 유지한다.

설정 완료 뒤 정상 시작 대기는 공용 자리 배치의 게임 배경에서 유지한다. LP/마피아와
공용 phone connecting 단계는 이미 별도 정상 준비 안내를 표시하지 않는다. Final Call과
게임 템플릿의 connecting도 준비 announcement를 명시적으로 끈다. 실제 단절/실패와
ready 입력 보호는 유지한다. 홀덤 단일 기기 보호 문제는 이번 후속 범위에서 제외했다.

### 2026-10-11 최초 준비와 실제 복구 구분 후보

사용자 승인에 따라 `game/public/recovery.purpose`를 선택 필드로 추가한다.
새 게임의 최초 barrier는 `initialReadiness`이며 게임 배경을 유지한다. 필수 기기의
단절·준비 실패가 등록되면 `recovery`로 전환하고, 원인이 해소돼도 전체 ready 완료 전까지
그 목적을 유지한다. 필드 부재·알 수 없는 값·실제 cause가 있는 데이터는 기존 중단
안내를 유지한다. pause/ready/CAS/입력·타이머 계약은 변경하지 않는다. 구버전 앱은 새
필드를 무시하므로 최초 준비 안내가 남을 수 있고, 신버전 앱과 구 서버 조합도 기존
안내를 유지한다. 서버와 앱 모두 반영한 뒤 36번을 다시 판정한다.

현재 세션 조회는 UID만으로 controller를 우선 선택하지 않는다. 유효한 controller
토큰을 제공한 요청만 controller context를 얻고, 나머지는 현재 active player membership을
조회한다. 동일 계정의 두 역할은 각 connectionId/sequence를 유지하며 추방된 phone은
controller context를 얻지 못한다. 잘못된 controller 토큰은 player로 우회하지 않는다.

게임 화면의 controller가 새로 만들어지면 준비 확인은 새 화면의 예산을 사용한다.
방 단위로 보존된 세션의 이전 화면 예산을 재사용해 첫 데이터 수신 즉시 실패시키지
않는다. 진행 중인 방 복구가 있으면 그 복구의 기존 30초 예산은 공유하며, 같은 화면의
데이터 갱신이나 늦은 ready로 실패를 자동 해제하거나 예산을 계속 연장하지 않는다.

Final Call 태블릿은 분배 연출 완료를 시작 시각·라운드로 기억한다. 전체 ready와
pause 해제가 확인된 뒤 분배 완료 명령을 전송하며, 준비 대기 자체는 진행 명령의
재시도 횟수를 소모하지 않는다. 같은 완료는 한 번만 처리하고 새 판·라운드나 화면
종료 후에는 옛 완료를 전송하지 않는다. 서버의 단계·세션 검증은 그대로 적용한다.
