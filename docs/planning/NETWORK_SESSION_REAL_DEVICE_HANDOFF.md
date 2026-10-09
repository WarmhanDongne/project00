# 네트워크·세션 실기기 테스트·후속 개발 인계

2026-10-09 KST. 사용자가 이 채팅의 테스트·개발을 다른 채팅에서 이어 가도록 요청했다.
이는 기존 작업의 인계다. 이미 성공한 배포/FULL을 처음부터 반복하는 요청이 아니다.
현재 작업 상태의 원본은 [TASKS.md](TASKS.md)다.

## 새 채팅의 첫 행동

1. root `AGENTS.md`, [Engineering Contract](../engineering/ENGINEERING_CONTRACT.md),
   이 문서와 아래 실행 기록을 읽는다. 실제 구현/수정 시에는 repository의
   Mosigame Implement and Validate skill을 적용한다. 인계 확인만으로 FULL을 실행하지 않는다.
2. 원래 checkout의 branch/HEAD·staged/unstaged/untracked 상태를 확인한다. 사용자 변경을
   보존하고 임의 switch/stash/reset/restore를 하지 않는다. CI worktree도 기존 것을 사용한다.
3. 아래 APK가 있으면 hash를 확인한다. 현재 APK를 설치하는 사용자에게 pub get·재빌드·
   재배포를 다시 요구하지 않는다. APK는 ignored 산출물이므로 다른 PC의 clone에는 없다.
4. 사용자의 실제 기기 결과를 받는다. 아직 받은 결과가 없으므로 항목을 PASS로 채우지 않는다.
   먼저 태블릿 1대·휴대폰 2대로 라이어스포커/홀덤의 시작·단절·재실행·정상 종료를 확인한다.
5. 문제를 받은 뒤 재현·회귀 테스트·수정을 진행한다. 기기 결과가 없는데 제품 버그를
   가정하거나 운영 데이터/로그를 광범위하게 조회하지 않는다.

## 사용자가 확정한 기준

- 태블릿 1대, 휴대폰은 평소 2대·최대 4대. 4대를 계속 유지할 수 없으므로 파이널콜·마피아의
  필수 테스트만 추가 기기가 모이는 날 진행한다. 진행 가능한 제외는 그날 3대로 함께 확인한다.
- 태블릿·휴대폰 모두 **실제 Android 기기에 같은 APK를 설치**한다.
- 서버는 기존 Firebase **`project0000-ec01e`**를 사용한다. 별도 프로젝트나 실기기→에뮬레이터
  연결을 기본 설치 경로로 다시 제안하지 않는다.
- 사용자가 **구버전 앱과 호환될 필요 없음, 변경 사항 전체 배포**를 명시했다.
  이 결정에 따른 배포는 이미 완료했다. 추가 변경의 검증/배포는 해당 후보의 범위를 확인한다.
- 사용자의 체크리스트는 구체적인 **내가 할 조작 → 화면에서 확인할 결과**로 유지한다.
  검토 ID·서버 값·로그를 적도록 요구하지 않는다. 서버/진단 작업은 담당자가 별도 관리한다.
- Android 다중 에뮬레이터의 RAM 부족 전력이 있다. PC에서는 필요한 backend 검증을 우선하고
  실제 앱/OS 확인은 실기기를 사용한다.

## 브랜치와 코드 후보

| 역할 | 브랜치·위치 | 인계 문서 추가 전 마지막 푸시 SHA |
| --- | --- | --- |
| 제품 코드/회귀 | `codex/e01-validation-wiring`, 현재 checkout | `e99032796d4ecccc62111fd0694ae27c6e49221e` |
| 에뮬레이터/CI | `codex/e13-emulator-ci`, 기존 managed worktree | `428b8575e51831ec678e60fb3d31a36dbaddb6f7` |

인계 문서 자체는 후속 문서 커밋으로 두 브랜치에 반영된다. 재개 시 최신 HEAD를 확인한다.
제품 후보와 실제 배포/APK의 코드 기준은 `7bc3d317cd67b85c138a38e97ca74d4a5d23b733`과
동일하다. 그 이후는 문서뿐이며 검증된 제품 코드·설정·lockfile의 diff는 0이었다.

로컬 운영 위치를 찾을 때는 `git worktree list`를 사용한다. 이 채팅의 실제 위치는 다음과 같았다.
이 경로는 로컬 산출물 찾기용이며 제품 의도/공식 구현 근거를 대신하지 않는다.

- 원래 checkout: `C:/workspace/git/project00`
- 기존 CI worktree: `C:/Users/USER/.codex/worktrees/e13-emulator-ci/project00`

두 브랜치는 인계 준비 시작 시 clean/원격 SHA 일치였다. 두 브랜치의 차이는 정확히 다음
8개 테스트 인프라 경로뿐이다. 원래 브랜치에 병합하지 않는다.

```text
.github/workflows/emulator-e13.yml
.github/workflows/validate.yml
firebase.e13.json
tool/emulator/README.md
tool/emulator/backend.test.mjs
tool/emulator/client.cjs
tool/emulator/functions.cjs
tool/emulator/run.mjs
```

제품 결함이 발견되면 원래 브랜치에서 **수정+회귀 테스트를 별도 커밋**으로 만들고,
필요하면 같은 커밋을 CI 브랜치에 cherry-pick한다. 테스트 인프라와 제품 수정 커밋을 섞지 않는다.
구체적인 수정 후에는 관련 suite와 skill의 승인된 FULL 절차로 재검증한다.

## 완료된 검증·수정

- 기존 미커밋 FULL PASS 후보를 `56cd535`로 커밋·푸시하고 정확히 같은 SHA에서 CI worktree를 만들었다.
- 실제 RTDB emulator에서 cold transaction cache에 의한 생성 재전송/조건부 정리 실패와
  첫 cursor `startAt("")`의 invalid key를 재현했다.
- 제품 수정/회귀: 원래 `76319f5`, CI cherry-pick `401c6f4`.
  `room-allocation-sdk-cache.test.mjs`는 수정 전 FAIL 0/3·exit 1 → 수정 후 PASS 3/3·exit 0.
- 승인된 로컬 FULL: PASS 12단계·root Flutter 334·5 package 167·Functions 371·mutation PASS.
- 실제 backend emulator: 10/10 PASS. 실제 SDK/rules/onDisconnect/trigger·4게임 흐름·중단/
  barrier·퇴장 재확인·생성/정리 queue를 포함한다. skipped/cancelled 0.
- 성공 CI: [Actions #37890040738](https://github.com/WarmhanDongne/project00/actions/runs/37890040738),
  검증 SHA `17ca1f59921d689c83c54b9173070ecdc30b3e3c`.
  backend 10/10·canonical FULL 12단계 PASS/exit 0. 이후 CI 후보와 비문서 diff 0.
- SDK는 Flutter 3.47.5/Dart 3.13.4, Node 22(최근 실행 22.23.2).
  SDK 3.44.8 차이로 실패한 첫 CI와 테스트 브랜치 SDK/lockfile 보정은 E13 기록에 보존했다.
  원래 workflow의 SDK 정렬은 아직 후속이다.

상세 command·중간 실패·검증 한계는 [E02~E12](NETWORK_SESSION_E02_E12_IMPLEMENTATION.md),
[E13](NETWORK_SESSION_E13_BACKEND_CI.md)에 있다.
E13 전체 FlutterFire/UI, E14 실기기/성능, 출시 판정을 모두 통과한 것은 아니다.

## 기존 Firebase 배포 완료

이번 사용자의 명시 결정 후 다음을 실제 실행했다. 모두 최종 PASS/exit 0이다.

- 변경된 방·게임·복구 **69 Functions**를 10개 이하 7묶음으로 배포.
- `database.rules.json` 배포.
- 제거된 세 함수 삭제:
  `cleanupDeletedRoomCreationRequest`(asia-southeast1),
  `game_common_interruption_vote_to_continue`,
  `game_common_interruption_finish_now`(asia-northeast3).
- 마지막 원격 metadata: 현재 index의 **79 export와 정확히 일치**, 전부 ACTIVE·Node 22,
  RTDB trigger 5개는 asia-southeast1·나머지는 asia-northeast3. queue retry:true 확인.

최초 첫 묶음은 retry policy 확인에서 FAIL/exit 1이었다. 새 queue trigger가 있는 첫 묶음만
이 검증된 설정 확인에 `--force`를 사용해 완료했다. 전체 함수/서비스 강제 배포가 아니었다.
변경 없는 Auth 10개·Firestore/Storage rules·Hosting·게임 목록/에셋은 이 배포에서 갱신하지 않았다.
기존 사용자/방 데이터·실행 로그는 읽지 않았고 migration/계정·방 데이터 삭제도 하지 않았다.

재개 자체를 이유로 배포·삭제를 재실행하지 않는다. 이후 production 접근·새 배포/migration은
Engineering Contract의 범위와 승인을 따르고 Firebase MCP를 쓴다면 read-only pilot 조건을
별도로 충족한다. 이번 배포 완료 기록을 무관한 운영 조회/쓰기의 포괄 승인으로 해석하지 않는다.

## 준비된 APK

```text
로컬 경로: C:/workspace/git/project00/build/app/outputs/flutter-apk/app-debug.apk
형식: debug APK, 기존 Firebase 설정
크기: 239409237 bytes
SHA-256: f62881911d555aa211c9fa5ea9f89af9792b14496d6893c32bd352266e9d81b1
```

`flutter pub get --enforce-lockfile`, `flutter build apk --debug --no-pub` PASS/exit 0.
현재 APK를 모든 기기에 옮겨 설치하면 된다. 직접 재빌드할 때만 PC에서 pub get/빌드가 필요하다.
다른 PC에서 APK가 없으면 위 SDK와 같은 제품 후보로 재빌드하고 새 artifact hash를 기록한다.
기기 설치·로그인·정상 게임 시작·실기기 테스트는 **NOT_RUN**이며 사용자 결과를 기다린다.
서명 충돌이면 사용자에게 기존 앱 데이터 삭제를 바로 지시하지 말고 같은 서명의 빌드를 준비한다.

## 남은 작업과 담당 구분

**사용자:** [실기기 조작 목록](../operations/NETWORK_SESSION_REAL_DEVICE_TEST.md)의 화면 확인.
결과는 게임·기기·직전 조작·증상만 받으면 된다. 정상 시작에서 홀덤 파일/권한 문제도 확인한다.
게임 목록·Storage v2 파일의 원격 상태는 이번 배포에서 따로 조회하지 않았다.

**담당자:** [서버·진단 후속](../operations/NETWORK_SESSION_SERVER_FOLLOWUP.md).
실제 Cloud Scheduler delivery, 실제 배포 trigger/rules의 기기 연동, FlutterFire stream/parse·
공개/private 도착 순서, 정확한 응답 유실, durable/file write 실패, 성능 계측이 남아 있다.
필요한 fault injection은 별도 테스트 브랜치/adapter로 재현하고 새 hook이 구현됐다고 가정하지 않는다.
사용자의 비행기 모드 조작만으로 서버 처리 후 응답 유실·디스크 실패를 검증했다고 단정하지 않는다.

SDK의 connected=true, 서버의 ACTIVE 상태, JS emulator PASS는 실제 앱의 화면 준비 완료/
실기기 통과를 대신하지 않는다. schedule handler를 emulator에서 `.run`으로 호출한 결과도
실제 Cloud Scheduler delivery PASS가 아니다.

## 읽을 문서와 로컬 evidence

- [설치·배포 준비/실행 결과](../operations/NETWORK_SESSION_TEST_PREPARATION.md)
- [현재 네트워크·세션 계약](../engineering/NETWORK_SESSION_CONTRACT.md)
- [Project CLI](../engineering/PROJECT_CLI.md): Windows 검증은 guarded invocation.
- [Cloud Functions](../engineering/CLOUD_FUNCTIONS.md), [작업 관리](TASK_MANAGEMENT.md),
  [월별 기록](logs/2026-10.md), SESSION/TEST 상세와 목록.
- 테스트 브랜치 `tool/emulator/README.md`: loopback/demo 일회성 runner.
  실제 앱에 `use*Emulator` 연결은 없다. 현재 runner로 실기기가 바로 접속할 수 있다고 안내하지 않는다.

같은 PC의 ignored `build/e13-baseline/`에 full-approved, ci-approved-summary,
deployment-final-summary, deploy-functions-approved-results, deploy-server-final-steps,
deploy-inventory-after, apk-build-result, deployment-git-final-summary JSON과 로컬 로그가 있다.
다른 PC에 없을 수 있으며 Git의 정제 기록/CI 결과가 공식 실행 근거다.
credential/token·개인 계정·손패/private payload를 출력하지 않는다.

## 새 채팅용 시작 요청

> `docs/planning/NETWORK_SESSION_REAL_DEVICE_HANDOFF.md`와 Engineering Contract를 읽고
> 기존 네트워크·세션 작업을 이어가줘. 기존 Firebase의 69 Functions/RTDB 규칙 배포와 구형
> 3개 제거, APK 빌드는 이미 끝났으니 반복하지 말아줘. 우선 branch/working tree와 APK를
> 확인하고 내가 실기기 체크리스트 결과를 전달하면 문제를 재현해 회귀 테스트와 수정으로
> 이어가줘. 기본 태블릿 1대·휴대폰 2대, 파이널콜·마피아 필수 항목만 추가 기기 4대로 한다.
> 구버전 앱 호환은 필요 없고 기존 Firebase를 사용한다. 제품 수정/회귀는 원래 브랜치의
> 별도 커밋, emulator/CI 구성은 테스트 브랜치에 유지해줘. 서버·로그 진단은 사용자 조작
> 목록과 분리하고 새 운영 접근/배포나 FULL은 해당 규칙의 승인 절차를 따라줘.
