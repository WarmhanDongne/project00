# Mosigame 개발환경 설정

이 문서는 새 팀원과 기존 개발자가 Mosigame 저장소를 같은 기준으로 준비하고
검증하기 위한 사람용 안내서다. 목표는 모든 것을 무인 설치하는 것이 아니라,
저장소가 안전하게 자동화할 수 있는 작업은 반복 가능하게 실행하고 운영체제 설치,
라이선스, 계정과 secret처럼 사람의 판단이 필요한 지점에서는 정확히 멈추는 것이다.

## 왜 이 환경을 만들었나

Mosigame은 Flutter 앱과 Node.js Firebase Functions를 함께 관리한다. 사람과 Codex가
서로 다른 명령이나 완료 기준을 사용하면 로컬에서는 통과하지만 다른 환경에서는
실패하거나, 기존 working tree를 덮어쓸 위험이 있다. 따라서 역할을 세 부분으로
나눈다.

1. setup script는 도구와 설정을 점검하고 repository-local dependency만 준비한다.
2. Project CLI doctor는 공통 환경 상태를 판정한다.
3. Project CLI targeted/FULL validation은 코드의 완료 여부를 판정한다.

## 지원 범위

| 환경 | 지원 상태 | 공식 진입점 |
| --- | --- | --- |
| Windows | 실제 검증 대상 | tool/setup_mosigame.ps1 및 Windows guard |
| macOS | 지원 설계 완료, 팀원 실기기 검증 필요 | tool/setup_mosigame.sh 및 raw Project CLI |
| Linux | Project CLI raw 실행만 지원 | setup script 지원 대상 아님 |

macOS setup entry는 저장소에 포함되지만 이 Windows 작업에서 실행할 수 없었다.
macOS 결과는 팀원이 실제로 실행하기 전까지 USER VERIFICATION REQUIRED다.

## 필요한 도구와 기준

- Git
- Flutter stable 3.44.8, Dart 3.12.2 기준
- Node.js major 22: 저장소 .nvmrc와 Functions engines의 공통 계약
- npm과 functions/package-lock.json
- Java 17 이상: Android 빌드 target은 JVM 17
- macOS iOS 개발 시 Xcode, CocoaPods, Xcode license
- Android 개발 시 Android SDK와 ADB

Flutter patch 버전을 영구 고정한 것은 아니다. pubspec.yaml의 Dart SDK 제약,
.nvmrc, Android/iOS project 설정과 Project CLI doctor가 현재 source of truth다.
버전 기준을 바꾸면 이 문서와 계획 문서도 함께 갱신한다.

## 기존 개발자의 적용 방법

1. 작업 중인 변경을 commit하라는 뜻이 아니라 현재 Git 상태를 먼저 기록한다.
2. 최신 branch를 가져오는 작업은 본인이 충돌 가능성을 확인한 뒤 수행한다.
3. Codex에서 `docs/development/AGENT_SETUP.md` 실행을 요청하거나 OS별 setup entry를
   직접 실행한다.
4. 환경이 이미 준비돼 있으면 dependency를 다시 설치하지 않고 audit만 수행한다.

Windows:

    powershell -ExecutionPolicy Bypass -File .\tool\setup_mosigame.ps1

macOS:

    bash ./tool/setup_mosigame.sh

## 신규 개발자의 최초 설정

시스템 도구 설치는 각 도구의 공식 설치 절차를 사용해 사람이 완료한다. setup
script는 관리자 권한 설치, package manager 설치, 라이선스 동의 또는 보안 설정
변경을 수행하지 않는다.

1. Git, Flutter, Node 22, npm과 필요한 플랫폼 SDK를 설치한다.
2. 저장소를 clone하고 repository root로 이동한다.
3. 플랫폼 Firebase 설정 파일이 tracked 상태로 존재하는지 확인한다.
4. repository dependency 준비를 명시적으로 요청한다.

Windows:

    powershell -ExecutionPolicy Bypass -File .\tool\setup_mosigame.ps1 -Prepare

macOS:

    bash ./tool/setup_mosigame.sh --prepare

Prepare는 flutter pub get과 functions 디렉터리의 npm ci만 실행한다. 실행 전후 Git
상태가 달라지면 스크립트는 성공으로 보고하지 않으며 파일을 자동 복원하지 않는다.

## Project CLI 사용법

Windows의 자동화와 완료 검증은 process-tree cleanup과 timeout을 보장하는 guard를
사용한다.

    .\tool\invoke_mosigame.ps1 doctor
    .\tool\invoke_mosigame.ps1 test session
    .\tool\invoke_mosigame.ps1 test auth
    .\tool\invoke_mosigame.ps1 validate --full

macOS에서는 raw Project CLI가 공식 경로다.

    dart run :mosigame doctor
    dart run :mosigame test session
    dart run :mosigame test auth
    dart run :mosigame validate --full

세부 timeout과 exit code는 `docs/engineering/PROJECT_CLI.md`를 따른다.

## Targeted와 FULL validation

- session 또는 auth targeted suite는 관련 구현 중 빠른 피드백용이다.
- 관련 영역만 선택하며 두 suite를 습관적으로 모두 실행하지 않는다.
- targeted PASS는 작업 완료가 아니다.
- 최종 구현 후보는 validate --full을 통과해야 한다.
- 문서 전용 작업은 변경 위험에 비례해 검증하되 실행하지 않은 검증을 PASS라고
  기록하지 않는다.

setup entry에서도 선택적으로 실행할 수 있다.

    .\tool\setup_mosigame.ps1 -Targeted session -Full
    bash ./tool/setup_mosigame.sh --targeted session --full

## Local config와 secret

현재 다음 Firebase 앱 설정은 tracked repository config다.

- android/app/google-services.json
- ios/Runner/GoogleService-Info.plist
- lib/firebase/firebase_options.dart
- .firebaserc와 firebase.json

.env.example은 local override 형식의 예시이고 .env.dev는 Git ignore 대상이다. 현재
애플리케이션 코드가 .env.dev를 필수 입력으로 읽지는 않으므로 setup script도 자동
생성하거나 값을 요구하지 않는다. 향후 실제 소비 코드가 생기면 예시 키만 문서화하고
각 팀원이 local 파일에 값을 입력한다.

secret, production credential, Firebase 로그인과 계정 선택은 자동 생성하거나
덮어쓰지 않는다. Firebase MCP의 제한된 읽기 절차는
`docs/operations/FIREBASE_MCP.md`를 별도로 따른다.

## 흔한 문제

- Node major mismatch: nvm use로 .nvmrc의 Node 22를 선택한다.
- Functions dependencies incomplete: 승인 후 Prepare를 실행하거나 functions에서
  npm ci를 실행한다.
- Flutter not on PATH: Flutter stable bin을 현재 shell PATH에 추가하고 새 shell에서
  다시 실행한다.
- Windows startup-timeout: SDK 파일이나 ACL을 수정하지 말고
  `docs/engineering/PROJECT_CLI.md`의 guard troubleshooting을 따른다.
- Xcode 또는 CocoaPods 누락: Mac 팀원이 공식 설치와 license 동의를 완료한 뒤 다시
  setup entry를 실행한다.
- Android SDK/ADB 누락: 공식 Android 도구로 SDK를 설치하고 환경 변수를 설정한다.
- setup 뒤 Git 상태 변화: 자동 restore하지 말고 diff를 검토해 dependency resolution
  결과인지 기존 변경인지 먼저 판단한다.
- Emulator multi-device 자동화: 현재 보류 상태다.
  `docs/operations/EMULATOR_PILOT.md`를 참고하고 사용자 승인 없이 재개하지 않는다.

## AI가 자동화하지 않는 작업

- 관리자 권한이 필요한 시스템 설치
- Xcode 또는 Android SDK license 동의
- production credential 발급이나 Firebase 운영 계정 로그인
- secret 값 입력
- 기존 설정, source 또는 working-tree 변경 덮어쓰기
- OS 보안 설정, SDK cache ACL 변경
- deploy, migration 또는 production 데이터 접근

이 경우 결과는 READY가 아니라 다음처럼 끝나야 한다.

    BLOCKED — 사용자 작업 필요

    필요한 작업:
    1. 사람이 필요한 설치, license 또는 local secret 단계를 완료한다.
    2. 같은 setup entry를 다시 실행한다.

모든 요청된 단계가 통과하고 Git 상태가 보존됐을 때만 다음을 사용한다.

    READY — MOSIGAME DEVELOPMENT ENVIRONMENT
