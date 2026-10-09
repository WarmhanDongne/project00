# 출시 전 네트워크·세션 작업 목록

ID를 누르면 작업별 상세 설명으로 이동한다. [전체 작업 목록](TASKS.md) · [관리 방법](TASK_MANAGEMENT.md) · [월별 기록](logs/)

이번 출시 전에 함께 확인할 네트워크·세션 작업을 모은 보기용 문서다.
2026-10-08 기준으로 TASKS.md의 상태·다음 행동을 옮겼으며, 현재 분류·상태의 원본은
TASKS.md다. 작업이 변경되면 원본을 먼저 갱신하고 이 보기에도 반영한다.
기존 ID를 모은 목록으로, 전체 작업 개수에 새 작업을 추가하지 않는다.
제품 정책은 [설계](NETWORK_SESSION_DESIGN.md), 구현 계약 제안은 [기술안](NETWORK_SESSION_TECHNICAL_DESIGN.md),
담당·채팅 단위·검증은 [R16~R18 실행 계획안](NETWORK_SESSION_IMPLEMENTATION_PLAN.md)에서 확인한다.
계획 초안 작성으로 아래 원본 상태나 보류/승인 조건을 변경하지 않는다.
2026-10-09 후속 사용자 합의로 최신 newgui·기술안 A~C를 채택하고 SESSION의 보류 사유/다음 행동만 TASKS.md와 동기화했다.
그 뒤 develop에서 E00을 정리하고 사용자 전체 담당으로 E01을 시작했다. 최신 기준은 [착수 기록](NETWORK_SESSION_E00_BASELINE.md), 검증 배선·회귀 복원 후보는 [E01 기록](NETWORK_SESSION_E01_VALIDATION.md)에 남겼다.

| 분류 | 개수 |
| --- | ---: |
| 출시 전 필수 — 핵심 작업 | 7 |
| 출시 전 필수 — 연관 작업의 일부 범위 | 1 |
| 합계 | 8 |

## 출시 전 필수

| ID | 작업 | 상태 | 다음 행동 |
| --- | --- | --- | --- |
| [SESSION-RECONNECT-02](tasks/SESSION-RECONNECT-02.md#session-reconnect-02) | 4게임 재접속·단절/퇴장 오류·네트워크 가드·기기별 검증 | 검증 대기 — E13 백엔드·FULL/CI PASS | 별도 제품 수정/회귀·backend 10/10·로컬 및 canonical CI FULL PASS. 남은 FlutterFire/앱·기기 확인 |
| [NEWGUI-RECOVERY-01](tasks/NEWGUI-RECOVERY-01.md#newgui-recovery-01) | 새 연결 화면·로비·에셋·퇴장 흐름에 세션 복구 연결 | 검증 대기 — E08/E09 로컬 검증 PASS | 단일 안내·복귀/에셋/route 검사와 현재 FULL PASS. E13/E14 확인 |
| [HOLDEM-01](tasks/HOLDEM-01.md#holdem-01) | 다운로드형 텍사스 홀덤·복구 흐름 보완 | 검증 대기 — E04/E07 로컬 검증 PASS | 복구·allIn 회귀와 현재 FULL PASS. E13 통합·E14 실기기 확인 |
| [ROOM-CREATE-REQUEST-01](tasks/ROOM-CREATE-REQUEST-01.md#room-create-request-01) | 방 생성 요청 기록 잔류 | 검증 대기 — E11 로컬 검증 PASS | generation CAS·보상·지속 정리 회귀와 현재 FULL PASS. E13 부분 실패 확인 |
| [NET-RECOVERY-01](tasks/NET-RECOVERY-01.md#net-recovery-01) | 네트워크 복구 체감 지연 | 진행 중 — E12 계측 로컬 검증 PASS | 계측 회귀와 현재 FULL PASS. E14 실측 뒤 목표/출시 기준 합의 |
| [GAME-COMM-DIAGNOSTICS-01](tasks/GAME-COMM-DIAGNOSTICS-01.md#game-comm-diagnostics-01) | 게임 통신 실시간 진단 | 검증 대기 — E12 로컬 검증 PASS | debug·버퍼/N/A·단계 회귀와 현재 FULL PASS. E14 룰렛·실측 확인 |
| [TEST-REGRESSION-01](tasks/TEST-REGRESSION-01.md#test-regression-01) | 핵심 회귀 테스트 복원·추가 작성과 검증 배선 | 진행 중 — E13 백엔드·FULL/CI PASS | cold-cache/query 회귀·backend·로컬 FULL·17ca1f5 canonical CI PASS. 남은 앱/기기 회귀와 원래 CI SDK 정렬 검토 |
| [CORE-REVIEW-01](tasks/CORE-REVIEW-01.md#core-review-01) | 핵심 구현 점검·그룹 목록 권한 회귀 | 검증 대기 — 연관 E10/E11 로컬 검증 PASS | 그룹 권한·Holdem 제외·generation 회귀와 현재 FULL PASS. E13 경합·기존 핵심 검토 |

2026-10-09 E02~E12 순차 구현 요청에 따른 [현재 후보와 검증](NETWORK_SESSION_E02_E12_IMPLEMENTATION.md)을 연결한다. 관련 검사와 사용자 승인 후 FULL은 PASS다. 후속 E13/E14는 남아 있다.

## 이번 묶음에서 확인할 범위

현재 E01 착수 후보는 최신 newgui `fcee643`와 E00 문서를 포함한 develop `151eff8`이다.
과거 분석 `999c3e9` 이후의 제품 변경은 E00에서 대조했고, E01은 `codex/e01-validation-wiring`에서 진행한다.
게임은 라이어스포커·Final Call·Mafia·Holdem 4종의 휴대폰·태블릿 흐름이다.
아래는 이번 묶음의 범위다. 위 표의 상태·다음 행동과 각 태스크 전체의 완료 조건은 원본을 따른다.

| ID | 네트워크·세션 범위 |
| --- | --- |
| SESSION-RECONNECT-02 | 참가 자격·게임 상태 복원, 취소된 구독 재개, 데이터 준비 뒤 입력 허용, 다중 단절·턴 보존, 오래된 요청과 퇴장 일관성 |
| NEWGUI-RECOVERY-01 | 연결 화면 6종의 상태·실제 재시도·실패 안내, 상세/스토어 중 복원, 에셋 준비·퇴장 route 경합 |
| HOLDEM-01 | 실패 요청 재시도, 분배·결과·턴 자동 진행 복구, 비정상 종료 후 복귀, 단절·재실행 |
| ROOM-CREATE-REQUEST-01 | 생성 응답 유실·재시도 시 중복 방 방지, 예약 잔류·부분 실패·정리 재처리 |
| NET-RECOVERY-01 | 상태가 보존된 성공 복구의 단계별 시간 측정과 지연 개선, 측정 조건·목표 합의 |
| GAME-COMM-DIAGNOSTICS-01 | 기존 debug 진단의 newgui·실기기 동작 확인, 연결·상태 수신·요청·재시도의 지연/실패 구분 |
| TEST-REGRESSION-01 | 이번 결함의 회귀 테스트와 관련 인증·세션 검증, targeted suite·package·FULL·CI 실행 연결 |
| CORE-REVIEW-01 | 연관 범위만 포함: 일반 참가자의 그룹 게임 목록 권한, 홀덤 중단·제외 시 최소 인원 판정, 방/매핑/예약 정합성 |

HOLDEM-01의 신작 전체 출시 조건, TEST-REGRESSION-01의 나머지 인증 회귀,
CORE-REVIEW-01의 나머지 핵심 점검은 각각의 상세 문서에서 계속 관리한다.
이번 묶음의 일부 검증 통과를 해당 태스크 전체의 완료로 표시하지 않는다.

## 공통 완료 확인

- 담당 범위와 복구 완료·턴 재개 계약, NET의 측정 조건·목표를 확정한다.
- 반복 단절·복구 중 재단절·다중 단절·분배 중 재실행·최초 오프라인·응답 유실·퇴장에서
  방·참가 자격·손패·턴·남은 시간 보존과 안전한 복귀/종료를 확인한다.
- 현재 후보의 관련 자동 테스트·targeted suite·package 테스트·FULL·CI와 필요한 실제 기기
  결과를 남긴다. 최종 출시 판정은 [관리 방법의 출시 판정 기준](TASK_MANAGEMENT.md#출시-판정-기준)을 따른다.
- 공통 테스트 근거는 TEST-REGRESSION-01, 게임별 실제 기기 결과는 SESSION-RECONNECT-02에
  연결한다. 기존 보류·계약 변경·production 접근·배포 승인 경계는 각 원본 태스크를 따른다.
