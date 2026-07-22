# Project 00

여러 미니게임을 하나의 앱에서 제공하기 위한 Flutter 프로젝트입니다. 공통 플랫폼 기능과 게임별 코드를 분리하여, 새 게임을 추가해도 기존 게임과 앱 기능에 미치는 영향을 줄이는 구조입니다.

## 시작하기

```bash
flutter pub get
cp .env.example .env.dev
flutter run
```

Firebase Functions를 개발할 때는 Node.js 22를 사용합니다.

```bash
nvm use
cd functions
npm install
npm run lint
npm run build
npm run serve
```

Functions 배포는 프로젝트 루트에서 다음 명령으로 실행합니다.

```bash
./functions/node_modules/.bin/firebase deploy --only functions
```

현재 기본 HTTP 함수는 `healthCheck`이며 기본 리전은 서울 리전인 `asia-northeast3`입니다.

Firebase 플랫폼 설정 파일은 다음 위치에 있어야 합니다.

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`
- Flutter 설정: `lib/firebase_options.dart`

환경별 값은 `.env.dev`에 작성합니다. `.env.dev`는 Git에 포함되지 않으므로 팀원마다 `.env.example`을 복사해 사용합니다. API 키처럼 실제 비밀값은 Flutter 앱 번들에 넣지 말고 서버에서 관리해야 합니다.

## 자주 사용하는 명령어

```bash
dart format lib test
flutter analyze
flutter test
flutter run
```

## 개발 규칙

- 앱 전체에서 사용하는 값과 도구는 `lib/core`에 둡니다.
- 로그인, 사용자, 스토어, Firebase 같은 앱 플랫폼 기능은 `lib/platform`에 둡니다.
- 두 개 이상의 기능이나 게임이 재사용하는 UI와 게임 기반 기능은 `lib/shared`에 둡니다.
- 특정 게임에서만 쓰는 코드는 `lib/games/<game_id>`에 둡니다.
- 특정 화면에서만 쓰는 위젯은 그 기능의 `widgets`에 둡니다. 여러 영역에서 쓰이기 시작하면 `shared`로 이동합니다.
- 파일명은 `snake_case`, 클래스명은 `PascalCase`, 변수와 함수명은 `camelCase`를 사용합니다.
- 기능 추가 후 `flutter analyze`와 `flutter test`를 통과시킵니다.

전체 디렉터리와 각 파일의 역할은 [`docs/PROJECT_STRUCTURE.md`](docs/PROJECT_STRUCTURE.md)를 참고하세요.

## 현재 구현 상태

현재는 UI를 직접 설계하기 위한 빈 앱 상태입니다. `screens`, `widgets`, `router`, `theme` 폴더는 위치만 유지하며 기본 구현을 제공하지 않습니다.

- 완료: Firebase Core 초기화와 빈 `MaterialApp` 실행
- 완료: Firebase Realtime Database 패키지와 공용 인스턴스
- 골격: 인증, Firestore, Storage, Functions, Messaging 서비스 인터페이스
- 골격: 사용자 저장소, 매치메이킹, 실시간 게임 룸, Liar's Bar 상태 관리
- 미구현: 화면 UI, 공용 위젯, 테마, 라우팅
- 추후 작업: 실제 인증 흐름, 데이터 직렬화, Firebase 보안 규칙, 에러/로딩 처리, 다국어 코드 생성 및 화면 연결
