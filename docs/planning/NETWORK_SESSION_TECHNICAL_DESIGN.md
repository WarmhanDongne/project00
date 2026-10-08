# 네트워크·세션 기술 설계안 — R11~R15

[제품 정책·시나리오](NETWORK_SESSION_DESIGN.md) · [작업 묶음](NETWORK_SESSION_TASKS.md) · [작업 관리](TASK_MANAGEMENT.md)

2026-10-09 작성. 사용자가 합의한 제품 정책을 구현 가능한 계약으로 구체화한 기술 설계안이다.
후속 사용자 답변으로 A 준비/접속 식별, B 퇴장 의도 저장, C terminal/정리 방식의 권장안을 채택했다.
아래 API·필드·상태 전이는 채택한 방식의 계약안이며 실제 구현된 기능이나 검증 결과로 표현하지 않는다.
구버전 앱 호환·shim·최소 앱 버전 제한은 사용자 지정으로 제외한다. 현재 앱·서버 내부의 정합성은 검토한다.
담당·구현 채팅·최종 테스트 계획 R16~R18은 이 기술안 검토 뒤 확정한다.
R16~R18의 [실행 계획 초안](NETWORK_SESSION_IMPLEMENTATION_PLAN.md)은 후속 사용자 요청으로 작성했다.
코드 기준은 최신 newgui다. E00에서는 착수 최신 SHA/후속 변경과 담당을 확인한다. 개발 시작 지시는 아직 없다.
같은 날 사용자 검토를 반영해 행동 후 데이터 대응, 연결 유지 중 준비 실패, 화면 이동/안내,
최초 오프라인/온보딩 복구, terminal 정리 대상 선정과 복구 측정 지점을 보충했다. 상위 제품 합의는 유지한다.

## 1. 근거와 적용 범위

현재 checkout은 `review/#136-wirte-task-list`, HEAD `172b26205eb1e7c2b1eb480c71597cfebcc4c930`이다.
newgui 후보는 로컬 `origin/newgui`의 `999c3e99086b9f917ea941cd8f283b8ac40f3f85`를 `git show`로 비교했다.
후보 fetch·checkout·병합, 제품 코드 변경, 테스트 실행, production 조회·배포는 하지 않았다.

| 구분 | 확인한 근거 | 설계에 주는 영향 |
| --- | --- | --- |
| 기존 계약 | [game-interruption/state.ts](../../functions/src/game-interruption/state.ts)는 참가자 1명만 저장하고 연결 true에서 해제한다. [controller-presence.ts](../../functions/src/game-interruption/controller-presence.ts)는 별도 시간 슬롯을 사용한다 | 중단 원인 집합과 시간 보관 슬롯을 통합해야 다중 단절·준비 대기를 일관되게 처리할 수 있음 |
| 기존 계약과 합의의 차이 | [expire-resolution.ts](../../functions/src/game-interruption/expire-resolution.ts)·[expire-scheduler.ts](../../functions/src/game-interruption/expire-scheduler.ts)는 만료 후 자동 제외/종료한다 | 만료는 진행자 선택 가능 상태만 만들도록 교체. 방 보존/정리 정책과 구분 |
| 기존 공용 기반 | [game_session_controller.dart](../../packages/game_kit/lib/recovery/providers/game_session_controller.dart)는 public/private 구독·public 세대 검사를 소유하지만 명시적 구독 재생성·전체 준비 완료 계약이 없음 | 구독 복구와 준비 결과를 공용 계약에 추가. 게임별 필드 해석은 각 게임 adapter가 담당 |
| 기존 진행 요청 | [game_progress_command.dart](../../packages/game_kit/lib/recovery/services/game_progress_command.dart)는 실패 후 3초 무제한 재예약. 기존 LP/FC complete_dealing에 예상 판·라운드 검증이 없음 | 합의한 유한 재시도·처리 확인·태블릿 수동 재시도로 교체. 이미 보낸 옛 요청은 서버에서 차단 |
| 퇴장 차이 | [RoomProvider](../../lib/platform/home/room/providers/room_provider.dart)의 조회 실패는 false, 이후 의도 해제·heartbeat 재시작. [RoomLeaveIntent](../../lib/platform/home/room/services/room_leave_intent.dart)는 메모리 Set | 결과를 3가지로 구분하고 요청 전 로컬 저장. 복구와 퇴장 확인을 같은 조율자가 선택 |
| 인원 규칙 | [Final Call 제외](../../functions/src/final-call/exclude-player.ts)는 실제 퇴장 시 팀 구성 파괴로 종료. [Mafia 제외](../../functions/src/mafia/exclude-player.ts)는 단계·최소 인원·승패를 검사 | 공통 숫자 비교로 계속 가능 여부를 판단하면 안 됨. 기존 게임 전이의 결과를 미리 판단하는 adapter 필요 |
| 후보의 차이 | newgui Holdem `game.ts`는 제외 때 정산 전 stack>0 인원으로 종료를 판단. `act.ts`는 revision 검사와 명령 결과 보관, complete_dealing/result는 예상 게임·핸드 검증이 없음 | 현재 핸드의 팟 자격과 다음 핸드의 칩 보유 인원을 분리. 완료 요청에도 같은 서버 검증 적용 |
| 방/권한 | [realtime-room-functions.ts](../../functions/src/room/realtime-room-functions.ts)는 예약→방→controller 매핑을 별도 처리. [그룹 조회](../../functions/src/room/realtime-room-lifecycle.ts)는 요청 UID의 controllerRooms로 방을 선택 | 요청 방의 멤버십 조회로 수정. 생성의 부분 실패·삭제 뒤 지연 생성은 별도 계약으로 보호 |
| rules | [database.rules.json](../../database.rules.json)은 public/private/server를 분리하고 현재 presence 경로만 클라이언트 쓰기 허용 | 준비·게임 중단·명령 결과를 클라이언트 쓰기로 열지 않음. 새 접속 경로만 제한적으로 검토 |
| 최초 오프라인 | [태블릿 홈](../../lib/platform/home/tablet/screens/tablet_home.dart)은 초기 restoreControllerRoom을 호출하지만, 실패 후 메모리 roomCode가 없는 상태의 복원 재시작 계약은 없음 | 저장 세션에 대한 pending restore를 연결/인증 준비와 함께 재평가해야 함 |
| 온보딩 결함 | [AuthGate](../../lib/platform/auth/widgets/auth_gate.dart)는 watcher 오류 후 성공 데이터가 와도 failed를 해제하지 않으며 callback에 UID/generation 검사가 없음 | 정상 수신의 오류 해제와 이전 계정/구독/timeout 결과 폐기 필요. newgui 후보의 timeout 보완만으로 해결되지 않음 |
| 방 정리의 기존 경계 | [정리 scheduler](../../functions/src/room/realtime-room-lifecycle.ts)는 cleanupAt/lastSeen별 첫 500개를 조회하고 실제 방 노드를 삭제함 | terminal 최소 기록을 도입한다면 조회 대상 선정도 바꿔야 함. 기존 쿼리에서 terminal을 건너뛰기만 하면 충분하지 않음 |
| 측정의 기존 경계 | [GameCommunicationLog](../../packages/game_kit/lib/core/diagnostics/game_communication_log.dart)는 debug 전용 최근 200개 기록 | 구간 시작/끝과 요약 보존을 추가해야 복구 시간을 비교할 수 있음. 현재 실측 성능 근거는 없음 |

이 표는 정적 확인이다. 실기기 발생 빈도·실패 재현·함수 배포 상태·측정 성능을 확인한 결과는 아니다.

## 2. 공통 식별·변경 단위 제안

시간값 하나나 roomCode만으로 늦은 요청을 구분하지 않는다. 아래 식별자는 인증을 대신하지 않는다.
callable은 매번 Firebase Auth UID와 현재 서버 자격을 먼저 검증한다.

| 식별자 | 생성·변경 기준 | 용도 |
| --- | --- | --- |
| roomInstanceId | 서버가 실제 새 방을 생성할 때 발급. 코드 재사용 시 새 값 | 같은 roomCode의 옛 방과 새 방 구분 |
| gameInstanceId | 게임 시작·다시하기 때 서버 발급. 다음 라운드/핸드는 같은 값 | startedAt은 표시/진단에 유지하되 명령·복구의 유일한 판 식별자로 사용하지 않음 |
| membershipId | 실제 신규 참가 때 발급, reconnectOnly에서는 유지 | 퇴장 요청이 같은 UID의 재가입을 제거하지 못하게 함 |
| connectionId·connectionSeq | 접속 복구의 새 transport 세션 때 발급/증가, 같은 복구 작업 재전송은 같은 결과 | 옛 onDisconnect·heartbeat·준비 결과와 현재 접속 구분 |
| controllerSessionId | 현재 controller 소유권 계약 유지 | UID와 함께 진행자 권한 확인. connectionId와 별개의 소유권 정보 |
| phaseSeq·turnSeq | 실제 단계/세부 단계 전이·새 턴 때 증가. 같은 phase 이름 반복도 새 값 | 게임별 round/handNumber·trial/night 세부 단계와 함께 옛 진행/행동 요청 차단 |
| dataSeq | 게임 의미 상태가 변할 때 증가. presence/준비 응답만으로는 증가시키지 않음 | public와 본인 private의 대응 확인. 기존 revision은 전체 공개 갱신 순서로 유지 |
| resumeEpoch | 최초 중단과 중단 중 게임 의미 상태/필수 대상 집합 변경 시 증가 | 같은 준비 barrier에 대한 보고인지 확인. 추가 단절만으로 모든 정상 기기의 준비를 다시 초기화하지 않음 |
| incidentId | 참가자의 같은 단절/준비 실패가 시작될 때 발급 | 기본 60초·연장 1회의 대상. 복구 시도마다 바꾸지 않음 |
| commandId·operationId | 논리 명령을 만들 때 한 번 발급 | 전송 재시도·중복 클릭에서 같은 작업의 결과 반환 |

서버 상태 변경은 현재 게임 쓰기 경계인 `rooms/{roomCode}`의 primed transaction 안에서 처리한다.
순수 reducer는 입력 상태·서버 시각·명령을 받아 새 상태와 응답을 만든다. transaction callback에서
랜덤 결과 생성·외부 조회·알림 같은 부수 효과를 반복하지 않는다. UUID·카드/추첨 결과는 재실행에도 고정되게 준비한다.
roomInstanceId·gameInstanceId·dataSeq 등은 신규 persistent/API 계약이므로 검토 후 구현한다.

## 3. R11 — 준비 확인과 서버 재개

### 3.1 책임 분리

| 계층 | 책임 |
| --- | --- |
| 플랫폼 복구 조율자 | UID·방/참가 자격·controller 권한·접속 수명·복귀 선택·퇴장 의도. 게임별 private 필드 해석은 하지 않음 |
| game_kit 세션 기반 | public/private 구독 한 벌·재생성·세대 무효화·준비 보고·입력 잠금·진행 요청 수명 |
| 게임 adapter | 역할·단계별 필수 데이터, 정상 빈 값, 사용할 화면 상태·최소 필수 에셋, 게임별 계속 가능 여부 |
| 서버 공용 reducer | 현재 자격·연결·준비 보고의 식별/최신성 확인, 필수 대상 집합·중단 원인·마지막 재개 판정 |

플랫폼과 게임은 주입된 공용 계약으로 통신한다. game_kit/게임에서 `lib/platform`를 import하지 않는다.
기존 GameRoomContext와 GameSessionController에 필요한 준비/복구 callback을 확장하는 안을 우선 검토한다.
새 조율자의 이름과 파일 배치는 제안이며 R16에서 담당을 지정한다.

### 3.2 필수 준비 목록

모든 필수 기기는 현재 방/게임 식별, 유효 자격, 현재 public와 지속 구독, 사용 가능한 화면,
필수 에셋 준비를 갖춘다. 태블릿은 타 참가자의 private를 읽거나 준비 증거에 담지 않는다.

| 게임·단계 | 생존 휴대폰의 추가 필수 데이터 | 정상 빈 값·태블릿 조건 |
| --- | --- | --- |
| LP dealing | 현재 분배 대기 화면에 필요한 public. private 손패는 아직 필수가 아님 | pendingHands가 server에 있고 private가 없는 상태는 정상. 태블릿은 해당 단계 화면/완료 요청 수명 준비 |
| LP playing·lastCardChallenge·penalty | 본인 hand와 공개 턴/선택/벌칙 상태 | 남은 카드 0이면 빈 hand 허용. missing private와 빈 손패를 명시적 메타데이터로 구분 |
| FC dealing | 현재 분배 대기 public, 아직 공개하지 않은 손패를 요구하지 않음 | pendingHands 대기 정상. 공개되기 전 카드를 복구 목적으로 앞당겨 전달하지 않음 |
| FC playing·callerSubmit·finalTurns·finalSubmit | 본인 hand·필요한 pendingDraw·제출 상태와 공개 단계 | pendingDraw가 없는 정상 상태 허용. 제출 후 잠금/다른 턴을 준비 실패로 보지 않음 |
| FC roundResult | 결과 화면에 필요한 public와 본인 상태 | 서버가 결과를 공개한 범위만 사용. 이미 끝난 연출을 준비 조건으로 재생하지 않음 |
| Mafia roleReveal·night·morning·day·voting·voteResult | 본인 roleId·해당 단계의 능력/선택/투표 상태와 public | 행동 대상 미선택·제출 완료·능력 없음은 정상. trial 단계·밤 세부 단계도 식별. 다른 사람 역할/선택은 준비 보고에 싣지 않음 |
| Holdem dealing·preflop·flop·turn·river | 후보는 dealing부터 본인 hand가 존재. 이후 현재 hand·legalActions와 public 보드/팟/턴 | folded/allIn의 legalActions 없음은 정상. allIn stack=0을 손패 불필요/탈락으로 오인하지 않음 |
| Holdem handResult | public 결과·본인 표시 데이터 | 폴드 승리 때 공개되지 않은 타인 손패는 요구하지 않음 |
| 사망/탈락/관전 | 본인 화면에 필요한 public/private로 로컬 복구 | 전체 재개 필수 대상에는 포함하지 않음. 본인 입력 보호·비공개 경계는 유지 |
| finished | 기존 결과/종료 안내에 필요한 데이터 | 게임 재개 대상이 아님 |

다운로드 게임은 로컬 manifest·필수 버전·크기/해시 검증을 포함한다. 번들 게임은 prepareGame의
빈 작업만으로 화면 준비를 보증하지 않고, 필수 이미지의 읽기/디코딩 결과를 게임 adapter가 보고한다.
장식 효과·배경 음악·완료된 시작 연출은 필수가 아니다. 파일 예외가 확인될 때만 합의한 동의 후 복구를 제공한다.

### 3.3 같은 상태의 public/private 확인

public에 gameInstanceId·phaseSeq·turnSeq·dataSeq를 넣고, private가 필요한 대상에는 본인 private의
`_context` 메타데이터를 넣는 안을 제안한다. 메타데이터와 실제 private는 같은 room transaction에서 갱신한다.
빈 hand도 메타데이터 노드는 남기므로 RTDB가 빈 객체를 없앤 경우와 누락을 구분할 수 있다.
dealing처럼 private가 아직 불필요한 단계는 adapter의 `privateRequirement=none`으로 판단한다.

게임 의미 상태를 바꾸는 transaction은 dataSeq를 한 번 증가시키고 **새 단계에서 private가 필요한 모든 대상의
메타데이터도 같은 값으로 갱신**한다. 실제 손패/역할/선택 내용이 바뀐 사람만 갱신하는 방식은 금지한다.
private의 phaseSeq/turnSeq도 해당 public에 대응시킨다. 메타데이터 갱신은 비공개 내용 공개나 재분배를 뜻하지 않는다.
서버의 게임별 mutation 경계를 통해 이 불변식을 유지하고, 명령 결과만 따로 저장하는 갱신·heartbeat·준비 보고·
대기 만료 안내는 dataSeq를 올리지 않는다. 새 단계에서 private가 불필요해지면 그 단계의 adapter 규칙을 적용한다.

예: A가 행동해 public dataSeq가 10→11이 되고 B의 손패가 그대로여도 B private의 `_context.dataSeq`는 11이다.
B는 public 11과 private 11을 조합해 계속 사용한다. 손패 내용의 변화나 모든 사람의 ready 호출을 기다리지 않는다.
B private 메타데이터가 10에 머문 상태는 정상 손패와 구분되는 대응 실패로 확인/복구한다.

구독 두 개의 이벤트 순서는 보장되지 않는 것으로 설계한다. 클라이언트는 방/게임/구독 generation별로
최신 public와 본인 private를 조합하며, 더 새로운 값이 관측됐으면 옛 일치 조합으로 입력을 다시 풀지 않는다.
역순·옛 판 private는 폐기한다. 단계의 필수 데이터와 최신 조합이 맞을 때 `localUsable=true`가 된다.

`localUsable`과 서버 중단/초기 진입의 `barrierReady`를 구분한다. 정상 행동마다 dataSeq가 바뀌는 것은
로컬 대응을 다시 확인하는 계기이며 전체 중단이나 전 기기 ready 왕복의 계기가 아니다.
barrier 안에서 게임 의미 상태/필수 대상이 바뀌면 resumeEpoch도 바꾸고 새 대상 상태를 확인한다.
추가 단절·준비 보고만으로 정상 기기의 유효한 barrier 응답을 다시 요구하지 않는다.

이벤트 한쪽을 기다리는 정상 구간은 입력 보호와 동기화 상태로 처리한다. 불일치가 계속되면 공용 최대 30초
준비 복구 묶음 안에서 현재 상태 조회/필요 구독 재생성을 수행하고, 일치하면 즉시 끝낸다.
새 dataSeq가 도착할 때마다 해결되지 않은 불일치의 예산을 초기화하지 않는다. 단순 이벤트 대기만으로
참가자 incident를 만들지 않지만, 묶음 소진 후에도 현재 필수 화면을 사용할 수 없으면 failed를 보고한다.
구독 종료·권한/파싱 오류·필수 파일 오류처럼 실제 실패가 확인되면 30초를 기다리지 않고 아래 절차를 따른다.

### 3.4 준비 보고 API 제안

`game_common_recovery_report`라는 공용 callable 한 개에 `ready` / `failed` 보고를 제안한다.
공통 요청은 roomInstanceId·gameInstanceId·membership/controller 자격·connectionId/Seq,
명령 식별자·reportSeq와 최소 결과다. UID는 auth에서 취하고 역할은 서버에서 결정한다.
ready는 현재 resumeEpoch·phaseSeq·turnSeq·dataSeq와 필수 준비 결과가 모두 필요하다.
failed는 마지막 관측 상태와 오류 종류를 선택적으로 보내며 최신 public/private의 확보를 전제하지 않는다.
데이터를 못 읽는 기기에 최신 데이터 준비 증명을 요구해 실패 보고 자체를 막지 않는다.
같은 접속의 준비/실패 보고에는 단조 증가하는 reportSeq를 붙인다. 서버는 더 낮은 보고를 무시하므로
화면 실패 뒤 늦은 이전 ready 요청이 도착해 준비 실패를 다시 해제하지 못한다.
같은 operation 재전송은 reportSeq를 다시 만들지 않는다. 높은 번호의 ready라도 상태 식별이 맞지 않으면
barrier 준비로 인정하지 않고 현재 context를 돌려준다. 보고 순서 정보와 유효한 준비 증거를 분리해서 보관한다.
화면 표시 가능 여부와 필수 파일 성공 여부는 신뢰한 앱의 보고이며 서버가 실제 픽셀·로컬 파일을 검증한 증거는 아니다.
서버가 증명할 수 있는 자격·상태 식별·필수 private 존재·접속 상태는 별도로 검사한다.

서버는 준비 보고를 현재 connection과 barrier에 연결해 저장한다. first pause에서는 모든 필수 기기의
새 barrier 준비를 확인한다. 정상 온라인 기기도 화면을 폐기하지 않고 현재 데이터 대응을 확인해 응답한다.
다른 원인이 추가돼도 이미 유효한 정상 기기의 준비는 유지한다. 해당 기기의 재단절·세션/단계 변경은 무효화한다.
준비 보고 때문에 dataSeq/resumeEpoch를 계속 증가시켜 다시 준비를 요구하는 순환을 만들지 않는다.

재개 transaction은 다음을 한 번에 다시 검사한다: 방/게임 유효, 종료/퇴장 우선 처리 없음,
태블릿·필수 생존 참가자 자격과 최신 접속, 같은 barrier의 유효한 준비, 남은 중단 원인 없음.
통과하면 타이머 복원과 공개 resume 상태를 함께 commit한다. 준비 callable의 단순 성공 응답만으로
입력을 풀지 않고, 현재 판의 서버 resume 상태와 로컬 데이터 준비가 모두 일치할 때 푼다.
내 준비가 끝났고 다른 기기를 기다리는 상태는 내 자동 복구 성공으로 처리한다. 다른 기기의 대기로
내 30초를 소진하거나 정상 기기에 계속 재시도 안내를 띄우지 않는다.

### 3.5 접속 세대와 재구독

현재 단일 isConnected에 옛 onDisconnect가 쓰면 새 접속을 구분할 정보가 없다.
따라서 참가자·controller 모두 접속별 presence 경로와 서버가 선택한 currentConnectionId를 제안한다.
각 SDK onDisconnect는 자기 connectionId 경로만 false로 바꾸고, 서버는 현재 접속의 이벤트만 반영한다.
서버 재개와 명령은 요약 connected 값만 믿지 않고 현재 connection 경로도 확인한다.
heartbeat stale 판정은 기존 20초 기준 등 현재 감지 정책을 유지하고 최신 연결/lastSeen을 transaction에서 재검사한다.

새 접속 할당은 기존 join/resume callable에서 같은 recoveryOperationId 재시도에 같은 결과를 반환하도록 한다.
새 접속 요청에는 expectedConnectionSeq를 포함하고 현재 세대와 CAS로 대조한다. 더 새로운 복구가 이미
할당됐으면 옛 요청이 다음 세대를 다시 발급하지 못한다. 앱 재실행은 저장된 membership/접속 정보를
서버로 확인한 뒤 현재 세대에 대해 요청하며, 결과 미확정인 할당은 기존 operation 결과부터 확인한다.
한 UID·역할의 현재 접속은 하나로 두고 옛 접속의 ready/heartbeat는 무시한다. 이 소유권 범위의 API 변경을 검토받는다.
복구 중 연결 세대가 바뀌면 이전 Future의 화면 효과만 폐기한다. 이미 서버에 도착한 명령 처리는 R13 결과 확인을 따른다.
구독 복구는 필요한 public/private를 취소 후 한 번 재생성하고, 정상 구독을 위젯마다 추가하지 않는다.
private 이벤트에도 gameInstanceId·dataSeq·로컬 subscription generation 검사를 적용한다.
현재 판의 필수 game route를 벗어나거나 화면이 폐기되면 로컬 ready를 무효화하고 플랫폼이 준비 상실을 보고한다.
이미 종료/퇴장 처리 중이면 해당 종료 흐름이 우선한다. 태블릿 상세·스토어에서 복귀를 묻는 동안에는
게임 화면 ready를 보고하지 않으며 동의 후 준비한다. 거절하면 복구 대신 지속 퇴장 intent를 생성한다.

### 3.6 연결 유지 중 준비 실패에서 서버 중단까지

1. game_kit/게임 adapter가 실제 필수 준비 상실을 확인하면 즉시 본인 입력과 자동 진행 요청을 막는다.
   플랫폼에 실패 종류를 전달하고 현재 connection의 단일 보고 소유자가 failed를 전송한다.
   명령 하나의 실패나 정상 빈 private는 이 경로를 시작하지 않는다.
2. 서버는 인증·현재 방/게임·멤버/역할·connection·보고 순서를 검사한다. 옛 판·퇴장자·옛 접속의 실패는
   현재 판을 중단시키지 않는다. 데이터가 없다는 보고는 현재 자격 검사를 통과해야 하며 클라이언트 시각을 신뢰하지 않는다.
3. 필수 태블릿/생존 참가자의 유효한 실패는 room transaction에서 중단 원인으로 반영한다.
   최초 중단이면 **그 transaction의 serverNow**에 남은 시간을 보관하고 deadline 제거·barrier를 함께 commit한다.
   참가자 incident의 기본 60초도 이 서버 확정에서 시작한다. 기존 incident/보존 시간은 덮어쓰지 않는다.
   사망/관전 기기 실패는 본인 복구만 수행한다. 이미 finished/terminal이면 종료 결과를 반환한다.
4. 서버 pause를 받은 모든 필수 기기는 현재 barrier 준비를 확인한다. 실패 기기는 파일/구독/화면을 복구한 뒤
   더 높은 reportSeq의 ready를 보낸다. 연결 true만으로 원인을 지우지 않으며 최종 재개는 3.4의 transaction이 담당한다.

failed 전송/응답이 실패하면 본인 입력 보호와 **중단 확인 중** 안내를 유지한다. 서버 pause 관측이나
해당 작업의 서버 결과 확인 전에는 전체 게임이 멈췄다고 표시하지 않는다. 동일 작업의 확인/재전송은
요청별 8초·전체 30초 복구 예산을 사용하고 오프라인에는 추가 요청을 멈춘다.
이 지연 동안 다른 기기에서 진행된 상태/시간을 소급 취소하지 않는다.
이미 준비 복구 묶음이 실행 중이면 실패 보고/결과 확인도 그 잔여 예산을 공유하며 새 30초를 중첩하지 않는다.
한도 소진 때 아직 보내지 못한 failed는 보류 결과로 남긴다. 수동 재시도/실제 재연결 등 합의한 새 묶음의
시작 조건에서 먼저 확인/전송하고, 그 전에는 중단 미확정과 입력 보호를 유지한다.

failed 결과 전에 로컬 준비가 회복돼도 불명확한 중단을 임의 해제하지 않는다. 현재 상태를 확인해 새 ready를 보낸다.
서버는 현재 connection의 높은 보고 순서를 보존해 늦은 failed가 새 보고를 덮지 못하게 하고,
이미 생긴 barrier에는 최신 context의 ready를 다시 요구한다. 아직 barrier가 없는 경우의 상태 확인 응답은
전체 재개의 증거로 쓰지 않는다. 이 역순 처리를 report/status API와 함께 구현·검증한다.

### 3.7 최초 오프라인 실행 뒤 세션 복원

플랫폼에 저장 세션의 `pendingRestore`를 둔다. 메모리 roomCode가 생긴 뒤의 재연결만 처리하지 않는다.
[RealtimeConnectionMonitor](../../packages/game_kit/lib/recovery/services/realtime_connection_monitor.dart)의 현재 연결값,
저장 세션 읽기 완료, 인증 UID 준비, foreground를 함께 평가한다. 저장/인증 준비보다 먼저 true가 왔어도
나중에 조건을 다시 평가하므로 다음 false→true 이벤트를 기다리지 않는다.

| 상태 | 처리 |
| --- | --- |
| 최초 오프라인·저장 세션 있음 | pending 유지·오프라인 안내. 세션 삭제/새 방 생성/반복 callable 없음 |
| 조건 충족·미확정 퇴장 있음 | 퇴장 결과 확인 우선. 자동 restore/join 금지 |
| 조건 충족·태블릿 세션 있음 | 메모리 roomCode가 없어도 저장 세션으로 서버 확인/복원. 상세·스토어가 열렸으면 합의한 복귀 질문 적용 |
| 조건 충족·휴대폰 세션 있음 | 복원 가능한 대상 확인 후 재참여 질문. 동의 전 자동 join/input/ready 금지 |
| 통신 실패·30초 소진 | pending 보존·수동 재시도. 실제 재연결/foreground 복귀는 기존 조건에 따라 새 제한 묶음 |
| 서버가 해당 대상 종료/제거/자격 상실 확정 | 해당 저장 세션만 정리하고 합의한 목적지/사유 표시. 조회 실패와 구분 |

UID·역할·저장 방 identity별 소유자 하나가 초기 호출/연결 이벤트/수동 버튼을 합친다.
다른 계정, 화면 폐기, 더 최신 복원 세대의 옛 응답은 버린다. 복원이 끝나면 pending을 해제한다.
현재 [RoomProvider](../../lib/platform/home/room/providers/room_provider.dart)의 일회 restore와
[휴대폰 홈](../../lib/platform/home/phone/screens/phone_home.dart)의 복귀 확인을 이 계약에 연결한다.
태블릿의 누락 데이터 대기를 위해 독립 150ms 재예약 루프를 늘리지 않고 준비 조건 변화로 재평가한다.

### 3.8 온보딩 오류 회복과 watcher 수명

[AuthGate](../../lib/platform/auth/widgets/auth_gate.dart)의 각 watcher에 UID·watchGeneration을,
초기화 timeout에 단계/generation을 붙인다. 데이터/error/onDone/timeout callback 모두 현재 값과 비교한다.
이전 계정·폐기한 watcher의 응답이나 8초 timeout이 새 계정의 오류·화면 상태를 바꾸지 못하게 한다.

현재 watcher에서 유효한 온보딩 데이터를 받으면 loaded=true와 **failed=false를 함께 반영**하고 해당 timeout을 끝낸다.
이미 오류 화면이어도 complete/settingPassword/settingProfile의 기존 화면 분기로 다시 평가한다.
회복만으로 로그아웃/사용자 문서 초기화/홈 이동을 추가하지 않는다. 현재 Auth 복원 timeout의 별도 정책 변경은 이 보충의 범위가 아니다.

[OnboardingService](../../lib/platform/auth/services/onboarding_service.dart)의 활성 Firestore watcher와 기존 제한 재시도를
우선 사용한다. 최종 오류/onDone으로 끝난 watcher는 수동 재시도 또는 연결/foreground 조건 충족 때 한 번 재생성한다.
활성 구독이 정상 회복 중이면 새 구독을 병렬 생성하지 않는다. 재시도 소유자에게 잔여 예산을 전달해 내부 재시도와 중첩하지 않는다.
RTDB connected=true는 재평가 계기이며 Firestore 온보딩 정상 수신의 증거가 아니다.

문서 없음(null)은 서버 확인된 부재와 오프라인/캐시만의 미확정을 구분하는 내부 관측 정보가 필요하다.
미확정 null로 legacy 온보딩 전환/새 등록을 시작하지 않고 보호 상태에서 확인한다. 서버 확인된 부재만 기존 처리로 넘긴다.
새 사용자 schema나 온보딩 제품 단계를 만들지 않는다. 명시적 온보딩 실패를 세션 준비 성공으로 오인하지 않는다.

## 4. R12 — 다중 중단·시간·진행자 선택

### 4.1 저장 모양 제안

| 위치 | 내용 | 공개 범위 |
| --- | --- | --- |
| game/public/recovery | pauseId, resumeEpoch, pausedAt, paused/awaitingDecision 상태, 기기별 공개 원인·참가자 incidentId·기본/연장 마감·연장 사용 여부·계속 가능 사유 | 방의 허용된 소비자. 손패/역할/토큰 없음 |
| game/server/recovery | 유효한 ready 보고, 현재 필수 대상·접속 식별, 단일 보존 타이머, 처리한 선택 ID | 서버 전용 |
| game/public/turnDeadlineAt | 정상 진행 때만 활성 deadline. 중단 중에는 없음 | 기존 공개 타이머 |

기기별 원인은 disconnected / preparationFailed를 구분한다. 동일 기기의 원인이 바뀌거나 겹쳐도
필수 준비까지 같은 incidentId와 최초 마감을 유지한다. 명시적 self leave는 R13에서 실제 퇴장 처리하며
새 60초 네트워크 대기로 바꾸지 않는다. 태블릿 원인에는 참가자용 60초/제외 선택을 만들지 않는다.

필수 생존 대상은 게임 adapter가 정하고 room active membership와 교차 확인한다. Holdem folded는
다음 핸드에 남아 있는 생존 참가자이며 allIn도 현재 핸드 정산 전 생존 대상이다. stack=0만으로 대상에서 빼지 않는다.
새 게임의 initialPreparing barrier에서는 타이머를 시작하지 않고 최초 데이터/화면 준비를 확인한다.
정상 초기 준비만으로 참가자 60초를 시작하지 않으며 실제 단절/준비 실패가 서버에 확인됐을 때 incident를 만든다.
각 게임의 dealing/roleReveal 첫 진행 요청도 초기 준비와 pause 검사를 통과해야 한다.

타이머는 `{kind: none}` 또는 `{kind: remaining, phaseSeq, turnSeq, remainingMs}`로 저장한다.
RTDB null 삭제 특성 때문에 null만 든 객체를 보존 슬롯으로 사용하지 않는다. remainingMs=0과 none을 구분한다.
최초 중단에서만 `max(0, deadlineAt-serverNow)`를 저장하고 추가 원인·재시도·만료로 덮어쓰지 않는다.

### 4.2 서버 전이

| 사건 | transaction의 결과 |
| --- | --- |
| 최초 유효 단절/준비 실패 | 시간 1회 보관·deadline 제거·pause/barrier 생성·대상 원인과 참가자 최초 60초 마감 생성 |
| 추가 기기 단절 | 대상 원인 추가. 보존 시간·다른 참가자 마감 유지 |
| 연결만 true | 접속 상태 갱신. 준비 대기 원인을 유지하며 재개 금지 |
| 해당 기기 ready | 최신 준비 등록·해당 원인 해소. 다른 원인/필수 준비가 남으면 계속 중단 |
| 참가자 기본/연장 만료 | 대상 선택 상태를 만료로 표시. 자동 제외·종료 금지 |
| 더 기다리기 | 현재 controller·현재 incident·만료·미사용 연장 확인, 수락 serverNow+30초와 used=true를 함께 저장 |
| 제외 후 계속 | 현재 incident unresolved 여부·게임별 계속 가능성을 다시 검사, room 멤버십/게임 제외/원인 제거를 함께 처리. 다른 원인은 유지 |
| 제외로 단계/턴 변경 | 새 단계의 필수 대상·데이터 준비 barrier 생성. 새 턴 표준 시간은 보관해 두고 실제 재개 때부터 시작 |
| 모든 필수 준비·원인 없음 | 같은 턴은 serverNow+remainingMs, 새 턴은 해당 게임 표준 시간. timer none이면 임의 생성하지 않음 |
| 수동 종료·게임 규칙 종료 | 게임 finished·원인/준비/보존 타이머 해제. resume/timeout 지연 요청은 게임을 되살리지 않음 |

상태가 이미 바뀐 대상에 대한 진행자 선택은 `alreadyResolved` / `staleContext`로 끝낸다.
복구와 제외가 겹치면 commit 순서가 최종 결과다. ready가 먼저 해당 원인을 해소했다면 낡은 제외는 실행하지 않는다.
제외가 먼저 확정됐다면 뒤늦은 ready는 자격 검사에서 거절한다. 단순 접속 true만으로 제외를 무효화하지 않는다.
연장 중복 요청은 같은 선택 commandId로 같은 마감을 반환하며 30초를 다시 더하지 않는다.
만료 스케줄·연결 trigger·callable은 같은 reducer를 사용한다. 마감 정확성은 serverNow 비교로 판단하고
1분 스케줄이 정확히 만료 순간 실행된다고 가정하지 않는다.

공용 중단 명령의 최소 API 표면은 다음과 같이 제안한다. 아래 이름/입력은 아직 구현되지 않은 계약이다.

| callable | 입력·검사 | 응답·효과 |
| --- | --- | --- |
| game_common_interruption_wait_more — 신규 | controller UID/session·현재 접속, room/game identity, pauseId, targetUid, incidentId, commandId. 대상 만료·연장 미사용 재검사 | extended/alreadyResolved/staleContext와 수락 마감. 같은 commandId는 같은 마감 반환 |
| game_common_interruption_exclude_player — 보완 | 위 대상 식별·현재 controller, 최신 게임별 preview | excluded와 현재 pause/resume/finish 상태. 계속 불가는 이유와 함께 거절 |
| game_common_interruption_expire — 동작 교체 | 유효 방 멤버, 현재 room/game/incident, 서버 now | notExpired/awaitingDecision/alreadyResolved. 제외·게임 종료 권한 없음 |
| game_common_interruption_report_stale_player — 보완 | controller, 대상 connectionId/Seq·관측 lastSeen, 현재 identity | 최신 실제 접속/heartbeat와 대조해 단절 확인. 옛 관측은 무시 |

일반 종료는 각 게임의 기존 end_game을 사용하고 현재 controller 권한·판 identity를 검사한다.
중단 제외 투표와 휴대폰 finish_now API/호출부는 제거 대상으로 관리한다. 일반 게임 투표는 유지한다.
controller 연결 trigger와 만료 scheduler는 callable과 같은 reducer를 호출하며 독자적인 시간 복원 경로를 갖지 않는다.

모든 일반 행동·완료 연출·턴 timeout·강제 timeout은 공용 pause 검사를 통과해야 한다.
복구 보고, 진행자 중단 해결/일반 종료, 본인 퇴장만 허용한다. 이미 전송된 요청도 transaction 시점에 검사한다.

### 4.3 게임별 계속 가능 판정

`previewExclude(room, uid)`는 실제 제외와 같은 게임 reducer를 부수 효과 없는 상태 복사에 적용해
`continue / normalFinish / cannotContinue`와 이유·새 턴/단계 시간을 반환하는 안을 제안한다.
UI의 canContinue는 참고값이고 실제 선택 transaction에서 다시 판정한다.
정상 승부 정산으로 결과에 도달하는 것과 최소 인원/구성 파괴로 진행 불가인 것을 구분한다.

| 게임 | 적용 기준 |
| --- | --- |
| LP | 생존 최소 2와 카드/직전 제출/벌칙/새 라운드 규칙을 함께 적용. 카드 0만으로 생존 참가자에서 제거하지 않음 |
| FC | 시작 4/6 및 실제 퇴장으로 팀 구성이 깨지면 기존 종료 규칙 유지. 6명에서 1명을 빼면 5명이라는 단순 최소4 판정은 사용하지 않음. 이 경우 제외 후 계속은 비활성화 |
| Mafia | 기존 최소 인원·역할 승패·night/voting/trial 전이 유지. 일반 게임 투표는 유지하고 중단 제외 투표만 제거 |
| Holdem | folded는 현재 팟 승부 자격과 다르지만 칩이 있으면 다음 핸드 대상. allIn은 stack=0이어도 현재 팟 자격 유지. 퇴장/제외 대상의 기여 팟·자격을 처리한 뒤 핸드를 정산하고 다음 핸드/우승 판단 |

Holdem의 퇴장 stack 소거·팟 기여·제외된 사람의 정산 후 복귀 방지를 함께 확인한다.
홀덤의 칩 보존·우승을 건너뛰는 임의 인원 부족 종료는 새 공통 코드로 만들지 않는다.
구체적 팟 예제와 기존 최소 인원 예외는 해당 게임 구현/테스트 계약으로 검토한다.

## 5. R13 — 명령·복구·퇴장 수명

### 5.1 명령과 결과 계약

안전하게 재시도할 명령은 stable commandId, domain payload, 예상 room/game/phase/turn 식별자를 가진다.
재연결 후 인증/transport envelope만 현재 접속으로 갱신할 수 있으며 행동 내용·예상 판/단계는 바꾸지 않는다.
서버 결과 보관은 commandId뿐 아니라 auth UID·명령 종류·정규화한 domain payload를 함께 검사한다.
같은 ID에 다른 내용/UID가 오면 거절한다. 기존 processedCommands의 결과만 바로 반환하는 경로를 보완한다.

처리 순서는 인증/요청 room identity → 같은 작업의 기존 결과 확인 → 미처리 요청의 현재 자격·접속·예상 상태·pause 검사
→ 게임 규칙 → 상태 변경과 결과 기록의 같은 transaction이다. 처리된 결과 재조회는 허용하되 게임 변경을 반복하지 않는다.
진행 완료에는 expected phaseSeq/round/handNumber·세부 단계, 턴 행동/timeout에는 turnSeq를 필수로 한다.
기존 revision/stateVersion 검사가 있는 Holdem도 revision만으로 다른 판을 구분하지 않는다.

`game_common_operation_status` callable 제안은 요청자의 단일 작업에 대해
applied / rejected / notApplied / stale / unknown 결과와 현재 최소 context를 반환한다.
unknown은 서버 조회 실패/정합성 미확정이며 notApplied로 바꾸지 않는다. 카드·역할·전체 ledger는 반환하지 않는다.
notApplied는 미래 처리 불가능의 증거가 아니다. 늦은 요청이 살아 있을 수 있으므로 같은 작업만 재전송한다.
결과를 지워도 옛 요청이 재실행되지 않도록 해당 게임/단계 종료 식별 검증이 먼저 필요하다.
진행 중 ledger의 임의 TTL 삭제는 설계하지 않고, 게임 데이터 수명/방 정리와 함께 정리한다.

| 종류 | 조율과 한도 |
| --- | --- |
| 세션 복구 | 방·UID·역할당 조율자 하나. 즉시 첫 시도·실패 종료 후 1/2/4/8초·이후8초, 요청별8초·전체30초. SDK 물리 재연결은 SDK 책임 |
| 게임 행동·자동 진행 | 동일 명령 정책의 최초 포함4회·0.25/0.5/1초·요청별8초·전체12초. GameProgressCommand의 3초 무제한 재예약 제거 |
| 재시도 소진 | 서버 결과/현재 단계 확인. 미처리 자동 진행은 태블릿에 해당 단계의 수동 재시도. 새 버튼 클릭도 미확정 작업의 ID/내용 유지 |
| busy/notExpired | 새 행동 실패로 자동 반복하지 않음. busy는 단일 작업 큐에서 현재 작업 종료를 기다리며 예산 갱신 금지. notExpired는 현재 서버 deadline에 맞춰 timeout 작업을 예약 |
| 명시적 권한/규칙 거절 | 같은 명령 반복 중단·현재 인증/자격/단계 확인·이유와 행동 안내 |
| 일시 통신 실패 | unavailable·응답 timeout 등은 멱등성이 확보된 작업만 반복. aborted는 transaction 경쟁인지 상태 변경 거절인지 reason을 함께 분류. internal/unknown을 모두 통신 실패로 단정하지 않음 |
| 오프라인·백그라운드 | 추가 앱 요청 중단·현재 묶음 종료. 실제 연결 또는 foreground 복귀 때 유효 대상이면 새30초. 이전 결과는 식별 검사, server 명령 취소로 간주하지 않음 |
| 수동 복구 | 새 최대30초지만 기존 작업 확인/필요 재전송. 중복 클릭 병합·참가자60초/연장30초와 분리 |

중첩 retryPolicy가 바깥 30초를 매번 새 30초로 늘리지 않도록 조율자가 잔여 예산을 전달한다.
UI Guard는 표시와 사용자 클릭 전달만 담당하며 자체 서버 retry loop를 소유하지 않는다.
내 준비 완료 뒤 다른 기기의 재개를 기다리는 상태는 UI 상태로 표시하고 복구 요청을 계속 반복하지 않는다.

### 5.2 퇴장 intent의 로컬·서버 계약

나가기 선택 즉시 복구 세대를 무효화하고 입력을 막는다. 서버 전송 전에 기존 SharedPreferences 기반 저장소에
최소 레코드를 단일 직렬화 값으로 저장하는 안을 제안한다. 새 dependency는 추가하지 않는다.
저장 실패 시 성공한 퇴장 선택으로 처리하거나 서버 요청을 보내지 않고 저장 재시도 안내와 입력 보호를 유지한다.
앱 재실행 때 이 레코드를 세션 복원보다 먼저 읽는다. 저장 성공 후 재실행 보존을 자동/기기 테스트로 확인한다.

| 필드 | 목적 |
| --- | --- |
| schemaVersion, UID, role | 현재 로그인 계정에만 실행. 다른 계정 로그인 시 그 계정으로 대신 요청하지 않음 |
| roomCode, roomInstanceId, membershipId 또는 controllerSessionId | 같은 코드의 새 방/재가입 대상에 옛 퇴장을 실행하지 않음 |
| leaveOperationId, scope, 최초 선택 시각 | 같은 작업 유지. 참가자 본인 게임/방 퇴장과 controller 방 종료를 구분 |
| state=requested/awaitingOutcome/confirmed | 미전송도 intent 유지·취소 미제공. confirmed 이후 로컬 정리가 끝나야 레코드 제거 |

손패·역할·다른 사용자 정보·인증 토큰은 intent에 넣지 않는다. UID/세션 정보는 진단 로그로 출력하지 않는다.
계정 변경 시 이전 UID 레코드는 실행하지 않고 보관하며 해당 계정으로 다시 로그인했을 때 결과를 확인한다.
시간 경과만으로 미확정 intent를 지우지 않는다. 명시적 재가입도 같은 대상의 퇴장 확인이 끝난 뒤 새 membership으로 처리한다.

서버 self leave는 room membership와 게임의 기존 제외/승부 규칙을 같은 transaction에서 적용하고
별도의 room 수명 operation 결과를 남긴다. game 삭제 이후에도 membership별 퇴장 결과를 확인할 수 있게 한다.
controller의 방 나가기는 기존 closeRoom의 방 전체 종료 의미를 유지하며 identity 검사와 중복 결과 처리를 보완한다.
마피아 등 현재 leave가 중단 제외 투표를 만드는 경로는 제거하지만 게임 고유 투표/승패 규칙은 유지한다.

연결 회복 때는 게임 자동 join보다 퇴장 결과 확인을 먼저 한다.
applied 또는 동일 방의 해당 membership이 없다는 서버 확정이면 confirmed,
아직 같은 membership이면 동일 operation으로 퇴장 재시도, 조회/권한 확인 실패이면 awaitingOutcome을 유지한다.
방이 이미 종료/정리됐거나 새 roomInstanceId/membership으로 바뀌었으면 옛 대상의 작업만 종료하고 새 대상은 건드리지 않는다.
게임 종료만으로 방 퇴장까지 완료됐다고 보지 않는다. controller mapping만 없어졌다는 사실도 방 종료 완료 증거로 사용하지 않는다.

퇴장 확인은 세션 조율자의 8초/총30초 제한 안에서 query·동일 작업 요청을 수행하는 안을 제안한다.
이 경로에서는 현재 RoomService의 10초/20초 leave retry를 중첩하지 않는다.
처리 결과를 확인한 뒤 저장 세션·presence 예약·구독을 정리하고 홈/대기실을 한 번만 이동한다.
저장 정리 실패로 재실행해도 confirmed가 남으므로 게임으로 복귀하지 않고 정리만 반복한다.

### 5.3 안내 상태와 화면 이동의 단일 처리

플랫폼/game_kit은 연결·로컬 준비·서버 recovery·명령 결과·퇴장 intent·종료 사실을 공통 안내 상태로 합친다.
출력은 주 안내 하나, 나머지 원인 요약, 입력 차단 여부, 역할별 버튼, 목적지/사유다.
이 상태를 기존 연결 안내 위젯에 전달하며 위젯 자체가 재시도나 Navigator 이동을 시작하지 않는다.
newgui 후보의 `mosi_connection.dart`는 표시 기반이며 아래 reducer/이동 소유자가 이미 구현됐다는 뜻은 아니다.

| 우선순위 | 안내와 허용 동작 |
| --- | --- |
| 확정 종료·명시적 퇴장 확인 | 종료는 아래 목적지로 한 번 이동. 미확정 퇴장은 확인/재시도만 제공하고 게임 자동 복귀 금지 |
| 내 기기 연결/필수 준비 실패 | 즉시 입력 보호·작은 안내·본인 나가기. 복구 묶음 소진 뒤 다시 시도. 서버 중단 미확정이면 중단 확인 중 |
| 태블릿 단절 | 서버 중단 상태와 진행자 복구 대기. 휴대폰은 본인 나가기, 전체 게임 종료/타인 제외 없음 |
| 다른 참가자 단절/준비 실패 | 중단 원인 요약. 태블릿에 incident별 상태·마감·조기 제외·만료 후 선택, 일반 게임 종료 권한 유지 |
| 개별 명령 실패 | 통신/규칙 사유와 해당 행동의 재시도 안내. 전체 연결 실패로 덮어쓰거나 자동 퇴장하지 않음 |

단절/복구 실패의 지속 시작 시각을 원인별로 유지해 10초 뒤 전체 안내를 보여준다.
재시도·작은 화면 rebuild·동일 incident의 오류 종류 변경으로 10초를 다시 시작하지 않는다.
서버 게임 중단 안내는 즉시 표시한다. 정상 데이터 대응 대기는 동기화로 표시하며 실패와 구분한다.
주 안내가 바뀌어도 남은 원인의 시각과 상태 요약을 보존한다. 동일 사건의 dialog/snackbar를 쌓지 않는다.
태블릿의 대상 버튼은 목록 index가 아닌 현재 membership/incident에 연결하고 서버 결과에 따라 목록을 갱신한다.
만료 뒤 ready가 먼저 확정되면 그 대상 선택을 닫는다. 명령 실패만으로 다른 대상 안내까지 닫지 않는다.

| 서버로 확인한 결과 | 목적지와 처리 |
| --- | --- |
| 정상 승패/무승부 종료 | 기존 결과 화면과 닫기 흐름 유지. 종료 이벤트만으로 결과를 건너뛰지 않음 |
| 비정상 게임 종료·방/본인 자격 유효 | 자동 대기실 상태로 이동하고 종료 사유 표시 |
| 방 닫힘/제거·본인 강퇴·본인 방 퇴장 완료 | 홈으로 이동하고 사유 표시 |
| 명시적 나가기 결과 미확정 | 입력 보호·퇴장 확인 중. 홈 이동 성공으로 처리하지 않음 |
| 조회 실패·오프라인·인증/자격 확인 미완료 | 현재 보호 화면 유지·확인/재시도. 없는 방/강퇴로 추정하지 않음 |

플랫폼 route 소유자는 종료 효과를 room/game/member identity와 종료 결과별로 한 번 소비한다.
먼저 해당 복구/화면 열기/ready 세대를 무효화하고, 게임 위에 쌓인 dialog를 닫은 뒤 **대상 게임 route만** 닫는다.
[game_route_exit.dart](../../packages/game_kit/lib/shared/widgets/game_route_exit.dart)의 route active/current 검사를 활용하고,
route가 이미 없어졌으면 부모 홈/대기실을 추가 pop하지 않는다. 화면 반영은 mounted·현재 UID·대상 identity를 재검사한다.
route 종료 후 기존 홈의 대기실 상태를 재사용하거나 필요한 목적지를 열며, 애니메이션 중 더 최신 종료/계정 변경이
발생하면 옛 후속 이동을 폐기한다. 태블릿 복귀 질문은 같은 소유자가 한 번만 띄운다.

[room_restore_to_waiting.dart](../../lib/platform/home/room/services/room_restore_to_waiting.dart)의 정리는 게임 route 종료 뒤 수행한다.
정상 결과는 기존 결과 닫기 이후에만, 비정상 종료는 자동 이동 이후에 태블릿이 selectedGame/game 정리를 요청한다.
정리 명령에는 expected room/game identity와 finished 조건을 넣어 옛 callback이 새 게임을 지우지 못하게 한다.
휴대폰의 종료 화면 이동이 태블릿 결과를 먼저 지우지 않는다. 방이 유효한데 정리 요청만 실패하면 대기실에서
정리 대기를 안내하고 같은 작업을 확인/재시도하며, 서버가 완료하기 전 새 게임 시작 가능 상태로 표시하지 않는다.
방이 닫혔으면 대기실 정리 대신 홈 경로를 따른다. 사유는 provider 세션 clear 전에 목적지 소유자에게 전달하고
도착 후 한 번 표시해, clear 과정에서 안내를 잃거나 다음 방에서 다시 표시하지 않는다.

## 6. R14 — 그룹 조회와 방 생성 예약

### 6.1 해당 방의 그룹 게임 조회

기존 이름 `fetchRealtimeRoomGroupEntitlements`를 유지하고 입력 roomCode·roomInstanceId를 필수로 바꾸는 안을 제안한다.
서버는 해당 방 controller 또는 active 참가자인 auth UID인지 확인한다. 다른 방의 controllerRooms를 조회 대상으로 선택하지 않는다.
현재 activeGroupUids의 controller+active 참가자 소유 게임 합산과 무료 게임 처리 의미를 유지한다.
응답은 해당 그룹의 최소 ownedGameIds·membershipRevision만 반환한다. 사용자별 구매 정보나 users 문서를 반환하지 않는다.

가입/퇴장/강퇴/방 종료 시 membershipRevision을 증가시키고, 서버는 외부 소유 데이터 조회 전후
방 identity·호출자 자격·membershipRevision을 확인한다. 중간에 변하면 제한 재조회 또는 stale 응답으로 끝낸다.
클라이언트는 방/목록 generation이 바뀐 결과를 버리고 한 번 갱신한다. heartbeat마다 소유 조회를 반복하지 않는다.
조회 결과는 표시용이며 실제 게임 선택/시작은 기존 서버의 그룹 접근 권한을 다시 검사한다.
소유 게임 자체 변경의 갱신은 현재 구매/홈 갱신 경로를 확인해 연결하고 새로운 구매 기능을 만들지 않는다.

### 6.2 생성 operation과 부분 실패

createRealtimeRoom의 operationId를 필수로 하고 앱이 보내기 전 저장한다. 중복 클릭/응답 유실/재실행은 같은 operation이다.
서버 예약은 reserved → created → terminal을 명시하고 roomCode·roomInstanceId·allocationGeneration을 함께 기록한다.
현재 controllerRooms 매핑은 결과의 원본이 아닌 조회용 index로 취급한다. 불일치 복구 시 다른 유효 방 매핑을 덮어쓰지 않는다.
같은 controller의 생성 operation은 단일 활성 슬롯을 CAS로 소유하게 하고, 미확정 상태에서 다른 새 operation을 병행하지 않는다.

| 서버에서 확인한 상태 | 처리 |
| --- | --- |
| 예약 없음·새 operation | 활성 생성 슬롯 확보 후 코드/identity 예약, 같은 요청으로 생성 |
| reserved·아직 방 없음 | 같은 코드/identity/generation으로 생성 단계를 계속. 새 코드로 중복 생성하지 않음 |
| 동일 operation의 유효 방·매핑 누락 | 해당 방 반환·조건부 매핑 복구 |
| 다른 identity의 방/매핑 | collision/stale로 처리. 남의 방·나중에 생성된 방 수정 금지 |
| 이미 종료/정리된 동일 operation | terminal 응답. 옛 operation으로 방을 다시 만들지 않음 |
| 진짜 고아·유효 writer 없음이 확인됨 | 같은 operation의 안전한 정리/재처리. 단순 createdAt 경과만으로 판단하지 않음 |
| 상태 조회 실패 | unknown 안내와 같은 operation 확인/재시도. 새 방 병행 생성 금지 |

### 6.3 삭제 뒤 옛 생성 요청 방지 — 검토가 필요한 저장 방식

현재처럼 예약·방을 별도 transaction으로 처리하면 예약 조회와 방 쓰기 사이에 삭제가 끼어들 수 있다.
최종 재조회만으로 이미 시작된 옛 writer를 취소할 수는 없다. 루트 전체 transaction은 모든 방의 상태를
경쟁시키므로 기본안으로 채택하지 않는다.

권장안은 방 정리 때 `rooms/{code}`의 게임/멤버/private/presence를 제거하면서
최소 roomInstanceId·allocationGeneration·terminal 표시만 남기는 것이다. 이 작은 terminal 기록은
기능상 삭제된 방이며 validate/join/resume/query는 removed로 반환하고 controller index에서 제외한다.
동일 room transaction에서 terminal 전환을 확정한 뒤 예약/매핑을 identity 조건부로 정리한다.
같은 코드의 재사용은 새로운 allocationGeneration을 claim한 신규 operation만 가능하다.
코드 할당은 room transaction의 expectedAllocationGeneration CAS로 수행한다. 처음 빈 코드는 0,
terminal 기록의 현재 값은 g로 보고 새 요청만 g+1을 할당한다. 같은 operation의 재전송은 이미
할당한 generation을 유지하며 동일 generation의 terminal 상태를 다시 waiting으로 바꾸지 않는다.
이전 생성/삭제 writer는 expected generation이 달라지거나 동일 operation terminal을 보고 거절한다.
물리 노드를 완전히 없애는 GC는 오래된 writer를 다시 유효하게 만들지 않는 별도 근거 없이는 실행하지 않는다.

이는 기존 room 삭제 모양·cleanup trigger의 persistent/state-machine 변경이다. 실제로 적용하기 전 검토가 필요하다.
현재 onValueDeleted backstop은 방 전체 삭제만 관찰하므로 terminal 전환 처리로 바꾸고,
예약을 무조건 remove하는 대신 동일 identity의 terminal 결과를 보존/정리하도록 수정해야 한다.
진행 방·결과 방의 기존 보존 시간은 기능상 종료/정리 시점을 유지한다. 이 제안으로 새 게임 대기 시간을 늘리지 않는다.

대안은 저장 모양을 유지하고 writer 안전성을 증명하지 못한 예약은 unknown으로 남겨 자동 재생성을 제한하는 것이다.
확인 가능한 부분 실패만 복구하고, 모호한 고아 정리는 별도 검토한다. 자동 복구 범위가 줄어들지만
물리 삭제 계약은 유지한다. 과거 고아의 생성/삭제 이력이 없으면 새 필드를 추측해 채우지 않는다.

### 6.4 terminal 기록과 정리 대상 선정

6.3의 terminal 보존안을 선택하면 기존 `cleanupAt`/`controllerPresence.lastSeen` 첫 500개 조회를 그대로 유지하지 않는다.
terminal 기록을 transaction에서 건너뛰기만 하면 같은 기록이 조회 한도를 계속 차지할 수 있다.
메타데이터를 없앴다는 이유만으로 기존 범위 쿼리에서 제외된다고 가정하지 않는다.

정리할 일을 나타내는 서버 전용 `roomCleanupQueue/{roomCode}`를 제안한다.
항목은 roomInstanceId·allocationGeneration·nextCheckAt·workKind만 담고 방의 정리 자격 원본으로 사용하지 않는다.
workKind는 live retention 확인 또는 terminal 전환 후 예약/매핑 정리다. 방 생성/수명 변경 때 예약하고,
heartbeat마다 index를 쓰는 대신 due 처리 시 실제 최신 방을 읽어 보존 마감에 맞춰 다음 점검을 예약한다.

1. due 항목마다 room transaction에서 identity/generation·현재 상태·lastSeen/보존 마감을 재검사한다.
   아직 유효한 방은 지우지 않고 점검만 미룬다. 기능상 정리 가능하면 terminal로 전환한다.
2. terminal의 최소 정리 정보에 cleanupPending을 남긴다. 동일 identity의 예약/매핑만 조건부로 정리하고,
   부분 실패는 due 작업을 유지해 재실행한다. 방 전환과 외부 index 갱신이 별도 쓰기라는 점을 숨기지 않는다.
3. 완료하면 cleanupPending과 해당 generation의 due 작업을 제거한다. terminal fence는 유지하되
   cleanupAt/presence나 반복 due 작업으로 살아 있는 방의 정리 목록을 점유하지 않는다.
4. 누락된 queue/중간 실패는 방 key를 이어서 읽는 제한적 보정 scan으로 찾아 복구한다.
   매번 첫 500개부터 시작하지 않으며, 완료 terminal을 다시 enqueue하지 않는다.

scheduler는 due 순서와 key cursor로 다음 페이지를 처리한다. 실패 항목은 제한된 backoff로 미루고,
동일 실패만 반복해 뒤의 유효 방을 영구히 굶기지 않게 한다. 실행당 처리량은 제한하되 다음 위치/작업을 보존한다.
페이지 회차를 끝내면 처음으로 돌아가 새로 삽입된 이른 마감도 확인한다. 과거 cursor보다 앞에 생긴 작업을 놓치지 않는다.
옛 job의 예약/queue 삭제도 identity/generation을 대조하므로 재사용 코드의 새 방 작업을 지우지 않는다.
playing 만료·고아 점검·backstop 등 다른 scan도 terminal을 진행 방으로 취급하지 않는 조건을 공유한다.
완료/연기/부분 실패/잔여 작업 수를 진단하며 실제 사용자/방 식별자는 진단 로그에 넣지 않는다.

이는 선택 C의 정리 index/marker를 포함하는 추가 저장 계약 제안이다. 실제 query/index/rules/export와
보정 scan의 비용은 구현 검토에 포함한다. 기존 15분/3분 등 보존 기준을 새 대기 시간으로 바꾸지 않으며
production queue 생성·보정·과거 고아 정리는 실행하지 않았다.

## 7. R15 — 반영 순서와 기존 데이터

구버전 앱 동작 보장·shim·최소 버전 게이트를 만들지 않는다. 현재 앱의 모든 4게임·room consumer와 서버가
동일 계약을 사용하도록 맞춘다. 구버전 제외가 현재 진행 방의 데이터 상태까지 무시해도 된다는 뜻은 아니다.

| 영향 대상 | 필요한 변경 |
| --- | --- |
| room create/join/resume/close/leave | instance/member/connection/operation identity와 결과 계약·부분 실패·퇴장 우선 처리 |
| game-common interruption/connection | 단일 interruption/controllerPause에서 단일 pause+원인 집합으로 전환, 연결만으로 재개하는 경로 제거 |
| expire callable/scheduler·finish_now | 만료 상태 표시만 수행. 중단 제외 투표·휴대폰 전체 종료 경로 제거. 태블릿 권한 검증·일반 종료 유지 |
| 4게임 start/command/complete/timeout/leave/end | state 식별·metadata·pause 검사·게임별 제외 preview와 실제 처리·결과 ledger. 종료 후 cleanup도 새 모델 정리 |
| game_kit·4게임·플랫폼 | 주입된 준비 계약·구독 재생성·단일 retry owner·persistent intent·route 결과 처리·안내 상태 |
| RTDB rules | public는 현재 멤버/controller, private는 본인, server/ledger는 서버만. 클라이언트 준비·게임 쓰기 금지. 접속별 presence는 본인/현재 세션의 허용 필드만 쓰게 검증 |
| 함수 export/trigger | 신규 report/status/extend 명령 배선, 투표/phone finish 경로 제거, 중복 reducer 실행 방지. 함수 이름/리전 목록은 실제 구현 diff로 확정 |
| 방 정리·예약/매핑 | R14 선택에 맞춰 terminal 및 generation 검사. due queue의 서버 전용 접근·nextCheckAt index·scheduler/보정 scan 배선, stale callback의 새 방/예약 보호 |

room/players 상위 `.read`가 이미 넓게 허용되면 자식 `.read=false`만으로 민감한 필드를 숨길 수 없다.
새 credential 성격의 값을 그 아래에 공개하지 않고 서버 전용으로 두며 rules 영향 범위를 함께 검사한다.
connectionId 등 비밀이 아닌 식별자도 자격을 대신하지 않는다. 기존 controllerSessionId 비공개 경계는 유지한다.

### 7.1 반영 순서 제안

1. 위 계약·R14 정리 방식 검토와 R16 담당/후보 기준 확정.
2. 순수 서버 reducer/adapter·공용 DTO/API를 맞추고 관련 검증 배선을 복구.
3. 4게임과 플랫폼을 새 계약에 연결하고 로컬/emulator 통합을 검증.
4. 현재 후보 FULL·실기기 검증 및 실패/복구/정리 경합 확인. 목표 성능 수치는 측정 후 별도 합의.
5. 실제 배포 단계에서는 변경 함수·rules·앱의 구체 목록과 데이터 상태를 검토받아 반영.

구체 배포안의 기본은 진행 중 방이 없는 시점의 일괄 전환이다. 기존 방이 있으면 종료/정리 시점까지
전환을 보류하는 안을 우선 제시한다. 현재 진행 방을 새 모델로 자동 변환하거나 강제 종료하는 승인은 없다.
전환 동안 새 방 생성/게임 시작을 막아야 하는지는 실제 반영 수단과 서비스 상태를 확인해 결정한다.
이를 확인하지 않고 서버만 먼저 바꿔 기존 데이터의 interruption을 새 recovery로 해석하지 않는다.
서버 callable/scheduler와 rules를 준비한 뒤 맞는 앱을 사용할 수 있게 하되, 그 사이 혼합 상태에서는 게임을 시작하지 않는다.

### 7.2 데이터별 전환

| 데이터 | 제안 |
| --- | --- |
| 새 방/게임 | 처음부터 새 identity·recovery 계약 사용 |
| 기존 active 방/게임 | 기본안은 끝날 때까지 반영 보류. 기존 단일 슬롯에서 잃어버린 다중 원인·준비 증거를 추정해 migration하지 않음 |
| 기존 종료 방·예약/매핑 | 실제 identity·operation이 확인되는 것만 정리/전환. 과거 고아는 별도 대상·근거·안전 조건 필요 |
| 로컬 저장 세션 | 새 앱에서 서버 identity 확인 후 보완. 조회 실패만으로 삭제하지 않음 |
| 기존 메모리 퇴장 마커 | 앱 종료 뒤 사라진 과거 퇴장 의도를 복구할 수 없음. 새 저장 성공 이후의 의도부터 보장 |
| 새 미확정 퇴장 저장 | UID·schemaVersion 검사, confirmed 정리 전까지 보존. 시간 경과만으로 삭제 금지 |

롤백은 코드만 되돌리는 것으로 가정하지 않는다. 새 schema로 만든 진행 방이 생긴 뒤에는 해당 방을
구 계약으로 안전하게 읽을 수 있는지 별도 판단해야 한다. 구버전 호환을 만들지 않으므로 기본은 생성 방의
정상 종료/안전한 보존 후 반영 수정이다. production 작업은 구체 계획의 검토 후 별도로 실행한다.

### 7.3 복구 측정 지점과 기록 계약

시간 구간은 클라이언트의 단조 증가 `Stopwatch` 기준으로 측정한다. 클라이언트 DateTime과 서버 시각을
서로 빼거나 서로 다른 기기의 시계를 섞지 않는다. 서버 pause/resume·참가자 마감은 서버 시각끼리 별도 확인한다.
다음 이벤트는 UI 문자열이 아니라 실제 작업 소유자가 해당 조건을 완료/실패한 지점에서 기록한다.
측정 episode는 같은 대상의 준비 상실부터 입력 복귀/확정 종료까지다. 수동 재시도는 열린 episode 안의 새 batch이며,
기존 episode가 없다면 새로 시작한다. 앱 종료로 끝 지점을 기록하지 못한 episode는 미완료로 구분한다.

| 지점 | 완료/시작 조건 |
| --- | --- |
| runStart | 최초 오프라인 복원 대기, 실제 단절, 준비 실패 또는 기존 episode 없는 수동 복구가 새 episode를 시작함 |
| sdkDisconnected / sdkConnected | 해당 RTDB SDK 연결값을 관측함. 현재 true를 뒤늦게 읽은 경우에는 관측 종류도 구분 |
| batchStart / attemptStart·End | 같은 episode의 제한 복구 묶음과 개별 요청 시작/결과. 재시도 대기시간 포함 |
| authReady / onboardingReady | 최초 실행에 필요한 UID/온보딩이 실제로 사용 가능. 해당하지 않는 경로는 N/A |
| sessionValidated / presenceBound | 현재 방/멤버/접속 자격 확인과 해당 세대 presence 등록 완료 |
| subscriptionsBound / dataMatched | 현재 세대 필수 구독 생성과 최신 public/private 조합 확보를 각각 기록 |
| assetsReady / screenUsable | 필수 에셋 확인과 현재 game route 첫 사용 가능한 frame 완료. 단순 route push를 화면 완료로 쓰지 않음 |
| localPrepared / readySent·Ack | 필수 로컬 준비의 마지막 조건 완료, 현재 barrier 보고 송신/유효 수락을 각각 기록 |
| resumeObserved / inputUnlocked | 현재 판 서버 resume 수신, 최신 로컬 준비와 함께 입력 보호 해제를 각각 기록 |
| batchEnd | 로컬 복구 성공·30초 소진·실제 거절·오프라인/백그라운드 중단 등 제한 묶음의 결과 |
| runEnd | 입력 복귀 또는 확정 퇴장/종료·대상/계정 변경으로 해당 episode가 끝남. batch 소진만으로 총 측정을 초기화하지 않음 |

기존 [GameCommunicationLog](../../packages/game_kit/lib/core/diagnostics/game_communication_log.dart)의 debug 전용 경계를 유지한다.
로컬 측정용 임의 run 번호, 역할·OS·게임 종류·실험 조건·시도 수·결과 코드·구간 길이만 남긴다.
room/game/member/connection 실제 ID·UID·roomCode·카드/역할/요청 내용·credential은 로그에 넣지 않는다.
최근 200개 이벤트가 잘려도 시작/종료 및 구간 집계를 잃지 않도록 제한된 run 요약을 별도로 보존한다.
누락 지점은 미측정으로 표시하며 0ms로 채우지 않는다. release 로그/원격 telemetry 업로드를 새로 만들지 않는다.

| 산출 구간 | 의미와 제외 조건 |
| --- | --- |
| 단절 노출: SDK false→true | 사용자가 오프라인으로 머문 시간도 포함. 순수 SDK 재연결 속도로 이름 붙이지 않음 |
| SDK 포함 재연결 | 실험에서 물리 연결 복원 지점을 같은 기기 시계로 표식한 경우 그 지점→SDK true. 표식이 없으면 미측정 |
| 연결 후 앱 준비: SDK true→localPrepared | 자격/구독/데이터/필수 에셋/화면 준비. 이미 연결된 수동 시도는 batchStart를 기준으로 따로 분류 |
| 본인 준비 후 재개 대기: localPrepared→resumeObserved | 다른 필수 기기와 서버 barrier 대기. 본인 복구 실패/재시도 시간으로 합치지 않음 |
| 입력 복귀: resumeObserved→inputUnlocked | 서버 재개 후 로컬 반영. 정상 결과/퇴장 경로는 N/A |
| 총 관측 복구: runStart→inputUnlocked | 사용자 관측 총시간. 실제 오프라인 체류·다른 기기 대기 포함 여부를 함께 표시 |

최초 오프라인 실행은 앱 실행→onboardingReady→sessionValidated→localPrepared도 별도 집계한다.
백그라운드 체류, 복귀 질문에서 사용자 선택을 기다린 시간, 퇴장 확인은 자동 복구와 구분해 기록한다.
수동 재시도가 새 30초 batch를 만들더라도 같은 incident의 총 관측 시간은 보존하며 batch와 episode를 혼동하지 않는다.
준비 완료 뒤 다른 기기만 기다리면 본인 batch는 성공 종료하고 episode의 재개 대기 측정만 이어간다.

조건별 성공 구간의 중앙값·95백분위·최대와 성공률을 산출한다. 실패/상태 유실/종료/사용자 대기/미측정은
성공 지연 통계에서 분리하고 건수를 함께 보고한다. 타이머 보존·중복 처리 여부는 성능과 별도의 정합성 확인이다.
batch 결과와 episode의 최종 결과를 각각 집계해 여러 재시도가 한 번의 성공률 분모로 섞이지 않게 한다.
이 지점과 기록 형식을 R18 실험에 연결한 뒤 목표 수치/출시 통과 기준을 합의한다. 현재 30초는 retry 상한이다.

## 8. 주요 선택의 채택 결과와 다음 계획

2026-10-09 사용자가 A~C 모두 아래 권장안을 수락했다. 대안은 비교 근거로 남긴다.

| 선택 | 권장·근거 | 다른 선택의 영향 |
| --- | --- | --- |
| A — 준비/접속 식별 | 명시적인 room/game/member/connection identity·private 메타데이터·중단 barrier 준비 확인. stale 요청과 분배 중 정상 빈 private를 함께 처리 | startedAt/roomCode/presence만 재사용하면 코드 재사용·재가입·public/private 대응 증거가 부족. 같은 정확성을 보장할 다른 계약이 필요 |
| B — 퇴장 저장·재시도 | 요청 전 durable intent, UID/해당 membership별 확인, 결과 미확정은 TTL 없음. 퇴장 확인은 복구 조율자의 8초/30초 안에서 실행 | 현재 leave 10초/20초 별도 정책을 유지한다면 바깥 복구 30초와 중첩되지 않는 독립 예산/결과 확인 계약이 필요 |
| C — 생성/삭제 경합 | 최소 terminal 방 기록과 allocationGeneration으로 옛 생성 writer 차단. 동일 코드의 새 방은 새 generation. due 정리 index/부분 실패 marker로 terminal의 반복 조회와 정리 누락 방지 | 기존 물리 삭제 유지 시 안전성이 불명확한 고아 자동 재생성은 제한. 데이터 모양·cleanup 영향은 작지만 복구 범위가 줄어듦 |

이 선택은 R01~R10 제품 합의에 이어 채택한 신규 API·persistent data·state-machine 구현 방식이다.
허용 파일/담당안·의존 순서·채팅별 완료 단위·검증 목록은 [R16~R18 실행 계획](NETWORK_SESSION_IMPLEMENTATION_PLAN.md)에 작성했다.
착수 최신 newgui/후속 변경 대조와 담당 확정 뒤 그 계획의 E01부터 진행한다. 이번 요청은 문서 push/develop merge이며 개발은 시작하지 않는다.

검증 계획에는 최소한 다음 경계를 연결한다. 아직 테스트를 실행하거나 통과시킨 목록은 아니다.

- R11: dealing private 미존재·빈 hand·Mafia 정상 미선택·Holdem allIn, 구독 재생성·엇갈린 dataSeq·late private·재단절.
- R11 보충: 타인 행동 뒤 본인 private 내용 불변/메타데이터만 갱신, 새 public 뒤 옛 일치 조합 사용 금지,
  정상 이벤트 지연은 자동 해소/무제한 대기 금지, 최신 데이터 없이 failed 보고·failed/ready 역순·서버 수락 전 시간 보존 금지.
- 초기화 보충: 최초 오프라인 뒤 연결/저장/인증 준비의 모든 순서, roomCode 미설정 복원, 퇴장 우선,
  휴대폰 동의 전 join 금지, 온보딩 오류→정상 데이터에서 failed 해제, 옛 UID/watcher/timeout 폐기, 캐시 null과 서버 부재 구분.
- R12: A/B/controller 모든 해소 순서, 만료/ready/연장/제외 경합, 0/none/새 턴 시간, FC 팀 구성과 Holdem 정산, paused 중 모든 진행 요청 차단.
- R13: 처리 전 실패·처리 후 응답 유실·동일 ID 다른 내용·옛 게임/턴 요청·12/30초 상한·busy, durable save/cleanup 실패·재실행/계정 변경·미전송 취소 미제공.
- 화면 보충: 종료/퇴장/내 오류/타인 오류 동시 발생의 주 안내, retry로 10초 초기화 금지, 정상 결과 유지,
  dialog 위 게임 종료·이미 닫힌 route·이동 중 계정 변경·방 정리 실패/새 게임 경합·도착 사유 한 번 표시.
- R14: 일반 참가자/외부 계정/다른 방 controller·가입 중 목록 조회, 예약만 성공·매핑 실패·중복 생성·삭제 직전 writer·코드 재사용·과거 고아.
- 정리 보충: terminal 500개 이상 뒤 live 방 정리, 실패 due 작업 뒤 대상 진행, terminal 전환/queue 갱신 사이 실패,
  보정 scan cursor 유지·중복 실행·옛 generation job이 새 방/queue를 제거하지 않음.
- R15: 새 계약의 모든 consumer·함수/rules 배선, 기존 데이터 전환 조건·중복 trigger·혼합 반영 중 시작 차단 수단.
- 측정 보충: client/server 시계 분리, 이벤트 버퍼 잘림에도 run 요약 보존, 다른 기기 대기/백그라운드/질문 대기 분리,
  미측정과 0 구분, retry batch/incident 총시간 구분, 민감값 미기록과 release 비활성 유지.

기존 관련 테스트는 약화/삭제해 통과시키지 않는다. 제품 정책과 달라진 과거 투표/자동 제외/무제한 재시도 기대는
새 정책의 테스트로 교체하고 나머지 안정성 보호는 유지한다. targeted/package/FULL/CI·실기기 수행은 실행 계획 R18에 연결했다.
