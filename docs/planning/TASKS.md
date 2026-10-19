# 작업 목록

2026-10-10 새 채팅에서 LP 룰렛·재시작 원인 재확인 → 설계 → 구현을 이어가는 요청은
[최신 수정 인계](NETWORK_SESSION_REPAIR_HANDOFF.md)를 따른다.

ID를 누르면 작업별 상세 설명으로 이동한다. [관리 방법](TASK_MANAGEMENT.md) · [완료 작업](COMPLETED_TASKS.md) · [월별 기록](logs/) · [네트워크·세션 작업 보기](NETWORK_SESSION_TASKS.md)

2026-10-08 네트워크·세션 조사와 `origin/newgui`의 `999c3e9` 비교를 반영했다.
기존 오류 해결은 SESSION-RECONNECT-02, 테스트 실행 경로는 TEST-REGRESSION-01에서
관리한다. 사용자 요청으로 새 UI 연결 작업과 홀덤 구현 후보도 출시 전 필수에 포함했다. newgui 코드는
당시 checkout에 병합하지 않았으며, 작업 등록은 구현·계약 변경·배포 승인이나 완료 판정이 아니다.
2026-10-09 사용자는 최신 newgui와 기술안 A~C의 권장 방식을 채택했다. SESSION의 보류 사유는
담당 범위·착수 대기로 갱신했다. 후속 요청으로 develop에서 E00을 시작하고 [착수 기준](NETWORK_SESSION_E00_BASELINE.md)을 기록했다.
현재 develop에는 최신 newgui와 E00 문서가 반영돼 있다. E01 검증 배선·회귀 복원 후보는 관련 검사와 사용자 승인 FULL을 통과했고 [검증 기록](NETWORK_SESSION_E01_VALIDATION.md)을 남겼다.
E02~E12의 [구현 후보와 관련 검사](NETWORK_SESSION_E02_E12_IMPLEMENTATION.md) 및 승인 FULL PASS 후보는 56cd535로 커밋·푸시했다. [E13 기록](NETWORK_SESSION_E13_BACKEND_CI.md)의 별도 제품 수정 76319f5도 원래 브랜치에 반영했고 현재 로컬 FULL과 실제 backend CI는 PASS다. canonical FULL CI의 SDK 차이는 테스트 브랜치에서 보정해 후속 승인 재실행도 PASS다. 남은 FlutterFire/앱 통합·E14 기기/성능·원래 CI SDK 정렬/출시 판정은 후속이다.
후속 사용자 결정으로 기존 Firebase에 변경 전체 배포·구버전 호환 불필요·Android 실기기 APK
설치를 확정했다. [준비/배포 기록](../operations/NETWORK_SESSION_TEST_PREPARATION.md)을 따른다.

| 분류 | 개수 |
| --- | ---: |
| 구현 검증 대기 | 7 |
| 출시 전 필수 | 11 |
| 출시 전 권장 | 11 |
| 출시 후 작업 | 8 |
| 합계 | 37 |

## 구현 검증 대기

| ID | 작업 | 상태 | 다음 행동 |
| --- | --- | --- | --- |
| [LOCAL-EMULATOR-01](tasks/LOCAL-EMULATOR-01.md#local-emulator-01) | 로컬 Firebase 개발환경과 서버 전환 | 검증 대기 — local 통합·auth/session·양 모드 회귀·iPad 실행 PASS | 사용자 승인 FULL |
| [GAME-CATALOG-I18N-01](tasks/GAME-CATALOG-I18N-01.md#game-catalog-i18n-01) | Firestore 게임 이름 다국어화 | 검증 대기 — 앱·Functions targeted PASS | 운영 문서 갱신·확인, 사용자 승인 FULL |
| [LIARS-CATALOG-01](tasks/LIARS-CATALOG-01.md#liars-catalog-01) | 라이어스 Firebase 문서 ID 이전 | 검증 대기 — 호환 reader·이전 스크립트 회귀/session PASS | 사용자 승인 FULL, 사용 앱 배포 범위 확인 → 서버 두 함수/앱 반영 → 문서 원자 이전 및 실제 게임 확인 |
| [MAFIA-RULES-03](tasks/MAFIA-RULES-03.md#mafia-rules-03) | 마피아 규칙·역할·룰북 개선 | 검증 대기 | 사용자 명시 승인 후 FULL, 양 기기 실제 게임 흐름 확인 |
| [MAFIA-ROLE-SETUP-02](tasks/MAFIA-ROLE-SETUP-02.md#mafia-role-setup-02) | 마피아 신분카드 구성 화면 개선 | 검증 대기 | 사용자 승인 후 FULL, 실제 태블릿 터치·전환 확인 |
| [GAME-DEVICE-BOARD-01](tasks/GAME-DEVICE-BOARD-01.md#game-device-board-01) | 게임 패키지 기기별 화면·흐름 구조 정리 | 검증 대기 | 사용자 승인 후 FULL, 회귀 테스트는 TEST-REGRESSION-01에서 관리 |
| [YUT-GAMEPLAY-01](tasks/YUT-GAMEPLAY-01.md#yut-gameplay-01) | 윷놀이 3종 서버 게임·휴대폰/태블릿 플레이 화면 | 구현 완료, 검증 승인 대기 | 사용자 승인 후 targeted 테스트와 FULL validation, 4인 실제 플레이 검증. 카탈로그 공개·Functions 배포는 별도 출시 승인 |

## 출시 전 필수

| ID | 작업 | 상태 | 다음 행동 |
| --- | --- | --- | --- |
| [HOLDEM-01](tasks/HOLDEM-01.md#holdem-01) | 다운로드형 텍사스 홀덤·복구 흐름 보완 | 검증 대기 — E04/E07 로컬 검증 PASS | 복구·allIn 회귀의 기존 FULL PASS 유지. 10/10 로컬 사운드·진동·연결 띠 통합 후보 검증 중. E13 통합·E14 실기기 확인 |
| [NEWGUI-RECOVERY-01](tasks/NEWGUI-RECOVERY-01.md#newgui-recovery-01) | 새 연결 화면·로비·에셋·퇴장 흐름에 세션 복구 연결 | 검증 대기 — 10/11 통합 관련 검사 PASS | [develop 네트워크·로컬 GUI 통합 후보](DEVELOP_GUI_INTEGRATION_20261011.md): d9a61f8 후속 반영, 세션 Flutter180/Functions116 및 로비·음악 PASS, 목록 회귀 보완20 PASS. 기존 작업 보존, 이번 후보 FULL 승인 대기. E13/E14 확인 |
| [NET-RECOVERY-01](tasks/NET-RECOVERY-01.md#net-recovery-01) | 네트워크 복구·앱 응답 지연 | 진행 중 — 세 방 작업 성능 설계, 준비/재참여 검증 유지 | [10/12 생성·탈퇴·초기화 계획](ROOM_ACTION_LATENCY_PLAN_20261012.md): 승인된10/11 15~17시 로그에서 leave6건170~184ms/2.82~3.27초 두 군 확인. 버전·leave/transaction 계측 후 실행 준비·close 중복 읽기/create 독립 읽기·접속 예약 대기 중 확인된 병목부터 개선. 구현/실측 대기. [개발팀 공유](../engineering/NETWORK_LATENCY_IMPROVEMENTS.md)의 최초 퇴장·목록/자리 배치/다운로드 개선 및 과거 session/auth/FULL PASS(99초/exit0), create 단독 배포 기록 보존. 후속 ready FULL1006개/exit0·iPad568ms 승인 확인. 휴대폰 재참여 실패·분배/첫 턴·E14 미완료 유지 |
| [GAME-COMM-DIAGNOSTICS-01](tasks/GAME-COMM-DIAGNOSTICS-01.md#game-comm-diagnostics-01) | 게임 통신 실시간 진단 | 검증 대기 — E12 로컬 검증 PASS | debug·버퍼/N/A·단계 회귀와 현재 FULL PASS. E14 룰렛·실측 확인 |
| [SESSION-RECONNECT-02](tasks/SESSION-RECONNECT-02.md#session-reconnect-02) | 4게임 재접속·단절/퇴장 오류·네트워크 가드·기기별 검증 | 검증 대기 — B 재참가 신원 수정·실기기38/FULL 대기 | [후속 조사·계획·구현](tasks/NETWORK_SESSION_20261011_IMPLEMENTATION.md): 02:25 이후 B/T 최신 debug 설치 일치. B heartbeat 권한 거부·즉시 준비 timeout, 제외 성공 뒤 T 준비 재보고 timeout 확인. membership 간 순번 비교로 새 신원/pending 정리가 누락되는 결함 probe 재현(exit0), B 실제 신원 대조는 미실행. 신원 저장·직접 재참가 처리 수정, session Flutter212/Functions123·mutation PASS(exit0), 변경5파일 분석 문제0. 다음은 FULL 승인·38번 실기기 확인. 제외 후 ready 예산·LP 분배 완료 대기는 별도 미해결. 태블릿 가로 시작 사용자 성공. 이전 준비23/FC2·session199/123·mutation PASS(exit0), 변경5파일 분석 문제0 보존. 이번 조사 제품 수정·배포 없음. 기존14개 배포/36 LP·37 사용자 성공 기록 보존. native idle·28 초기 접속·expire403·응답 유실/옛 cleanup 미확인 유지. Final Call 재개, FULL/16번 보류 및 홀덤 단일 기기 조사 제외 유지 |
| [TEST-REGRESSION-01](tasks/TEST-REGRESSION-01.md#test-regression-01) | 핵심 회귀 테스트 복원·추가 작성과 검증 배선 | 진행 중 — LP 단절 후보 targeted PASS | controller 복구/정체·서버 pause·분배 응답 유실 회귀와 session Flutter 160·Functions 97 PASS. FULL은 사용자 지시로 보류, 실기기 결과 대기 |
| [TABLET-ASSET-01](tasks/TABLET-ASSET-01.md#tablet-asset-01) | 게임 구성품 이미지 덮임 | 조사 전 | 기기·게임·빌드를 기록하고 재현 |
| [TABLET-MEMBERS-01](tasks/TABLET-MEMBERS-01.md#tablet-members-01) | 키보드 등장 시 구성원 목록 깨짐 | 조사 전 | 닉네임 수정 흐름 재현 |
| [TEST-ACCOUNT-01](tasks/TEST-ACCOUNT-01.md#test-account-01) | 배포용 테스트 계정 준비 | 요구사항 확인 | 용도·환경·권한 확정 |
| [CORE-REVIEW-01](tasks/CORE-REVIEW-01.md#core-review-01) | 핵심 구현 점검·그룹 목록 권한 회귀 | 검증 대기 — 연관 E10/E11 로컬 검증 PASS | 그룹 권한·Holdem 제외·generation 회귀와 현재 FULL PASS. E13 경합·기존 핵심 검토 |
| [ROOM-CREATE-REQUEST-01](tasks/ROOM-CREATE-REQUEST-01.md#room-create-request-01) | 방 생성 요청 기록 잔류 | 진행 중 — 배포 전 현재 접속 보호 보완 필요 | [안정성 후속 검토](ROOM_ACTION_LATENCY_PLAN_20261012.md#7-2026-10-12-functions-안정성-검토와-계획-수정): leaf 재접속의 요약 지연으로 정상 membership 제거·대기 방 전체 종료 재현. 참가자/controller 현재 connection 신원/heartbeat 보호와 회귀를 배포 선행 조건으로 추가. 기존 [RTDB 정리 기록](../operations/RTDB_RETENTION_REVIEW.md)의 운영 요약50회 completed7/failed0·관련57/build/lint PASS·FULL 12단계 PASS(exit0, Flutter449/패키지238/Functions454, mutation PASS)는 유지하되 새 경합 미포함. 미배포. 고아 예약 해제·이력 GC 보류. 과거 E11/FULL은 신규 범위와 구분 |

## 출시 전 권장

| ID | 작업 | 상태 | 다음 행동 |
| --- | --- | --- | --- |
| [RELEASE-EVIDENCE-01](tasks/RELEASE-EVIDENCE-01.md#release-evidence-01) | 출시 증빙 보완 | 요구사항 확인 | 기존 성공 보고의 기기·빌드·날짜 보완 |
| [HEARTBEAT-B1-01](tasks/HEARTBEAT-B1-01.md#heartbeat-b1-01) | B1-C Heartbeat/Ping 경량화 | 검증 대기 — 운영 Functions81/Rules 배포 완료, FULL 분석 FAIL | [배포·FULL 기록](../operations/HEARTBEAT_B1_IMPLEMENTATION.md#2026-10-13--운영-배포full-검증). 4e9df2e 배포/81개 ACTIVE·새 trigger/Rules 일치. FULL은 기존 테스트 보조 중괄호INFO8개로 분석 FAIL/exit1, 후속 전체 테스트 미실행. 보완·분석·새 FULL·실기기·실과금 확인 필요. 로비 HB 유지 |
| [COST-01](tasks/COST-01.md#cost-01) | Functions 과금 점검·최적화 | 조사 전 | 청구 원인, 정리 후보 제한·부분 실패, 4게임 명령 기록 수명과 transaction 비용 확인 |
| [SECURITY-01](tasks/SECURITY-01.md#security-01) | 보안 위험 점검·중대한 문제 수정 | 조사 전 | newgui·홀덤 포함 RTDB 읽기/presence 세션 경계와 기존 캐릭터 ID 호환 대조 |
| [DOCS-CORE-01](tasks/DOCS-CORE-01.md#docs-core-01) | 핵심 구조·개발·운영 문서 정비 | 조사 전 | 기존 설명과 코드·테스트 대조 |
| [NOTIFICATION-UI-01](tasks/NOTIFICATION-UI-01.md#notification-ui-01) | 사용자 알림 디자인 통일 | 조사 전 | 알림 종류·표시 방식 목록화 |
| [PHONE-SELF-01](tasks/PHONE-SELF-01.md#phone-self-01) | 모바일 그룹에서 본인 표시 | 조사 전 | 현재 식별 방식과 표시 위치 확인 |
| [GENRE-TAGS-01](tasks/GENRE-TAGS-01.md#genre-tags-01) | 태블릿 장르 태그 표시 범위 정리 | 요구사항 확인 | 보유 게임 기준인지 전체 장르인지 확정 |
| [CODE-AUDIT-01](tasks/CODE-AUDIT-01.md#code-audit-01) | 전체 코드 구조·최적화 후보 조사 | 조사 전 | 조사 범위와 순서 정의 |
| [CODE-OPTIMIZE-01](tasks/CODE-OPTIMIZE-01.md#code-optimize-01) | 일반 최적화·리팩터링 | 조사 전 | 조사 결과로 개선 우선순위 결정 |
| [PACKAGE-MIGRATION-01](tasks/PACKAGE-MIGRATION-01.md#package-migration-01) | Flutter workspace 물리 패키지 분리 | 최종 검증 대기 | 승인 후 `validate --full`, 앱·Firebase Storage 실기기 확인 |
| [DOCS-DETAIL-01](tasks/DOCS-DETAIL-01.md#docs-detail-01) | 기능별 상세 구현 문서화 | 조사 전 | 핵심 문서 외 설명이 필요한 기능 선정 |

## 출시 후 작업

| ID | 작업 | 상태 | 다음 행동 |
| --- | --- | --- | --- |
| [LOBBY-DESIGN-01](tasks/LOBBY-DESIGN-01.md#lobby-design-01) | 로비 전체 디자인 개선 | 진행 중 | 10/16 휴대폰 참가자 목록의 `나` 표시를 얼굴 오른쪽 아래 작은 중첩 배지로 통일. 관련 GUI 37개 PASS. 방향성 배경 전환의 GUI69·session Flutter219/Functions155 근거도 유지. 다음 체감 항목 결정 후 사용자 승인 FULL·실기기 확인 |
| [STORE-ENTITLEMENT-01](tasks/STORE-ENTITLEMENT-01.md#store-entitlement-01) | 게임 상점과 소유권·구매 기반 구조 | 검증 대기 — 비과금 gateway·상점/library 분리 targeted PASS | 사용자 승인 FULL. 실제 과금은 별도 승인 후 서버 검증·entitlement·스토어 sandbox 구현 |
| [GAME-DESIGN-01](tasks/GAME-DESIGN-01.md#game-design-01) | 게임 디자인 개선 | 요구사항 확인 | 대상 게임·화면·우선순위 결정 |
| [LOBBY-TUTORIAL-01](tasks/LOBBY-TUTORIAL-01.md#lobby-tutorial-01) | 로비 첫 입장 튜토리얼 | 요구사항 확인 | 첫 사용 안내 범위 결정 |
| [GAME-TUTORIAL-01](tasks/GAME-TUTORIAL-01.md#game-tutorial-01) | 게임 첫 플레이 튜토리얼 | 요구사항 확인 | 게임별 안내 범위 결정 |
| [GAME-PAUSE-UX-01](tasks/GAME-PAUSE-UX-01.md#game-pause-ux-01) | 남은 시간 재개 안내 | 관찰 중 | 기존 타이머 계약 안에서 안내 검토 |
| [WINNER-CONNECTION-LAYER-01](tasks/WINNER-CONNECTION-LAYER-01.md#winner-connection-layer-01) | winner 아래 연결 안내 겹침 | 관찰 중 | 결과·연결 안내의 표시 순서 확인 |
| [ACCESSIBILITY-SCALE-01](tasks/ACCESSIBILITY-SCALE-01.md#accessibility-scale-01) | 글씨·화면 확대 설정 대응 | 관찰 중 | 기기·빌드·확대 설정별 재현 |
