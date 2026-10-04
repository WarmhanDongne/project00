# 네트워크 복구와 세션 관리 동작 명세 — 현재 구현 기준

이 문서는 **연결이 끊기거나 앱을 다시 켰을 때, 무엇이 복구됐고 무엇이 아직 준비되지
않았는지 구분하기 위한 설명**이다. 현재 앱과 서버가 문제를 어떻게 알아차리고, 무엇을
확인한 뒤 어떤 처리를 하는지 살펴본다.

예를 들어 인터넷 연결이 돌아왔어도 내 손패가 아직 도착하지 않았다면 게임 화면은
준비되지 않았을 수 있다. 이런 차이를 알아야 연결 문제인지, 참가 자격 문제인지,
데이터 수신 문제인지 구분할 수 있다.

확인일: 2026-10-04. 기준 HEAD는 `8357a6b7ff7cbe40e353223dbe08587cafb3233b`이며,
조사 시 작업 트리에 있던 변경도 함께 읽었다. 코드 링크는 저장소의 상대 경로이며,
이 문서와 함께 읽는 checkout의 구현을 가리킨다. 운영에 배포된 앱·서버와 실기기 동작을
이번에 확인한 결과는 아니다. 테스트 링크는 존재하는 검사와 그 범위를 가리키며 실행
PASS를 뜻하지 않는다. 이전 제목은 ‘사건으로 읽는 현재 세션 흐름’이다.

각 사건을 **감지 → 판단 → 변경 → 성공 확인 → 실패가 남는 곳** 순서로 읽는다.
복구 계약 보완은 [SESSION-RECONNECT-02](../planning/TASKS.md#session-reconnect-02),
누락된 회귀 검사와 실행 배선은 [TEST-REGRESSION-01](../planning/TASKS.md#test-regression-01)에서
관리한다. 이 문서는 그 개선을 구현하거나 새 계약으로 확정하지 않는다.

## 읽는 순서와 용어

먼저 상태의 의미와 판단 주체를 읽고, 전이표에서 이동 조건을 확인한 뒤,
상황별 의사코드를 따라간다. 뒤의 1~5장은 원래 사건별 설명을 보존한 상세 근거다.
‘단절·재연결·앱 재실행·명령 응답 유실·퇴장/강퇴’는 대표 사건이지 서로 배타적인
전체 시나리오가 아니다. 예를 들어 요청 중 단절되고 앱을 다시 켜는 동안 강퇴될 수 있다.

- **상태:** 지금 어떤 사실이 성립하는가. ‘연결됨’과 ‘참가 자격 유지’는 다른 상태다.
- **사건:** 연결 false, 요청 실패, 퇴장 버튼처럼 판단을 시작하게 하는 일이다.
- **전이:** `현재 상태 + 사건 + 검사 조건 → 처리 + 다음 상태` 한 단위다.
- **세대:** 요청을 시작할 때 기억한 연결·세션의 번호다. 새 연결이나 퇴장으로 번호가
  달라지면 이전 작업의 늦은 응답을 현재 상태에 적용하지 않는다. 서버 요청 취소와는 다르다.
- **접속 정보(presence):** 접속 여부와 마지막 heartbeat 시각이다. 참가 자격 자체가 아니다.
- **미확정:** 조회 실패 등으로 자격 상실·삭제를 증명하지 못한 상태다. ‘없음’과 구분한다.

상태명과 의사코드는 여러 파일의 논리를 사람이 읽기 쉽게 복원한 것이다. 서비스에
같은 이름의 단일 상태 머신이나 enum이 있다는 뜻은 아니다. **구현에서 확인한 처리**,
**검증이 필요한 결과**, **구현 공백**을 구분하며 작성자의 의도를 추측해서 채우지 않는다.

## 먼저 구분할 상태 영역

아래 항목은 앱과 서버의 여러 코드가 각각 확인하거나 관리하는 상태다. 확인에
쓰는 정보와 담당 코드가 서로 달라 각각 살펴봐야 한다. 한 항목이 정상이어도 나머지가
모두 정상이라는 뜻은 아니다.

| 확인할 상태 | 쉽게 말하면 | 헷갈리지 말아야 할 점 |
| --- | --- | --- |
| 로그인과 초기 설정 | 누구로 로그인했는지, 앱을 이용하기 위한 초기 설정을 마쳤는지. | 로그인했어도 특정 방이나 게임에 참가할 수 있다는 뜻은 아니다. 인터넷이 끊겼다는 사실만으로 로그아웃되는 것도 아니다. |
| 방·게임 참가 자격 | 그 방에 참가자로 남아 있는지, 게임에서 계속 플레이하는 사람인지 탈락 후 관전하는 사람인지. 진행을 맡은 태블릿은 그 방을 제어할 자격이 있는지도 확인한다. | 방에 참가자로 남아 있는 것과 게임에서 행동할 수 있는 것은 다르다. 손패가 아직 없다는 이유만으로 참가 자격을 잃었다고 볼 수 없다. |
| 통신 연결 | 내 기기가 Firebase의 실시간 데이터베이스(RTDB)에 연결돼 있는지, 다른 기기는 최근 접속 신호를 보냈는지. | 내 기기의 연결과 다른 기기의 접속 신호는 따로 확인한다. 연결돼 있어도 최신 게임 데이터가 도착했다는 뜻은 아니다. |
| 게임 데이터 수신과 구독 | 화면에 필요한 게임 정보와 본인 정보를 받았는지, 이후 변경도 계속 받을 수 있는지. ‘구독’은 데이터가 바뀔 때 계속 받아 보는 처리를 말한다. | 카드 분배가 끝나지 않아 본인 손패가 아직 공개되지 않은 경우, 실제 손패가 0장인 경우, 읽기 권한 오류로 수신이 멈춘 경우를 구분해야 한다. |
| 화면 연출 | 게임 시작 안내, 카드 분배, 라운드 안내 같은 화면 연출을 어디까지 재생했는지. | 서버의 게임 진행 단계와 화면의 연출 진행은 별개다. 화면을 새로 만들면 이전 연출을 끝냈다는 기록이 초기화될 수 있다. |
| 서버 게임 진행·중단 | 게임이 진행 중인지, 참가자 interruption 또는 controller pause가 있는지, 턴 마감이 흐르는지. | 내 연결이 돌아와도 다른 중단 원인이 남으면 서버 게임은 멈춰 있을 수 있다. |
| 명령 처리 | 전송 중인지, 응답을 받았는지, 서버에 반영됐는지, 재시도할 수 있는지. | 클라이언트 시간초과는 서버의 미실행이나 취소를 뜻하지 않는다. |

### 코드에서는 어디서 확인하거나 관리하나?

위 표는 각 상태의 의미를 설명한다. 실제 구현에서 **어떤 정보를 확인하고 어느 코드가
처리하는지**는 아래와 같다. 코드 링크는 그 설명의 근거가 되는 구현 위치다.

- **로그인과 초기 설정:** Firebase 인증 도구(Auth SDK)의 `userChanges()`로 로그인
  변화를 받고, 현재 사용자 식별자(UID)를 확인한다. `AuthGate`는 로그인과 초기 설정
  상태에 따라 보여 줄 화면을 정한다. 서버도 앱이 보내는 작업 요청(callable)을 처리할
  때 인증 UID를 별도로 확인한다. [인증 화면 코드][auth-gate]
- **방·게임 참가 자격:** 서버는 방의 참가자 기록(`players/{uid}`)이 있는지와
  `active` 값을 확인한다. 진행 기기(controller)의 방 제어 자격은 UID와 세션으로
  확인하며, 게임 명령은 게임의 공개 참가 명단과 각 명령의 조건으로 검증한다. 기존 `active` 참가자를
  복구하는 서버의 방 참가(join) 조건에는 손패 데이터 존재가 포함되지 않는다.
  [방 재참가 판정 코드][join-policy], [게임 행동 검증 코드 예시][game-validation]
- **통신 연결:** 앱은 `.info/connected`로 내 기기의 RTDB 연결을 확인한다. 방에는
  참가자의 `isConnected/lastSeen`과 진행 기기의 `connected/lastSeen`이 기록된다.
  이 값들은 접속 여부와 마지막 접속 신호 시각을 나타낸다. 주기적으로 보내는 접속
  신호를 heartbeat라고 부른다. [연결 감지 코드][transport], [접속 정보 접근 규칙][presence-rules]
- **게임 데이터 수신과 구독:** 게임 세션을 관리하는 코드가 공개 정보(`public`)와
  본인만 볼 수 있는 정보(`private`)의 구독을 시작하고 관리한다. 라이어스포커는
  공개 정보와 손패를 받았는지, 서버의 게임 단계와 남은 카드 수가 어떤지를 따로
  확인한다. 구독을 시작했다는 사실만으로 필요한 데이터를 모두 받았다고 볼 수는 없다.
  [구독을 시작하는 코드][game-subscribe], [라이어스포커의 준비 판정 코드][entry-ready]
- **화면 연출:** `GameScreenPhase`는 게임 화면의 표시 단계를 나타낸다. 게임 화면을
  조율하는 board의 코드는 연출 완료 여부와 라운드 안내를 관리하고,
  `AnimationController`는 애니메이션 재생을 제어한다. 이 기록은 서버의
  게임 상태(`status/phase`)와 구분된다.
  [화면 단계 코드][screen-phase], [Final Call의 화면 연출 기록][presentation-local]

**현재 코드는 이 상태 영역들을 모두 묶어 ‘복구 완료’로 판정하지 않는다.**
presence 복구 정상 경로는 접속 쓰기·join과 heartbeat 재개까지 처리한다. 다만 퇴장·세대
변경으로 처리를 생략한 경우에도 Future가 정상 반환할 수 있으므로 반환만으로 실제
presence 복구를 단정하지 않는다. guard는 콜백 정상 반환과 자체 연결·구독 세대로
완료를 판단한다. 필요한 게임 데이터·화면 준비까지 확인한 공통 완료 판정은 없다.

예를 들어 `통신 연결됨 / 참가 자격 유지 / 손패 대기 / 다른 참가자 때문에 게임 중단`
이라는 조합이 가능하다. 한 영역의 ‘정상’으로 다른 영역을 덮어쓰면 대응을 잘못 이해한다.

## 누가 무엇을 결정하는가

| 판단 주체 | 결정하는 일 | 이 판단만으로 확정되지 않는 일 |
| --- | --- | --- |
| 로컬 연결 monitor·network guard | 내 RTDB 연결 관측, 화면 입력 보호, 안내, 복구 재시도 | 서버 중단, 자격 유지, 최신 손패 준비 |
| RoomProvider·RoomService | 기존 방 복구, heartbeat, 퇴장 의도, 방·본인 제거 재확인 | 게임 규칙·승패·서버 턴 전이 |
| 서버 join·controller callable | 인증 UID, 방 상태, 기존 참가자 또는 controller 세션 검증 | 복귀 기기의 데이터 수신·연출 완료 |
| 서버 presence trigger·중단 처리 | 최신 presence 대조, 중단 생성·해제, 시간 보존·제외 | 기기의 안내 표시 시각 |
| 게임 세션 controller·board | public/private 해석, 화면 준비, 연출, 진행 명령 | 서버에서 허용하지 않은 행동·신규 참가 |
| RTDB rules | 클라이언트 읽기·presence 쓰기 허용 여부 | 구독 재생성, 복구 완료 |

## 상태 전이표

표의 다음 상태는 **그 영역에서의 결과**다. ‘guard 복구 완료’는 게임 전체 준비 완료가
아니며, ‘서버 중단 해제’도 클라이언트 데이터 준비 완료가 아니다.

### 연결과 로컬 입력 보호

| ID | 현재 상태·사건 | 조건 | 처리 | 다음 상태 |
| --- | --- | --- | --- | --- |
| G1 | guard 정상 → 연결 false | 연결 감시가 적용된 화면 | 복구 필요 기록, 입력 잠금, 안내 예약 | 복구 필요·단절 |
| G2 | 복구 필요 → 연결 true 또는 foreground 복귀 | foreground·연결됨·다른 재시도 없음 | 복구 콜백 호출 | 복구 중 |
| G3 | 복구 중 → 콜백 정상 반환 | mounted·연결됨·연결/연결 감시 구독 세대 동일 | 안내·재시도 타이머 정리, 입력 잠금 해제 | guard 복구 완료 |
| G4 | 복구 중 → 실패 또는 오래된 완료 | foreground·연결됨·복구 필요 | backoff 재시도 예약 | 재시도 대기 |
| G5 | 복구 중 → 재단절 | 연결 세대 변경 | 옛 완료로 잠금 해제하지 않음 | 복구 필요·단절 |
| G6 | 복구 필요 → background | foreground 아님 | 안내·재시도 타이머 취소 | 복구 필요 유지 |

근거: [guard][network-guard]. 단절 직후 즉시 잠그고 기본 3초 작은 안내·10초 모달을
예약한다. foreground 복귀 시 안내를 다시 예약하므로 항상 단절 시각부터 같은 벽시계
시간에 표시된다는 뜻은 아니다. 재시도 실패 횟수만으로 방을 종료하지 않는다.

### 참가 자격과 로컬 방 세션

| ID | 현재 상태·사건 | 조건 | 처리 | 다음 상태 |
| --- | --- | --- | --- | --- |
| R1 | 실행 중 방 → 참가자 재연결 | UID·프로필 존재, 퇴장 아님 | 기존 자격 보존 join, 세대 재검사, heartbeat | presence 복구 또는 무효화 |
| R2 | 로컬 저장 힌트 → 휴대폰 재실행 | 동일 UID·퇴장 차단 없음·서버 복원 조건 충족 | 복귀 안내; 사용자 선택 후 join·구독 시작 | 로컬 방 복원 |
| R3 | 복원 조사 → 복원 종류 none | 조회가 완료돼 조건 불충족 | 저장 힌트 삭제 | 복귀 대상 없음 |
| R4 | 복원 조사 → 일시 RoomCommandException | 복원 종류를 확정하지 못함 | 힌트 유지 | 복원 미확정 |
| R5 | 방 이용 → 본인 퇴장 | 다른 퇴장 진행 중 아님 | 퇴장 의도·세대 기록, heartbeat 중지, 요청 | 퇴장 중 |
| R6 | 퇴장 중 → 성공 | 응답 성공 또는 방/본인 active 노드 부재 확인 | 힌트·구독·로컬 상태 정리 | 퇴장 완료 |
| R7 | 퇴장 중 → 실패·재확인 불가 | 서버 퇴장 완료 증명 없음 | 오류 표시, 퇴장 의도 해제, 기존 세션 유지 | 방 이용 재개 가능 |
| R8 | 본인 누락 관측 → 재조회 | 연결·확인 작업 유효, 방 존재·본인 active 없음, 구독에도 본인 없음 | 강퇴 표시·로컬 정리 | 강퇴 확정 |
| R9 | 방 부재 후보 → 재조회 | 현재 세션·연결·존재 관측 유효, 방 없음 | 종료 사유 기록·로컬 정리 | 방 삭제 확정 |

근거: [RoomProvider][presence-recovery], [복원 분류][restore-classifier], [서버 join][join-policy].
서버 join은 기존 player의 status가 없거나 active이면 reconnect를 허용하는 반면,
휴대폰 재실행 분류는 active를 명시적으로 요구한다. `preserveProfile=true`는
기존 참가자가 없으면 신규 참가를 만들지 않는다.

### 서버 중단과 턴 시간

| ID | 현재 상태·사건 | 조건 | 처리 | 다음 상태 |
| --- | --- | --- | --- | --- |
| P1 | 진행 중 → 참가자 false | 이벤트가 최신 presence와 맞고 해당 참가자가 생존, 기존 참가자 중단 없음 | 중단·투표 조건 생성, 남은 시간 저장, deadline 비움 | 참가자 중단 |
| P2 | 참가자 중단 → 해당 UID true | 최신 presence도 true, 기록된 중단 UID와 일치 | 중단 해제; controller pause가 있으면 시간을 넘김 | controller만 중단 또는 턴 재개 |
| P3 | 진행 중 → controller false | 최신 controller presence도 false, 아직 pause 없음 | 별도 pause에 남은 시간 저장, deadline 비움 | controller 중단 |
| P4 | controller 중단 → controller true | 최신 presence도 true, pause 존재 | 참가자 중단이 있으면 시간 인계; 없으면 deadline 복원 | 참가자만 중단 또는 턴 재개 |
| P5 | A 중단 → B false | A의 중단 슬롯이 이미 존재 | B presence는 false일 수 있으나 두 번째 중단 생성 거부 | A 중단만 기록 |
| P6 | 중단 → 투표 승인·제외·만료 | 해당 중단 ID·각 명령 권한/마감/계속 가능 조건 | 참가자 노드 정리, 게임별 제외 또는 인원 부족 종료 | 게임 계속 또는 종료 |

근거: [참가자 중단][participant-pause], [controller pause][controller-pause],
[투표·제외 callable][stale-server], [만료 해결][expire-resolution].
현재 참가자 중단 슬롯은 하나다. P2/P4의 ‘남은 원인’ 검사는 참가자 한 슬롯과
controller pause 사이의 검사이며, 모든 단절 참가자를 다시 조사하는 검사가 아니다.

## 상황별 대응을 논리 단계로 읽기

아래 S01~S18은 현재 구현을 설명하는 대표 시나리오다. 사건 순서를 바꾸거나 게임·기기
역할을 바꾸면 다른 경우가 된다. 모든 조합이 자동 검증됐다는 뜻은 아니다.
의사코드의 `별도 경로`는 순서대로 기다리는 단계가 아니라 독립적으로 실행되는 처리다.

### S01. 게임 중 내 기기의 인터넷이 끊긴다

```text
내 RTDB 연결 false 또는 연결 스트림 오류를 받으면:
  로컬 guard: 입력 잠금 → 안내 예약 → 연결 복귀 대기                 [G1]
별도 서버 경로:
  등록된 onDisconnect가 전달되면 presence를 false로 변경
  최신 presence·게임 진행·생존 여부 검사 → 해당 서버 중단 처리         [P1/P3]
```

**결과:** 화면은 유지하면서 조작을 보호한다. 서버 중단은 서버가 false를 받아 처리한
시점부터다. 비행기 모드를 켠 시점부터 서버 타이머가 멈췄다고 해석하지 않는다.
**공백:** onDisconnect 등록 실패는 입장·복구를 실패시키지 않고 삼킨다. 서버 전달 시간과
예약 실패의 실제 영향은 별도 관찰이 필요하다. 근거: [연결 감지][transport], [예약][presence-arm].

### S02. 내 연결은 정상인데 다른 참가자의 heartbeat가 끊긴다

```text
태블릿이 참가자 목록을 평가하면:
  active player·connected·lastSeen 존재·20초 초과인지 검사
  같은 (UID, lastSeen)을 이미 신고했으면 건너뜀
  새 관측값이면 먼저 신고 기록 → 서버 callable 전송
서버 transaction:
  controller UID·session 검증
  최신 lastSeen이 더 새롭거나 stale이 아니면 변경하지 않음
  여전히 stale이면 presence false → 참가자 중단 시도                 [P1/P5]
```

**결과:** 오래된 관측값으로 돌아온 참가자를 다시 끊지 않도록 서버가 재검사한다.
**공백:** 신고 실패 시 in-flight만 해제하고 관측 기록은 남는다. 같은 lastSeen을 다음 평가에서
재신고하지 않는다. 후보 선정과 실제 서버 중단 성공을 구분한다. 근거: [stale 후보·tracker][stale-tracker], [신고][stale-report], [서버][stale-server].

### S03. 한 참가자가 끊겼다가 실행 중인 앱으로 돌아온다

```text
연결 true 뒤 방 복구가 시작되면:                                    [G2/R1]
  진행 중 복구가 있으면 그 Future를 공유
  방 없음 → 오류; 퇴장 중·퇴장 의도 있음 → 복구 생략
  현재 방·세션·연결 세대를 기억
  참가자 UID·프로필 확인 → preserveProfile=true join
  응답 뒤 현재 세대·방·퇴장 상태 재검사
  유효하면 heartbeat 재개
별도 서버 경로: 해당 참가자 최신 true → 기록된 중단 해제              [P2]
별도 guard 경로: 콜백 정상 반환·자체 세대 유효 → 입력 잠금 해제        [G3]
별도 게임 구독 경로: public/private 수신 → 화면 갱신
```

**결과:** 기존 참가 자격·좌석·게임 데이터의 소유 경로를 유지하며 presence를 복구한다.
제거된 참가자는 자동 신규 가입으로 되살리지 않는다.
**공백:** guard는 최신 게임 스냅샷 준비를 기다리지 않는다. 입력 잠금 해제가 최신 손패·턴
수신까지 증명하지 않는다. 근거: [복구][presence-recovery], [join][join-policy], [guard 완료][guard-recovery].

### S04. 태블릿만 끊겼다가 실행 중인 앱으로 돌아온다

로컬 controller session이 있으면 참가자 join 대신 controller presence를 직접 복구한다.
쓰기 뒤 방·세대·퇴장 상태가 유효하면 controller heartbeat를 재개한다. 서버는 최신
controller true를 대조한 뒤 pause를 해제한다 [P4]. 이 실행 중 쓰기의 rules는 UID를
확인하며 controller session을 검증하는 재실행 callable과 동일한 경로가 아니다.

**결과:** 참가자 중단이 없다면 보존 시간으로 턴 마감을 다시 만든다. 휴대폰의 controller
stale 안내만으로 서버 pause가 생성되지는 않는다. 근거: [쓰기][controller-write], [rules][controller-presence-rule], [pause][controller-pause].

### S05. 참가자와 태블릿이 함께 끊기고 순서대로 돌아온다

```text
먼저 끊긴 쪽: 유효한 남은 턴 시간 저장 → deadline 비움
나중에 끊긴 쪽: 별도 중단 슬롯 생성; 이미 비워진 deadline은 없음으로 저장
먼저 돌아온 쪽: 다른 중단이 있으면 보존 시간을 그쪽으로 인계 → deadline 유지
마지막 중단 해제: 보존 시간이 숫자이면 now + 남은 시간으로 deadline 복원
                원래 시간 제한이 없었다면 deadline을 만들지 않음
```

**결과:** 참가자 한 명과 controller의 중첩 중단은 복구 순서가 달라도 시간을 넘겨받는다.
서버가 멈춘 뒤 기다린 시간을 새 턴 시간에서 빼지 않는다. 근거: [참가자 시간 복원][participant-pause], [controller 시간 복원][controller-pause], [관련 검사][pause-test].

### S06. A·B가 끊겼는데 A만 돌아온다

```text
A false → A 중단 기록                                               [P1]
B false → 이미 A 슬롯 존재 → B 중단 추가 생성 안 함                  [P5]
A true  → 최신 A true 확인 → A 중단 해제                             [P2]
          이 분기에서 전체 참가자의 연결 상태를 다시 검사하지 않음
```

**현재 결과:** controller pause가 없다면 B가 false여도 deadline이 복원될 수 있다.
이것은 S05의 중첩 처리로 해결되지 않는 구현 공백이다. 같은 UID가 두 번 끊기는 S07과도
다르다. 근거: [begin/reconcile/cancel][participant-pause], [기존 비교 근거](../planning/SESSION_BEHAVIOR_COMPARISON_2026-10-04.md).

### S07. 복구 중 다시 끊기거나 첫 복구 응답이 늦게 도착한다

```text
새 단절·재연결 → 연결 세대 변경
옛 복구 응답 → 기억한 세대와 다르면 heartbeat 재개·guard 잠금 해제에 적용하지 않음
RoomProvider 복구 루프 → 새 연결이며 같은 세션·방이면 최신 연결 복구를 다시 시도
서버의 늦은 false/true 이벤트 → transaction의 최신 presence와 다르면 무시
```

**결과:** 이전 이벤트가 현재 단절을 지우는 것을 방어한다 [G5]. 이미 서버에 전송한
join·쓰기 자체를 취소한 것은 아니다. 앱 경합·서버 이벤트 순서 검사를 모두 봐야 한다.
근거: [복구 세대][presence-recovery], [guard 세대][guard-recovery], [서버 최신값 검사][participant-pause].

### S08. 앱을 background로 보냈다가 foreground로 가져온다

guard는 background에서 안내·재시도 타이머를 멈추고, 복구 필요 상태라면 foreground에서
안내와 재시도를 다시 시작한다 [G6→G2]. 태블릿 홈은 paused/detached에 controller presence를
중지하고 resumed에 재개한다. 일시 inactive는 이 홈의 중지 조건이 아니다.

**결과:** background·연결 끊김·프로세스 재실행은 같은 사건이 아니다. 프로세스가 살아
있을 때의 lifecycle 처리가 저장 힌트로 방을 찾는 S09/S11을 대신하지 않는다.
근거: [guard lifecycle][network-guard], [태블릿 홈][tablet-restore].

### S09. 휴대폰 앱을 완전히 종료한 뒤 다시 켠다

```text
AuthGate를 통과해 홈에 도달 → 첫 프레임 또는 연결 true에서 저장 힌트 조사
  힌트 없음 → 복귀 안내 없음
  저장 UID 불일치 또는 퇴장 의도 있음 → 힌트 삭제
  서버 본인 active 노드 없음 → none
  방 closed/finished → none
  방 waiting/seating → waitingRoom
  그 외 game public.status=playing·선택 게임 존재·private 노드 존재 → activeGame
  나머지 → none
none으로 판정 완료 → 힌트 삭제                                      [R3]
조사 중 일시 RoomCommandException → 힌트 유지                        [R4]
복귀 가능 → 안내 → 사용자 복귀 선택 → 다시 판정·join·방 구독·heartbeat [R2]
사용자 거절 → 퇴장 의도 기록·힌트 삭제; 이 조사 경로에서 서버 leave 요청은 안 함
```

**결과:** 저장 정보는 자격을 찾는 힌트이며 손패·게임 상태의 로컬 백업이 아니다.
실제 복귀 후 대기실 route를 거쳐 게임 흐름을 따른다. `true` 반환은 최신 데이터·연출
완료까지 뜻하지 않는다. 복귀 요청 중 퇴장이 확정되면 로컬 반영을 막고 서버 leave를
최선 노력으로 요청하는 보상 경로도 있다. 근거: [휴대폰 홈][phone-restore], [탐지·실제 복귀][player-restore], [분류][restore-classifier].

### S10. 카드 분배 도중 휴대폰을 다시 켠다

라이어스포커·Final Call은 분배 중 `public=playing/dealing`, 참가 명단을 두고 손패를
server.pendingHands에 보관한다. private는 아직 비어 있다. 방 status까지 playing으로
미러된 시점에 S09를 실행하면 private 존재 조건을 충족하지 못해 none으로 분류하고
저장 힌트를 지운다. 방 status가 waiting/seating이면 앞선 대기실 분기로 간다.

**현재 결과:** 참가 자격이 남아 있어도 정상적인 데이터 미공개 상태를 복원 불가로
분류하는 불일치가 있다. 분배 완료가 이미 지운 힌트를 되살리는 것은 아니다.
손패 0장·관전 복귀까지 같은 실패라고 일반화하지 않는다. 근거: [분류][restore-classifier], [LP 시작][lp-start], [FC 시작][fc-start], [상세 분배 사례](#참가-자격과-데이터-준비를-혼동하는-실제-분배-사례).

### S11. 태블릿 앱을 다시 켜거나 처음부터 오프라인으로 켠다

```text
홈 initState → 저장 방·controller session 로드
  힌트 없음 → 복원 대상 없음
  resume callable → 서버 UID·session·방 존재·closed 여부 검사
  seating이면 서버 방을 waiting으로 돌림
  성공 → controller presence·방 구독·heartbeat 복원
  진행 중 게임 → 게임 상태·에셋·좌석 조건 확인 후 게임 route 열기
  finished → 홈 현재 화면·게임 안 여는 중·방/게임 모두 finished일 때 대기실 정리
  not-found/permission-denied/failed-precondition → 저장 session 삭제
  기타 요청 실패 → 오류; 저장 session은 유지
```

**공백:** 최초 복원 실패로 roomCode가 없는 경우 resumed의 presence 재개는 반환한다.
이 홈에는 연결 true를 받아 저장 방 복원을 다시 시작하는 휴대폰과 같은 경로가 없다.
방을 복원했더라도 새 화면 State에서 연출 완료 기록이 다시 초기화될 수 있다.
근거: [태블릿 홈][tablet-restore], [서비스 복원][controller-restore], [서버 resume][controller-resume-server], [결과 정리][finished-restore].

### S12. 연결은 돌아왔지만 public/private 구독이 오류 또는 빈 값을 낸다

```text
public 빈 값 → 즉시 삭제 확정 안 함 → 1.5초 뒤 한 번 재조회
  그동안 정상 stream 도착 → 확인 세대 변경 → 옛 조회 결과 버림
  유효한 재조회에 값 있음 → public 반영
  유효한 재조회에 값 없음 → 게임 제거 상태로 전이
  조회 자체 실패 → 마지막 정상 상태 유지
public permission-denied → 오류 처리 + 같은 재확인 경로; 오류만으로 삭제 확정 안 함
private 오류 → 게임별 오류 처리
```

**결과:** ‘조회 오류’와 ‘정상 조회에서 없음’을 구분한다. 공개 스냅샷은 startedAt과
revision으로 이전 판·이전 revision을 거르는 처리도 있다.
**공백:** 공통 controller에는 종료된 구독을 재생성하는 복구 경로가 없다. LP는 일부
권한·native 오류 표시를 생략한다. 일반 RTDB 자동 재연결이 권한 오류 후 재구독과 최신
public/private 준비까지 보장하는지 별도 검증해야 한다. 근거: [구독·재확인][game-subscribe], [LP 오류 처리][lp-subscription-error].

### S13. 행동을 서버에 보낸 뒤 응답이 사라진다

```text
공용 run 명령 → commandInFlight면 중복 시작 안 함
callable 실패·시간초과:
  재전송을 켠 명령 + 일시 오류이면 같은 payload로 예산 안에서 재시도
  LP 제출 서버: 같은 commandId 처리 기록이 있으면 이전 결과 반환
  LP 제출 클라이언트: 호출 실패 뒤 제출 카드가 손패에서 제거됐는지 제한적으로 재확인
최종 응답·확인 실패 → 오류 기록; 명령 잠금 해제
별도 public/private stream → 실제 서버 반영 상태를 화면에 전달
```

**결과:** 응답 실패만으로 서버 미실행을 확정하지 않는다. 기본 callable 정책은 요청
1회 8초·전체 12초·최대 4회이며, LP 추가 손패 확인이나 다른 명령 정책을 포함한 모든
처리가 12초 안에 끝난다는 뜻은 아니다. timeout은 서버 명령을 취소하지 않는다.
**공백:** 모든 명령이 멱등하거나 하나의 잠금을 쓰는 것은 아니다. 앱 재실행 후 미확정
명령을 재전송하는 공통 영속 outbox도 없다. 근거: [정책][callable-retry], [LP 제출][submit-server], [LP 재확인][submit-client].

### S14. 분배·라운드 연출 완료 알림이 실패하거나 새 판과 겹친다

GameProgressCommand는 판 시작 시각·라운드·단계로 만든 key의 요청을 보내고 실패하면
기본 3초 뒤 재시도한다. 단계·세대가 바뀌거나 화면이 폐기되면 옛 재시도를 멈춘다.
이미 전송된 요청은 취소할 수 없다. 분배 완료 callable은 기대 startedAt·round를
받지 않으므로 클라이언트 key 검사와 서버에서 옛 요청을 거절하는 계약을 구분한다.

**공백:** 새 화면이 이미 끝난 연출을 다시 선택할 수 있다. 같은 State의 pause/resume
검사는 프로세스 재실행 후 연출 복원을 증명하지 않는다. 근거: [진행 명령][progress-command], [화면 단계][screen-phase], [FC 로컬 기록][presentation-local], [분배 완료][lp-deal-complete].

### S15. 본인이 퇴장하며 복구나 응답 유실이 겹친다

```text
퇴장 버튼 → 중복 퇴장이면 반환
  퇴장 의도 설정·세션 세대 변경·heartbeat 중지                       [R5]
  대기실 leave 또는 게임별 leave 요청
  응답 성공 → 힌트·구독·메모리 정리                                 [R6]
  응답 실패 → 최대 4초 재조회
    방 없음 또는 본인 active 노드 없음 → 성공으로 정리               [R6]
    그 외/조회 실패 → 오류·기존 세션 유지·퇴장 의도 해제              [R7]
옛 복구 응답 → 세대·퇴장 상태 재검사로 로컬 재개 방지
```

**서버 차이:** 대기실 leave는 참가자 노드를 삭제한다. 생존자의 진행 중 game leave는
room player를 false로 남기고 `left` 중단을 시도한다. 따라서 게임 퇴장 성공은 즉시 서버
참가자 노드 삭제와 다르다. 이미 다른 UID 중단이 있으면 단일 슬롯 제약도 적용된다.
**공백:** game leave가 반영돼도 응답이 유실되고 active 노드가 남으면 재조회는 성공을
증명하지 못해 복구를 다시 허용할 수 있다. 근거: [퇴장][leave-client], [재조회][leave-recheck], [게임별 leave][lp-leave].

### S16. 강퇴·제외된 기기가 연결을 켜거나 재실행한다

players 구독에서 본인 누락을 보면 연결돼 있을 때 방·본인 active 노드를 재조회한다.
본인이 여전히 구독/서버에 있으면 유지한다. 방이 없으면 방 삭제, 방은 있고 본인이
없으면 강퇴로 확정한다 [R8/R9]. 재확인 실패는 마지막 상태를 유지한다.
자동 복구 join은 없는 참가자를 신규 생성하지 않고, presence rules도 기존 active
참가자의 쓰기를 요구한다. 재실행 탐지도 active 노드 부재면 힌트를 지운다.

**결과:** 읽기 권한 오류 하나만으로 강퇴를 단정하지 않으며, 확정 제거 후 자동 복구와
늦은 heartbeat로 참가자가 재등장하는 것을 방어한다. 대기실 removePlayer는 playing에서
거절되며 게임 중 제외는 S17 경로다. 근거: [제거 확인][removal-check], [join][join-policy], [rules][presence-rules].

### S17. 참가자가 돌아오지 않아 투표·제외·중단 만료로 처리한다

중단 생성 시 해당 UID를 뺀 생존 인원과 연결된 투표 자격자를 계산하고, 계속 가능 여부·
필요 표 수·기본 60초 마감을 저장한다. 마감 전 자격자의 투표가 충족되거나 controller가
허용된 제외를 요청하면 해당 UID를 지우고 게임별 제외 처리를 한다. 만료 시에는 저장된
canContinue에 따라 제외 후 계속하거나 인원 부족 종료한다. 인원 부족일 때 controller의
즉시 종료 경로도 있다. 잘못된 중단 ID·권한·아직 이른 만료는 각각 거절/무변경으로 처리한다.

**경계:** 기록된 한 중단을 해결하는 흐름이다 [P6]. 여러 단절 참가자를 집합으로 추적해
제외 후 전체 중단·인원을 재계산하는 흐름은 아니다. 최소 인원과 팀 구성 같은 게임별
조건을 하나의 공통 숫자로 일반화하지 않는다. 근거: [중단 생성][participant-pause], [투표·제외][stale-server], [만료][expire-resolution], [즉시 종료][finish-now-resolution].

### S18. 게임 종료·방 종료·방 삭제·장기 오프라인을 만난다

```text
game finished → 결과 표시와 방 상태 미러
  controller 게임 route 종료 뒤 방도 finished이면 선택 해제 → 대기 상태 복원
  결과 직후 controller 재실행 → S11의 홈 정리 조건 충족 시 같은 정리
controller 명시적 closeRoom → 서버 closed, 저장 controller session 정리
room closed 관측 → 로컬 종료 처리
room 존재 마커 없음 → 연결 중 재조회 → 최신 방 부재 확인 뒤 삭제 확정 [R9]
서버 정리 schedule → cleanupAt/오래된 heartbeat 후보 수집 → 최신 방 재검사 → 삭제 여부 결정
```

**결과:** 게임 종료는 다음 게임을 준비할 수 있는 방으로 돌아가는 흐름이며 방 전체
종료·삭제와 다르다. controller presence false만으로 방 종료를 확정하지 않는다.
정리 판정은 waiting 등에서 마지막 controller heartbeat + 3분, playing에서 +15분,
finished에서 retainUntil(없으면 유효한 lastSeen +15분), closed에서 cleanupAt을 사용한다.
5분 주기 실행과 후보 제한이 있으므로 각 숫자는 정확한 삭제 시각이나 복구 보장 시간이
아니다. 소스 상단의 오래된 주석보다 현재 후보 조회·판정 구현을 기준으로 읽는다.
근거: [결과→대기실][finished-restore], [방 종료·정리][room-lifecycle], [클라이언트 삭제 확인][removal-check].

## 구현이 지키려는 규칙과 현재 경계

| 규칙 | 코드에서 확인한 방어 | 현재 한계 |
| --- | --- | --- |
| 연결 단절만으로 참가 자격·방 삭제를 확정하지 않음 | 참가자/방 재조회, 조회 오류 시 상태 유지 | 휴대폰 재실행의 private 존재 조건이 분배 중 복원을 차단 |
| 퇴장한 방을 늦은 복구로 되살리지 않음 | 퇴장 의도·세대 검사, reconnectOnly join, presence rules | 게임 leave 응답 유실 시 active 노드가 남아 성공 판정 미확정 |
| 오래된 비동기 결과가 현재 연결·판을 덮지 않음 | 연결/세션 세대, 최신 presence, public startedAt/revision, 진행 key | 이미 전송한 서버 요청 취소·새 판 검증은 별도 계약 |
| 중단이 남으면 턴 시간을 재개하지 않음 | 참가자 한 슬롯과 controller pause의 시간 인계 | 여러 참가자 동시 단절을 전체 재검사하지 않음 |
| 응답 유실로 같은 행동을 두 번 반영하지 않음 | 적용 명령의 동일 payload/commandId, LP 처리 기록 | 모든 callable의 멱등성·재실행 후 복원 보장은 아님 |
| 조작 가능해질 때 필요한 데이터가 준비됨 | 게임별 화면 준비 판정 존재 | guard 완료와 public/private 준비를 묶은 공통 판정 없음 |

이 표는 새 정책이나 보장 선언이 아니라 구현을 평가하는 기준이다. 공백 수정은
[SESSION-RECONNECT-02](../planning/TASKS.md#session-reconnect-02)의 담당 범위·계약 합의가
필요하며, 이 문서 작성으로 해당 작업을 완료하거나 보류를 해제하지 않는다.

## 시나리오 조합과 확인 범위

| 비교할 축 | 독립적으로 확인할 경우 | 연결된 설명 |
| --- | --- | --- |
| 실행 수명 | 실행 중 재연결 / background 복귀 / 프로세스 재실행 / 최초 오프라인 | S03·S04 / S08 / S09·S11 |
| 역할·단절 수 | 참가자 한 명 / controller / 둘 중첩 / 여러 참가자 / 같은 참가자 반복 | S03 / S04 / S05 / S06 / S07 |
| 게임 데이터 | 대기실 / 분배 미공개 / 진행 / 관전·빈 손패 / 결과 | S09 / S10 / S03·S12 / 게임별 준비 판정 / S18 |
| 오류 경로 | onDisconnect 실패 / stale 신고 실패 / 구독 권한 오류 / callable 응답 유실 | S01 / S02 / S12 / S13·S15 |
| 겹치는 사건 | 복구 중 재단절 / 복구 중 퇴장 / 재실행 전 제외 / 새 판 뒤 옛 명령 완료 | S07 / S15 / S16 / S14 |
| 종료 판정 | 본인 leave / controller 강퇴 / 중단 후 제외 / game finished / room closed·삭제 | S15 / S16 / S17 / S18 |

라이어스포커·Final Call·Mafia의 서버 게임 단계와 private 형태는 서로 다르다. 관전·
빈 손패·역할 데이터에 대해서는 각 게임의 준비 판정과 명령 검증을 확인하며 분배 사례를
그대로 적용하지 않는다. 이 문서는 공통 복구/세션 분기와 알려진 게임별 차이를 설명하고,
게임 전체 규칙·모든 연출 단계·모든 기기/OS 조합까지 열거하지 않는다.
실제 실행 기록은 [현재 기준 수동 테스트](PRE_DEVELOPMENT_AUTH_NETWORK_SESSION_TEST.md),
과거 검증 범위는 [기술 참고](AUTH_NETWORK_SESSION_TECHNICAL_REFERENCE.md)와
[완료 작업](../planning/COMPLETED_TASKS.md)에 있다. 아래 상세 장의 테스트 설명 역시
이번 문서 작성에서 테스트를 실행했다는 뜻은 아니다.

## 구현·데이터 위치 찾아보기

논리를 읽은 뒤 실제 판정값을 찾을 때 사용하는 표다. 아래 서버 경로는 별도 JSON
파일명이 아니라 RTDB 데이터 트리다. 로컬 저장 힌트와 Firebase 디스크 캐시는 서로 다르다.

| 확인할 사실 | 데이터·메모리 위치 | 담당 구현 |
| --- | --- | --- |
| 로그인·홈 진입 | Auth 현재 UID, 온보딩 상태 | [AuthGate][auth-gate] |
| 내 RTDB 연결·입력 보호 | `.info/connected`, `_needsRecovery`, 연결 감시 구독/연결 세대 | [monitor][transport], [guard][network-guard] |
| 방 참가 자격·presence | `rooms/{code}/players/{uid}`의 status·isConnected·lastSeen | [RoomService][restore-read], [서버 join][join-policy] |
| controller 자격·presence | 방의 controllerUid·controllerSessionId, controllerPresence의 connected·lastSeen | [controller 검증][controller-resume-server], [쓰기 규칙][controller-presence-rule] |
| 게임 자격·공개 진행 | `rooms/{code}/game/public`의 players·status·phase·startedAt·revision | 게임별 validator, [공개 구독][game-subscribe] |
| 개인 정보 준비 | `rooms/{code}/game/private/{uid}`; LP 구독은 그 아래 hand | [구독][game-subscribe], [LP 준비 판정][entry-ready] |
| 중단·시간 보존 | game/public.interruption·turnDeadlineAt, game/server.interruption·controllerPause | [참가자][participant-pause], [controller][controller-pause] |
| 앱 재실행 힌트 | SharedPreferences의 UID·방 코드·공개 프로필 또는 controller session | [참가자 저장](../../lib/platform/home/room/services/player_room_session_store.dart), [controller 저장](../../packages/game_kit/lib/session/controller_room_session_store.dart) |
| 퇴장·오래된 결과 차단 | RoomLeaveIntent, RoomProvider의 세션/연결 세대·확인 ID | [provider][leave-client] |
| 화면 연출·명령 처리 | GameScreenPhase, board 로컬 완료값, commandInFlight·progress key | [화면][screen-phase], [진행 명령][progress-command] |
| 방 종료·정리 | 방 status·cleanupAt·retainUntil·controllerPresence.lastSeen | [방 lifecycle][room-lifecycle] |

presence rules의 ‘기존 active 참가자’ 조건은 기존 nickname 존재와 status가 active이거나
아직 없는 구형 데이터 호환 조건을 포함한다. 이는 status=active를 명시적으로 요구하는
휴대폰 재실행 분류와 같지 않다. game/public 읽기와 game/private 읽기도 서로 다른
rules를 사용하므로 한 경로의 읽기 성공으로 다른 경로의 자격·준비를 판정하지 않는다.

## 사건별 상세 근거

이하에서는 앞의 전이와 시나리오를 감지·판단·변경·완료·실패 관측으로 다시 확인한다.

## 1. 단절

확인 기준: 위에 명시한 HEAD와 조사 시 작업 트리. 내 기기의 연결 종료와 상대 기기의 stale presence는
서로 다른 경로로 감지된다.

1. **감지:** 내 연결은 [RealtimeConnectionMonitor][transport]가 `.info/connected`를
   구독한다. 연결 스트림 오류도 false로 전달한다. 서버는 미리 등록한 `onDisconnect`의
   presence 변경을 받는다. 태블릿은 [20초 지난 참가자 heartbeat][stale-report]도 후보로
   잡아 서버에 신고한다.
2. **판단:** [AppNetworkGuard][network-guard]는 로컬 입력 보호와 안내를 판단한다.
   [stale 신고 서버 transaction][stale-server]은 controller UID·session과 최신 heartbeat를 다시 확인한다.
   게임 중단·시간 보존은 서버의 참가자 중단 처리와 [controller pause 처리][controller-pause]가
   결정한다. controller heartbeat가 오래됐다는 휴대폰의 표시 판정만으로 서버 타이머가
   멈추지는 않는다. controller pause trigger는 `connected` 값 변화를 처리한다.
3. **변경:** 로컬 guard는 즉시 입력을 막고 기본 3초 뒤 작은 안내, 단절부터 10초 뒤
   모달을 표시한다. 서버 게임 중단은 남은 시간을 보관하고 deadline을 비운다.
   참가자 중단과 controller pause는 합성되며, 로그인·참가 자격은 이 연결 변화와 별개다.
4. **성공 확인:** 로컬 입력 잠금·안내가 작동하는지와 서버 deadline 보존을 각각 확인한다.
   로컬 false 수신만으로 서버 interruption 생성까지 성공했다고 판단하지 않는다.
5. **실패가 남는 곳:** 연결 기록은 debug 통신 로그, heartbeat·stale 신고 실패는
   `debugPrint`에 남는다. `onDisconnect` 등록 실패는 [서비스에서 catch로 삼킨다][presence-arm].
   stale 신고는 요청 전에 `(uid,lastSeen)`을 기록하므로 실패해도 같은 관측값으로 다시
   신고하지 않는다. 서버가 단절을 확인하지 못하면 기존 연결·게임 진행 상태가 남을 수 있다.

테스트·확인 기준: [guard 검사][guard-test]는 입력·안내·복구 경합을,
[stale 판정 검사][stale-test]는 20초 경계와 최신 heartbeat·중복 신고를,
[controller 시간 검사][pause-test]는 남은 시간과 참가자+controller 중첩 중단을 검증한다.
현재 [참가자 중단 슬롯][participant-pause]은 한 UID만 추적한다. A 단절 → B 단절 → A 복귀에서
B의 단절을 유지하는 검사는 이 단일 참가자/컨트롤러 검사로 대체할 수 없다. OS/Firebase가
실제로 `onDisconnect`를 전달하는 시간과 stale 신고 실패 후 재시도도 별도 검증 대상이다.

## 2. 재연결

확인 기준: 위에 명시한 HEAD와 조사 시 작업 트리. 실행 중인 세션의 연결 복구 흐름이다.

1. **감지:** `.info/connected=true`와 foreground 복귀가 guard·RoomProvider의 복구를
   시작한다. [RoomProvider][presence-recovery]는 진행 중 복구 Future를 공유하고 연결·세션
   세대값으로 오래된 작업을 무효화한다.
2. **판단:** 실행 중 controller 복구는 로컬 session 유무로 분기한 뒤 직접 presence를
   쓴다. [rules][controller-presence-rule]는 controller UID를 확인하며 이 쓰기에서 session을
   검증하지 않는다. player는 서버 join 정책으로 기존 active 자격을 재확인한다.
   `preserveProfile: true` 복구는 이미 제거된 참가자를 새로 만들 수 없다. [서버 join 정책][join-policy]
3. **변경:** controller presence 또는 player join이 성공하면 heartbeat를 다시 시작한다.
   서버는 해당 interruption/pause를 해제하고 다른 중단 원인이 남지 않은 경로에서
   deadline을 복원한다. 게임의 public/private 데이터는 별도 stream이 받아 화면에 반영한다.
4. **성공 확인:** 현재 guard는 `onRetry` 정상 반환과 연결·구독 세대의 일치로 보호를
   해제한다. [복구 완료 판정][guard-recovery]에는 public/private 최신 스냅샷 수신 대기가
   없다. [GameSessionController][game-subscribe]도 시작할 때 구독을 열지만 권한 오류로
   끝난 구독을 다시 만드는 복구 경로는 없다. RTDB의 일반 자동 재연결과 구독 재생성은 다르다.
5. **실패가 남는 곳:** guard의 `_needsRecovery`와 입력 잠금·안내가 유지되고 복구 재시도가
   이어진다. debug의 `recovery_failed` 기록은 영속 오류 저장이 아니다. 표시 대상 구독 오류는
   controller의 오류 문구에 남을 수 있으며, [LP는 권한·일시 native 오류 표시를 생략한다][lp-subscription-error].
   [공개 상태 재확인][public-recheck]은 1.5초 뒤
   조회가 실패하면 마지막 정상 화면을 유지하고, 빈 값이 확인되면 게임 제거 상태로 바꾼다.

테스트·확인 기준: [guard 테스트][guard-test], [서버 기존 참가자 복구][join-test],
[태블릿 시간 재개][resume-test]가 각 경계를 검증한다. [게임 세션 검사][game-session-test]는
정상 stream 뒤 늦은 빈 조회를 버리고 반복 권한 오류를 삭제로 오인하지 않는 것을 검사한다.
권한 오류 후 public/private 재구독, 같은 판의 최신 데이터 준비 후 입력 허용, 복구 중
재단절은 각각의 관측값으로 확인해야 한다. presence 성공만으로 이 세 항목을 통과 처리할 수 없다.

## 3. 앱 재실행

확인 기준: 위에 명시한 HEAD와 조사 시 작업 트리. 로컬 저장 정보는 서버 자격을 찾는 힌트다.

1. **감지:** [휴대폰 홈][phone-restore]은 첫 프레임과 연결 true에서 저장 세션을 조사한다.
   [태블릿 홈][tablet-restore]은 `initState`에서 저장 controller 방 복원을 한 번 시작한다.
   앞서 [AuthGate][auth-gate]가 로그인과 온보딩을 통과시켜야 홈에 도달한다.
2. **판단:** 휴대폰은 현재 UID·저장 UID·퇴장 의도와 서버 참가자 active 여부를 확인한 뒤
   [복원 종류][restore-classifier]를 계산한다. 태블릿은 서버의 controller UID·session으로
   [복구를 검증한다][controller-resume-server]. 휴대폰에서는 유효한 힌트를 찾으면 복귀 안내를 보여주며 사용자의
   복귀 선택 뒤 실제 join을 호출한다.
3. **변경:** [휴대폰 복귀][player-restore]는 기존 profile을 보존한 join 뒤 roomCode·방 구독·
   heartbeat를 설정하고 대기실 route를 연다. 태블릿은 방 구독과 heartbeat를 복원하고,
   [게임 상태·에셋·좌석을 확인한 뒤][tablet-route] 게임 route를 연다. 서버 seating 복원은
   waiting으로 되돌리며, finished 방은 [별도 대기실 정리 경로][finished-restore]를 사용한다.
4. **성공 확인:** 휴대폰의 true 반환은 join과 로컬 구독 시작을 뜻한다. 게임 public/private
   준비와 현재 단계의 화면 복원은 이후 확인 사항이다. 이미 완료한 GAME START/ROUND/분배
   연출을 재생하지 않았는지도 별도로 본다. Final Call의 [로컬 완료값][presentation-local]과
   [단계 계산][presentation-stage], 라이어스포커 [태블릿 첫 스냅샷 처리][tablet-presentation]에는
   새 State로 복귀할 때 연출을 다시 선택할 수 있는 분기가 있다.
5. **실패가 남는 곳:** 휴대폰은 복원 판정 none이면 [저장 힌트를 삭제][restore-detect]한다.
   조사 중 일시 `RoomCommandException`은 힌트를 유지하지만, 실제 복귀 실패는 provider의
   `errorMessage`에 남고 종료·미존재로 분류된 실패는 힌트를 지운다. 태블릿은
   [not-found/permission-denied/failed-precondition에서 저장 세션을 지운다][controller-restore].
   최초 오프라인 복구가 실패해 roomCode가 없으면 이후 lifecycle의 presence 재개만으로
   저장 방 복원을 다시 시작하지 않는다.

### 참가 자격과 데이터 준비를 혼동하는 실제 분배 사례

| 순서 | 서버·클라이언트의 현재 상태 | 결과 |
| --- | --- | --- |
| 정상 분배 시작 | 라이어스포커와 Final Call은 `public.status=playing`, `phase=dealing`, 참가 명단을 저장한다. 손패는 `server.pendingHands`에 있고 `private={}`다. 별도 [방 상태 미러][room-status-mirror]가 room.status에도 playing을 반영한다. [LP 시작][lp-start], [Final Call 시작·라운드][fc-start] | 참가자는 남아 있지만 본인 private 노드는 아직 없다. |
| 방 status도 playing으로 반영된 분배 중 휴대폰 재실행 | [복원 조회][restore-read]가 `game/private/{uid}.exists`를 읽고, [판정][restore-classifier]이 `gameStatus=playing && selectedGameId && privateGameDataExists`를 요구한다. public phase·게임 명단은 이 판정에서 확인하지 않는다. | 정상 참가자도 none으로 분류된다. |
| none 처리 | [탐지][restore-detect]와 [실제 복귀][player-restore]가 저장 세션을 삭제한다. | 복귀 안내·저장 힌트가 사라진다. 이 로컬 처리가 서버의 참가 자격을 삭제하는 것은 아니다. |
| 정상 분배 완료 | 서버가 pendingHands를 private에 공개하고 phase를 playing으로 바꾼다. [LP 완료][lp-deal-complete], [Final Call 완료][fc-deal-complete] | 데이터 준비의 전이이며, 앞서 지운 로컬 복귀 힌트를 복원하는 경로는 아니다. |

**확인된 불일치:** active 참가자 확인에 더해 개인 데이터 존재를 복원 조건으로 사용하므로,
분배 완료 전 데이터 미공개가 복원 불가로 분류된다. room.status가 아직 waiting/seating이면 먼저 waitingRoom으로
분류하므로 위 실패 조건은 방 status의 미러 반영 뒤다. 손패 0장이나 탈락 관전까지
같은 이유로 실패한다고 일반화하지 않는다.
각 게임의 private 노드 유지와 [화면 준비 판정][entry-ready]을 따로 확인해야 한다.

테스트·확인 기준: [분배 데이터 검사][dealing-test]가 `dealing`, `private={}`, 생존자의
pendingHands를 정상 상태로 검증한다. [방 정책·controller 세션 검사][join-test]와
[연출 pause/resume 검사][presentation-test]도 존재한다. 그러나 현재 휴대폰 복원 판정을
실행하는 회귀 테스트는 없고, 연출 검사는 같은 State의 pause/resume이며 프로세스
재실행의 완료값 복원 검사가 아니다. 분배 중 재실행, 최초 오프라인 태블릿 복구,
빈 손패·관전 복귀, 완료 연출 재실행을 별도 검증해야 한다.

## 4. 명령 응답 유실

확인 기준: 위에 명시한 HEAD와 조사 시 작업 트리. 서버 변경이 끝났지만 callable 응답을 못 받으면
클라이언트의 실패와 서버의 미실행을 동일하게 판단할 수 없다.

1. **감지:** [게임 명령 실행][command-run]이 Future 예외·timeout 또는 명시적인
   `success:false`를 받는다. 공용 `run()`을 쓰는 경로는 `commandInFlight`로 중복 시작을
   막는다. 게임별 메뉴·진행 명령의 잠금은 별도이므로 모든 명령을 하나로 직렬화하는 보장은 아니다.
2. **판단:** [callable 정책][callable-retry]은 기본 1회 대기 8초·전체 12초 예산 안에서
   최대 4회를 허용한다. 일시 오류 재전송은 호출부가 켠 명령에만 적용한다.
   [GameCommandService][command-invoke]는 같은 payload를 유지한다. 예를 들어
   [LP 제출 서버][submit-server]는 transaction에서 같은 commandId의 처리 기록을 먼저
   확인하여 이전 결과를 반환한다. 이 보장을 모든 callable로 확대하지 않는다.
3. **변경:** 서버는 제출·개인 손패·턴·revision과 처리 기록을 transaction에 반영하고,
   클라이언트 게임 상태는 public/private stream으로 갱신한다. timeout은 이미 전송한
   서버 명령을 취소하지 않는다. 라이어스포커 [제출 controller][submit-client]는 호출 실패
   뒤에도 제출 카드가 private 손패에서 사라졌는지 제한된 횟수로 확인한다.
4. **성공 확인:** 재시도 응답이 성공하거나 LP 제출의 손패 제거 확인이 성공하면 해당
   호출을 성공으로 반환한다. 최종 게임 진행은 서버 스냅샷으로 확인한다.
   [GameProgressCommand][progress-command]는 현재 판·단계 key와 세대가 유효할 때만
   진행 명령 재시도를 계속하며, 성공하면 멈춘다. 이미 전송된 옛 요청을 서버에서 새 판과
   구별하는 계약과는 별개다. 분배 완료 callable은 기대 startedAt·round를 받지 않는다.
5. **실패가 남는 곳:** 공용 `run()`의 예외는 게임 state의 오류 문구와 [CrashReporting][crash-log]
   경로에 남고 finally에서 입력 잠금을 푼다. LP 제출 특수 경로는 손패 재확인까지 실패하면
   state 오류 문구와 명령 서비스의 debug 통신 로그에 남으며 CrashReporting을 호출하지 않는다.
   debug 통신 로그에는 전송·재전송·응답 시간축이 남는다.
   명령을 디스크에 저장해 앱 재실행 뒤 다시 보내는 공통 outbox는 이 경로에 없다.
   이때 서버에서 이미 반영한 행동을 새 commandId로 다시 보내도 안전하다고 판단할 수 없다.

테스트·확인 기준: [진행 명령 검사][progress-test]는 실패 후 재시도·단계 변경·폐기 뒤 늦은
실패를, [처리 기록 검사][command-record-test]는 기록 직렬화를 검증한다. 서버 성공 직후
응답 유실 → 동일 commandId 재요청을 끝까지 실행하는 제출 검사는 확인되지 않았다.
이 시나리오에서는 행동·손패 변경이 한 번인지, 최신 스냅샷이 도착하는지, 입력 잠금이
예산 안에서 풀리는지, 옛 진행 요청이 새 판을 변경하지 않는지를 따로 확인해야 한다.

## 5. 퇴장·강퇴

확인 기준: 위에 명시한 HEAD와 조사 시 작업 트리. 대기실 제거, 게임 생존자의 퇴장 중단,
서버의 최종 제외는 서로 다른 전이다.

1. **감지:** 본인 퇴장은 버튼에서 `leaveRoom/leaveGame`을 요청한다. 강퇴·본인 제거는
   방 players 구독에서 자신이 사라졌을 때 [재확인][removal-check]을 시작한다.
   구독 권한 오류만으로 강퇴를 확정하지 않는다.
2. **판단:** [대기실 서버][room-leave-server]는 강퇴에 UID·controller session을, 본인
   퇴장에 인증 UID를 검증하고 `playing`에서 대기실 leave/removePlayer를 거절한다.
   게임별 leave는 public roster의
   생존 여부·게임 종료 여부를 판정한다. [LP][lp-leave], [Final Call][fc-leave],
   [Mafia][mafia-leave] 모두 생존자의 진행 중 퇴장을 `left` 중단으로 처리하는 경로가 있다.
3. **변경:** [RoomProvider 퇴장][leave-client]은 퇴장 의도·세대를 기록하고 heartbeat를
   멈춘 뒤 요청한다. [퇴장 요청의 별도 재시도 예산][leave-budget]은 1회 10초·전체 20초다.
   대기실 leave/removePlayer는 방 player를 삭제한다. 세 게임의
   생존자 leave는 room player를 `isConnected=false`로 남기고 interruption을 생성한다.
   서버의 중단 만료·제외 처리가 이후 해당 참가자 정리와 계속 진행/인원 부족 종료를 결정한다.
   성공 응답 뒤 클라이언트는 저장 힌트·구독·타이머·메모리 상태를 정리한다.
4. **성공 확인:** 퇴장 응답이 실패해도 [4초 서버 재조회][leave-recheck]로 방 부재 또는
   본인 active 노드 부재를 확인하면 퇴장 성공으로 정리한다. 강퇴는 별도 8초 재조회에서
   방은 남고 본인 active 참가자가 없음을 확인한 뒤 `wasKicked`와 로컬 정리를 반영한다.
   따라서 생존자 게임 leave의 성공은 즉각적인 서버 노드 삭제와 같지 않다.
5. **실패가 남는 곳:** 퇴장 실패와 재조회 미확정이면 errorMessage·기존 세션을 남기고
   퇴장 의도 마커를 해제해 복구를 다시 허용하며 heartbeat를 다시 시작한다.
   생존자 leave가 서버에서 이미 `left`로 반영됐어도
   응답이 유실되고 active 노드가 남아 있으면 재조회는 성공을 증명하지 못한다.
   강퇴 재조회 오류는 마지막 상태를 유지하고 debugPrint에 남는다. 로컬 `clearRoom`은
   구독·메모리 정리이며 Firebase의 디스크 캐시 삭제가 아니다.

테스트·확인 기준: [자동 복구 정책][join-test]과 [presence rules 검사][presence-rules-test]는
제거된 참가자가 join/늦은 heartbeat로 다시 생기지 않도록 검사한다. rules 검사는 실제
Firebase Rules 엔진 통합 검사가 아니다. [중단 만료 검사][expire-test]는 당사자 노드 정리·
최소 인원 종료·계속 진행·중복 처리를 검증한다. 생존자 game leave callable의 노드 보존과
응답 유실 뒤 클라이언트 처리, 직접 강퇴 UI, 종료 route 경합의 현재 Flutter 회귀 검사는
확인되지 않았다. 자발적 퇴장·controller 강퇴·중단 후 제외 각각에서 잔류와 재등장을 확인한다.

## 실패 기록을 읽는 범위와 검증 배선

[GameCommunicationLog][communication-log]는 debug에서 최근 200건을 메모리와
`[game_comm]` 콘솔에 남긴다. 앱 재실행 후 복원할 영속 사건 기록은 아니다.
[DevErrorLog][dev-error-log]도 debug 메모리 기록이며 콘솔에는 context·오류 타입·첫 frame을
남긴다. CrashReporting을 호출한 경로는 debug에서 DevErrorLog로, 비debug에서 Crashlytics로
보낸다. 위 흐름의 모든 실패가 Crashlytics에 자동 저장된다고 해석하지 않는다.
실패 상태의 서버 잔류와 로컬 오류 문구·콘솔 관측을 각각 확인해야 한다.

현재 [session/auth manifest][suite-manifest]가 요구하는 루트 Flutter 파일 20개는 없다.
이 문서에는 없는 파일을 테스트 근거로 링크하지 않았다. [FULL 실행 설정][full-pipeline]과
[CI][validation-ci]에도 game_kit 테스트 경로를 별도로 실행하는 배선이 없다. 따라서
package 테스트가 존재하는 사실, 과거 FULL/실기기 통과, 현재 후보의 검증 성공을 구분한다.
실제 명령·status·exit code와 실행 전후 working-tree 상태는 해당 실행의 evidence로 보고한다.

<!-- Reference links point to repository source, not an assumed production deployment. -->
[auth-gate]: ../../lib/platform/auth/widgets/auth_gate.dart
[transport]: ../../packages/game_kit/lib/core/network/realtime_connection_monitor.dart
[network-guard]: ../../packages/game_kit/lib/core/network/app_network_guard.dart
[guard-recovery]: ../../packages/game_kit/lib/core/network/app_network_guard.dart
[guard-test]: ../../packages/game_kit/test/core/network/app_network_guard_test.dart
[presence-recovery]: ../../lib/platform/home/room/providers/room_provider.dart
[controller-write]: ../../lib/platform/home/room/services/room_service.dart
[presence-arm]: ../../lib/platform/home/room/services/room_service.dart
[stale-tracker]: ../../lib/platform/home/room/services/player_presence.dart
[stale-report]: ../../lib/platform/home/room/providers/room_provider.dart
[stale-server]: ../../functions/src/game-interruption/functions.ts
[stale-test]: ../../functions/test/game-interruption.test.mjs
[participant-pause]: ../../functions/src/game-interruption/state.ts
[controller-pause]: ../../functions/src/game-interruption/controller-presence.ts
[pause-test]: ../../functions/test/controller-presence-timer.test.mjs
[resume-test]: ../../functions/test/controller-presence-timer.test.mjs
[join-policy]: ../../functions/src/room/room-join-policy.ts
[join-test]: ../../functions/test/room-lifecycle.test.mjs
[game-validation]: ../../functions/src/liars-poker/common/validator.ts
[presence-rules]: ../../database.rules.json
[controller-presence-rule]: ../../database.rules.json
[presence-rules-test]: ../../functions/test/room-presence-rules.test.mjs
[game-subscribe]: ../../packages/game_kit/lib/game_flow/game_session_controller.dart
[public-recheck]: ../../packages/game_kit/lib/game_flow/game_session_controller.dart
[game-session-test]: ../../packages/game_kit/test/game_flow/game_session_controller_test.dart
[entry-ready]: ../../packages/game_liars_poker/lib/shared/providers/game_controller.dart
[lp-subscription-error]: ../../packages/game_liars_poker/lib/shared/providers/game_controller.dart
[screen-phase]: ../../packages/game_kit/lib/game_flow/game_screen_phase.dart
[presentation-local]: ../../packages/game_final_call/lib/tablet/src/board_state.dart
[presentation-stage]: ../../packages/game_final_call/lib/tablet/providers/game_stage.dart
[tablet-presentation]: ../../packages/game_liars_poker/lib/tablet/src/board_state.dart
[presentation-test]: ../../packages/game_kit/test/game_flow/game_presentation_test.dart
[phone-restore]: ../../lib/platform/home/phone/screens/phone_home.dart
[tablet-restore]: ../../lib/platform/home/tablet/screens/tablet_home.dart
[tablet-route]: ../../lib/platform/home/tablet/screens/tablet_home.dart
[restore-classifier]: ../../lib/platform/home/room/services/room_common.dart
[restore-read]: ../../lib/platform/home/room/services/room_service.dart
[restore-detect]: ../../lib/platform/home/room/providers/room_provider.dart
[player-restore]: ../../lib/platform/home/room/providers/room_provider.dart
[controller-restore]: ../../lib/platform/home/room/services/room_service.dart
[controller-resume-server]: ../../functions/src/room/realtime-room-lifecycle.ts
[finished-restore]: ../../lib/platform/home/room/services/room_restore_to_waiting.dart
[room-status-mirror]: ../../functions/src/room/realtime-room-lifecycle.ts
[room-lifecycle]: ../../functions/src/room/realtime-room-lifecycle.ts
[lp-start]: ../../functions/src/liars-poker/start-game.ts
[fc-start]: ../../functions/src/final-call/start-game.ts
[lp-deal-complete]: ../../functions/src/liars-poker/complete-dealing.ts
[fc-deal-complete]: ../../functions/src/final-call/complete-dealing.ts
[dealing-test]: ../../functions/test/start-game-transaction.test.mjs
[command-run]: ../../packages/game_kit/lib/game_flow/game_session_controller.dart
[callable-retry]: ../../packages/game_kit/lib/services/callable_retry_policy.dart
[command-invoke]: ../../packages/game_kit/lib/services/game_command_service.dart
[submit-server]: ../../functions/src/liars-poker/submit-card.ts
[submit-client]: ../../packages/game_liars_poker/lib/shared/providers/game_controller.dart
[progress-command]: ../../packages/game_kit/lib/game_flow/game_progress_command.dart
[progress-test]: ../../packages/game_kit/test/game_flow/game_progress_command_test.dart
[command-record-test]: ../../functions/test/liars-poker-common.test.mjs
[crash-log]: ../../packages/game_kit/lib/core/diagnostics/crash_reporting.dart
[communication-log]: ../../packages/game_kit/lib/core/diagnostics/game_communication_log.dart
[dev-error-log]: ../../packages/game_kit/lib/core/diagnostics/dev_error_log.dart
[removal-check]: ../../lib/platform/home/room/providers/room_provider.dart
[room-leave-server]: ../../functions/src/room/realtime-room-lifecycle.ts
[leave-client]: ../../lib/platform/home/room/providers/room_provider.dart
[leave-budget]: ../../lib/platform/home/room/services/room_service.dart
[leave-recheck]: ../../lib/platform/home/room/providers/room_provider.dart
[lp-leave]: ../../functions/src/liars-poker/leave-game.ts
[fc-leave]: ../../functions/src/final-call/leave-game.ts
[mafia-leave]: ../../functions/src/mafia/end-game.ts
[expire-resolution]: ../../functions/src/game-interruption/expire-resolution.ts
[finish-now-resolution]: ../../functions/src/game-interruption/finish-now-resolution.ts
[expire-test]: ../../functions/test/game-interruption-expire-resolution.test.mjs
[suite-manifest]: ../../tool/mosigame_cli/test_suites.dart
[full-pipeline]: ../../tool/mosigame_cli/validate.dart
[validation-ci]: ../../.github/workflows/validate.yml
