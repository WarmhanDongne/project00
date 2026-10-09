# 네트워크·세션 구현 계약

2026-10-09 E02~E12 로컬 구현 후보의 계약이다. 배포 여부를 뜻하지 않는다.
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

클라이언트는 자신의 현재 connections 노드의 connected/lastSeen만 갱신한다.
서버 선택 접속과 membership/room이 일치해야 rules와 syncRealtimeRoomConnection이 반영한다.
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
| leaveRealtimeRoom 및 게임별 leave | 원래 roomInstanceId·membershipId·operationId | 원래 자격만 제거. applied/stale 확인 후 intent/identity 정리 |
| closeRoom | 원래 roomInstanceId, controller token, operationId | 같은 방만 close. 응답 유실은 결과 조회 우선 |
| fetchRealtimeRoomGroupEntitlements | roomInstanceId, 현재 방 참가 자격 | 구매 조회 전후 revision/자격 검사. 다른 방 controller라도 현재 참가자는 조회 가능 |

UID/역할별 identity와 미확정 transport/durable 작업은 직렬 저장한다.
저장 실패면 전송하지 않으며 결과 미확정 기록은 TTL로 버리지 않는다.
퇴장 의도가 남으면 자동 참가·heartbeat보다 결과 확인을 먼저 한다.
join/resume 재생은 최신 접속을 되돌리지 않는다. 현재 sequence를 읽어 새 복구 작업을 만든다.

## 공용 게임 중단과 명령

네 게임 실제 reducer를 game-command-transaction과 game-mutation에 연결한다.
callback 재실행은 동일 수락 시각과 난수 seed를 사용한다. 공개 변경과 필수 private._context를
같은 gameInstanceId/phaseSeq/turnSeq/dataSeq 네 값으로 저장한다.
resumeEpoch는 공개 barrier와 준비 보고에만 사용하며 private 대응 조건에 넣지 않는다. 시작은 새 gameInstanceId,
단계·라운드·핸드·재판 변화는 phaseSeq, 턴 변화는 turnSeq를 갱신한다.

현재 방·자격·접속·game/phase/turn을 검증하고 paused 진행을 거절한다.
중복 명령은 UID·종류·domain이 같아야 기존 결과를 반환한다.
저장한 domain/ID는 자동·수동 재시도에서 유지한다. 종료·자기 퇴장·복구 선택은 pause 중에도 서버 검증을 거친다.

최초 실패만 public.recovery.paused/pauseId/pausedAt 및 server.recovery.timer를 만든다.
timer는 kind=none 또는 kind=remaining으로 저장해 RTDB의 null 생략에도 마감 없음과 0ms 남음을 구분한다.
추가 원인은 최초 남은 시간을 덮어쓰지 않는다. 생략된 빈 causes/ready는 빈 집합으로 처리한다.

| 공용 callable | 역할과 결과 |
| --- | --- |
| game_common_recovery_report | 현재 접속 ready/failed와 reportSeq. failed에는 알려진 game ID만으로 보고 가능 |
| game_common_interruption_report_stale_player | controller가 관찰한 접속·sequence·lastSeen이 현재와 같을 때 실패 원인 추가 |
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
| 소진 뒤 | 미확정 ID/domain 유지, 결과 확인 후 실제 수동 재시도 |
| 재연결/foreground | UID·방·수명 확인 후 새 제한 묶음; 중첩 소유자 없음 |

완료된 owner를 긴 구독이 상속하지 않는다. 늦은 operation의 이어 실행은 원래 deadline을 유지한다.
소진된 request는 새 호출을 시작하지 않는다. AppNetworkGuard/GameRecoveryLayer는 주 안내 하나로 입력을 막는다.
자기 퇴장은 처음부터, 상세 재시도는 10초 뒤, 서버 pause는 즉시 표시한다.
phone은 자기 퇴장만, controller는 실제 제외·한 번 연장·확인 후 종료를 선택한다.
정상 캐시는 재다운로드하지 않는다. 누락/손상 파일만 동의 후 복구하고 디코딩·프레임을 다시 준비한다.
route 완료와 게임 정리는 캡처한 game ID로 처리한다.

## 생성·정리·debug 기록

roomCreateSlots/roomCreateRequests의 reserved/created/terminal, generation CAS와 tombstone이
늦은 생성 부활과 새 generation의 삭제를 막는다. 부분 매핑 실패는 자신의 방만 terminal로 보상한다.
syncRoomCleanupQueue는 현재 방을 재조회한다. cleanupStaleRealtimeRooms는 due index 최대 300개와
지속 key cursor 100개를 함께 처리한다. waiting 유예는 heartbeat 후 3분, playing/finished는 15분,
명시 close는 cleanupAt을 따른다. 매핑·예약·slot은 원래 room/generation일 때만 정리한다.
실패는 backoff/cleanupPending, 최종 tombstone은 최소 식별·generation·종료 정보로 남긴다.
조건부 생성·정리 CAS는 기존 runPrimedTransaction으로 value listener의 서버 값을 받은 뒤 실행한다.
단독 get() 뒤의 초기 빈 SDK 캐시를 실제 부재로 판정하지 않는다. mapping 비교는 key 순서와 무관하며,
정리 첫 key page에는 빈 문자열 경계를 넣지 않고 저장된 cursor가 있을 때만 startAt을 적용한다.

RecoveryMetrics는 단조 episode/batch와 연결·인증·identity·구독·public/private·에셋·프레임·
ready·barrier·입력 단계를 기록한다. debug event 200개와 독립 요약 50개로 제한한다.
N/A/미완료 및 버퍼 유실을 구분한다. 실제 UID·방/게임/명령 ID·카드·역할·토큰은 기록하지 않는다.
입력 단계는 실제 canSend가 true인 시점에 기록해 서버 ready 수락보다 앞선 성공으로 집계하지 않는다.
release 기록은 비활성이다. 성능 판정은 E14 실기기 측정과 목표 합의가 필요하다.
