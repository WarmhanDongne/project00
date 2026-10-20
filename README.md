# 모시겜 (Mosigame)

모시겜은 "모여서 시작하는 게임"의 줄임말입니다. 태블릿 한 대를 함께 보는 게임판으로,
각자의 휴대폰을 개인 손패와 컨트롤러로 쓰는 오프라인 파티게임 앱입니다. 별도의
보드게임 도구나 게임기 없이, 모인 자리에서 이미 가진 기기만으로 바로 게임을 시작할 수
있습니다.

## 플레이 방식

1. 태블릿에서 방을 만들면 QR 코드가 표시됩니다.
2. 참가자는 휴대폰으로 QR 코드를 스캔해 입장하고, 태블릿에서 자리를 정합니다.
3. 게임판과 공개 정보는 태블릿에, 내 카드와 비공개 선택지는 휴대폰에 표시됩니다.
4. 게임이 끝나면 다시 하거나 다른 게임을 고릅니다.

## 게임

| 게임 | 소개 | 상태 |
|---|---|---|
| 라이어스 | 상대의 선언이 거짓인지 가려내는 카드 심리전 게임 | 공개 |
| 파이널 콜 | 4명 또는 6명이 팀을 나눠 겨루는 카드 게임 | 공개 |
| 마피아 | 역할을 숨기고 진행하는 추리 게임 | 다듬는 중 |

게임은 패키지 단위로 분리되어 있어, 앱 구조를 바꾸지 않고 새 장르를 계속 추가할 수
있습니다.

## 현재 상태

Google Play 비공개 테스트를 진행하고 있으며, 2026년 10월 말 정식 출시를 목표로
하고 있습니다.

## 팀

한동대학교 학생 창업팀 **따스한동네**가 만들고 있습니다. 사람들이 직접 만나 함께
웃는 시간이 늘어나는 "따뜻한 동네"를 만들고 싶다는 마음에서 시작했습니다.

## 기술 구성

- 앱: Flutter (Android, iOS), 게임별 패키지 `packages/game_*`와 공용 패키지 `packages/game_kit`
- 백엔드: Firebase Authentication, Realtime Database, Cloud Firestore, Cloud Storage
- 게임 서버: Cloud Functions (Node.js 22, 서울 리전). 게임 규칙, 턴 검증, 승패와
  비공개 정보는 서버가 결정합니다.

---

## 시작하기

전체 문서 목차는 [`docs/README.md`](docs/README.md)에 있습니다. 사람이 읽는 전체
설치·검증 안내는
[`Development setup`](docs/development/DEVELOPMENT_SETUP.md)을 따릅니다. Codex에 환경 준비를
맡길 때는 [`Agent setup`](docs/development/AGENT_SETUP.md)을 실행 계약으로 사용합니다. 현재 상태와
후속 계획은 [`Development environment plan`](docs/development/DEVELOPMENT_ENVIRONMENT_PLAN.md)에
계속 갱신합니다.

앱을 운영 Firebase와 분리된 로컬 Auth·RTDB·Firestore·Functions·Storage에서 실행하려면
[`Local Firebase`](docs/development/LOCAL_FIREBASE.md)의 실행 옵션과 테스트 계정을 사용합니다.

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
- Flutter 설정: `packages/game_kit/lib/firebase/firebase_options.dart`

`.env.example`은 local override 형식의 예시지만 현재 앱은 `.env.dev`를 필수로
읽지 않습니다. local config와 secret의 현재 계약은
`docs/development/DEVELOPMENT_SETUP.md`를 따르며, 실제 비밀값은 Flutter 앱 번들에
넣지 않습니다.

수동 테스트 중 production Realtime Database 상태를 제한적으로 확인해야 한다면
[`Firebase MCP RTDB Read-only Pilot`](docs/operations/FIREBASE_MCP.md)의 별도 계정, 승인 및 최소 경로
규칙을 따릅니다. 이 파일럿은 Project CLI와 자동화된 테스트를 대체하지 않습니다.

과거 Android 1~3기기 조작 자동화 파일럿의 결과와 현재 로컬 환경에 남은 한계는
[`Emulator pilot record`](docs/operations/EMULATOR_PILOT.md)에 보존합니다.

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
[`PROJECT_CLI.md`](docs/engineering/PROJECT_CLI.md)를 참고합니다.

## 개발 규칙

- 공통 값·도구, 게임 계약과 재사용 게임 UI·기반 기능은 `packages/game_kit`에 둡니다.
- 로그인, 사용자, 방·홈 같은 플랫폼 기능은 앱의 `lib/platform`에 둡니다.
- 새 게임은 `packages/game_template`을 복사해 시작합니다. 게임 패키지는 앱이나
  다른 게임을 참조하지 않고 공용 `game_kit`을 사용합니다.
- 특정 게임에서만 쓰는 코드와 에셋은 `packages/game_<game_id>`에 둡니다.
- 특정 화면에서만 쓰는 위젯은 그 기능의 `widgets`에 둡니다. 여러 영역에서 쓰이기 시작하면 `shared`로 이동합니다.
- 파일명은 `snake_case`, 클래스명은 `PascalCase`, 변수와 함수명은 `camelCase`를 사용합니다.
- 기능 추가 후 Mosigame Project CLI의 관련 targeted suite와 FULL validation을
  통과시킵니다.

저장소 안내는 [`AGENTS.md`](AGENTS.md), 공통 규칙은
[`Engineering Contract`](docs/engineering/ENGINEERING_CONTRACT.md), 구조 설명은
[`Architecture Reference`](docs/engineering/ARCHITECTURE.md)에 있습니다.

## 현재 구현 상태

현재 앱에는 인증·온보딩, 방 생성/참가와 session lifecycle, 휴대폰·태블릿 플랫폼
화면이 구현되어 있습니다. 게임은 `GameRegistry`를 통해 라이어스포커, 파이널콜,
마피아를 등록하며, 게임 command와 중요한 상태 전이는 Firebase Functions가
server-authoritative하게 처리합니다. 정확한 현재 contract는 코드와 테스트를
우선하고, 구조 변경 전에는 Architecture Reference를 확인합니다.

## 자주 발생하는 문제 해결 (Troubleshooting)

### 안드로이드 에뮬레이터에서 앱 실행 시 즉시 튕기는 현상 (Impeller 오류)
Flutter 3.22+ 버전부터 안드로이드에 새로운 그래픽 렌더링 엔진인 **Impeller**가 기본 적용되었습니다. 하지만 윈도우 환경의 일부 안드로이드 에뮬레이터(가상 기기)에서는 그래픽 드라이버 호환성 문제로 인해 `Requested texture size (1, 1) exceeds maximum supported size of (0, 0)` 에러와 함께 앱이 즉시 강제 종료되는 문제가 있습니다.
