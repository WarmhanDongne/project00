# Mosigame agent environment setup

이 문서는 Codex가 기존 working tree를 보존하면서 Mosigame 개발환경을 점검하고
repository-local 준비를 수행하는 실행 계약이다.

팀원 요청 예시:

    저장소의 docs/development/AGENT_SETUP.md를 읽고 현재 개발환경을 점검·설정해줘.
    기존 변경을 보존하고, 승인이나 사용자 입력이 필요한 단계에서는 멈춰서 알려줘.

## 실행 순서

1. OS를 확인한다. Windows와 macOS만 setup entry 지원 대상으로 판정한다.
2. branch, HEAD, upstream, staged, unstaged, untracked 상태를 기록한다.
3. 루트 `AGENTS.md`와 `docs/engineering/ENGINEERING_CONTRACT.md`를 완전히 읽는다.
4. `docs/engineering/PROJECT_CLI.md`와
   `docs/development/DEVELOPMENT_SETUP.md`를 읽는다.
5. 기존 변경과 보호 대상 파일을 식별한다. stash, reset, restore, checkout, 삭제,
   stage 또는 commit하지 않는다.
6. 설치된 Git, Flutter/Dart, Node/npm, Java와 플랫폼 도구를 조사한다. 계정,
   credential, token과 secret 값은 출력하지 않는다.
7. 먼저 Prepare 없이 OS별 setup entry를 실행한다.
8. dependency가 누락된 경우에만 사용자에게 repository-local Prepare 승인을 받는다.
9. 승인 후 Prepare를 실행하고 Git 상태가 바뀌었는지 비교한다. 시스템 package
   manager나 관리자 권한 설치를 실행하지 않는다.
10. tracked Firebase config의 존재만 확인한다. local secret을 읽거나 출력하지 않는다.
11. Windows는 guard, macOS는 raw command로 doctor를 실행한다.
12. 작업 범위가 session 또는 auth라면 관련 targeted suite만 실행한다.
13. 사용자가 환경 완료 검증을 요청했다면 FULL validation을 실행한다.
14. 실행 전후 Git 상태와 exit code를 비교해 READY 또는 BLOCKED를 보고한다.

## OS별 deterministic entry

Windows:

    powershell -ExecutionPolicy Bypass -File .\tool\setup_mosigame.ps1

macOS:

    bash ./tool/setup_mosigame.sh

명시적 승인 뒤 dependency 준비:

    powershell -ExecutionPolicy Bypass -File .\tool\setup_mosigame.ps1 -Prepare
    bash ./tool/setup_mosigame.sh --prepare

선택적 검증:

    powershell -ExecutionPolicy Bypass -File .\tool\setup_mosigame.ps1 -Targeted session -Full
    bash ./tool/setup_mosigame.sh --targeted session --full

setup script가 실패한 뒤 임의의 대체 설치 명령을 추측하지 않는다. 출력된 누락
capability와 `docs/development/DEVELOPMENT_SETUP.md`의 수동 절차를 보고한다.

## 반드시 멈추는 조건

- 관리자 권한 또는 시스템 package 설치가 필요함
- Xcode/Android license 동의가 필요함
- Firebase 로그인, production credential 또는 secret 입력이 필요함
- 기존 local config를 덮어써야 함
- dependency 준비가 pubspec.lock 등 tracked 상태를 바꿈
- 기존 사용자 변경과 충돌함
- production 접근, deploy 또는 migration이 필요함
- 중요한 architecture 또는 제품 결정이 필요함
- Project CLI가 BLOCKED, INTERNAL ERROR 또는 timeout을 반환함

## 결과 형식

성공:

    READY — MOSIGAME DEVELOPMENT ENVIRONMENT
    OS: windows 또는 macos
    Setup: audit 또는 prepare
    Doctor: PASS, exit 0
    Targeted: PASS 또는 NOT RUN
    FULL: PASS 또는 NOT RUN
    Working tree: 기존 상태 보존
    User action: 없음

중단:

    BLOCKED — 사용자 작업 필요
    실패 단계와 실제 exit code:
    보존된 기존 변경:
    수행하지 않은 단계:
    필요한 사용자 작업:
    재실행 명령:

Targeted 또는 FULL을 실행하지 않았다면 NOT RUN이라고 적는다. macOS 절차를 실제
macOS에서 실행하지 않았다면 PASS가 아니라 USER VERIFICATION REQUIRED라고 적는다.
