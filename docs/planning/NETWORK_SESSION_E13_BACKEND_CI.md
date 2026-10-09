# E13 백엔드 emulator·CI 검증 기록

2026-10-09 사용자 요청으로 [E02~E12 검증 기록](NETWORK_SESSION_E02_E12_IMPLEMENTATION.md)을
읽고 후보 커밋·푸시, 같은 SHA의 CI 브랜치/worktree, 백엔드 우선 검증을 진행했다.
이 문서는 실제 실행 결과와 남은 범위를 구분한다. 현재 상태의 원본은 [TASKS.md](TASKS.md)다.

## 후보 분리

- 시작: `codex/e01-validation-wiring`, HEAD `151eff871e6af36c8cd69d0284ac830b844e2abb`,
  staged 0, tracked 수정 115, untracked 64, 총 179경로.
- 기존 로컬 FULL PASS 후보를 `56cd535c6c4bc815e5dc6448a09a69942b338e7f`로 커밋·푸시했다.
  커밋 전후 179파일의 SHA-256은 모두 같고 원래 working tree는 clean이었다.
- 정확히 같은 SHA에서 managed worktree와 `codex/e13-emulator-ci`를 만들었다.
  에뮬레이터 설정·실행 도구·CI 구성은 이 테스트 브랜치에만 추가한다.
- 제품 수정·회귀는 원래 브랜치의 `76319f5b85e896093ebdd84ecbbad9137e5b916f`로 분리했고
  테스트 브랜치에는 cherry-pick `401c6f494076a809da5892aaa0e18d52a12ce51a`로 반영했다.
  테스트 인프라를 원래 브랜치에 병합하지 않는다.
- CI 전용 인프라는 `9a3ddf2eed9402768f3a3efc791b82e2da4671d6`로 커밋·푸시했다.
  실제 CI 첫 실행을 확인한 뒤 SDK/lockfile 보정을 테스트 브랜치의
  `17ca1f59921d689c83c54b9173070ecdc30b3e3c`로 분리했다.

## 발견한 제품 결함과 회귀

실제 emulator에서 같은 생성 operation을 재전송하면 기존 방이 terminal로 바뀌는 실패를 재현했다.
RTDB `get()`은 transaction의 지속 캐시를 채우지 않는다. 조건부 callback이 초기 null에서
undefined를 반환하면 서버 값을 읽기 전에 중단된다. 예약/slot 완료 표시, mapping CAS,
terminal reconciliation와 queue CAS에 기존 `runPrimedTransaction`을 적용했다.
Mapping 비교는 RTDB 객체의 key 순서와 무관한 기존 canonical fingerprint를 사용한다.

정리 scheduler의 첫 `orderByKey().startAt("")`도 실제 RTDB에서 invalid key로 거절되었다.
첫 페이지는 key 경계 없이 조회하고, 저장된 cursor가 있는 경우에만 `startAt(cursor)`를 적용했다.
public API·persistent shape·state-machine 계약·dependency는 변경하지 않았다.

`functions/test/room-allocation-sdk-cache.test.mjs`의 세 행동 회귀는 수정 전 모두 FAIL/exit 1,
수정 후 3/3 PASS/exit 0이다. cold cache에서 생성 예약·slot 완료/같은 작업 재생,
terminal 정리와 새 mapping 보호, 첫 페이지/저장 cursor를 검증한다.
session manifest와 그 정확한 순서를 검증하는 기존 CLI 회귀에도 연결했다.

## 테스트 브랜치 실행 구조

`firebase.e13.json`과 `tool/emulator/`는 고정 demo project `demo-mosigame-e13`, loopback의
Auth·RTDB·Firestore·Functions만 사용한다. Node 22·Java 21, 기존 npm lockfile을 사용하며
새 dependency는 없다. Android 다중 emulator는 실행하지 않는다. Java heap은 각 512 MiB,
시나리오는 순차 실행한다.

별도 ignored runtime entry는 emulator=true와 정확한 demo project를 확인한 뒤 실제 제품
exports를 로드한다. RTDB 트리거 5개의 discovery region만 us-central1로 바꾼다.
원래 함수 소스와 production `firebase.json`의 asia-southeast1은 유지하며 negative discovery도 검사한다.
Admin·client·rules namespace를 `demo-mosigame-e13-default-rtdb`로 일치시키고
첫 검사에서 실행된 rules와 저장소 rules가 같은지 확인한다.

별도 Node 프로세스의 client는 기존 firebase-admin lockfile에 포함된 RTDB standalone SDK를
Admin mode 없이 사용한다. Auth emulator의 합성 token은 메모리에서만 전달한다.
실제 구독/get/write/onDisconnect와 rules 허용·거절을 검증한다. 이 내부 SDK 진입점 사용은
테스트 브랜치에만 한정한다. token·실제 계정·private payload를 채팅/evidence 요약에 기록하지 않는다.

505개 기존 terminal fixture를 seed하는 짧은 구간만 background dispatch를 억제하고 바로 복원한다.
실제 live trigger와 scheduler assertions는 dispatch가 활성인 상태에서 실행한다.
Scheduler handler는 emulator 데이터에 명시 호출하며 Cloud Scheduler delivery를 검증했다고 주장하지 않는다.

Runner는 source 내용 hash와 Git 상태를 전후 비교하고, 시작 전·종료 후 포트를 확인한다.
10분 emulator deadline과 자신의 child tree/process group 정리만 사용한다.
CI는 같은 Node runner와 canonical FULL workflow를 호출하며 sanitized 결과 JSON을 artifact로 보관한다.

## 실행 evidence

| 실제 command·위치 | status | exit | 범위 |
| --- | --- | ---: | --- |
| `git commit`, `git push --set-upstream origin codex/e01-validation-wiring` | PASS | 0 | 원래 179경로 후보 56cd535, 원격 SHA 일치 |
| `node --test functions/test/room-allocation-sdk-cache.test.mjs` (원래 root, 수정 전) | FAIL | 1 | 3/3 기존 결함 재현 |
| `npm run build --prefix functions` (원래 root, 수정 후) | PASS | 0 | TypeScript |
| `npm run lint --prefix functions` (원래 root) | PASS | 0 | Functions ESLint |
| 같은 회귀 명령 (수정 후) | PASS | 0 | 3/3 |
| `.\tool\invoke_mosigame.ps1 test session --json` (원래 root) | PASS | 0 | manifest 10/8, Flutter·Functions 및 working-tree mutation PASS |
| `flutter test --no-pub test/mosigame_cli/test_suites_test.dart` (원래 root) | PASS | 0 | 기존 CLI 회귀 20개 |
| `node tool/emulator/run.mjs` (CI worktree, 최종 후보) | PASS | 0 | 백엔드 10/10, fail/skipped/cancelled 0, 실제 tests 122705ms |
| runner 전후 source/Git/포트 확인 | PASS | 0 | 1433파일 내용 hash·상태 동일, 관련 7포트 모두 해제 |
| `.\tool\invoke_mosigame.ps1 validate --full --json` (제품 수정 후보 a3fe7fc) | PASS | 0 | 사용자 명시 승인 후 1회, 12단계·root 334·5 package 167·Functions 371, mutation PASS, 322506ms |
| GitHub Actions backend (9a3ddf2) | PASS | 0 | Ubuntu/Node 22/Java 21, 10/10, fail/skipped/cancelled 0, 52906ms, source/포트 PASS |
| GitHub Actions canonical FULL (9a3ddf2) | FAIL | 1 | Flutter 3.44.8의 dart-format 단계에서 중단, 후속 검사 NOT_RUN |
| CI SDK·lockfile·canonical 배선/실패 파일 포맷 검사 (17ca1f5) | PASS | 0 | 로컬 Flutter 3.47.5/Dart 3.13.4와 일치, enforce-lockfile 준비 후 source/lockfile 동일 |
| 보정된 CI 후보 `git push origin codex/e13-emulator-ci` (17ca1f5) | PASS | 0 | 후속 사용자 명시 승인 후 푸시, 로컬/원격 SHA 일치 |
| GitHub Actions backend 재실행 (17ca1f5) | PASS | 0 | 10/10, fail/skipped/cancelled 0, 41710ms, source/포트 PASS |
| GitHub Actions canonical FULL 재실행 (17ca1f5) | PASS | 0 | 12단계·root 334·5 package 65/2/14/55/31·Functions 371, mutation PASS |

승인된 로컬 FULL은 2026-10-09 14:24:57~14:30:28 KST에 원래 브랜치의
`a3fe7fc3b4084e894fcbb3640a3467cc5437d517`에서 실행했다. 모든 step의 timedOut=false,
원래 tree는 실행 전후 staged/unstaged/untracked 0으로 동일했다.
guard startup 6514ms, CLI 322506ms다. 결과/exit/stderr는 ignored
`build/e13-baseline/full-approved.json`·`full-approved-exit.json`·`full-approved-stderr.log`에 남겼다.

[첫 CI 실행 #37888465474](https://github.com/WarmhanDongne/project00/actions/runs/37888465474)은
동일 SHA `9a3ddf2`의 backend 성공과 canonical FULL 실패를 함께 보존한다.
Backend sanitized artifact는 `e13-backend-9a3ddf2eed9402768f3a3efc791b82e2da4671d6`,
artifact ID 11596749727이다. FULL의 기존 Flutter 3.44.8/Dart 3.12.2는 로컬 승인 환경과 달라
dependency 준비에서 lockfile 7항목을 바꾸고 `test/mosigame_cli/invocation_guard_test.dart`의
포맷 검사를 거절했다. 분석/테스트 미실행이며 CI 전체 PASS로 표시하지 않는다.
제품/테스트 source와 lockfile을 바꾸지 않고 테스트 브랜치 workflow만 Flutter 3.47.5와
`flutter pub get --enforce-lockfile`로 보정했다. 관련 YAML·배선 검사와 dependency 준비,
해당 파일 포맷·전후 tree/diff check는 PASS/exit 0이다. 새 후보의 CI FULL은 별도 승인을 요청했다.

후속 사용자 명시 승인으로 `17ca1f59921d689c83c54b9173070ecdc30b3e3c`를 푸시하고
[CI #37890040738](https://github.com/WarmhanDongne/project00/actions/runs/37890040738)을 1회 실행했다.
2026-10-09 14:44:45~14:49:51 KST, workflow와 두 job 모두 success다. 실제 backend command
`node tool/emulator/run.mjs`는 10/10 PASS/exit 0, tests 41710ms, 관련 포트 해제와 내용 snapshot PASS다.
artifact는 `e13-backend-17ca1f59921d689c83c54b9173070ecdc30b3e3c`, ID 11598081275,
digest `sha256:59d3b50a9b03c8eea4e4066c33130888cc16b4143ebb388cf68f9ee93a9ee4f2`다.
`flutter pub get --enforce-lockfile`와 경계 검사 이후 실제 `dart run :mosigame validate --full`은
12 PASS·fail/blocked/invalid 0·exit 0이다. root 334·5 package 167·Functions 371개,
포맷 148파일 변경 0·분석/lint·working-tree mutation PASS를 확인했다.
run/job/step·artifact와 결과 요약은 ignored `build/e13-baseline/ci-approved-summary.json`에 남겼다.

성공한 코드 후보 이후에는 검증 문서만 동기화한다. 최종 기록 커밋에는 `[skip ci]`를 사용해
같은 구현 후보의 FULL을 추가 실행하지 않는다([GitHub 공식 절차](https://docs.github.com/en/actions/how-tos/manage-workflow-runs/skip-workflow-runs)).
최종 tree가 검증된 17ca1f5와 문서 이외에는 같은지 Git diff로 확인한다.
원래 브랜치와 테스트 브랜치의 제품/CLI 소스도 같다. emulator 설정·runner·CI 구성 8경로만
테스트 브랜치에 남기고, 두 tree의 staged/unstaged/untracked 0과 원격 SHA를 확인한다.

초기 emulator 실행들은 FAIL/exit 1이었다. 제품 결함 외에 harness의 초기 준비 보고 누락,
Admin·client·rules namespace 불일치, SDK get/write 권한 오류 표현 차이를 진단·보정했다.
기대 허용/거절·회귀 assertion을 제거하거나 약화하지 않았다. 초기 실패를 PASS evidence로 사용하지 않는다.
Raw SDK 로그는 ignored 로컬 폴더에 두고 CI artifact는 합성 시나리오 이름·status·duration만 담는다.
최종 backend log/exit는 원래 checkout의 ignored `build/e13-baseline/backend-final.log`와
`backend-final-exit.json`, sanitized 결과와 source snapshot은 CI worktree의
`build/e13/backend-result.json`·`run-result.json`에 보관한다. session JSON/exit와 CLI manifest log도
원래 checkout의 `build/e13-baseline/`에 남겼다.

## 범위와 남은 확인

백엔드 시나리오는 V02/V03/V04/V06/V07/V08/V09/V10/V11/V18/V19/V20/V21의 서버·JS SDK
경계를 확인한다. 전체 V00~V22와 FlutterFire/UI 검증을 모두 통과했다는 뜻은 아니다.
V01 앱 초기 복원, V05 Flutter 구독/파싱 오류, V12/V13 예산/lifecycle, V14 auth UI,
V15 assets, V16 안내/route, V17 모든 게임별 역할 조합, V22 계측의 기존 단위/widget evidence는
E02~E12 기록에 있으며 현재 수정 후보의 로컬 FULL과 테스트 브랜치의 canonical FULL CI는 통과했다.
FlutterFire·실제 앱 통합과 기기 확인은 미실행 범위로 남긴다. 요청에 따라 SDK 보정도 테스트
브랜치에만 적용했으므로, 원래 workflow의 Flutter 3.44.8 정렬은 후속 반영 계획에서 검토한다.
E14 OS/물리 네트워크/성능, E15 반영 계획, production 접근·deploy·migration은 미실행이다.

동작/범위의 상세 절차는 테스트 브랜치의 `tool/emulator/README.md`를 따른다.
