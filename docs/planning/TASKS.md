# 작업 목록

ID를 누르면 작업별 상세 설명으로 이동한다. [관리 방법](TASK_MANAGEMENT.md) · [완료 작업](COMPLETED_TASKS.md) · [월별 기록](logs/) · [네트워크·세션 작업 보기](NETWORK_SESSION_TASKS.md)

2026-10-08 네트워크·세션 조사와 `origin/newgui`의 `999c3e9` 비교를 반영했다.
기존 오류 해결은 SESSION-RECONNECT-02, 테스트 실행 경로는 TEST-REGRESSION-01에서
관리한다. 사용자 요청으로 새 UI 연결 작업과 홀덤 구현 후보도 출시 전 필수에 포함했다. newgui 코드는
현재 checkout에 병합하지 않았으며, 작업 등록은 구현·계약 변경·배포 승인이나 완료 판정이 아니다.
2026-10-09 사용자는 최신 newgui와 기술안 A~C의 권장 방식을 채택했다. SESSION의 보류 사유는
담당 범위·착수 대기로 갱신하며 [실행 계획](NETWORK_SESSION_IMPLEMENTATION_PLAN.md)에 연결한다. 개발은 아직 시작하지 않는다.

| 분류 | 개수 |
| --- | ---: |
| 구현 검증 대기 | 3 |
| 출시 전 필수 | 11 |
| 출시 전 권장 | 11 |
| 출시 후 작업 | 7 |
| 합계 | 32 |

## 구현 검증 대기

| ID | 작업 | 상태 | 다음 행동 |
| --- | --- | --- | --- |
| [MAFIA-RULES-03](tasks/MAFIA-RULES-03.md#mafia-rules-03) | 마피아 규칙·역할·룰북 개선 | 검증 대기 | 사용자 명시 승인 후 FULL, 양 기기 실제 게임 흐름 확인 |
| [MAFIA-ROLE-SETUP-02](tasks/MAFIA-ROLE-SETUP-02.md#mafia-role-setup-02) | 마피아 신분카드 구성 화면 개선 | 검증 대기 | 사용자 승인 후 FULL, 실제 태블릿 터치·전환 확인 |
| [GAME-DEVICE-BOARD-01](tasks/GAME-DEVICE-BOARD-01.md#game-device-board-01) | 게임 패키지 기기별 화면·흐름 구조 정리 | 검증 대기 | 사용자 승인 후 FULL, 회귀 테스트는 TEST-REGRESSION-01에서 관리 |

## 출시 전 필수

| ID | 작업 | 상태 | 다음 행동 |
| --- | --- | --- | --- |
| [HOLDEM-01](tasks/HOLDEM-01.md#holdem-01) | 다운로드형 텍사스 홀덤·복구 흐름 보완 | 검증 대기 — newgui 구현 후보 | 재시도·자동 진행·비정상 종료 복귀 누락 보완 범위 합의, 현재 후보 FULL·실기기 확인 |
| [NEWGUI-RECOVERY-01](tasks/NEWGUI-RECOVERY-01.md#newgui-recovery-01) | 새 연결 화면·로비·에셋·퇴장 흐름에 세션 복구 연결 | 요구사항 확인 | 6종 연결 화면의 상태·콜백 대조, 상세·스토어 중 복원과 퇴장 경합 재현, 담당 범위 합의 |
| [NET-RECOVERY-01](tasks/NET-RECOVERY-01.md#net-recovery-01) | 네트워크 복구 체감 지연 | 관찰 중 | newgui에서 연결·세션 준비·화면 복귀 시간을 구분해 측정, 기존 착수 조건과 목표 합의 유지 |
| [GAME-COMM-DIAGNOSTICS-01](tasks/GAME-COMM-DIAGNOSTICS-01.md#game-comm-diagnostics-01) | 게임 통신 실시간 진단 | 실기기 확인 대기 | 휴대폰·아이패드 룰렛 재테스트 |
| [SESSION-RECONNECT-02](tasks/SESSION-RECONNECT-02.md#session-reconnect-02) | 4게임 재접속·단절/퇴장 오류·네트워크 가드·기기별 검증 | 보류 — 담당 범위·착수 대기 | 최신 newgui·기술안 A~C 채택, 플랫폼/서버 담당 확정과 착수 SHA/후속 변경 대조. 구현은 아직 시작하지 않음 |
| [TEST-REGRESSION-01](tasks/TEST-REGRESSION-01.md#test-regression-01) | 핵심 회귀 테스트 복원·추가 작성과 검증 배선 | 요구사항 확인 | 누락된 suite 파일 20개 대조, 4게임·새 UI 회귀 작성과 package/FULL/CI 실행 경로 확정 |
| [TABLET-ASSET-01](tasks/TABLET-ASSET-01.md#tablet-asset-01) | 게임 구성품 이미지 덮임 | 조사 전 | 기기·게임·빌드를 기록하고 재현 |
| [TABLET-MEMBERS-01](tasks/TABLET-MEMBERS-01.md#tablet-members-01) | 키보드 등장 시 구성원 목록 깨짐 | 조사 전 | 닉네임 수정 흐름 재현 |
| [TEST-ACCOUNT-01](tasks/TEST-ACCOUNT-01.md#test-account-01) | 배포용 테스트 계정 준비 | 요구사항 확인 | 용도·환경·권한 확정 |
| [CORE-REVIEW-01](tasks/CORE-REVIEW-01.md#core-review-01) | 핵심 구현 점검·그룹 목록 권한 회귀 | 요구사항 확인 | newgui의 일반 참가자 조회 계약·역할별 재현, 홀덤 인원 판정과 정리 정합성 대조 |
| [ROOM-CREATE-REQUEST-01](tasks/ROOM-CREATE-REQUEST-01.md#room-create-request-01) | 방 생성 요청 기록 잔류 | 요구사항 확인 | 중복 방지 유지, 응답 유실·고아 예약·삭제 트리거 부분 실패 검증과 처리 검토 |

## 출시 전 권장

| ID | 작업 | 상태 | 다음 행동 |
| --- | --- | --- | --- |
| [RELEASE-EVIDENCE-01](tasks/RELEASE-EVIDENCE-01.md#release-evidence-01) | 출시 증빙 보완 | 요구사항 확인 | 기존 성공 보고의 기기·빌드·날짜 보완 |
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
| [LOBBY-DESIGN-01](tasks/LOBBY-DESIGN-01.md#lobby-design-01) | 로비 전체 디자인 개선 | 요구사항 확인 | newgui 구현 후보와 기존 요구 대조, 세션 연동 회귀는 NEWGUI-RECOVERY-01과 연결 |
| [GAME-DESIGN-01](tasks/GAME-DESIGN-01.md#game-design-01) | 게임 디자인 개선 | 요구사항 확인 | 대상 게임·화면·우선순위 결정 |
| [LOBBY-TUTORIAL-01](tasks/LOBBY-TUTORIAL-01.md#lobby-tutorial-01) | 로비 첫 입장 튜토리얼 | 요구사항 확인 | 첫 사용 안내 범위 결정 |
| [GAME-TUTORIAL-01](tasks/GAME-TUTORIAL-01.md#game-tutorial-01) | 게임 첫 플레이 튜토리얼 | 요구사항 확인 | 게임별 안내 범위 결정 |
| [GAME-PAUSE-UX-01](tasks/GAME-PAUSE-UX-01.md#game-pause-ux-01) | 남은 시간 재개 안내 | 관찰 중 | 기존 타이머 계약 안에서 안내 검토 |
| [WINNER-CONNECTION-LAYER-01](tasks/WINNER-CONNECTION-LAYER-01.md#winner-connection-layer-01) | winner 아래 연결 안내 겹침 | 관찰 중 | 결과·연결 안내의 표시 순서 확인 |
| [ACCESSIBILITY-SCALE-01](tasks/ACCESSIBILITY-SCALE-01.md#accessibility-scale-01) | 글씨·화면 확대 설정 대응 | 관찰 중 | 기기·빌드·확대 설정별 재현 |
