# 대기 단축 변경 — 실기기 테스트와 자동 수집

기능 기준: `codex/wait-reduction`의 `ea08181`. 임시 계측은 별도 변경이며 아직 FULL·실기기 예비 검증 전이다. 10/19 선택·첫 제출 연결 보완은 protocol4다.
설계·검토: [계측 계획](../planning/WAIT_REDUCTION_INSTRUMENTATION_PLAN_20261018.md).

## 준비

- 새 계측 Debug APK를 태블릿과 모든 참여 폰에 설치한다. 기본 Debug·Release·Profile은 계측하지 않는다.
- APK 생성은 아래 로컬 명령으로 한다. 기존 lock/의존성을 사용하며 자동 설치하지 않는다.
  출력 폴더의 APK·build-manifest.json·빌드 로그를 함께 보존한다. 빌드 실패 시 옛 APK를 사용하지 않는다.
- 새 빌드 설치 후 앱을 다시 실행한다. `$buildFolder`·`$captureBuildId`·`$captureBuild`도 새 manifest 기준으로 갱신한다. hot reload/restart로 다른 소스로 바꾸지 않는다.
- 태블릿 1대와 폰 A·B 모두 ADB에 연결한다. USB/무선 혼합 가능하며 매회 실제 현재 포트를 사용한다.
- 시험 날짜, 각 기기의 모델/OS/앱 버전과 연결 방식, 인터넷 조건, 특이사항을 기록한다.
  폴더 생성 시각은 버튼 시각이 아니다. 영상은 화면 이상 확인용 선택 자료다.

```powershell
Set-Location C:\Users\USER\.codex\worktrees\wait-reduction\project00
$capturePython = 'C:\Users\USER\.pyenv\pyenv-win\versions\3.13.11\python.exe'
$captureAdb = 'C:\Users\USER\AppData\Local\Android\Sdk\platform-tools\adb.exe'
& $capturePython tool/startup_measurements/build_debug.py
# 출력 폴더의 app-debug.apk를 모든 기기에 설치한 뒤:
$buildFolder = Read-Host '출력된 빌드 폴더의 전체 경로'
$buildManifest = Get-Content (Join-Path $buildFolder 'build-manifest.json') -Raw | ConvertFrom-Json
$captureBuildId = $buildManifest.build_id
$captureApk = Join-Path $buildFolder 'app-debug.apk'
& $captureAdb devices
$tabletId = Read-Host '태블릿 ID'
$phoneAId = Read-Host '폰 A ID'
$phoneBId = Read-Host '폰 B ID (무선이면 포트 포함)'
$captureDevices = @('--device', "tablet=$tabletId", '--device', "phone_A=$phoneAId", '--device', "phone_B=$phoneBId")
$captureBuild = @('--build-id', $captureBuildId, '--apk', $captureApk)
```

## 예비 수집 — 경로별 1회

한 명령에 해당 동작을 한 번만 수행한다. `COLLECTING: all devices armed` 이전에는 누르지 않는다.
종료는 수집기 터미널의 Ctrl+C이며 앱을 닫지 않는다. 모든 기기의 stop/drain·시계를 회수한 뒤 끝난다.

| 경로 | 수집 전 준비 | 안내 후 동작 |
| --- | --- | --- |
| 최초 시작 | 자리 배치에서 설정 완료 누르기 전 | 설정 완료 1회 |
| 메뉴 재시작 | 메뉴의 재시작 버튼이 보이는 상태 | 재시작 1회 |
| 결과 재시작 | 실제 결과 화면 | 다시하기 1회 |
| 초기화 | 태블릿 방에 모든 폰 참가, 로비 대기 | 초기화 확인 1회 |

```powershell
& $capturePython tool/startup_measurements/collect.py --adb $captureAdb @captureDevices @captureBuild --scenario initial_start --duration 180 --pilot
```
```powershell
& $capturePython tool/startup_measurements/collect.py --adb $captureAdb @captureDevices @captureBuild --scenario menu_restart --condition repeated --duration 180 --pilot
```
```powershell
& $capturePython tool/startup_measurements/collect.py --adb $captureAdb @captureDevices @captureBuild --scenario result_restart --condition repeated --duration 180 --pilot
```
```powershell
& $capturePython tool/startup_measurements/collect.py --adb $captureAdb @captureDevices @captureBuild --scenario room_reset --condition repeated --duration 180 --pilot
```

시작·재시작: 태블릿과 각 폰 카드팩을 한 번씩 공개하고, **실제 선공 폰에서 카드 선택 → 위로 드래그 제출 성공**까지 확인한다.
선공은 임의 지정하지 않는다. 카드 공개 연출이 끝난 뒤 손패를 선택하고 **첫 제출의 성공까지** 확인한다.
`PROGRESS`는 COLLECTING(수집 중·최종 판정 전)이다. input_validation의 selection_seen/submission_seen/submission_succeeded가
모두 true인지 확인한 뒤 종료한다. 마지막 기록·시계 품질·최종 통과는 종료 뒤 summary에서 확인한다.
선택 탭/드래그의 실제 상태 변경을 기록하고 같은 선택 번호→첫 제출 번호→성공 결과를 연결한다.
이후 차례의 선택이나 재시도 성공으로 첫 제출 검증을 대신하지 않는다. 첫 제출이 실패/기록 누락이면 그 수집을 보존하고 종료한다.
측정 종료는 태블릿·선공 폰 입력 준비이며 이후 실제 선택·제출 시간은 제외한다. 카드팩 공개만으로 검증 완료가 아니다.

초기화: 태블릿과 폰 모두 이전 방에서 빠져나왔는지 확인한다. 같은 수집을 유지하며 새 방을 만들고 모든 폰이 참가한다.
참가 상태가 안정된 뒤 **35초 이상** 기다리고 종료한다(판정은 시계 오차를 포함해 최소 30초 보장 여부).
이 수집 안에서 게임을 시작하지 않는다. 새 방 게임 시작은 다음 별도 initial_start 수집으로 확인한다.
초기화 지표는 로컬 방 정리 관측이며 화면 프레임·실제 입력 가능 완료를 측정한 것으로 쓰지 않는다.

## 판정과 본시험

- 예비 통과는 저장된 `summary.json`의 `pilot_passed=true`다. `COLLECTED`는 종료·파일 저장 상태이지 동작/측정 통과가 아니다.
- 전체/사용자 단독 대기 제외 추정 범위 폭은 시작 경로에서 각각 250ms 이하. 초기화는 전체 정리 범위와 별도 새 방 관찰을 검사한다.
- 시작의 조회 완료·전환 사건, 초기화의 종료 의도·서버 요청·세대별 기기 정리·옛 접속 취소 결과를 검사한다.
  취소 pending이면 초기화 성공 화면과 별개로 증거 미완료이며 통과시키지 않는다. 실패 로그도 보존한다.
- seq/drop/process/마지막 회수 검사는 기록된 사건의 무결성 검사다. 미계측 작업·stop 이후 결과까지 무누락임을 뜻하지 않는다.
- 무선 지연은 시계 교환 추정 폭에 반영된다. 기준 초과면 게임 속도 문제로 단정하지 말고 수집 연결/예비 로그부터 점검한다.
- 이전 protocol2·3 APK는 거절된다. 앱 변경 때문에 세 기기 모두 새 protocol4 APK를 재설치한다. 빌드 표식과 APK 해시를 보존하지만 PC 소스 해시만으로 설치 APK 동일성을 증명하지 않는다.
- 예비 통과 후 같은 명령에서 `--pilot`만 빼 본시험: 최초 5회, 메뉴/결과 각 2회, 초기화·새 방 각 5회.
  본시험도 실제 선택·제출 검증과 새 방 관찰은 유지하고 summary를 확인한다. 실패 시도를 삭제하거나 정상 회차로 바꾸지 않는다.

## 범위와 회귀

정상 시작·재시작·초기화·새 방이 본 시험이다. 지연/실패/늦은 완료는 자동 주입 회귀에서 검증한다.
**인터넷 강제 단절은 선택적인 기존 동작 회귀이며 본 시험의 필수 항목이 아니다.** 진행하면 단절 시각·복구·최종 결과를 별도 기록한다.
다른 게임과 지원 이전 버전 혼합은 준비 가능한 구성에서 기능 회귀로 분리한다. LP 전용 시간 분석·pilot를 그대로 적용하지 않는다.
기기가 없거나 이전 APK가 준비되지 않으면 미실행으로 남기고 전체 호환 통과로 표현하지 않는다.

## 보존·제거

매회 항목/회차/수집 폴더/특이사항을 기록하고 APK·manifest·events·summary·integrity를 보존한다.
최종 계측 커밋만 revert할 때 기능 커밋 `ea08181`의 두 변경을 유지하는지 확인한다.
제거 후 관련 검증과 최종 배포 모드 앱의 정상 시작·초기화·새 방을 실기기에서 간단히 재확인한다.
현재는 커밋·제거·기기 설치·실기기 시험을 수행하지 않았다.


## 2026-10-19 보완과 예비 재확인

[보완 계획·검토](../planning/WAIT_REDUCTION_INPUT_VALIDATION_FIX_20261019.md).
기존 `debug-game-start-20261019-002440-a6286307`은 파일/시간 자료를 보존하되 첫 선택→첫 제출의 예비 증거는 확정하지 않는다.
새 protocol4 APK를 세 기기에 설치한 뒤 최초 시작 예비 1회부터 확인한다. 실제 선택·제출을 반복하며 true로 만들지 않는다.
예비 기준은 최종 pilot_passed와 input_validation_details의 PASSED이며 250ms 기준을 유지한다.
실기기 실제 수신/콘솔 갱신 지연량을 새로 측정한 것으로 표현하지 않는다.


## 2026-10-19 본 시험 종료·기록 보존

실기기 LP 본 수집은 사용자가 마지막에 지정한 최초/메뉴/결과/초기화 각5건이다. 원본 판정 19/20, 결과1건은 첫 제출 후 다음 라운드 중복 기록으로 최초 구간만 별도 복원했다. G1은 생략, V1은 보류한다. [평가 보고서](../planning/evidence/wait-reduction-device-20261019/REPORT.md)와 부록에 원본/파생·영상 관측·미검증 범위를 구분했다. 이 브랜치 계측 코드는 기록 보존용이며 통합 브랜치에 포함하지 않는다. APK·대량 로그·영상은 Git에 넣지 않고 별도 로컬 백업 manifest로 보존한다. 계측 없는 최종 앱의 간단한 실기기 확인은 남아 있다.
