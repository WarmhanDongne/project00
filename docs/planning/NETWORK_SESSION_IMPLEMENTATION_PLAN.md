# 네트워크·세션 실행 계획안 — R16~R18

[제품 합의](NETWORK_SESSION_DESIGN.md) · [기술 설계안](NETWORK_SESSION_TECHNICAL_DESIGN.md) · [작업 묶음](NETWORK_SESSION_TASKS.md) · [작업 관리](TASK_MANAGEMENT.md)

2026-10-09 사용자 요청으로 작성했다. 합의한 제품 결과와 보충한 기술안을 담당·의존 순서·채팅별 완료 단위·검증에 연결한다.
이 문서는 실행 계획안이다. 사용자는 후속 답변에서 최신 newgui를 코드 기준으로 지정하고 기술안 A~C의 권장 방식을 채택했다.
2026-10-09 후속 요청으로 develop에서 E00을 시작했다. [착수 기준 기록](NETWORK_SESSION_E00_BASELINE.md)에 최신 commit/후속 변경·기존 계약/실제 소비자·검증 공백을 대조했다.
후속 답변으로 전체 작업을 사용자가 수행한다고 확인했다. 사람별 담당 분리는 제거하고 채팅별 범위와 의존 순서를 유지한다.
설계 채택과 문서 merge를 production 접근·배포·migration 승인으로 확대하지 않는다.
E/V 번호는 기존 태스크의 하위 실행/검증 번호이며 새 작업 ID나 출시 차단 항목을 추가하지 않는다.

## 1. R16 — 담당 범위와 인수인계

### 1.1 이번 묶음의 완료 범위

| 기존 작업 | 이번 계획의 결과 | 전체 작업과 구분할 범위 |
| --- | --- | --- |
| [SESSION-RECONNECT-02](tasks/SESSION-RECONNECT-02.md) | 4게임의 자격·구독·준비·다중 중단·시간 보존·요청/퇴장·초기 복구 | 관련 인증은 최초 실행/온보딩/UID 수명에 한정. 계정 기능 전체 재설계는 제외 |
| [NEWGUI-RECOVERY-01](tasks/NEWGUI-RECOVERY-01.md) | 6종 안내의 공용 상태 소비·실제 버튼·복귀 질문·에셋/route 수명 | 일반 로비/게임 디자인 개선은 기존 별도 작업에 유지 |
| [HOLDEM-01](tasks/HOLDEM-01.md) | 현재 후보의 요청·진행·비정상 종료·올인/제외·네트워크 회귀 | 신작 전체 출시 조건과 남은 비네트워크 구현은 해당 상세에서 계속 관리 |
| [ROOM-CREATE-REQUEST-01](tasks/ROOM-CREATE-REQUEST-01.md) | 같은 생성 작업의 부분 복구·중복 방 방지·정리 경합 보호 | 과거 production 고아의 조회/일괄 정리는 별도 구체 계획 필요 |
| [NET-RECOVERY-01](tasks/NET-RECOVERY-01.md) | 상태 보존 성공 복구의 단계별 실측, 측정 후 목표/출시 기준 합의 | 실패·상태 유실을 지연 개선으로 축소하지 않음 |
| [GAME-COMM-DIAGNOSTICS-01](tasks/GAME-COMM-DIAGNOSTICS-01.md) | debug 진단 회귀·복구 구간 집계·휴대폰/태블릿 룰렛 재확인 | release 기록/원격 telemetry 기능 추가 제외 |
| [TEST-REGRESSION-01](tasks/TEST-REGRESSION-01.md) | 이번 회귀 작성·필요한 기존 회귀 복원·targeted/package/FULL/CI 배선 | 나머지 인증 제품 수정은 이 묶음에 자동 편입하지 않음 |
| [CORE-REVIEW-01](tasks/CORE-REVIEW-01.md) | 해당 방 그룹 목록 권한·게임별 인원·방/매핑/예약 정합성 | 전체 핵심 구현 감사·일반 비용/보안 최적화는 별도 범위 |

구버전 앱 호환·shim·버전 제한은 제외한다. 게임 규칙·비공개 경계·기존 방 보존 기준은 유지한다.
실제 파일이 없는 Holdem/newgui 코드를 존재한다고 가정하지 않으며 E00에서 실행 후보에 포함시킨다.

### 1.2 단일 담당과 작업 영역

사용자가 패키지·플랫폼·서버·검증 전체를 수행한다. 기존 2인 협업을 전제한 사람별 분담안은 적용하지 않는다.
아래 P/T는 후속 표를 읽기 위한 **작업 영역**이며 별도 담당자가 아니다. AI는 각 구현 채팅에서 사용자의 작업을 돕는다.
한 담당이 진행해도 각 채팅의 결과·완료 조건·검증을 정하고 다음 단위에 기록을 전달한다.
새 채팅 생성이나 다른 채팅으로 메시지 전송은 별도 사용자 요청이 있을 때 수행한다.

| 기호 | 작업 영역 | 허용 구현·테스트 범위 | 다음 단위에 남길 결과 |
| --- | --- | --- | --- |
| P | 패키지 | `packages/game_kit/`, `packages/game_liars_poker/`, `packages/game_final_call/`, `packages/game_mafia/`, `packages/game_holdem/`와 각 package test | 공용 Flutter 계약·게임 adapter·안내/입력 보호·debug 기록. 플랫폼/서버 import 금지 |
| T | 플랫폼/서버 | 합의한 `lib/platform/`, `lib/game_assets/`, 필요한 앱 조립; `functions/src/room/`, `functions/src/game-interruption/`, 4게임 서버·`functions/src/index.ts`·관련 `functions/test/`·`database.rules.json` | 방/게임 권위·자격·persistent intent·초기 복원·route·callable/rules/trigger와 패키지 소비 계약 |
| T | 검증 배선 | `test/`, `test/mosigame_cli/`, `tool/mosigame_cli/`, 관련 경계 검사·`.github/workflows/validate.yml` | 실제 테스트 목록·package working directory·FULL/CI 실행 증거와 package 테스트 연결 |
| 공통 | 기준/통합/기기 | 설계/계획/작업 기록, 통합 판정, 실제 기기 확인 | 계약·후보 확인, 측정 후 성능 목표, 별도 반영 계획 검토 |

이 표는 폴더 전체를 자유롭게 수정하는 승인안이 아니다. 각 채팅은 아래 단위의 관련 파일만 바꾼다.
새 dependency·새 저장/API 방식·범위 밖 수정은 [Engineering Contract](../engineering/ENGINEERING_CONTRACT.md)의 경계를 따른다.
기능 구현/버그 수정 채팅에는 [Mosigame Implement and Validate](../../.agents/skills/mosigame-implement-and-validate/SKILL.md)를 적용한다.
문서·기준 확정·읽기 전용 리뷰 채팅에는 적용하지 않는다.

### 1.3 계약을 전달하는 기준

2026-10-09 사용자 합의 결과는 아래와 같다. 기존 대안은 비교 근거로 보존하며 다시 선택을 요청하지 않는다.

| 항목 | 채택한 기준 |
| --- | --- |
| 코드 기준 | 최신 newgui `fcee643d2dad6337e7ae40504cd8804c77ce2215`를 포함한 develop `58634d1aee294a6ab4295bb814ae6c168539a7f5`. E00에서 fetch·포함 관계·내용 일치를 확인 |
| A | room/game/member/connection 식별·public/본인 private 대응·현재 접속의 준비 보고와 barrier 재개 |
| B | 서버 전송 전 durable 퇴장 intent 저장·재실행 보존·결과 확인 우선·단일 8초/30초 복구 예산 |
| C | terminal 최소 방 기록·allocationGeneration·due 정리 index/부분 실패 marker로 지연 writer와 정리 누락 보호 |

과거 정적 분석의 `999c3e9`를 최신 후보로 오인하지 않는다. 착수 때 최신 remote commit을 다시 확인해
실제 실행 SHA로 고정하고, 그 사이 계약/파일/소비자 변경을 대조한다. 계획 문서 머지 뒤 별도 PR #140으로 newgui 제품 코드가 반영됐으며 E00 기록을 현재 기준으로 사용한다.
E00에서 확정한 계약·담당 범위는 후속 채팅에 그대로 전달하며 변경이 없으면 다시 승인을 요구하지 않는다.
새 충돌/결정이 생긴 경우에만 근거와 영향 범위를 제시한다.

계약 기록은 다음 내용을 갖춘다. 새로운 관리 시스템이나 별도 schema 저장소를 만들 필요는 없다.

- callable 이름·리전·요청/응답·거절 코드·멱등 결과와 모든 소비자.
- room/game/member/connection/phase/data/barrier/report/command 식별자의 생성·검증·수명.
- public/본인 private/server 경계, 모든 필수 private 메타데이터 갱신 불변식.
- 플랫폼↔game_kit callback/DTO, 준비 성공/실패·퇴장·종료·route 결과의 소유자.
- 재시도 소유자와 예산, 서버 시간 보관/참가자 마감, terminal/부분 실패 정리 규칙.
- 검증 fixture와 예상 결과. 예제는 합성 식별자/데이터를 사용하며 실제 credential/사용자 정보는 기록하지 않음.

제공자는 계약·관련 테스트·변경 파일을 전달하고 소비자는 이를 사용하는 테스트를 남긴다.
계약 변경은 같은 기록을 갱신하고 영향받는 E/V 단위를 표시한다. 양쪽 DTO가 다르면 중간 shim으로 숨기지 않는다.

## 2. R17 — 의존 순서와 채팅별 완료 단위

### 2.1 실행 순서

1. **기준 확정:** E00 → E01. 실제 후보·계약·담당과 테스트 실행 배선을 먼저 확인한다.
2. **공용 기반:** E02 → E03 → E04의 게임별 서버 작업. P는 확정된 E03 계약으로 E05를 진행한다.
3. **앱/게임 연결:** E05 → E12 계측 기반 → E06 플랫폼. 각 게임은 해당 E04와 E06을 받아 E07을 진행한다.
4. **안내/방 흐름:** E08 → E09. E10-S/E11-S의 서버 결과를 받아 E10-P에서 그룹/생성 앱 소비자를 맞춘다.
5. **전체 검증:** 필요한 구현 단위 전부 → E13 → E14 → E15 반영 계획 검토.

단일 담당이 선행 결과를 받아 순서대로 진행한다. 같은 파일/DTO를 동시에 수정하는 채팅은 두지 않는다.
T의 RoomProvider 변경은 E06 → E09 → E10-P 순으로, room lifecycle 변경은 E02 → E10-S → E11-S 순으로 합친다.
이는 한 담당의 작업 순서이며 AI 하위 에이전트 실행을 요청하거나 새 채팅을 생성한 것은 아니다.

### 2.2 채팅별 범위·결과·완료 조건

아래 E04/E07의 네 게임은 각각 범위·완료 조건을 가진 단위다. 서버와 패키지를 구분한 이유는 제공 계약과 소비 결과의 선후 관계이며 담당자 차이가 아니다.
표의 기능 결과와 V 검증을 모두 만족하고 2.3의 공통 종료 조건을 충족해야 단위 완료로 표시한다.
게임 이름은 LP=라이어스포커, FC=Final Call, MA=Mafia, HE=Holdem이다.

| 단위·영역·관련 작업 | 선행 입력 | 해당 채팅의 구현/작성 범위 | 기능 결과·필수 검증 |
| --- | --- | --- | --- |
| E00 공통 — 기준/범위 확인, SESSION·NEWGUI | 최신 newgui·A~C 채택 결과 | 착수 최신 SHA/후속 변경·사용자 working tree 대조, 단일 담당/허용 파일, 채택 계약의 DTO/리전·실제 소비자 목록 확인 | 진행 후보에 4게임/newgui 있음. 사용자 전체 담당 확인. 채택한 A~C를 다시 묻지 않음. 기준 리뷰만 수행하며 구현 완료/FULL PASS로 표현하지 않음 |
| E01 T — 검증 배선, TEST | E00의 후보/담당 | session/auth 경로 20개를 실제 파일/시나리오에 대응, 기존 핵심 회귀 복원 계획과 루트 테스트, package 실행 manifest/working directory, FULL/CI·실행기 회귀 | 누락 파일 제거로 통과시키지 않음. 각 package가 실제 실행되고 실패가 전체 결과에 반영됨. V00 |
| E02 T — 방/세션 서버, SESSION·ROOM·CORE | E00, E01의 테스트 경로 | room/member/connection identity, join/resume 동일 operation·CAS, 접속별 presence/rules, self leave/close의 room 결과와 자격 검증, 생성 identity 기반 | 옛 onDisconnect/퇴장이 새 접속/재가입을 건드리지 않음. 미확정 결과 조회 가능. V01·V02·V10·V11·V21 |
| E03 T — 공용 게임 중단, SESSION·CORE | E02 | 공용 reducer·ready/failed/reportSeq·단일 타이머·원인 집합·60초/연장·선택 권한·operation status/ledger 기반·게임 adapter 계약 | 연결 true만으로 재개 금지. 실패 보고에 최신 데이터 확보 강제 금지. 만료 자동 제외/휴대폰 전체 종료 제거. V03~V08·V09·V11·V21 |
| E04-LP T — LP 서버, SESSION | E03 | LP의 의미 mutation/메타데이터, 시작·행동·분배·벌칙·timeout·퇴장/제외를 공용 계약에 연결 | dealing private 없음/빈 hand 정상, 옛 진행 요청·paused 진행 차단, 제외 후 시간·승부 유지. V04·V08·V09·V17·V18 |
| E04-FC T — FC 서버, SESSION·CORE | E03 | FC의 mutation/메타데이터, 분배·제출·라운드 결과·timeout·퇴장/제외 | 정상 pendingDraw 없음/제출 잠금 허용, 팀 구성 파괴의 기존 종료와 preview 일치. V04·V08·V09·V17·V18 |
| E04-MA T — Mafia 서버, SESSION | E03 | 역할/밤 세부 단계·trial/투표의 식별, private 대응, timeout·자체 퇴장·진행자 제외 | 정상 미선택/능력 없음 허용, 고유 투표 유지·네트워크 제외 투표 제거, 최소 인원/승부 유지. V04·V08·V09·V17·V18 |
| E04-HE T — Holdem 서버, HOLDEM·CORE | E03와 후보 Holdem | hand/turn/phase 식별·모든 진행 요청·pause/누락 deadline·private 대응·현재 핸드 정산/제외 | allIn stack=0 생존, 정산 후 다음 핸드 인원 판단. 같은 핸드 중복/옛 핸드 요청 보호. V04·V08·V09·V17·V18 |
| E05 P — game_kit 복구 기반, SESSION | E03의 확정 DTO, E01 | 세션/구독 세대·public/private 조합·localUsable/barrierReady·실패/준비 보고·단일 retry owner·진행 명령·주입 callback·측정 hook | 준비 전 입력/자동 진행 보호. 정상 변경마다 전체 ready 요구 금지. 8/30초·4회/12초·배경/복귀·옛 Future 폐기. V04·V05·V09·V12·V13 |
| E12 P — debug 계측 기반, DIAGNOSTICS·NET | E05의 hook | 단조 시계·episode/batch·단계 이벤트·제한 요약·기존 debug 타임라인에 연결 | 민감값 미기록·release 비활성, 버퍼 잘림/미측정 구분. 후속 E06/E07/E09가 같은 hook에 실제 완료를 보고. V22 |
| E06 T — 플랫폼 세션/초기화, SESSION | E02·E03·E05·E12 | RoomProvider/저장 세션/leave intent·단일 복구 조율자, pending restore, phone 복귀 동의·tablet 복원, AuthGate/OnboardingService 수명, stale 신고 재시도 | durable intent 선저장·퇴장 우선, 첫 오프라인 뒤 roomCode 없이 복원, 정상 온보딩의 failed 해제, 서버 확인과 unknown 구분. V01·V02·V05·V10~V14 |
| E07-LP P — LP phone/tablet, SESSION·NEWGUI | E04-LP·E05·E06·E12 | 준비 adapter·현재 화면 복원·명령/진행 재시도·공용 안내/종료 callback·측정 hook | 신규 분배/복귀 구분, 완료 연출 재실행 금지, 실제 상태 준비/필요 에셋 후 입력. V04·V09·V15·V17·V18 |
| E07-FC P — FC phone/tablet, SESSION·NEWGUI | E04-FC·E05·E06·E12 | 같은 공용 연결과 FC 단계별 필수 데이터/화면·제출 상태 복원 | 제출 완료/잠금은 실패 아님. 진행 실패는 태블릿 수동 재시도, 팀 종료 경로 일치. V04·V09·V15·V17·V18 |
| E07-MA P — Mafia phone/tablet, SESSION·NEWGUI | E04-MA·E05·E06·E12 | 역할별 준비·밤/재판/투표/관전 화면 복원·고유 입력과 공용 중단 분리 | 비공개 경계·사망자 로컬 보호, 옛 callback으로 단계 되돌림 금지. V04·V09·V15·V17·V18 |
| E07-HE P — Holdem phone/tablet, HOLDEM·NEWGUI | E04-HE·E05·E06·E12 | 실패 행동 실제 재시도·분배/결과/턴 진행·비정상 finished 전달·필수 에셋/화면 준비 | clearError만으로 재시도 처리 금지, 무제한 진행 재예약 금지, 정상 결과/비정상 종료 구분. V04·V09·V15·V17·V18 |
| E08 P — 공용 안내 UI, NEWGUI | E05·E12 | 6종 연결 화면의 주 안내/요약 reducer·역할별 버튼·입력 차단·즉시/10초 표시, 공용 game route exit 결과 | 휴대폰 타인 제외/전체 종료 없음, 내 나가기 처음부터, 서버 pause 즉시, retry로 안내 시각 초기화 금지. V06·V07·V16 |
| E09 T — 플랫폼 화면 연결, NEWGUI·SESSION | E06·E08·E07 네 게임 | 홈/대기실·상세/스토어 복귀 질문·에셋 진입·종료 route 단일 소유자·결과 후 정리·목적지 사유, 실제 측정 hook | 정상 결과 유지, 비정상 valid room→대기실/closed·kick→홈, unknown은 보호 유지. 예외 에셋만 동의 복구. V10·V15·V16·V18 |
| E10-S T — 그룹 권한 서버, CORE | E02 | 요청 방의 멤버십 기반 그룹 게임 조회·membershipRevision·외부 구매 조회 전후 검증 | 일반 참가자/다른 controller 방 보유 계정도 해당 그룹 목록, 외부 계정 거절·최소 응답. V19·V21 |
| E11-S T — 생성/정리 서버, ROOM·CORE | E02·E03·E10-S·E04 네 게임 | 예약/생성 operation·조건부 매핑 복구·선택 C의 지연 writer 보호, terminal 전환/정리 due index·부분 실패 보정·scheduler/trigger/rules | 중복/부활/유효 예약 오삭제 금지. terminal 500개 이후 대상도 정리. 기존 보존 기준 유지. V20·V21 |
| E10-P T — R14 앱 소비자, CORE·ROOM | E09·E10-S·E11-S | 요청 방 identity 전달·목록 cache/갱신, 생성 operation 전송 전 저장·중복 클릭/재실행/응답 유실 확인 | heartbeat마다 구매 조회 금지, unknown 때 새 방 병행 생성 금지, 옛 목록/생성 결과 폐기. V19·V20 |
| E13 공동/T 배선 — 전체 통합, TEST·SESSION | 위 필요한 구현 전부 | 공식 suite/package/FULL/CI, local emulator의 실제 callable·구독·rules·scheduler 경합, 소비자/함수 export 검사 | 전체 후보 V00~V22 결과와 미실행 범위 기록. 모든 게임·역할의 계약 일치. 다른 담당 파일 결함은 해당 단위로 돌려 수정 |
| E14 공동 — 실제 기기/성능, SESSION·NEWGUI·HOLDEM·NET·DIAGNOSTICS | E13의 같은 후보, debug 계측 빌드 | 4게임·역할·OS·물리 네트워크/lifecycle·룰렛 회귀, 성공 복구 실측과 목표 제안 | V23의 기기/빌드별 결과, 중앙값/p95/최대/성공률·정합성. 측정 뒤 사용자 목표/출시 기준 합의까지 NET 판정 유지 |
| E15 공동 — 반영 계획 검토, R15 | E13/E14 evidence·목표 합의 | 실제 앱/함수/rules 목록·현재 데이터 전환 조건·혼합 상태/rollback·사후 확인 계획 | 구현 검증과 출시/운영 완료 구분. 승인받은 구체 반영 전 production 작업 없음 |

E02/E03/E11-S에서 새 모듈을 작성해도 중간 상태를 배포하지 않는다. 현재 앱의 모든 소비자를 E13에서 맞춘다.
E04/E07은 게임별 순서를 LP→FC→MA→HE로 권장한다. 다음 게임은 공용 계약 변경 없이 적용 가능한지 확인한다.
공용 결함이 드러나면 E03/E05를 고치고 이미 연결한 게임을 회귀 검증하며, 게임마다 별도 복구 정책을 복제하지 않는다.

각 단위의 허용 경로는 아래와 같다. 공통으로 해당 작업 문서/기술 문서/월별 기록을 갱신할 수 있다.
새 파일도 해당 경로 안에서 역할을 따르며, 구현 시작 때 실제 변경 파일 목록을 인수인계 기록에 적는다.
후보에서 이동/삭제된 파일은 E00에서 대조한다. 관련성이 있다는 이유만으로 다른 단위의 경로까지 함께 수정하지 않는다.

| 단위 | 허용 변경 경로 |
| --- | --- |
| E01 | 루트 `test/`, `tool/mosigame_cli/`, `.github/workflows/validate.yml`. package 테스트 내용은 P 전달. 기존 경계 검사 기준을 낮추지 않음 |
| E02 | `functions/src/room/`, `functions/test/room-*.test.mjs`, 관련 presence/lifecycle 테스트, `database.rules.json`, 필요한 `functions/src/index.ts` |
| E03 | `functions/src/game-interruption/`, 그 공용 계약/결과 모듈, 관련 `functions/test/game-interruption*.test.mjs`/controller timer 테스트, 필요한 export/rules |
| E04-[게임] | 해당 `functions/src/liars-poker/`, `final-call/`, `mafia/`, 후보 `holdem/` 중 하나와 해당 서버 테스트. 공용 reducer 변경은 E03으로 전달 |
| E05 | `packages/game_kit/lib/recovery/`, 관련 공용 session/context 계약과 export, `packages/game_kit/test/recovery/` 및 해당 계약 테스트 |
| E12 | `packages/game_kit/lib/core/diagnostics/`와 공용 hook/진단 UI·그 테스트. 게임/플랫폼 hook 호출은 E07/E06/E09 담당 |
| E06 | `lib/platform/home/room/`, phone/tablet 홈의 복원 배선, `lib/platform/auth/widgets/auth_gate.dart`/관련 onboarding service·루트 관련 테스트. 패키지 저장 helper 변경은 P 전달 |
| E07-[게임] | 해당 `packages/game_liars_poker/`, `game_final_call/`, `game_mafia/`, 후보 `game_holdem/` 중 하나. 공용 kit 변경은 E05/E08 결과에 반영하고 연결된 게임 회귀를 확인 |
| E08 | 후보의 `packages/game_kit/lib/mosi_ui/`, `lib/recovery/widgets/`, 공용 game route exit helper와 해당 package test |
| E09 | `lib/platform/home/phone/`, `tablet/`, room의 화면 결과 배선, 후보 `lib/game_assets/`의 진입/복구 연결·관련 루트 테스트 |
| E10-S | `functions/src/room/realtime-room-lifecycle.ts`의 그룹 조회와 관련 room 계약/테스트/export |
| E11-S | `functions/src/room/`의 생성/예약/정리, 필요한 game cleanup 연결, 관련 Functions 테스트/export/rules. 게임 규칙 변경은 E04 담당으로 전달 |
| E10-P | `lib/platform/home/gamelist/service/`, room 생성/그룹 목록 provider/service·저장소·관련 루트 테스트 |
| E13 | 기존 통합/루트 테스트·local 재현 도구·검증 배선. 제품/패키지 결함은 해당 E 단위의 범위로 수정하고 후보 재검증 |
| E00/E14/E15 | 기준/체크리스트/측정/반영 계획/evidence 문서. E14는 승인된 테스트 환경·기기에서 수행. production 접근 범위 자동 부여 없음 |

### 2.3 각 채팅의 종료·인수인계

구현 채팅은 해당 단위의 관련 테스트를 함께 작성/수정한다. 테스트를 E13까지 미루지 않는다.
회귀는 가능한 경우 변경 전 실패를 재현하고 변경 후 통과를 기록한다. 입력 순서/시간은 가짜 시계·장애 주입으로 검증한다.

단위 완료는 범위 구현 + 관련 테스트 PASS + 현재 후보 FULL PASS + working tree 보존/예상 밖 변경 없음이다.
제품 동작에 실제 기기 확인이 필요한 단위는 자동 구현 검증과 E14의 남은 확인을 명시적으로 구분한다.
필수 실기기 확인까지 끝나기 전 태스크 전체나 출시 검증 완료로 표시하지 않는다.
FULL의 관련 없는 기존 실패도 숨기지 않는다. 원인·담당·실행 결과를 기록하고 완료 대신 미완료 인수인계로 표시한다.
독립 작업의 선행 인터페이스 전달과 해당 단위 완료는 다르다. 환경 차단/미실행을 PASS로 넘기지 않는다.

채팅 끝에는 다음 기록을 남긴다. 각 상세/월별 기록은 동일 evidence로 연결하고 내용을 중복 관리하지 않는다.

| 전달 항목 | 내용 |
| --- | --- |
| 후보와 변경 | branch·HEAD/작업 diff·기존 수정 보존, 변경 파일·담당 경계 |
| 최종 계약 | 결정한 DTO/API/저장/상태 변경·소비자·후속 단위 영향 |
| 구현 결과 | 해당 기능 결과·직접 재현한 결함·남은 가설/미완료 구분 |
| 검증 | 실제 command·working directory·status·exit code·실행 테스트/게임/기기·전후 tree |
| 다음 전달 | 다음 E 단위가 받을 결과, 남은 확인/담당. 범위를 넓혀 같이 수정하지 않음 |

새 구현 채팅에 전달할 요청 형식은 아래와 같다. 실제 실행 때 해당 E/V와 확정 후보를 넣는다.

```text
네트워크·세션 실행 계획의 E[단위]만 수행해.
확정한 후보·담당·계약과 선행 단위 결과를 먼저 확인하고 허용 파일 범위에서 구현해.
연결된 V[검증]와 관련 회귀를 같은 채팅에서 끝내고 플랫폼에 맞는 FULL을 실행해.
계약·변경 파일·command/status/exit code·전후 working tree·남은 확인을 기록해.
범위 밖 결정/수정이나 미통과 검증이 있으면 완료로 표시하지 말고 근거를 남겨.
```

## 3. R18 — 테스트 계획과 완료 판정

### 3.1 현재 검증 배선의 확인 근거

기준 checkout `review/#136-wirte-task-list`, HEAD `172b26205eb1e7c2b1eb480c71597cfebcc4c930`를 정적으로 확인했다.
로컬 newgui 비교 후보는 `999c3e99086b9f917ea941cd8f283b8ac40f3f85`이며 착수 후보는 E00에서 재확인한다.

- [test_suites.dart](../../tool/mosigame_cli/test_suites.dart)의 session 10개/auth 10개 Flutter 경로는 현재도 20개 모두 누락이다.
  이 문서 작성 중의 파일 존재 확인이며 실제 CLI의 FAIL/INVALID 실행 결과는 아니다.
- [validate.dart](../../tool/mosigame_cli/validate.dart)의 FULL은 루트 Flutter test를 실행하고 package test를 명시적으로 실행하지 않는다.
  [CI](../../.github/workflows/validate.yml)는 이 FULL을 사용하므로 package 테스트 존재만으로 실행을 보장할 수 없다.
- [Functions 설정](../../functions/package.json)의 npm test는 build 후 `test/*.test.mjs`를 실행한다.
  새 서버 테스트의 파일/실행 경로와 targeted suite 편입도 확인해야 한다.

E01에서 기존 20경로를 시나리오별로 대조해 복원/이동/재작성을 정한다. 파일명을 유지하려고 빈 테스트를 만들지 않는다.
경로 이동 시 원 시나리오의 실행 보존을 확인하며, 누락 항목 삭제로 manifest 검사만 통과시키지 않는다.
범위 밖 인증 제품 결함이 나오면 별도 담당/작업으로 연결하되 공식 auth 실행 누락을 이번 후보의 PASS로 표현하지 않는다.
package 실행에는 game_kit과 4게임의 관련 실제 테스트를 포함한다. 템플릿과 무관 패키지까지 일괄 확대하지 않는다.

### 3.2 검증 층과 테스트 소유권

| 층 | 검증할 경계 | 담당·실행 위치 |
| --- | --- | --- |
| 서버 단위/transaction | 원인 집합·타이머·마감·보고/명령 순서·식별·게임 규칙·정리의 원자성 | T, `functions/test/`. 재실행 callback·가짜 serverNow·정리 실패 주입 포함 |
| 공용 패키지 단위/widget | 구독 generation·데이터 조합·단일 retry/예산·입력/안내·route exit·계측 | P, `packages/game_kit/test/`. 가짜 시계·지연/역순 stream·Future 결과 |
| 게임 package/widget | 단계/역할별 준비·현재 화면·명령/자동 진행·연출·결과/종료 | P, 각 게임의 `test/`. phone/tablet 둘 다 |
| 플랫폼/앱 widget·service | durable 저장·자격 복원·온보딩·UID·홈/대기실/상세·실제 callback 배선 | T, 루트 `test/`. 저장 실패·route/lifecycle·계정 변경 |
| local emulator 통합 | 실제 callable/rules·SDK 구독·presence/onDisconnect·여러 소비자·부분 쓰기/trigger | 공동, E13. 합성 계정/방. test harness·필요 환경을 먼저 확인하고 production 설정과 분리 |
| 실제 기기 | OS/SDK 전환·백그라운드/프로세스 재실행·물리 입력·화면/에셋·성능 | 공동, E14. 자동 테스트 PASS로 대체하지 않음 |

기존 mock 단위 테스트만으로 rules 허용/거절과 실제 SDK 복구를 증명하지 않는다.
기존 local harness가 부족하면 필요한 합성 재현 도구/실행 절차를 E13에서 구체화한다. 새 dependency 필요 시 구현 전 검토한다.
새 함수 이름·rules·queue index/export 누락은 E13의 배선 검사에 포함한다. snapshot/rules 문자열 일치만으로 동작을 검증하지 않는다.

### 3.3 자동·통합 검증 목록

공통 기준은 제품 S01~S18과 기술 R11~R15다. 아래는 작성/실행할 목록이며 현재 PASS 결과가 아니다.
휴대폰과 태블릿 기기 표기는 역할이며 OS는 3.5에서 따로 교차 확인한다.

| ID·연결 시나리오 | 장애/입력 순서 | 반드시 확인할 결과 | 핵심 층·연결 E |
| --- | --- | --- | --- |
| V00 배선 | 20경로 누락/이동·package 실패·새 게임 편입 | 실제 파일/시나리오 실행, package WD와 실패 집계·FULL/CI 포함. 빈 테스트/목록 축소 금지 | CLI/FULL, E01·E13 |
| V01 S05 | 오프라인 앱 시작; 연결/저장 읽기/인증 준비의 순서를 모두 바꿈 | roomCode 없이 저장 대상 복원, 이미 true도 재평가, 세션 보존·중복 join 없음 | 플랫폼/emulator, E02·E06 |
| V02 S04·S06 | dealing/빈 hand/관전 재실행; 새 UID/방/게임/connection 후 옛 응답 | phone 동의 후 join/tablet 자동, 정상 private 부재 허용, 옛 작업 폐기·현재 세대만 presence | 서버/앱/package, E02·E06·E07 |
| V03 S02·S03 | A→B→controller 단절, 각 복귀/제외 순열·동시 사건 | 마지막 필수 원인/준비 전 재개 금지, 다른 원인/마감 보존, 사망/관전은 전체 중단 제외 | reducer/emulator, E03·E13 |
| V04 S07 | 타인 행동·본인 private 내용 불변; public/private 역순·늦은 옛 값·연속 dataSeq | 모든 필요한 private 메타데이터 갱신, 최신 조합만 입력, 정상 갱신마다 전 기기 ready 없음·무한 준비 없음 | 서버/package, E04·E05·E07 |
| V05 S07 | 연결 true인데 구독 종료/권한/파싱/화면 실패; failed/ready 역순·응답 유실 | 최신 데이터 없이 자격 있는 failed 가능, reportSeq 보호, 서버 수락 때만 중단/시간 확정. UI 중단 미확정 구분 | 서버/앱/package, E03·E05·E06 |
| V06 P5·R07 | incident 기본 60초 만료·늦은 더 기다리기·수락 후30초·반복 클릭·재만료 | 서버 확정 시작/연장, 한 번만 연장, 자동 제외/종료 없음. 재시도/재연결로 마감 초기화 없음 | reducer/UI, E03·E08 |
| V07 P5 | 만료 뒤 host 선택 전에 ready; ready/연장/제외 경합·조기 제외 | 해당 선택 닫힘·전체 준비면 재개, 태블릿만 타인 제외/종료, 불가 제외의 이유/UI/server 일치 | 서버/UI, E03·E08·E09 |
| V08 P3·S03 | 최초 pause→추가 pause→해소; remaining=0/none; 제외로 턴 전이; 옛 timeout | server pause 순간 시간 한 번 보존, 같은 턴 복원/새 턴 기본 시간, 모든 paused 진행 차단, finished 부활 없음 | reducer/4게임, E03·E04 |
| V09 S08·S09 | 처리 전 실패/처리 후 응답 유실/중복·같은 ID 다른 내용·옛 판/단계/턴·busy | 효과 한 번, payload/UID 일치, notApplied는 미래 미처리 보증 아님, 진행 한도 후 실제 태블릿 재시도 | 서버/package, E03~E07 |
| V10 S10 | 나가기 선저장 실패·미전송·처리 응답 유실·결과 query 실패·다음 실행/계정 전환 | 의도 유지/취소 없음·복구보다 우선, unknown 유지, 현재 대상만 leave, confirmed 정리 실패는 정리만 반복 | 플랫폼/emulator, E02·E06·E09 |
| V11 S06 | 옛 onDisconnect/heartbeat/failed/leave가 새 connection/재가입/코드 재사용 뒤 도착; stale 신고 실패 뒤 동일 heartbeat 재시도 | 새 대상 보호, 신고 제한 재시도와 서버 최신 presence 재검사, 권한/자격 오류 구분·error만으로 kick 없음 | 서버/앱, E02·E03·E06 |
| V12 P6 | 즉시·1/2/4/8/8초 복구, 요청8초/전체30초; 게임0.25/0.5/1초·4회·전체12초 | 응답/지연 포함 상한, 잔여 예산 전파, 중복 소유자/무제한 재예약 없음. failed 보고도 기존 잔여 예산 공유 | 가짜 시계, E05·E06 |
| V13 S01·R04 | 순간 단절/백그라운드→foreground/실제 연결; manual 연타; 옛 완료 | 같은 자격/게임 상태 복구, 유효 대상에 새30초, 전송 명령 취소로 오인 없음·operation/참가자 마감 유지 | package/플랫폼, E05·E06 |
| V14 S17 | 온보딩 error/timeout→유효 데이터; old UID/watcher/timeout; 캐시 null/서버 부재 | failed 해제·기존 단계로 전환, 구독 한 벌, 미확정 null로 신규 등록/삭제 없음 | 플랫폼, E06 |
| V15 S12·S13 | 정상 cached assets; 실제 필수 파일 예외; 상세/스토어 질문 중 종료·dispose·거절 | 일반 복구 재다운로드 없음, 확인 예외만 이유/동의, 준비 후 ready. 거절은 현재 게임/방 leave | 앱/게임/widget, E07·E09 |
| V16 S18 | own error+controller+others+command; sustained10초·retry·종료/leave 중복 | 주 안내 하나·요약, 입력 즉시 보호/본인 leave, server pause 즉시, 시각 보존·역할별 버튼 실제 동작 | widget/앱, E08·E09 |
| V17 R05 | LP 빈 hand/FC 팀 퇴장/Mafia 능력 없음·사망/Holdem allIn·fold·탈락 | 단계/역할 준비 정상성, 계속 가능 preview/실처리 일치, Holdem 정산 전0 stack 생존·정산 후 다음 핸드 판단 | 4게임 서버/package, E04·E07 |
| V18 S11 | 정상 결과/비정상 finished/room close·kick; dialog/뒤로가기/전환 중 종료·새 판 | 정상 결과 보존, 목적지 한 번·사유 도착, 부모 pop 금지·old cleanup이 새 game 지우지 않음 | route/서버/emulator, E04·E07·E09 |
| V19 S15 | T/A/B 서로 다른 계정·각자 소유 게임·외부 계정·A는 다른 방 controller; 멤버십 변경 | 같은 그룹 목록/최소 응답, 외부 접근 거절·옛 조회 폐기, heartbeat 반복 구매 조회 없음 | callable/rules/앱, E10-S·E10-P |
| V20 S14 | 예약만 성공/방 성공 매핑 실패/응답 유실/삭제 직전 writer·코드 재사용; terminal500개 이상·due 실패/누락 | 중복/부활/오삭제 없음, 동일 작업 복구, live 정리 진행·보정 cursor/부분 실패·새 generation 보호 | transaction/emulator/앱, E11-S·E10-P |
| V21 R15 | 각 callable/trigger/export·rules 경로/queue index·중복 callback·종료 데이터 정리 | 모든 소비자가 같은 계약, 본인 private만 접근/server 쓰기 금지, stale 정리 차단, 기존 데이터 전환 조건 구분 | rules/통합, E02·E03·E10-S·E11-S·E13 |
| V22 S16 | 버퍼200건 초과·미측정·manual 새 batch·다른 기기/질문/배경 대기·release 빌드 | 단조 시간/서버 시각 분리, 요약 보존·N/A 구분, 성공/실패 집계 분리·민감값 없음·release 비활성 | 진단/package/앱, E12·E06·E07·E09 |

모든 사건 순열을 실제 기기에 무작정 반복하지 않는다. 결정적인 상태/시간/역순 조합은 자동화하고
SDK/OS/물리 입력 차이는 실기기로 확인한다. 실제 기기에서 새 결함이 나오면 담당 E와 V 회귀를 추가한다.

### 3.4 실제 실행 경로와 증거

Windows의 공식 검증 경로는 [Project CLI](../engineering/PROJECT_CLI.md)를 따른다.

```powershell
.\tool\invoke_mosigame.ps1 test session
.\tool\invoke_mosigame.ps1 test auth
.\tool\invoke_mosigame.ps1 validate --full
```

macOS/Linux와 현재 Linux CI는 아래 raw CLI를 사용한다.

```text
dart run :mosigame test session
dart run :mosigame test auth
dart run :mosigame validate --full
```

빠른 피드백은 해당 변경의 테스트만 실행한다. Functions는 build 뒤 관련 `node --test` 경로,
패키지는 해당 working directory의 `flutter test --no-pub test` 또는 관련 파일 선택을 사용한다.
실제 파일/의존 설치/외부 deadline은 실행 후보에서 확인한다. 새 테스트는 E01의 공식 manifest에도 연결한다.
package 빠른 테스트나 targeted suite가 FULL을 대체하지 않는다. E01은 FULL에 package별 실행 결과를 명시적으로 포함시킨다.
추가 package 실행이 FULL의 총 deadline을 넘는다면 결과를 생략하지 않고 실행 구성/필요 정책을 검토한다.
Windows guard/process cleanup 자체를 바꿀 때만 Project CLI의 별도 invocation-guard 통합 검증을 추가한다.

FULL은 첫 non-PASS에서 멈추는 기존 정책을 유지한다. 실패 수정 중에는 해당 검사로 피드백하고
다음 최종 후보에 FULL을 다시 실행한다. 이후 코드 변경이 없는데 같은 검사를 이유 없이 반복하지 않는다.
CI PASS는 실제 실행된 commit/run을 기록하며 계획된 실행이나 다른 후보의 과거 PASS로 대체하지 않는다.
문서 작성 시점에는 위 제품 command·emulator·CI를 실행하지 않았다.

각 V 결과에는 NOT_RUN/PASS/FAIL/BLOCKED, 실제 command/status/exit code, 날짜·후보·실행 위치와 한계를 기록한다.
새 테스트 경로·실행 목록·수정 전 재현/수정 후 결과는 TEST 상세/월별 기록에 연결한다.
관련 없는 기존 사용자 변경은 테스트 실행 전후 tree로 보존 확인한다. token/UID/계정 인증 출력은 보고하지 않는다.

### 3.5 V23 — 실기기 조합과 성능 목표

물리 기기 검증은 최소 태블릿 T + 다른 계정의 생존 휴대폰 A/B로 다중 원인을 구성한다.
Android 휴대폰·iOS 휴대폰·Android 태블릿·iPad 역할을 모두 포함한다. 지원 OS/앱 빌드·실제 모델을 기록한다.
기기가 부족하면 자동/에뮬레이터로 통과했다고 대신 표시하지 않고 해당 조합을 NOT_RUN으로 남긴다.

| 실기기 묶음 | 4게임 공통 수행 | 추가 확인 |
| --- | --- | --- |
| 기본 게임 흐름 | 양 역할의 시작/진행/정상 결과·비정상 종료/홈·대기실 | 게임별 dealing/빈 데이터·Mafia 역할/밤·FC 제출/팀·Holdem allIn/다음 핸드 |
| 순간 단절/재단절 | phone과 tablet을 각각 Wi-Fi 차단/복원, 이동통신 가능 기기의 Wi-Fi↔셀룰러, 복구 중 재단절 | 앱 재시작 없이 같은 자격/상태, 서버 중단 남은 시간·입력 보호·안내 시각 |
| 다중 원인/진행자 선택 | A+B/T 겹친 단절·일부만 복귀, 60초 만료·연장 한 번·조기 제외/불가 제외·종료 | 연결 회복과 필수 준비를 구분, 마지막 준비 전 재개 금지·늦은 선택/ready 경합 |
| 재실행/초기화 | 앱 백그라운드/foreground·프로세스 종료/재실행·최초 오프라인→온라인 | phone 복귀 동의/tablet 자동, 온보딩 오류 회복·퇴장 intent 재실행 보존 |
| 화면/요청 경합 | 상세/스토어 복귀 질문, 진행/퇴장 응답 유실, 실제 버튼·뒤로가기/dialog·전환 중 종료 | 버튼이 실제 작업 수행, route/사유 한 번·정상 결과 유지·입력 접근성 차단 |
| 에셋/진단 | 정상 캐시 복구·통제된 파일 예외, debug 기록·복사·release 확인 | 정상 재다운로드 없음·예외 동의/준비, 휴대폰/iPad 룰렛 버튼 위치/가독성·요청과 회전 기록 |

최초 실기기 체크리스트는 구현 후 실제 경로에 맞춰 [기존 체크리스트](../operations/REAL_DEVICE_AUTH_NETWORK_SESSION_CHECKLIST.md)를
보완해 작성한다. 과거 통과 항목은 과거 후보 근거로 보존한다. physical SDK 연결 속도와 모의 응답 유실 테스트를 구분한다.

측정 지점/집계는 기술안 7.3을 그대로 사용한다. 구간은 연결 감지·앱 준비·다른 기기 대기·입력 복귀로 나눈다.
초기 수집안은 각 게임/역할/OS/대표 전환 조건별 정상 복구 10회다. 이는 제품 성능 목표나 p95 확정 근거가 아니다.
표본이 작으면 그 한계를 밝히고 실패/최대 지연/편차가 큰 조건은 반복을 늘린다. p95 판단에는 분포와 표본 수를 함께 제시한다.
새 다운로드 진입·실제 파일 예외·사용자 선택 대기·오프라인 체류·다른 기기 대기는 일반 연결 후 준비 성능과 분리한다.
상태 유실/실패는 성공 지연 통계에서 제외하되 실패율·원인·해당 V 결과로 반드시 보고한다.

E14 결과로 대표 조건별 중앙값/p95/최대/성공률·손패/자격/타이머 보존을 제시하고 사용자에게
목표 시간·허용 실패 기준·출시 통과 조건의 구체 수치를 제안한다. 목표 합의 전 NET의 수치 완료 판정을 하지 않는다.
합의 목표를 못 맞추면 실제 병목의 담당 E를 좁혀 개선하고 그 조건을 재측정한다. 30초 retry 상한을 목표로 사용하지 않는다.

### 3.6 전체 완료와 반영의 구분

| 판정 | 필요한 결과 |
| --- | --- |
| 계획 작성 | 이 문서와 기존 설계/태스크 연결. 실제 구현/검증과 구분 |
| 단위 구현 검증 | 2.3의 범위·관련 테스트/FULL·tree/evidence. 남은 필수 실기기 표시 |
| 네트워크·세션 묶음 구현 검증 | E00의 계약/담당 확정, 모든 소비자/통합 V와 현재 후보 targeted/package/FULL/CI PASS, V23 필요 조합 PASS, 측정 후 목표 합의/충족 |
| 각 기존 태스크 전체 완료 | 위 범위 외 해당 태스크의 남은 완료 조건까지 확인. 일부 통과만으로 TASKS 행 이동 금지 |
| 출시/운영 반영 완료 | 실제 변경 앱/함수/rules·기존 데이터·반영/rollback·사후 검증 계획의 별도 승인과 실행 evidence. [출시 판정 기준](TASK_MANAGEMENT.md#출시-판정-기준) 적용 |

E15는 기술안 R15의 진행 방 없는 시점 전환 기본안을 실제 반영 수단과 대조한다.
기존 active 방을 자동 migration/강제 종료하지 않는다. 구버전 앱을 고려하지 않아도 현재 데이터/함수/scheduler/rules의
혼합 상태는 점검한다. 필요한 함수만 이름/리전별로 명시하고 구체 배포 목록은 구현 diff로 만든다.
production RTDB 조회/배포/보정/migration을 이 계획의 자동 후속으로 실행하지 않는다.
Firebase MCP가 필요한 경우에도 [read-only pilot](../operations/FIREBASE_MCP.md)의 별도 사전 절차를 따른다.

## 4. 현재 작성 결과와 다음 행동

R16 담당안·허용 범위, R17 의존 순서/채팅 단위, R18 테스트/실기기/성능/완료 판정의 초안을 작성했다.
코드 기준은 최신 newgui, 기술안 A~C는 모두 권장 방식으로 채택됐다.
E00의 최신 SHA/후속 변경·소비자·검증 공백 확인은 [착수 기록](NETWORK_SESSION_E00_BASELINE.md)에 남겼다.
사용자가 전체를 수행한다고 확인해 담당 분담 결정을 닫았다. E00의 기준 확인과 인수인계는 정리됐다.
E01 배선·회귀는 [E01 기록](NETWORK_SESSION_E01_VALIDATION.md)에 남겼다.
후속 사용자 요청으로 E02~E12를 순차 구현했으며 [현재 계약](../engineering/NETWORK_SESSION_CONTRACT.md)과
[후보 검증](NETWORK_SESSION_E02_E12_IMPLEMENTATION.md)에 연결한다. 관련 검사와 사용자 명시 승인 후 현재 후보 FULL이 PASS/exit 0이다.
E13 emulator/CI·E14 실기기·E15 반영은 미실행이다.
현재 상태와 다음 행동은 TASKS.md를 따른다.
E00은 제품 코드·테스트 코드·검증 배선·새 채팅·production을 변경하지 않았다.
