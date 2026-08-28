# Mosigame

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

Functions 배포는 사용자 승인을 받은 뒤 프로젝트 루트에서 다음 명령으로 실행합니다.

```bash
./functions/node_modules/.bin/firebase deploy --only functions
```

Firebase 플랫폼 설정 파일은 다음 위치에 있어야 합니다.

- Android: `android/app/google-services.json`
- iOS: `ios/Runner/GoogleService-Info.plist`
- Flutter 설정: `lib/firebase/firebase_options.dart`

환경별 값은 `.env.dev`에 작성합니다. `.env.dev`는 Git에 포함되지 않으므로 팀원마다 `.env.example`을 복사해 사용합니다. API 키처럼 실제 비밀값은 Flutter 앱 번들에 넣지 말고 서버에서 관리해야 합니다.

## 자주 사용하는 명령어

Windows에서 validation, 자동화 또는 제한된 실행 환경을 사용할 때:

```powershell
.\tool\invoke_mosigame.ps1 doctor
.\tool\invoke_mosigame.ps1 test session
.\tool\invoke_mosigame.ps1 test auth
.\tool\invoke_mosigame.ps1 validate --full
```

macOS/Linux에서:

```bash
dart run :mosigame doctor
dart run :mosigame test session
dart run :mosigame test auth
dart run :mosigame validate --full
```

앱 실행은 모든 플랫폼에서 다음 명령을 사용합니다.

```bash
flutter run
```

Targeted suite는 관련 작업 중 빠른 피드백용이며, 완료 전에는 Project CLI의 FULL
validation을 실행합니다. Windows guard와 macOS/Linux raw CLI의 사용 조건은
[`PROJECT_CLI.md`](PROJECT_CLI.md)를 참고합니다.

## 개발 규칙

- 앱 전체에서 사용하는 값과 도구는 `lib/core`에 둡니다.
- 로그인, 사용자, 스토어, Firebase 같은 앱 플랫폼 기능은 `lib/platform`에 둡니다.
- 두 개 이상의 게임이 재사용하는 UI와 게임 기반 기능은 `lib/games/shared`에 둡니다.
- 특정 게임에서만 쓰는 코드는 `lib/games/<game_id>`에 둡니다.
- 특정 화면에서만 쓰는 위젯은 그 기능의 `widgets`에 둡니다. 여러 영역에서 쓰이기 시작하면 `shared`로 이동합니다.
- 파일명은 `snake_case`, 클래스명은 `PascalCase`, 변수와 함수명은 `camelCase`를 사용합니다.
- 기능 추가 후 Mosigame Project CLI의 관련 targeted suite와 FULL validation을
  통과시킵니다.

저장소 안내는 [`AGENTS.md`](AGENTS.md), 공통 규칙은
[`Engineering Contract`](ENGINEERING_CONTRACT.md), 구조 설명은
[`Architecture Reference`](ARCHITECTURE.md)에 있습니다.

## 현재 구현 상태

현재 앱에는 인증·온보딩, 방 생성/참가와 session lifecycle, 휴대폰·태블릿 플랫폼
화면이 구현되어 있습니다. 게임은 `GameRegistry`를 통해 라이어스포커, 파이널콜,
마피아를 등록하며, 게임 command와 중요한 상태 전이는 Firebase Functions가
server-authoritative하게 처리합니다. 정확한 현재 contract는 코드와 테스트를
우선하고, 구조 변경 전에는 Architecture Reference를 확인합니다.

## 자주 발생하는 문제 해결 (Troubleshooting)

### 안드로이드 에뮬레이터에서 앱 실행 시 즉시 튕기는 현상 (Impeller 오류)
Flutter 3.22+ 버전부터 안드로이드에 새로운 그래픽 렌더링 엔진인 **Impeller**가 기본 적용되었습니다. 하지만 윈도우 환경의 일부 안드로이드 에뮬레이터(가상 기기)에서는 그래픽 드라이버 호환성 문제로 인해 `Requested texture size (1, 1) exceeds maximum supported size of (0, 0)` 에러와 함께 앱이 즉시 강제 종료되는 문제가 있습니다.
