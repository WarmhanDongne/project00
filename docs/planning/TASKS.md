# 작업 목록

ID를 누르면 작업별 상세 설명으로 이동한다. [관리 방법](TASK_MANAGEMENT.md) · [완료 작업](COMPLETED_TASKS.md) · [월별 기록](logs/)

| 분류 | 개수 |
| --- | ---: |
| 구현 검증 대기 | 3 |
| 출시 전 필수 | 9 |
| 출시 전 권장 | 11 |
| 출시 후 작업 | 7 |
| 합계 | 30 |

## 구현 검증 대기

| ID | 작업 | 상태 | 다음 행동 |
| --- | --- | --- | --- |
| [MAFIA-RULES-03](tasks/MAFIA-RULES-03.md#mafia-rules-03) | 마피아 규칙·역할·룰북 개선 | 검증 대기 | 사용자 명시 승인 후 FULL, 양 기기 실제 게임 흐름 확인 |
| [MAFIA-ROLE-SETUP-02](tasks/MAFIA-ROLE-SETUP-02.md#mafia-role-setup-02) | 마피아 신분카드 구성 화면 개선 | 검증 대기 | 사용자 승인 후 FULL, 실제 태블릿 터치·전환 확인 |
| [GAME-DEVICE-BOARD-01](tasks/GAME-DEVICE-BOARD-01.md#game-device-board-01) | 게임 패키지 기기별 화면·흐름 구조 정리 | 검증 대기 | 사용자 승인 후 FULL, 회귀 테스트는 TEST-REGRESSION-01에서 관리 |

## 출시 전 필수

| ID | 작업 | 상태 | 다음 행동 |
| --- | --- | --- | --- |
| [NET-RECOVERY-01](tasks/NET-RECOVERY-01.md#net-recovery-01) | 네트워크 복구 체감 지연 | 관찰 중 | 기존 측정·착수 조건 유지 |
| [GAME-COMM-DIAGNOSTICS-01](tasks/GAME-COMM-DIAGNOSTICS-01.md#game-comm-diagnostics-01) | 게임 통신 실시간 진단 | 실기기 확인 대기 | 휴대폰·아이패드 룰렛 재테스트 |
| [SESSION-RECONNECT-02](tasks/SESSION-RECONNECT-02.md#session-reconnect-02) | 게임 재접속 보완·단절 신고 재시도·네트워크 가드·기기별 검증 | 보류 — 담당 범위·복구 계약 합의 대기 | 최신 코드 재확인, 플랫폼·서버·패키지 담당 범위와 계약 합의 |
| [TEST-REGRESSION-01](tasks/TEST-REGRESSION-01.md#test-regression-01) | 핵심 회귀 테스트 복원·추가 작성과 검증 배선 | 요구사항 확인 | 삭제·이동 테스트 대조, 핵심 장애 시나리오와 suite/FULL/CI 실행 경로 확정 |
| [TABLET-ASSET-01](tasks/TABLET-ASSET-01.md#tablet-asset-01) | 게임 구성품 이미지 덮임 | 조사 전 | 기기·게임·빌드를 기록하고 재현 |
| [TABLET-MEMBERS-01](tasks/TABLET-MEMBERS-01.md#tablet-members-01) | 키보드 등장 시 구성원 목록 깨짐 | 조사 전 | 닉네임 수정 흐름 재현 |
| [TEST-ACCOUNT-01](tasks/TEST-ACCOUNT-01.md#test-account-01) | 배포용 테스트 계정 준비 | 요구사항 확인 | 용도·환경·권한 확정 |
| [CORE-REVIEW-01](tasks/CORE-REVIEW-01.md#core-review-01) | 핵심 구현 점검·그룹 목록 권한 회귀 | 요구사항 확인 | 일반 참가자 조회 계약·역할별 재현, 나머지 핵심 점검 범위 확정 |
| [ROOM-CREATE-REQUEST-01](tasks/ROOM-CREATE-REQUEST-01.md#room-create-request-01) | 방 생성 요청 기록 잔류 | 요구사항 확인 | 중복 방지 유지와 잔류 처리 검토 |

## 출시 전 권장

| ID | 작업 | 상태 | 다음 행동 |
| --- | --- | --- | --- |
| [RELEASE-EVIDENCE-01](tasks/RELEASE-EVIDENCE-01.md#release-evidence-01) | 출시 증빙 보완 | 요구사항 확인 | 기존 성공 보고의 기기·빌드·날짜 보완 |
| [COST-01](tasks/COST-01.md#cost-01) | Functions 과금 점검·최적화 | 조사 전 | 청구 항목·기간과 실행 원인 확인 |
| [SECURITY-01](tasks/SECURITY-01.md#security-01) | 보안 위험 점검·중대한 문제 수정 | 조사 전 | 점검 범위와 위협 목록 작성 |
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
| [LOBBY-DESIGN-01](tasks/LOBBY-DESIGN-01.md#lobby-design-01) | 로비 전체 디자인 개선 | 요구사항 확인 | 개선 목표·화면 범위 결정 |
| [GAME-DESIGN-01](tasks/GAME-DESIGN-01.md#game-design-01) | 게임 디자인 개선 | 요구사항 확인 | 대상 게임·화면·우선순위 결정 |
| [LOBBY-TUTORIAL-01](tasks/LOBBY-TUTORIAL-01.md#lobby-tutorial-01) | 로비 첫 입장 튜토리얼 | 요구사항 확인 | 첫 사용 안내 범위 결정 |
| [GAME-TUTORIAL-01](tasks/GAME-TUTORIAL-01.md#game-tutorial-01) | 게임 첫 플레이 튜토리얼 | 요구사항 확인 | 게임별 안내 범위 결정 |
| [GAME-PAUSE-UX-01](tasks/GAME-PAUSE-UX-01.md#game-pause-ux-01) | 남은 시간 재개 안내 | 관찰 중 | 기존 타이머 계약 안에서 안내 검토 |
| [WINNER-CONNECTION-LAYER-01](tasks/WINNER-CONNECTION-LAYER-01.md#winner-connection-layer-01) | winner 아래 연결 안내 겹침 | 관찰 중 | 결과·연결 안내의 표시 순서 확인 |
| [ACCESSIBILITY-SCALE-01](tasks/ACCESSIBILITY-SCALE-01.md#accessibility-scale-01) | 글씨·화면 확대 설정 대응 | 관찰 중 | 기기·빌드·확대 설정별 재현 |
