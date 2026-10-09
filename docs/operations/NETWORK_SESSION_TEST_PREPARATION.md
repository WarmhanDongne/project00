# 네트워크·세션 실기기 테스트 설치·배포 준비

2026-10-09. [기기 조작 목록](NETWORK_SESSION_REAL_DEVICE_TEST.md)과
[담당자 서버·진단 후속](NETWORK_SESSION_SERVER_FOLLOWUP.md)을 함께 사용한다.

## 지금 준비된 것과 아직 필요한 것

제품 코드·회귀 테스트는 `codex/e01-validation-wiring`에 이미 커밋·푸시됐다.
`codex/e13-emulator-ci`에도 같은 제품 수정이 반영돼 있다. 에뮬레이터 설정·실행 도구·CI
변경은 테스트 브랜치에만 있다. 로컬 FULL과 실제 backend/canonical FULL CI는 PASS다.
상세 SHA·명령·결과는 [E13 기록](../planning/NETWORK_SESSION_E13_BACKEND_CI.md)을 따른다.

**이번 채팅에서는 Cloud Functions·RTDB rules를 배포하지 않았다.**
원격 배포 버전도 조회하지 않았으므로 원격 서버가 최신인지 여부는 아직 모른다.
현재 앱은 `DefaultFirebaseOptions`의 기존 `project0000-ec01e`에 연결한다.
CI의 demo 에뮬레이터로 자동 연결되지 않는다. 새 APK 설치만으로 서버 변경이 반영되지는 않는다.
이 문서의 배포 명령은 다음 작업을 위한 절차이며 현재 실행 승인이 아니다.

실기기 테스트 전 순서는 **테스트 환경 결정 → 서버·rules·게임 이용 준비 → 동일 앱 빌드·설치 → 기기 테스트**다.
기본 기기는 태블릿 1대·휴대폰 2대다. 파이널콜·마피아를 확인할 때만 휴대폰 4대를 모은다.
Android/iOS 조합과 별도 테스트 Firebase 프로젝트 사용 가능 여부는 아직 확인되지 않았다.

## 먼저 결정할 테스트 환경

| 선택 | 필요한 준비 | 현재 상태 |
| --- | --- | --- |
| 별도 Firebase 테스트 프로젝트 | 해당 프로젝트의 Android/iOS 앱 등록·생성 설정, Auth 제공자·프로필/온보딩, Functions·rules, 게임 목록·이용 권한·홀덤 파일 준비. 테스트용 checkout에서 생성 도구로 설정 분리 | 프로젝트 사용 가능 여부 미확인. 현재 코드에는 프로젝트 전환용 flavor/define이 없음 |
| 기존 Firebase 프로젝트의 테스트 계정·새 그룹 | 기존 앱 설정 사용. 배포 전 구버전 앱·진행 방·기존 데이터와의 호환 및 제거된 함수 처리 계획 승인 | 운영 환경 접근·배포 승인 및 배포 상태 확인 미실행 |
| PC의 Firebase 에뮬레이터 + 실기기 | 테스트 브랜치에 FlutterFire debug 연결, 기기가 접근할 LAN 주소·지속 실행·Auth/게임 fixture 준비. Android VM은 필요 없음 | backend CI만 준비됨. 현재 runner는 loopback/demo·일회성 검증용이라 실기기가 바로 접속할 수 없음 |

별도 프로젝트 사용 시 `--dart-define`에 프로젝트 ID만 넣거나 `.firebaserc`만 바꿔서 앱이
전환된다고 생각하면 안 된다. 앱의 생성 Firebase 설정·native 등록까지 일치시켜야 한다.
기존 생성 파일을 수동 편집하거나 운영 설정을 덮어쓰지 않는다. 위 환경 변경은 별도 작업으로 준비한다.

## 개발 PC에서 앱 준비

기존 checkout에 개인 변경이 있다면 그대로 보존하고 충돌 없이 업데이트한다.
아래는 **clean checkout, 기존 프로젝트 설정을 사용하기로 결정한 경우**의 PowerShell 예시다.
테스트 서버용 설정을 따로 준비했다면 그 checkout에서 실행한다.

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
개발용 실행을 쓰면 USB 디버깅 허용 후 `flutter devices`의 기기를 골라
`flutter run --debug -d <DEVICE_ID> --no-pub`로 실행한다.
([Flutter CLI](https://docs.flutter.dev/reference/flutter-cli),
[APK 빌드](https://docs.flutter.dev/deployment/android#build-an-apk)).

### iPhone/iPad 기기

Mac의 같은 브랜치·SDK에서 `flutter pub get --enforce-lockfile` 후 Xcode 서명·개발자 모드·
기기 신뢰를 준비하고 `flutter devices`, `flutter run --debug -d <DEVICE_ID> --no-pub`를 사용한다.
Windows에서 iOS 설치 결과를 만들었다고 보고하지 않는다.
([실제 iOS 기기 준비](https://docs.flutter.dev/platform-integration/ios/setup#deploy-to-a-physical-ios-device)).

### 로그인·게임 이용 준비

- 기기마다 별도 테스트 계정으로 로그인하고 온보딩을 마친다. 실제 결제·회원 탈퇴는 필요 없다.
- 선택한 환경에서 네 게임의 목록/이용 권한을 담당자가 준비한다. 홀덤은 다운로드형 게임이므로
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
10개를 제외한 **69개**다. 방/게임/공용 함수가 공통 변경을 사용하므로 마지막 결함 수정 파일만
배포하는 것으로 전체 후보를 테스트했다고 볼 수 없다. 인증 10개의 신규 변경은 이번 범위에 없다.
빈 테스트 프로젝트에서는 69개만 배포해도 로그인/온보딩이 완성되지 않으므로 기존 인증 baseline과
Firestore/Storage rules·기타 초기 데이터를 별도로 준비해야 한다.

기존 환경에 반영할 항목은 **대상 69 Functions + `database.rules.json`**이다.
현재 후보에서 Firestore/Storage rules는 변경되지 않았다. 기존 환경에 이 이유로 Hosting이나
나머지 서비스를 일괄 배포하지 않는다. RTDB는 해당 database instance와 지역도 확인한다.
RTDB trigger는 asia-southeast1, callable/schedule은 asia-northeast3다.
CI runtime의 trigger 지역 변환은 에뮬레이터 전용이며 실제 배포 설정이 아니다.

아래 세 기존 export는 현재 후보에서 없어졌다. 원격에 남아 있는지, 구버전 앱/데이터가 쓰는지
확인하고 유지·폐기 순서를 정해야 한다. 이 문서대로 자동 삭제하지 않는다.

- `cleanupDeletedRoomCreationRequest`
- `game_common_interruption_vote_to_continue`
- `game_common_interruption_finish_now`

승인 후 Functions는 최대 10개씩 선택 배포한다
([Firebase 권장](https://firebase.google.com/docs/functions/manage-functions)).
먼저 아래 명령으로 **7묶음의 이름만 출력해 검토**한다. 서버에 접근하지 않는다.

```powershell
$functionTargets = Get-Content docs/operations/NETWORK_SESSION_FUNCTION_TARGETS.json -Raw | ConvertFrom-Json
$functionNames = @($functionTargets.functions)
for ($batchStart = 0; $batchStart -lt $functionNames.Count; $batchStart += 10) {
    $batchEnd = [Math]::Min($batchStart + 9, $functionNames.Count - 1)
    ($functionNames[$batchStart..$batchEnd] | ForEach-Object { 'functions:' + $_ }) -join ','
}
```

배포 대상·호환 계획 승인 후 담당자가 한 묶음씩 실행하고 실패하면 멈춘다.
RTDB rules 배포와 앱 배포 순서는 구버전 공존 계획에서 확정한다. 현재 예시는 실행 순서 승인이 아니다.

```text
.\functions\node_modules\.bin\firebase.cmd deploy --only <REVIEWED_FUNCTION_BATCH> --project <APPROVED_PROJECT>
.\functions\node_modules\.bin\firebase.cmd deploy --only database --project <APPROVED_PROJECT>
```

위 예시는 Windows 경로다. macOS에서는 `./functions/node_modules/.bin/firebase`를 사용한다.
`functions` 전체나 `--force`를 쓰지 않는다. 기존 함수 삭제·migration은 별도 승인이다.
서비스별 배포는 [Firebase partial deploy](https://firebase.google.com/docs/cli#partial_deploys)를 따른다.
배포 결과와 실제 schedule/trigger 동작은 [서버 후속](NETWORK_SESSION_SERVER_FOLLOWUP.md)에 남긴다.

## 실기기 테스트를 시작할 수 있는 조건

- [ ] 대상 환경과 OS 조합이 정해졌다.
- [ ] 담당자가 해당 환경의 Functions·RTDB rules 버전과 호환 계획을 확인했다.
- [ ] 태블릿·휴대폰에 같은 후보의 앱을 설치했다.
- [ ] 각 기기 로그인·게임 이용/홀덤 다운로드가 준비됐고 새 그룹에서 정상 시작한다.

현재 위 환경 준비·앱 빌드/설치·배포·실기기 확인은 미실행이다.
준비가 끝나면 [기기 조작 목록](NETWORK_SESSION_REAL_DEVICE_TEST.md)만 따라 하면 된다.

## 이번 문서 작업에서 실제 확인한 것

`npm --prefix functions run catalog:holdem:dry-run`과
`npm --prefix functions run assets:holdem:dry-run`은 각각 PASS/exit 0이다.
목록 제안과 v2 로컬 파일 5개 검증만 했으며 실제 등록·업로드는 하지 않았다.
TypeScript AST로 79 export 중 인증 제외 69개 목록 일치, 새 문서의 local 링크 12개,
PowerShell 예시 4개 구문과 선택 배포 크기 10/10/10/10/10/10/9를 확인했다.
앱 준비/배포 명령은 실행하지 않았다. 코드 변경이 없는 문서 작업이므로 FULL을 재실행하지 않았다.
