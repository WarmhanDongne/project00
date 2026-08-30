# Mosigame development environment living plan

이 문서는 바이브 코딩 개발환경의 현재 상태와 다음 결정을 계속 갱신하는 tracked
계획서다. 과거 계획보다 현재 코드, 테스트, 설정과 canonical 문서를 우선한다.

Last updated: 2026-08-29

## 현재 상태

| 항목 | 상태 | 근거 |
| --- | --- | --- |
| Engineering context | ACCEPTED AND COMMITTED | AGENTS.md, docs/engineering/ENGINEERING_CONTRACT.md, docs/engineering/ARCHITECTURE.md |
| Project CLI | ACCEPTED BASE / COST OPTIMIZATION IN WORKING TREE | fail-fast FULL, separated guard integration |
| Windows invocation guard | ACCEPTED AND COMMITTED | docs/engineering/PROJECT_CLI.md, tool/invoke_mosigame.ps1 |
| One implementation Skill | ACCEPTED AND COMMITTED | .agents/skills/mosigame-implement-and-validate |
| Firebase MCP read-only pilot | ACCEPTED — LIMITED USE | docs/operations/FIREBASE_MCP.md |
| Limited validation loop | SIMPLIFICATION IN WORKING TREE | implementation Skill |
| Basic CI | DEFERRED | 현재 팀 규모와 local validation으로 우선 운영 |
| Emulator/integration pilot | DEFERRED — IMPLEMENTATION REVERTED | docs/operations/EMULATOR_PILOT.md |
| Phase 14 Minimal Team Adoption Pack | IMPLEMENTATION IN WORKING TREE / UNVERIFIED | 이 문서와 onboarding 산출물 |
| Advanced team standardization | DEFERRED | 교육 시스템·조직 정책 근거 없음 |

## Phase 14 최소 범위

산출물:

- docs/development/DEVELOPMENT_SETUP.md
- docs/development/AGENT_SETUP.md
- tool/setup_mosigame.ps1
- tool/setup_mosigame.sh
- README.md와 AGENTS.md routing
- Windows 실제 검증 evidence
- macOS 팀원 검증 절차와 USER VERIFICATION REQUIRED 상태

포함하지 않음:

- 시스템 package manager를 통한 무인 설치
- credential, secret, Firebase 로그인 자동화
- deploy 또는 production 접근
- Emulator 자동화 재개
- CI 구현
- 교육 시스템, 복잡한 템플릿과 조직 정책

## 현재 실행 순서

1. Phase 14 repository 산출물을 Windows에서 검증한다.
2. 독립 검토 후 ACCEPT 여부를 결정한다.
3. Mac 팀원이 setup_mosigame.sh를 실제 실행한다.
4. macOS doctor, relevant targeted smoke와 FULL validation evidence를 남긴다.
5. Windows/macOS onboarding 결과를 반영해 문서와 script의 최소 결함만 보정한다.
6. Phase 14를 ACCEPTED AND COMMITTED로 전환한다.
7. 이후 실제 제품의 network/session 및 UI 작업을 우선한다.

Basic CI와 Emulator pilot은 이 순서의 선행 조건이 아니다.

## 현재 CLI 비용 절감 작업

현재 working tree에서는 제품 개발로 빠르게 복귀하기 위해 다음 최소 보정을 진행한다.

- guard 준비시간과 Project CLI startup 예산을 분리
- Project CLI startup 기본 제한을 60초로 설정
- CLI FULL 전체 예산을 13분으로 제한하고 각 단계가 남은 예산만 사용
- final snapshot 2분과 별도로 validation/snapshot process cleanup 최악 시간
  10초씩을 FULL 예산 안에 예약
- FULL validation을 첫 비-PASS에서 중단하되 working-tree snapshot B는 유지
- step timeout 또는 cleanup 미확인 후 snapshot B가 동일해도 mutation evidence를
  신뢰하지 않고 FAIL 처리
- 느린 Windows guard 통합 테스트를 일반 FULL에서 제외
- guard setup을 startup 관찰·보고 시간에서 제외하고, startup deadline을 marker
  수용보다 먼저 판정
- 구현 Skill은 관련 targeted 검사와 최종 FULL 한 번 중심으로 단순화

guard 통합 테스트는 guard 또는 Project CLI process 실행 경계가 바뀔 때만 별도로
실행한다. 전체 15분 제한은 유지하며, 위 변경 검증 후 추가 환경 확장을 중단하고 제품
개발을 우선한다.

## Windows 검증 기록

현재 상태: PENDING

완료 시 다음 evidence를 갱신한다.

- setup audit command와 exit code
- setup prepare가 필요한지 여부
- guarded doctor 결과
- 관련 automated test
- guarded validate --full 결과
- 실행 전후 working-tree 비교와 process 잔류

## macOS 검증 기록

현재 상태:

    USER VERIFICATION REQUIRED

Mac 팀원은 다음을 기록한다.

- macOS와 CPU architecture
- Flutter/Dart, Node/npm, Java, Xcode, CocoaPods 버전
- setup_mosigame.sh audit 및 필요 시 승인된 prepare 결과
- raw doctor exit code
- relevant targeted suite exit code
- raw validate --full exit code
- 실행 전후 Git 상태
- 사람이 수행한 license, SDK 또는 local config 단계

## 확대 조건

다음 evidence가 있을 때만 범위를 확대한다.

- 동일한 onboarding 문제가 두 운영체제에서 반복됨
- 팀원이 수동으로 반복하는 단계가 안전하게 repository-local 자동화 가능함
- CI 부재 때문에 shared branch에서 회귀가 실제 발생함
- Project CLI가 접근할 수 없는 외부 정보가 반복적으로 필요함
- Emulator의 RTDB region과 deterministic identity 문제를 해결할 시간이 확보됨
