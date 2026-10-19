# NET-RECOVERY-01

네트워크 복구 체감 지연

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

- 담당 Issue: 착수 승인 시 생성.
- 분류 결정 근거: 2026-10-08 사용자 요청으로 출시 전 필수 지정.

## 현재 동작

- RTDB의 `.info/connected`가 복구되면 저장된 휴대폰 또는 controller 세션으로 같은 방의
  presence와 구독을 복원한다.
- 앱의 주요 복구 단계는 각각 8초 제한을 사용한다.
- 복구 중에는 안내 화면을 표시한다. 일시적인 문제라면 그대로 기다릴 수 있고, 기다릴
  수 없으면 `게임과 그룹 나가기`를 선택할 수 있다.
- 참가자 단절 판정은 별도 계약이다. 기존 10초 heartbeat와 `onDisconnect`를 유지하며,
  태블릿이 마지막 `lastSeen` 후 20초를 초과한 후보를 서버에 한 번 검증 요청한다.

이 항목은 **세션과 방 상태를 보존하며 복구에는 성공했지만 시간이 길게 느껴지는 경우**만
다룬다. 두 번째 단절 뒤 방·게임을 잃는 현상은 체감 개선이 아니라 출시 차단
`SESSION-RECONNECT-01`이다.

- 현재 분류(2026-10-08): 사용자 요청으로 출시 전 필수로 옮겼다. 아래 과거 관찰 근거는
  보존하며, 측정 목표·점검 범위는 착수 시 확정한다.

## 기존 출시 후 관찰 분류의 근거

- 첫 단절은 30초 안에 앱 재시작 없이 같은 게임으로 복귀했다.
- 체감 시간에는 앱 코드뿐 아니라 OS 네트워크 전환과 Firebase SDK 재연결 시간이 포함된다.
- 상태를 보존한 단일 복구에서 출시를 막을 수준의 반복적인 지연 측정값은 아직 없다.
- 복구 안내와 명시적인 나가기 경로가 있어 앱이 무응답 상태로만 보이지는 않는다.

과거 반복 단절의 세션·방 유실에는 이 보류 근거를 적용하지 않았다. 수정 APK의
2026-08-31 라이어스포커 최종 테스트(Medium Tablet 에뮬레이터 + A32·A35)는 반복
단절을 포함해 통과했다. 당시 순수한 체감 지연만 출시 후 관찰하기로 했으며 상태 유실이 재발하면
다시 출시 차단 여부를 평가하기로 했다.

## 기존 우선순위 재평가 조건

기존 관찰 단계에서는 다음 중 하나가 확인되면 P1 또는 출시 차단 항목으로 재평가하기로 했다.

- 짧은 일시 단절 뒤에도 앱 재시작이 필요하다.
- SESSION-RECONNECT-01 수정 후에도 방, 게임 또는 남은 턴 상태가 유실된다.
- 일반적인 네트워크 전환에서 재연결이 반복적으로 30초 이상 걸린다.
- 같은 증상의 사용자 문의 또는 실제 세션 사례가 반복된다.
- Play Console, Crashlytics 또는 지원 기록에서 freeze·ANR·복구 실패가 확인된다.

30초와 반복 사례 기준은 최초 관찰 기준이며, 실제 배포 지표를 확보하면 조정한다.

## 조사할 때 수집할 근거

- 단절 시작, `.info/connected` 복구, 세션 복원 완료 시각
- 휴대폰/태블릿 역할, OS, 네트워크 전환 종류
- 앱 재시작 필요 여부와 방·게임 상태 보존 여부
- 개인정보를 제외한 `[dev_error]`, `[game_comm]`, `room_connection` 구조화 로그

production RTDB 관찰이 필요하면
[`Firebase MCP RTDB Read-only Pilot`](../../operations/FIREBASE_MCP.md)의 사전 승인과
단일 경로 조회 절차를 따른다.

## 완료 기준

- 짧은 단절 뒤 앱 재시작 없이 같은 방과 게임으로 자동 복귀한다.
- 게임 상태와 중단 시 보존한 남은 턴 시간이 유지된다.
- 측정한 복구 시간이 착수 시 합의한 목표 안에 들어온다.
- Android와 iOS 실제 기기에서 단절·복구 회귀 테스트를 완료한다.
- 관련 Flutter·Functions 자동 테스트와 Project CLI FULL validation이 통과한다.

## 관련 코드와 문서

- [`RoomProvider.retryConnectionRecovery`](../../../lib/platform/home/room/providers/room_provider.dart)
- [`RealtimeConnectionMonitor`](../../../packages/game_kit/lib/core/network/realtime_connection_monitor.dart)
- [`ControllerReconnectGuard`](../../../lib/platform/home/phone/widgets/controller_reconnect_guard.dart)
- [`사용자 로그인·네트워크·세션 안내`](../../operations/USER_AUTH_NETWORK_SESSION_GUIDE.md)
- [`인증·네트워크·세션 기술 참고`](../../operations/AUTH_NETWORK_SESSION_TECHNICAL_REFERENCE.md)

## 2026-10-08 보완 — newgui 복구 지연의 측정 경계

검토 후보는 [`newgui`의 `999c3e9`](https://github.com/WarmhanDongne/project00/tree/999c3e99086b9f917ea941cd8f283b8ac40f3f85)이며,
이 등록은 병합·구현·검증 완료를 뜻하지 않는다. 현재 작업의 순수 체감 지연 범위와
착수 시 목표·점검 범위를 합의하는 조건은 유지한다.

- [ ] 측정점을 단절 시작 → OS/SDK 연결 복구 → presence/참가 상태 복구 → 필요한 구독과
  같은 판의 게임 데이터 수신 → 에셋 준비 → 입력 보호 해제/서버 중단 해제로 나눈다.
  [플랫폼 복구 반환](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/room/providers/room_provider.dart#L1003)을
  게임 준비 완료로 간주하지 않는다. 완료 계약은 [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md#session-reconnect-02)에서 합의한다.
- [ ] 새 연결 UI 6종의 안내/재시도/나가기 노출 시간은
  [NEWGUI-RECOVERY-01](NEWGUI-RECOVERY-01.md#newgui-recovery-01)과 함께 기록한다.
  [태블릿 단절 안내의 20초 나가기 노출](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/phone/widgets/controller_reconnect_guard.dart#L16)과
  stale 판정 유예·실제 네트워크 복구 시간을 구분한다. UI 문구나 버튼 표시만으로
  세션 복구 성공을 판정하지 않는다.
- [ ] [에셋 다운로드](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/game_assets/game_asset_prepare.dart#L5)와
  [960ms 퇴장 연출](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_kit/lib/widgets/game_exit_route.dart#L5)의
  대기 시간을 SDK 재연결 지연과 분리한다. 캐시 유무·게임·기기·OS·빌드를 측정에 남긴다.
- [ ] 라이어스포커·Final Call·Mafia·홀덤 4게임의 휴대폰/태블릿 조합에서 상태 보존이
  확인된 성공 복구만 지연 측정 대상으로 삼는다. 반복 단절 뒤 방/손패/턴 유실,
  취소된 구독의 미복원, 다중 단절 누락, pause 중 timeout 진행, 퇴장 응답 유실,
  숨은 오류·AuthGate 실패 잔류와 상세/스토어 복원 경합은 지연 개선으로 축소하지 않고
  [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md#session-reconnect-02) 및 새 UI 작업으로 보낸다.

위 측정 항목은 목표 수치나 재시도 횟수를 새로 확정하지 않는다. 운영 데이터 접근은 기존
Firebase MCP 사전 승인·단일 경로 제한을 유지한다.

## 2026-10-10 — 로비 생성·초기화 시간 측정

사용자가 iOS Simulator에서 방 생성·초기화가 각각 3~4초 걸린다고 보고하고 1초대 응답을
희망했다. 현재값은 체감 보고이며 원인이나 성능 합격선을 확정하지 않는다.
[측정 절차와 기록 의미](../../operations/ROOM_ACTION_LATENCY.md)에 따라 debug 클라이언트의
기존 호출·로컬 저장에 시간을 기록하는 후보를 추가했다. 생성 뒤 resume/presence, 초기화의
onDisconnect 취소/status 조회/close를 구분한다. 화면 프레임·760ms QR 연출은 별도다.
서버·rules·요청 내용·순서·재시도 정책은 변경하지 않았다.

사용자 승인 후 17:07~17:09 KST 실제 요청을 측정했다. 빈 방 초기화 1회는 7,418ms로
성공했고, 그중 status/close callable이 7,304ms였다. 생성은 3,901ms와 761ms로 두 번
실패하여 반복을 중단했다. 성공 생성 시간이나 5회 통계는 확보하지 못했다. 실패 후
빈 로비에 오류 안내가 없는 점도 확인했다. [측정 결과](../../operations/ROOM_ACTION_LATENCY.md)의
환경·한계를 따른다. 운영 서버 로그와 DB 직접 조회는 하지 않았다.

계측 관련 테스트 16개, session(Flutter 156·Functions 94), 분석과 iOS debug 빌드는
PASS/exit 0. 승인된 FULL 1회는 동일 소스 영문 경로 사본에서 FAIL/exit 1이었다.
포맷·전체 분석은 PASS, root 테스트 362 PASS/6 FAIL 후 fail-fast로 종료했다.
실패는 기존 `liars_poker_winner_restart_test.dart`의 Fake가 `watchServerConnection`을
구현하지 않아 발생했다. 후속 package 테스트·Functions lint/test는 FULL에서 미실행이며
검증 전후 mutation은 없었다. 계측 기능·지연 개선 전체 완료로 판정하지 않는다.


## 2026-10-10 — `디벨럽1` 개선 후보

사용자가 별도 브랜치에서 앞선 개선안을 구현하도록 요청했다. 시작 HEAD는 `7bb2b1e`,
이전 미커밋 계측과 디자인 export는 이어받아 보존했다. 최초 생성의 resume과 최초 close의
status 왕복을 생략하고, 미확정/재접속 경로는 유지했다. 서버의 종료 allocation에 일치하는
completed 생성 슬롯만 CAS로 교체해 즉시 재생성할 수 있도록 했다. 빈 로비의 생성 오류
안내와 표준 오류 코드/서버 단계별 계측을 추가했다. 이전 FULL 실패는 LP 테스트 Fake의
연결 스트림 구현 누락을 보완했으며 게임 동작과 기존 assertion은 유지했다.

로컬 재현은 수정 전 create→close→create가 creationPending으로 실패, 수정 후 성공했다.
신규 클라이언트 회귀는 fresh/replay/presence 실패/실제 restore/close 결과 유실을,
서버 회귀는 generation·동시 생성·옛 cleanup과 로그 비식별화를 검증한다.
최종 관련 클라이언트 30개·서버 9개 PASS, session Flutter 156·Functions 96 PASS.
FULL은 새 후보에 대한 사용자 1회 승인 후 PASS/exit 0(105.5초)였다.
포맷·전체 분석·root 378개·패키지 5개·Functions 397개 및 mutation 검사 모두 PASS. [검증 기록](../logs/2026-10.md#room-action-improvement-20261010).
서버 배포와 새 후보 실측은 별도이며 1초대 달성을 주장하지 않는다.

## 2026-10-10 — 앱 전체 동작 지연 정적 조사

사용자 요청으로 [전체 조사](../../operations/APP_LATENCY_AUDIT.md)를 작성했다.
직접 작성 소스 555개와 생성 번역 4개를 검색하고 검색행 1,090개 및 서버 export
79개를 바탕으로 시작·인증·로비·네 게임·리소스·공통 서버 경로를 추적했다.
고정 대기, 직렬 왕복, 연출 규칙, 실측이 필요한 구조상 가설을 구분한 후보 50개다.

우선 후보는 자리 배치의 서버 준비와 연출 병행, 입장/프로필 성공 후 대기, FC 명령 전
460ms 대기, 최초 leave 사전 조회, 카탈로그 독립 조회 병행이다. 서버 room 전체
transaction·ledger 누적·cleanup trigger는 데이터 크기/충돌/부하를 먼저 측정한다.
이번에는 앱 코드 수정이나 운영 요청을 하지 않았다. 제안은 구현 완료·성능 향상 확인을
뜻하지 않으며 기존 로비 후보의 배포·실측과 E14를 대체하지 않는다.

## 2026-10-10 — 앱 응답 개선 후속 후보

사용자가 개선과 개발팀 공유 문서를 요청했다. [개발팀 공유](../../engineering/NETWORK_LATENCY_IMPROVEMENTS.md)에
측정/가설, 이전 로비 후보와 이번 수정, 코드·회귀·배포 후 체크리스트를 구분했다.
이번 범위는 최초 leave status 생략, join의 독립 읽기 병행, 카탈로그/보유 조회 병행과
in-flight 공유, 착석 연출/서버 준비 병행, FC 교체 즉시 전송, 성공 check 뒤 추가 정지 제거,
에셋 파일 최대3개 병행 설치다. 서버/rules/schema/dependency/게임 규칙 변경은 없다.

직접 관련53개 및 추가8개(일부 중복), session Flutter156/Functions97, auth Flutter34/Functions12,
전체 Flutter 분석이 PASS/exit0다. session/auth 검증 전후 mutation 없음. 이번 후보의
FULL은 새 명시 승인 대기이며 앞선 후보의 FULL PASS를 재사용하지 않는다. 실제 지연 절감은
아직 미측정이고 운영 접근·배포·commit/push를 하지 않았다.

후속 승인 결과: 사용자가 FULL 실행을 승인하여 동일 소스 영문 경로 사본에서
Node22 PATH `dart run :mosigame validate --full --json`을 1회 실행했다. PASS/exit0,
99초·12단계, root393·game_kit100·LP12·FC14·Mafia55·Holdem31·Functions397 및
포맷·분석·lint 통과. 사본 mutation 검사와 원본 파일 해시도 변경 없음이다.
이후 결과 문서만 갱신했다. 배포·개선 후 실측 대기는 유지한다.


## 2026-10-10 — createRealtimeRoom 승인 배포

앱만 재실행한 상태에서 재생성 오류가 반복되어 사용자 승인 후 `createRealtimeRoom`만
운영 `project0000-ec01e`의 서울 리전에 배포했다. FULL 통과 소스 일치 확인,
predeploy lint/build와 CLI 업데이트 PASS·exit0. 배포 전후 소스·Git 상태 변경 없음.
다른 함수 timing 배포와 실제 생성→초기화→재생성·개선 속도 확인은 남아 있다.
[개발팀 공유](../../engineering/NETWORK_LATENCY_IMPROVEMENTS.md)의 인계 절차와
[월별 배포 기록](../logs/2026-10.md#2026-10-10--방-재생성-오류-수정-함수-배포)을 따른다.


## 2026-10-10 — 최초 ready 사전 조회 수정 후보

사용자의 해결·공유 문서 갱신 요청에 따라 공용 명령에서 Map 예약 전 미확정 여부를
판정하도록 수정했다. 최초 ready/failed는 status 없이 전송하고 응답 유실 재시도는
동일 ID/domain 조회·재생을 유지한다. 서버 준비 승인 실패 안내를 로컬 화면 준비와
구분하고, debug 단계·허용 코드만 기록한다. 제품/서버 state contract는 유지한다.

관련34개 PASS, 첫 session 제품 테스트는 통과했으나 별도 작업의 Final Call 에셋 변경으로
mutation FAIL/exit1이었다. 사용자 변경을 보존한 사본 session은 Flutter161·Functions97과
mutation 모두 PASS/exit0, analyze도 PASS/exit0다. 새 FULL 1회와 수정 앱 적용/기존 LP 방
기기별1회 재시험 승인을 요청했다. 아직 수정 앱 실행·서버 배포·commit/push 없음.
[개발팀 공유](../../engineering/NETWORK_LATENCY_IMPROVEMENTS.md#2026-10-10-게임-준비-보고-수정-후보)에
원인·구현·회귀·기기 인계를 추가했다.


### 2026-10-10 — 준비 보고 후보 FULL 및 승인된 기기 재시험

사용자 승인으로 동일 소스 영문 경로 사본의 Node22 PATH
`dart run :mosigame validate --full --json`을 1회 실행: PASS/exit0, 118.156초,
12단계·총1006개 테스트. 원본1470개 해시/Git 상태 변경 없음. 이후 결과 문서만 수정했다.
세 시뮬레이터 설치/실행 exit0. 기존 LP 방에서 iPad 자동 복귀와 ready 즉시 전송,
callable568ms/accepted·준비957ms를 확인했다. 두 휴대폰은 ‘게임 다시 참여’를 각1회
실행했으나 안내 화면에 머물렀고 ready 단계에 도달하지 않았다. 카드 분배/첫 턴 미확인.
휴대폰 복귀 오류가 UI/로그에 드러나지 않는 진단 공백을 확인했으며 실제 오류 원인은
미확정이다. 승인된 횟수 이상 재시험·방 초기화·서버 배포·commit/push는 하지 않았다.
후속 복귀 오류 계측/안내와 추가 재시험 필요. 전체 게임 복구 완료로 표시하지 않는다.
상세 시간·증거·한계는 NETWORK_LATENCY_IMPROVEMENTS.md에 추가했다.

## 2026-10-12 — 방 생성·그룹 탈퇴·초기화 지연 재조사와 설계

사용자 요청에 따라 현재 코드·테스트·canonical 문서·배포 기록·기존 정제 기록을 병행 검토하고
[실행 계획](../ROOM_ACTION_LATENCY_PLAN_20261012.md)을 작성했다. 정상 최초 생성의 resume과
탈퇴/초기화의 status 생략은 이미 구현되어 있어 신규 개선으로 중복 계산하지 않는다.

사용자가 2026-10-11 15:00~17:00 KST와 조회 전용 계정의 두 허용 역할 확인·조회 진행을
승인했다. project0000-ec01e의 관련 서울 callable metadata/고정 단계만 probe1+본조회99건
상한으로 읽었다. 반환1/9건, 고유9건이며 두 조회 PASS/exit0다. 원문·개인정보 없이 ignored
`build/device-test/room-action-plan-20261012/`에 정제 저장했다. SDK 최초 sandbox 실행은
접근 거부(exit1), 승인된 escalation 실행은 성공했다. 운영 데이터 쓰기는 하지 않았다.

leaveRealtimeRoom HTTP200 6건은 동일 revision에서 3건170~184ms, 3건2.82~3.27초였다.
resume은 HTTP200 441/3274ms와 HTTP403 149ms. 생성·초기화·단계 timing은 이 범위에서
미발견이다. metadata는 앱 전체 완료·신규/재생·cold start를 확정하지 않는다.

첫 변경은 leave/transaction 계측과 버전 일치 확인이다. 서버 실행 준비가 긴 군을 설명하면
핵심 함수 minInstances/비용 제한 실험을 우선 선택한다. DB 대기가 크면 close 사전 읽기와
priming 통합 및 create 독립 onboarding/mapping 병행, 앱 cancel이 명령을 막으면 durable
저장을 앞세운 접속 예약 coordinator/만료 continuation 차단을 선택한다.
cleanup 경합/이력 크기·지역 배치도 계측 후 별도 판단한다.

제품 구현·테스트/FULL·배포·실기기 재시험은 하지 않았다. 다른 작업의 Functions 정리·계정
삭제·회귀 변경을 보존했으며 해당 변경을 이번 계획의 검증 결과로 취급하지 않는다.
현재 준비/재참여 미해결과 실기기 검증 상태는 유지한다.

## 2026-10-12 — 정리 Functions 안정성 검토에 따른 계획 보완

사용자가 LP 실기기 검증 채팅의 변경을 재검토하도록 요청했다. 현재 정리 후보에서
connection leaf만 정상으로 돌아오고 player 요약 trigger가 지연된 두 경합을 로컬에서
재현했다. 정리가 최신 room snapshot을 읽어도 leaf를 판정에 사용하지 않아 정상 membership을
제거한다. 현재 controller leaf는 최근 heartbeat인데 요약은 3분 초과인 대기 방 전체가
종료되는 기존 경합도 재현했다. 기존 요약 갱신 reconnect 회귀와 다른 구간이며 운영 발생은 미확인이다.

[성능 계획의 후속 검토](../ROOM_ACTION_LATENCY_PLAN_20261012.md#7-2026-10-12-functions-안정성-검토와-계획-수정)에
참가자·controller 현재 connection의 신원/heartbeat 확인과 callback 재실행 회귀를 정리 후보
배포의 선행 조건으로 반영했다. 정상 create의 DB 호출 수는 바뀌지 않고 deleteAccount는
그룹 탈퇴와 다른 작업이다. 정리 실행 구간의 callable 시간·재실행·처리량을 함께 비교한 뒤
기존 실행 준비/읽기 통합/독립 읽기 병행/앱 취소 대기 후보를 선택한다. TTL 보류는 유지한다.

다른 채팅의 FULL은 최종 PASS(exit0, 12단계)이며 결과 파일을 확인했다. 새 leaf-only 경합은
그 테스트에 없다. 이번 probe 3개는 결함 재현 PASS(exit0)이지 수정 성공이 아니다.
제품 수정·새 FULL·운영 접근·배포는 하지 않았다. 상세 실행 근거는 위 계획과
[월별 검토 기록](../logs/2026-10.md#room-action-function-review-20261012)에 남겼다.


<a id="wait-reduction-integration-20261020"></a>
## 2026-10-20 — 대기 단축 두 항목의 최소 통합

최초 자리 배치의 게임 시작 성공 뒤 퇴장 정리 대상 조회를 남은 착석·줌과 병행한다.
조회는 현재 시작 시도·route·계정·방·접속·게임 문맥에 귀속하고, 실패 시 같은 유효
시도에서만 전환 직전 확인으로 돌아간다. 메뉴·결과 재시작·복구 경로 및 의도된 연출은 유지한다.

초기화는 정확한 옛 접속과 종료 의도를 먼저 고정·저장한 뒤 옛 예약 취소와 서버
close/status를 병행한다. 늦은 옛 등록·취소가 새 접속을 건드리지 않으며, 서버 결과가
미확정이면 원 operation ID·복구 신원을 보존한다. 서버 확인 전 성공 표시·신원 삭제는 금지한다.

구현 계약은 [네트워크·세션 계약](../../engineering/NETWORK_SESSION_CONTRACT.md),
측정 해석은 [로비 지연](../../operations/ROOM_ACTION_LATENCY.md)을 따른다.
방·게임의 공개 API·DB/Rules·서버 권위는 변경하지 않는다.

계측 앱의 최초/메뉴/결과/초기화 본 수집은 각5건이다. 원본 판정 19/20건 통과,
결과 재시작 1건은 첫 제출 이후 다음 라운드 기록 때문에 무효이며 첫 시작 구간을
별도 복원했다. 첫 선택·제출 연결은 15/15건, 초기화의 전체 참가 완료 뒤 새 방
최소30초 유지는 5/5건 확인했다. 각 새 방의 후속 게임 시작까지 5건 모두 확인한 것은 아니다.
R2 영상은 새 방 게임 진행·로비 복귀, S4는 오류 안내 후 게임 진행 재개를 보여주지만
정확한 단절 경합·폰 화면·완전한 복구 계약의 실기기 통과를 뜻하지 않는다.

조회 0.158~0.318초가 5건 모두 연출 안에서 끝났고 전환 시 조회 잔여 대기는 없었다.
취소 4.5~21.5ms와 서버 종료 요청의 병행을 확인했다. 이는 대기 의존성 축소 근거이며
전체 체감 절감량은 미확정이다. 과거 시험의 전체 시간 차이를 원인·절감량으로 단정하지 않는다.

사용자 결정으로 계측 없는 최종 앱의 정상 시작·초기화·새 방 간단 실기기 확인은
최초 방 생성·추방 개선 작업을 마친 뒤 함께 수행한다. 이번 병합의 선행 조건으로
두지 않으며 미실행을 통과로 바꾸지 않는다. G1 공용 경로 실기기 생략·V1 이전 버전
혼합 보류는 유지한다. 기존 타 작업의 미완료 항목은 이 변경으로 완료 처리하지 않는다.

기능 원본은 ea08181, 계측 보존은 e52d781, 상세 평가 보존은 기록 브랜치
codex/wait-reduction의 918228f다. APK·로그·영상은 Git 외 별도 로컬 백업으로 보존한다.
인수인계·계측·상세 CSV/JSON과 수집기는 develop에 포함하지 않는다.
기존 후보25d3ea3의 사용자 승인 FULL은 12단계 PASS/exit0이나 최종 최소 후보의
검증을 대신하지 않는다. 최종 후보의 관련 검사·FULL 결과는 후속 실행 기록으로 갱신한다.

향후 방 생성·추방 성능 작업은 기존 기록에서 재사용 가능한 시작·완료 경계를 먼저
확인하고 누락된 지표만 보완한다. 기존 로그를 일괄 폐기하거나 모든 시험을 다시
수집해야 한다고 가정하지 않는다. 추가 계측·운영 조회·실기기 실행은 별도 범위다.


### 10/20 최종 최소 후보 관련 검증

기존 lock 기준 Prepare/doctor READY, 변경 Dart7개 format(수정0)·analyze(문제0),
관련3파일39 tests와 guarded session suite가 모두 PASS/exit0이다. 각 실행 전후
파일 해시와 Git 상태가 같았다. session은 Flutter29/Functions15 파일을 실행했다.
명령은 `tool/setup_mosigame.ps1 -Prepare`, `dart format --output=none --set-exit-if-changed`
및 변경7파일, `flutter analyze --no-pub` 및 변경7파일,
`flutter test --no-pub test/room_action_fast_path_test.dart test/tablet_start_cleanup_test.dart test/tablet_start_launcher_test.dart`,
`tool/invoke_mosigame.ps1 test session --json`이다. Windows CLI는 guarded 경로로 실행했다.

검증 중 제품 코드를 바꾸지 않았고 이후 갱신은 이 결과를 남기는 작업 문서뿐이다.
최종 FULL은 이 후보에 대한 명시적 승인 대기이며 아직 실행하지 않았다. develop 병합·
push·배포는 하지 않았다. 원 수집·기록 브랜치의 미커밋 문서·이전 후보는 보존했다.


### 10/20 최종 FULL 승인·PASS

사용자가 “FULL 검증 후 병합 진행”을 승인했다. 최종 최소 후보6e07361에서
`powershell.exe -NoProfile -NonInteractive -OutputFormat Text -ExecutionPolicy Bypass -File tool/invoke_mosigame.ps1 validate --full --json`을 실행해
FULL12단계 PASS/exit0, 약 360.05초를 확인했다. 실행 전후 HEAD·branch·
staged/unstaged/untracked 상태가 같았다. 포맷·정적 분석·루트 앱·공용과 네 게임 패키지·
Functions lint/test·작업 트리 보존이 모두 통과했다.

검증 뒤 변경은 이 결과를 남기는 작업 문서3개뿐이며 제품·테스트·환경/설정 파일은
검증한 후보와 같다. 원 수집·기록 브랜치의 미커밋 문서·이전 후보도 보존했다.
비계측 앱 실기기 확인은 방 생성·추방 개선 후로 이관하며 G1 생략·V1 보류를 유지한다.
병합은 최신 develop 재확인 후 진행하고, 원격 push·배포는 별도다.


### 10/20 디벨럽1 결합 검토

앞선 최소 후보 FULL과 구분하여 팀원 디벨럽1b87418f를 포함한 새 후보를 검증했다.
양쪽 시작 전환/로컬 Firebase/취소 병행을 보존하고 관련 session/auth 및 직접 회귀가
PASS/exit0이다. 이번 결합의 최종 FULL은 승인 대기다.
[브랜치 기준·수정·검증·유지한 한계](../DEVELOP1_WAIT_REDUCTION_INTEGRATION_20261020.md).
