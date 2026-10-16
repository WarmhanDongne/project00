# 로컬 Firebase 개발환경

로컬/서버 선택은 **앱 실행 옵션**으로 결정한다. 선택을 바꿀 때 앱을 완전히 종료하고
다시 `flutter run`한다. Hot reload/hot restart로 접속 대상을 바꾸지 않는다.
옵션 생략 또는 `server`는 기존 `project0000-ec01e` 서버에 연결한다.
로컬 데이터와 계정은 고정 데모 프로젝트 `demo-mosigame-e13`에만 있다.

## 빠른 시작

Node 22, Java 21 이상, 설치된 Flutter/Dart와 `functions/node_modules`가 필요하다.
Mac에서 nvm을 쓰면 아래처럼 Node를 선택한다. 첫 실행은 에뮬레이터 바이너리와 UI를
다운로드할 수 있다. Firebase 로그인·서비스 계정·새 npm/Dart dependency는 필요 없다.

저장소 루트의 첫 번째 터미널:

```bash
nvm use
node tool/emulator/local.mjs start
```

`LOCAL READY`가 표시되면 두 번째 터미널에서 실행한다.

```bash
# 로컬: iOS 시뮬레이터 / Android 에뮬레이터
flutter run --dart-define=MOSIGAME_BACKEND=local

# 기기가 여러 개면 -d <device-id>를 추가한다.
# 서버: 기존 Firebase 프로젝트로 연결
flutter run --dart-define=MOSIGAME_BACKEND=server
```

관리 화면: <http://127.0.0.1:4000>. 기기 화면이 아니라 인증·데이터·로그 관리 UI다.
서버 모드 실행은 실제 Firebase 접근이다. 자동화 검증은 local 모드에서만 수행한다.

## 테스트 계정과 저장

| 역할 예시 | 이메일 |
| --- | --- |
| 진행용 태블릿 | `tablet@mosigame.test` |
| 참가자 1–4 | `phone1@mosigame.test` … `phone4@mosigame.test` |

공통 **테스트 전용** 비밀번호: `LocalMosigame123!`. 실제 계정에 사용하지 않는다.
이 계정들은 이메일 인증·프로필 설정이 완료된 상태로 준비된다. 게스트 로그인도 가능하다.
로컬 모드의 Google/Apple 버튼은 외부 인증을 시작하지 않고 테스트 계정 사용을 안내한다.

네 게임의 목록·설명·룰은 저장소 카탈로그에서 만든다. 로컬에서는 마피아도 활성화하고
테스트 계정에 마피아 소유권을 부여한다. 운영 게임 목록은 읽거나 복사하지 않는다.
처음 없는 문서만 생성하므로 UI에서 편집한 프로필·카탈로그는 재시작 때 보존된다.

`Ctrl+C`로 종료하면 `build/local-firebase/data/`에 저장하며 다음 `start`에서 불러온다.
강제 종료에서는 마지막 변경이 저장되지 않을 수 있다. 초기 상태로 되돌리려면 먼저
에뮬레이터를 종료한 뒤 이 폴더를 다른 이름으로 옮기고 다시 시작한다.
로그·데이터·생성 런타임은 ignored `build/` 안에만 둔다.

## 연결 구조와 기기

- Auth 9099, RTDB 9000, Firestore 8080, Functions 5001, Storage 9199, UI 4000.
- 서버는 `127.0.0.1`에만 바인딩한다. iOS 시뮬레이터는 `127.0.0.1`, Android
  에뮬레이터는 호스트 컴퓨터 별칭 `10.0.2.2`를 자동 선택한다.
- Android USB 실기기는 각 기기에서 `adb -s <serial> reverse tcp:<port> tcp:<port>`로
  위 다섯 서비스 포트를 연결하고 앱에 `--dart-define=MOSIGAME_EMULATOR_HOST=127.0.0.1`을
  추가한다. 기기의 앱은 debug 빌드여야 한다.
- iOS 실기기 LAN 연결은 이 loopback 기본 구성에 포함되지 않는다. 단순히 Mac IP만
  지정해서는 연결되지 않으며 별도 네트워크 바인딩·접근 범위 설정이 필요하다.
- 같은 포트를 쓰는 E13 자동 테스트와 개발 에뮬레이터는 동시에 실행하지 않는다.

`FirebaseBackend`가 앱·모든 게임의 인증/DB/함수 인스턴스를 선택한다. 로컬은 별도
이름의 Firebase 앱을 사용하므로 서버 계정·Firebase 캐시와 분리된다. 명시적 주입을
받는 서비스는 기존 주입 객체를 유지한다. Storage도 같은 선택된 앱을 사용한다.
로컬 모드의 App Check·Crashlytics 전송과 외부 소셜 로그인 초기화는 생략한다.
잘못된 모드 값과 로컬 release/profile 빌드는 Firebase 초기화 전에 거절한다.

`firebase.json`, `.firebaserc`, 플랫폼 운영 설정은 바꾸지 않는다. 별도
`firebase.local.json`이 실제 저장소의 DB/Firestore/Storage rules를 사용한다.
기존 E13 어댑터는 데모 프로젝트·에뮬레이터 실행을 확인한 다음 **로컬 런타임에서만**
RTDB 트리거 리전을 바꾼다. callable 리전은 `asia-northeast3`를 유지한다.

Functions 코드를 바꾸면 서버 터미널에서 `Ctrl+C` 후 `start`를 다시 실행한다.
시작할 때 TypeScript를 다시 빌드한다. Flutter 화면 수정은 평소처럼 hot reload한다.
Cloud Scheduler 주기 작업은 자동 실행되지 않는다. 기존 E13 검사는 handler를 직접
호출해 검증하며, 클라우드 스케줄 전달 자체는 실제 개발 서버에서 확인해야 한다.

## 검증

개발 에뮬레이터를 끈 상태에서:

```bash
node tool/emulator/local.mjs check
node --test functions/test/local-emulator-config.test.mjs
flutter test --no-pub test/firebase_backend_test.dart
flutter test --no-pub --dart-define=MOSIGAME_BACKEND=local test/firebase_backend_test.dart
```

`check`는 저장된 개발 데이터를 불러오거나 덮어쓰지 않는 일회성 환경에서 테스트 계정,
온보딩·게임 목록 조회, callable 방 생성/종료, RTDB 비인증 거절, Storage 소유자
업로드/다른 사용자 경로 거절을 검사하고 서비스를 종료한다.
세션 백엔드의 더 넓은 시나리오는 [기존 E13 검사](../../tool/emulator/README.md)를 따른다.
이 검사는 Project CLI targeted/FULL, 실제 기기 수명주기·성능 검증을 대체하지 않는다.

2026-10-15 macOS의 Flutter 3.47.5에서 `flutter analyze --no-pub`가 한글 경로의
LSP JSON 파싱 오류(exit 255)로 종료되는 현상을 관찰했다. `dart analyze --format machine`은
실행 가능했다. 이것을 canonical FULL 통과로 간주하지 않으며 SDK를 임의 수정하지 않는다.

관련: [개발환경](DEVELOPMENT_SETUP.md), [과거 파일럿](../operations/EMULATOR_PILOT.md),
[Firebase Emulator Suite](https://firebase.google.com/docs/emulator-suite).
