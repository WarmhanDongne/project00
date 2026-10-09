# 네트워크·세션 실기기 테스트 설치·배포 준비

2026-10-09. [기기 조작 목록](NETWORK_SESSION_REAL_DEVICE_TEST.md)과
[담당자 서버·진단 후속](NETWORK_SESSION_SERVER_FOLLOWUP.md)을 함께 사용한다.

## 지금 준비된 것과 아직 필요한 것

제품 코드·회귀 테스트는 `codex/e01-validation-wiring`에 이미 커밋·푸시됐다.
`codex/e13-emulator-ci`에도 같은 제품 수정이 반영돼 있다. 에뮬레이터 설정·실행 도구·CI
변경은 테스트 브랜치에만 있다. 로컬 FULL과 실제 backend/canonical FULL CI는 PASS다.
상세 SHA·명령·결과는 [E13 기록](../planning/NETWORK_SESSION_E13_BACKEND_CI.md)을 따른다.

2026-10-09 사용자가 **기존 Firebase `project0000-ec01e`에서 변경 사항 전체 배포·테스트,
구버전 앱 호환 불필요**를 확정했다. 태블릿·휴대폰 모두 Android 실기기에 같은 APK를 설치한다.
앱의 `DefaultFirebaseOptions`와 native 설정은 그대로 사용한다. 프로젝트 전환 코드 수정은 없다.
서버 반영 결과는 아래 실행 기록 및 [E13 기록](../planning/NETWORK_SESSION_E13_BACKEND_CI.md)에 남긴다.

실기기 테스트 전 순서는 **서버·rules·게임 이용 준비 → 동일 APK 빌드·설치 → 기기 테스트**다.
기본 기기는 태블릿 1대·휴대폰 2대다. 파이널콜·마피아를 확인할 때만 휴대폰 4대를 모은다.
실기기 설치 안내에는 에뮬레이터·별도 Firebase 프로젝트·iOS 선택지가 없다.
에뮬레이터는 [담당자 진단](NETWORK_SESSION_SERVER_FOLLOWUP.md)에만 사용한다.

## 개발 PC에서 앱 준비

이미 빌드된 `build/app/outputs/flutter-apk/app-debug.apk`를 기기로 옮겨 설치한다면 아래
PC 명령은 다시 실행할 필요 없다. 다음 명령은 본인이 같은 브랜치에서 APK를 재빌드할 때 사용한다.
기존 checkout에 개인 변경이 있다면 그대로 보존하고 충돌 없이 업데이트한다.
아래는 **clean checkout**의 PowerShell 예시다. 기존 프로젝트 설정을 사용한다.

```powershell
Set-Location C:\workspace\git\project00
git status --short
git switch codex/e01-validation-wiring
git pull --ff-only origin codex/e01-validation-wiring
flutter --version
flutter pub get --enforce-lockfile
flutter devices
```

현재 PASS 후보와 맞춘 SDK는 **Flutter 3.47.5 / Dart 3.13.4**다.
root의 `pub get` 한 번으로 workspace package 의존성을 준비한다. 새 dependency 추가는 없다.
`--enforce-lockfile` 오류가 나면 lockfile을 임의로 갱신하지 말고 SDK·checkout부터 맞춘다.
이 옵션은 잠금 파일과 dependency hash의 일치를 요구한다
([Dart 문서](https://dart.dev/tools/pub/cmd/pub-get#enforce-lockfile)).
게임 코드도 포함한 새 앱을 설치해야 한다. 기존 설치 앱에 hot reload만 한 결과를 최종 테스트로 쓰지 않는다.

### Android 기기

```powershell
flutter build apk --debug --no-pub
```

결과 `build/app/outputs/flutter-apk/app-debug.apk` 한 파일을 Android 태블릿·휴대폰에
동일하게 설치한다. USB 또는 파일 전송으로 설치할 수 있다. 기존 테스트 앱은 덮어써서
참가 정보·게임 캐시를 보존한다. 서명 충돌이면 임의로 삭제하지 말고 동일 서명의 테스트 빌드를 준비한다.
직접 설치할 때는 다음 순서로 한다.

1. USB로 기기를 연결해 파일 전송을 선택하고 APK를 기기의 Download 폴더로 복사한다.
2. 기기의 `내 파일`/파일 관리 앱에서 APK를 연다.
3. 필요한 경우 해당 파일 관리 앱의 `출처를 알 수 없는 앱 설치`를 허용한다. OS별 문구는 다를 수 있다.
4. `설치`/`업데이트`를 누르고 앱을 연다. 모든 기기에 동일 APK를 사용한다.
5. 각자 다른 테스트 계정으로 로그인하고 새 그룹에서 테스트한다. 기기에서 pub get은 하지 않는다.

개발용 실행을 쓰면 USB 디버깅 허용 후 `flutter devices`의 기기를 골라
`flutter run --debug -d <DEVICE_ID> --no-pub`로 실행한다.
([Flutter CLI](https://docs.flutter.dev/reference/flutter-cli),
[APK 빌드](https://docs.flutter.dev/deployment/android#build-an-apk)).

### 로그인·게임 이용 준비

- 기기마다 별도 테스트 계정으로 로그인하고 온보딩을 마친다. 실제 결제·회원 탈퇴는 필요 없다.
- 기존 Firebase에서 네 게임의 목록/이용 권한을 준비한다. 홀덤은 다운로드형 게임이므로
  게임 목록만 있어도 실제 Storage의 manifest·v2 이미지가 없으면 시작할 수 없다.
- debug 빌드를 쓰며 대상 환경에서 App Check가 강제된다면 담당자가 debug 기기의 token을
  해당 프로젝트 콘솔에 등록해야 할 수 있다. token을 체크리스트·Git·채팅에 올리지 않는다
  ([Firebase 절차](https://firebase.google.com/docs/app-check/flutter/debug-provider)).
- Google/Apple 로그인을 쓸 경우 해당 native 앱 등록·서명·제공자 설정도 테스트 환경과 맞춘다.
  `.env.dev`를 새로 만들거나 임의 credential을 넣는 작업은 현재 앱 준비에 요구되지 않는다.

## 담당자의 서버 배포 준비

Node 22와 기존 lockfile을 사용한다. 아래는 로컬 준비만 한다.

```powershell
npm ci --prefix functions
npm run lint --prefix functions
npm run build --prefix functions
npm --prefix functions run catalog:holdem:dry-run
npm --prefix functions run assets:holdem:dry-run
```

마지막 두 명령은 홀덤 목록 제안·로컬 이미지 검증만 하며 업로드하지 않는다.
실제 등록/업로드는 대상 환경·쓰기 승인을 정한 뒤 수행한다. 기존 스크립트는 기본값이 운영
프로젝트/Storage bucket이므로 승인된 `GCLOUD_PROJECT`와 **`FIREBASE_STORAGE_BUCKET` 둘 다**
지정해야 한다. 프로젝트 변수만 바꿔서는 bucket이 바뀌지 않는다.

### 기존 서버의 네트워크·세션 변경 반영 범위

[배포 대상 목록](NETWORK_SESSION_FUNCTION_TARGETS.json)은 현재 index export에서 인증
10개를 제외한 **69개**다. 변경 사항 전체 배포 승인은 이 변경 범위 전체에 적용한다.
방/게임/공용 함수가 공통 변경을 사용하므로 마지막 결함 수정 파일만
배포하는 것으로 전체 후보를 테스트했다고 볼 수 없다. 인증 10개의 신규 변경은 이번 범위에 없다.
기존 인증 baseline과 Firebase 앱 등록을 사용한다.

기존 환경에 반영할 항목은 **대상 69 Functions + `database.rules.json`**이다.
현재 후보에서 Firestore/Storage rules는 변경되지 않았다. 기존 환경에 이 이유로 Hosting이나
나머지 서비스를 일괄 배포하지 않는다. RTDB는 해당 database instance와 지역도 확인한다.
RTDB trigger는 asia-southeast1, callable/schedule은 asia-northeast3다.
CI runtime의 trigger 지역 변환은 에뮬레이터 전용이며 실제 배포 설정이 아니다.

아래 세 기존 export는 현재 후보에서 없어졌으며 원격 metadata에서 실제 잔존을 확인했다.
구버전 호환 불필요·전체 변경 반영 결정에 따라 이 세 이름/리전만 지정해 제거한다.

- `cleanupDeletedRoomCreationRequest`
- `game_common_interruption_vote_to_continue`
- `game_common_interruption_finish_now`

Functions는 최대 10개씩 선택 배포한다
([Firebase 권장](https://firebase.google.com/docs/functions/manage-functions)).
먼저 아래 명령으로 **7묶음의 이름만 출력해 검토**한다. 서버에 접근하지 않는다.
신규 `syncRoomCleanupQueue`가 들어 있는 첫 묶음은 `retry:true` 확인을 위해
배포 명령에 `--force`가 추가된다. 배포 대상은 해당 묶음의 이름으로 계속 제한한다.

```powershell
$functionTargets = Get-Content docs/operations/NETWORK_SESSION_FUNCTION_TARGETS.json -Raw | ConvertFrom-Json
$functionNames = @($functionTargets.functions)
for ($batchStart = 0; $batchStart -lt $functionNames.Count; $batchStart += 10) {
    $batchEnd = [Math]::Min($batchStart + 9, $functionNames.Count - 1)
    ($functionNames[$batchStart..$batchEnd] | ForEach-Object { 'functions:' + $_ }) -join ','
}
```

담당자가 한 묶음씩 실행하고 실패하면 멈춘다. Functions·RTDB rules 반영과 제거 대상 정리를
마친 뒤 새 APK로 새 그룹을 만든다. 이전 앱/방의 혼합 상태를 테스트 결과로 사용하지 않는다.

```text
.\functions\node_modules\.bin\firebase.cmd deploy --only <FUNCTION_BATCH> --project project0000-ec01e --non-interactive
.\functions\node_modules\.bin\firebase.cmd deploy --only database --project project0000-ec01e --non-interactive
.\functions\node_modules\.bin\firebase.cmd functions:delete game_common_interruption_vote_to_continue game_common_interruption_finish_now --region asia-northeast3 --project project0000-ec01e --force
.\functions\node_modules\.bin\firebase.cmd functions:delete cleanupDeletedRoomCreationRequest --region asia-southeast1 --project project0000-ec01e --force
```

위 예시는 Windows 경로다. macOS에서는 `./functions/node_modules/.bin/firebase`를 사용한다.
전체 서비스 일괄 배포나 일괄 함수 삭제를 하지 않는다. 삭제의 `--force`는 위 승인된 3개
이름/리전의 확인 프롬프트에만 사용한다. 기존 방/계정 데이터 migration·삭제는 이번 배포 범위가 아니다.
서비스별 배포는 [Firebase partial deploy](https://firebase.google.com/docs/cli#partial_deploys)를 따른다.
배포 결과와 실제 schedule/trigger 동작은 [서버 후속](NETWORK_SESSION_SERVER_FOLLOWUP.md)에 남긴다.

## 실기기 테스트를 시작할 수 있는 조건

- [x] 기존 Firebase·Android 실기기 APK·구버전 호환 불필요 기준이 정해졌다.
- [x] 담당자가 Functions·RTDB rules 반영과 제거된 함수 정리를 마쳤다.
- [ ] 태블릿·휴대폰에 같은 후보의 앱을 설치했다.
- [ ] 각 기기 로그인·게임 이용/홀덤 다운로드가 준비됐고 새 그룹에서 정상 시작한다.

서버 반영·APK 빌드는 완료했다. 아래에 실제 결과를 기록한다.
기기 설치·실기기 확인은 사용자가 수행한다. 준비가 끝나면
[기기 조작 목록](NETWORK_SESSION_REAL_DEVICE_TEST.md)만 따라 하면 된다.

## 이번 문서 작업에서 실제 확인한 것

`npm --prefix functions run catalog:holdem:dry-run`과
`npm --prefix functions run assets:holdem:dry-run`은 각각 PASS/exit 0이다.
목록 제안과 v2 로컬 파일 5개 검증만 했으며 실제 등록·업로드는 하지 않았다.
TypeScript AST로 79 export 중 인증 제외 69개 목록 일치, 새 문서의 local 링크 12개,
PowerShell 예시 4개 구문과 선택 배포 크기 10/10/10/10/10/10/9를 확인했다.
앱 준비/배포 명령은 실행하지 않았다. 코드 변경이 없는 문서 작업이므로 FULL을 재실행하지 않았다.

## 2026-10-09 환경 확정 후 실행

위 문서 작성 당시의 미실행 기록은 당시 근거다. 후속 사용자 결정으로 기존 프로젝트에
전체 변경 배포를 진행한다. Functions lint·build는 PASS/exit 0, root
`flutter pub get --enforce-lockfile`과 `flutter build apk --debug --no-pub`도 PASS/exit 0이다.
APK 경로는 `build/app/outputs/flutter-apk/app-debug.apk`, 크기 239409237 bytes,
SHA-256 `f62881911d555aa211c9fa5ea9f89af9792b14496d6893c32bd352266e9d81b1`이다.
앱 코드 후보는 `7bc3d31`과 동일하며 이후 수정은 문서뿐이다. 기기 설치는 아직 하지 않았다.

최초 Functions 1묶음 실행은 신규 `syncRoomCleanupQueue`의 `retry:true` 확인 때문에
비대화식 CLI가 FAIL/exit 1로 중단했다. 함수 배포 성공으로 세지 않는다.
선택한 첫 묶음에만 `--force`를 추가해 이 검증된 설정의 확인을 처리한다.
이는 전체 함수 강제 삭제 옵션으로 사용하지 않으며 배포 이름은 목록의 69개로 제한한다.
나머지 묶음에는 해당 옵션을 사용하지 않았다.

최종 배포는 **PASS/exit 0**이다. 이름을 지정한 7묶음(10/10/10/10/10/10/9)에서 69개
Functions를 모두 반영했다. `deploy --only database --project project0000-ec01e`도 PASS/exit 0,
위 3개 제거 함수의 리전별 삭제도 각각 PASS/exit 0이다.
마지막 `functions:list`는 현재 79 export와 원격 목록이 정확히 일치하고 전부 ACTIVE·Node 22,
5개 RTDB trigger는 asia-southeast1·나머지는 asia-northeast3임을 확인했다.
새 queue trigger의 retry 설정과 제거된 세 함수의 부재도 확인했다.

원격 사용자/방 데이터·실행 로그 조회, 기존 데이터 migration·삭제는 하지 않았다.
실제 Scheduler delivery·native 오류 주입·기기 화면 결과는 아직 검증되지 않았다.
이 배포에서 변경 없는 Auth 10개·Firestore/Storage rules·Hosting·게임 목록/에셋은 별도 갱신하지 않았다.
홀덤 파일/이용 권한은 설치 후 정상 시작 항목에서 확인하고, 문제가 있으면 담당자 후속으로 연결한다.
로컬 evidence는 ignored `build/e13-baseline/deployment-final-summary.json`,
`deploy-functions-approved-results.json`, `deploy-server-final-steps.json`,
`deploy-inventory-after.json`, `apk-build-result.json`에 있다. Git에는 정제한 문서 기록만 반영한다.
