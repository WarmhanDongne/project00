# 프로젝트 구조 설명서

> 이 문서는 **현재 저장소에 실제로 존재하는 구조**를 설명합니다.
> 게임 상태 머신, Riverpod, Cloud Functions, 애니메이션과 새 게임 추가 기준은
> [`AI_GAME_DEVELOPMENT_GUIDE.md`](AI_GAME_DEVELOPMENT_GUIDE.md)를 우선해서 읽으세요.
> 작업 원칙은 저장소 루트의 [`AGENTS.md`](../AGENTS.md)에 있습니다.

## 폴더를 나눈 의도

핵심 목적은 **앱 자체 기능**, **여러 게임이 함께 쓰는 기능**, **각 게임의 기능**이
서로 뒤섞이지 않게 하는 것입니다. 파일 이름보다 아래 사용 의도를 먼저 보고 위치를
결정합니다.

| 폴더 | 사용 의도 | 여기에 넣는 것 | 여기에 넣지 않는 것 |
|---|---|---|---|
| `lib/core/` | UI·게임을 몰라도 쓸 수 있는 기반 계층 | 앱 시작, 환경 설정, 상수, 예외, 화면 방향, 네트워크 감시, 사운드, 서버 시각 | 화면 구성, 특정 게임 규칙 |
| `lib/firebase/` | Firebase SDK 접근 지점 | 생성된 옵션, 각 Firebase 서비스 인스턴스, 값 변환 유틸 | 게임 규칙, 화면 로직 |
| `lib/platform/` | 게임이 없어도 앱 운영에 필요한 기능 | 로그인, 프로필, 홈, 게임 목록, 방 생성·입장, 테마 | 카드·턴·승패 규칙 |
| `lib/games/` | 게임별 기능을 독립적으로 관리 | 게임 규칙 미러 상태, 화면, 서비스, 게임 전용 위젯 | 로그인, 앱 설정 |
| `lib/games/shared/` | 둘 이상의 게임에서 재사용 | 공용 게임 흐름, 애니메이션, 모델, 좌석 배치, 공용 위젯 | 한 게임에서만 쓰는 코드 |
| `lib/gen/`, `lib/generated/` | 코드 생성물 | `build_runner`·`flutter gen-l10n` 산출물 | 직접 작성한 코드 |
| `assets/` | 코드가 아닌 앱 리소스 | 이미지, 폰트, 소리, 애니메이션, 번역 원본 | Dart 코드 |
| `functions/` | Cloud Functions 백엔드 | 게임 규칙 판정, 방 수명주기, 인증 보조 | 클라이언트 UI |
| `test/` | Flutter 단위·위젯 테스트 | 앱 동작 검증 | 실행 기능 코드 |

### `core`와 `games/shared`의 차이

- `core`는 Flutter 위젯이나 게임 개념을 몰라도 쓸 수 있는 가장 기초 코드입니다.
- `games/shared`는 게임이라는 개념을 아는, 게임끼리 공유하는 코드입니다.
- 예: 서버 시각 보정은 `core/time/server_clock.dart`, 게임 중단 배너는
  `games/shared/widgets/game_interruption_layer.dart`입니다.

### 코드 위치를 결정하는 순서

1. 특정 게임에서만 사용하는가? → `games/<game_id>/`
2. 여러 게임에서 사용하는가? → `games/shared/`
3. 로그인·프로필·홈·방 등 앱 운영 기능인가? → `platform/<feature>/`
4. UI와 무관한 상수·예외·변환 도구인가? → `core/`
5. 처음에는 가장 좁은 범위에 두고, 실제로 재사용될 때 상위 공용 폴더로 옮깁니다.

## 최상위 폴더

| 경로 | 의미 |
|---|---|
| `android/`, `ios/` | 네이티브 설정, 권한, Firebase 설정 파일 |
| `web/` | Flutter Web 시작 파일, 아이콘, manifest |
| `assets/` | 이미지, 소리, 폰트, 애니메이션, 번역 원본 |
| `lib/` | Flutter/Dart 애플리케이션 코드 |
| `functions/` | Firebase Cloud Functions(TypeScript) |
| `test/` | Flutter 단위·위젯 테스트 |
| `docs/` | 구조 설명서와 게임 개발 가이드 |
| `tool/` | 에셋·번역 등 개발 보조 스크립트 |

## 루트 설정 파일

| 파일 | 의미 |
|---|---|
| `pubspec.yaml` / `pubspec.lock` | 의존성, 앱 버전, 에셋 등록. 앱 프로젝트이므로 lock도 Git에 포함 |
| `analysis_options.yaml` | Dart 정적 분석 및 lint 규칙 |
| `l10n.yaml` | 다국어 코드 생성 설정 |
| `firebase.json` / `.firebaserc` | Firebase CLI 배포 대상과 프로젝트 별칭 |
| `database.rules.json` | **Realtime Database 보안 규칙. 방과 게임 상태의 실제 규칙** |
| `firestore.rules` | Firestore 보안 규칙. 게임 스토어 목록(`games`)과 사용자 프로필(`users`)만 |
| `.env.example` / `.env.dev` | 환경변수 예시와 로컬 값(`.env.dev`는 Git 제외) |
| `AGENTS.md` | 코드 수정 전 반드시 읽는 작업 원칙 |

## 앱 시작 흐름

```text
lib/main.dart
  -> core/app/bootstrap.dart
     -> Flutter 바인딩 초기화, Firebase 초기화, 화면 방향·시스템 UI 설정
     -> core/app/app.dart
        -> 테마(platform/theme) 적용, 네트워크 감시 래핑
        -> 로그인 여부에 따라 로그인 화면 또는 홈으로 진입
```

라우터 패키지는 쓰지 않습니다. 화면 이동은 `Navigator`와 `MaterialPageRoute`로
직접 처리하고, 게임 화면은 `TemplateGame`이 만들어 줍니다.

## lib/core

| 경로 | 의미 |
|---|---|
| `app/bootstrap.dart` | 앱 실행 전 필수 초기화 |
| `app/app.dart` | 최상위 `MaterialApp`, 테마·진입 화면 연결 |
| `config/env.dart` | `.env` 값 접근 지점 |
| `constants/app_constants.dart` | 앱 전체 고정값 |
| `constants/asset_paths.dart` | 에셋 경로 상수 |
| `constants/firebase_constants.dart` | Realtime Database URL 등 Firebase 고정 설정 |
| `error/app_exception.dart` | 앱 공통 예외 타입 |
| `layout/app_orientation.dart` | 화면 방향 정책 |
| `layout/app_system_ui.dart` | 상태바·내비게이션바 표시 정책 |
| `layout/device_layout.dart` | 휴대폰·태블릿 판별 |
| `network/realtime_connection_monitor.dart` | Realtime Database 연결 상태 감시 |
| `network/app_network_guard.dart` | 연결이 끊기면 앱 전체 모달 표시 |
| `network/network_unavailable_modal.dart` | 네트워크 불가 안내 모달 |
| `sound/app_sounds.dart` | 공용 사운드 에셋 경로 |
| `sound/sound_effects.dart` | 효과음 정의와 재생 옵션 |
| `sound/providers/sound_provider.dart` | 사운드 재생 상태 Provider |
| `sound/service/sound_service.dart` | 실제 재생을 수행하는 서비스 |
| `time/server_clock.dart` | 서버 시각 보정. 턴 마감 계산에 사용 |

## lib/firebase

| 경로 | 의미 |
|---|---|
| `firebase_options.dart` | FlutterFire CLI가 생성한 플랫폼별 옵션 |
| `services/realtime_database_service.dart` | 설정된 Realtime Database 공용 인스턴스 |
| `services/firestore_service.dart` | Firestore 접근 지점 |
| `services/firebase_functions_service.dart` | Callable Functions 접근 지점 |
| `services/firebase_storage_service.dart` | 파일 업로드 접근 지점 |
| `services/firebase_messaging_service.dart` | 푸시 메시징 접근 지점 |
| `utils/firestore_value.dart` | Firestore 원본 값 안전 변환 |

> `firebase.json`의 Flutter dart 출력 경로는 이 위치(`lib/firebase/firebase_options.dart`)와
> 맞춰 둡니다. `flutterfire configure`를 다시 실행할 때 경로가 어긋나면 중복 파일이
> 생깁니다.

## lib/platform

| 경로 | 의미 |
|---|---|
| `auth/screens/` | 로그인·회원가입 화면 |
| `auth/widgets/` | 회원가입 단계별 입력 UI |
| `auth/services/auth_service.dart` | 인증, 이메일 중복확인, 프로필 이미지 업로드 |
| `auth/providers/auth_provider.dart` | 로그인 상태 |
| `profile/models/user_model.dart` | 사용자 도메인 모델 |
| `profile/providers/user_provider.dart` | 현재 사용자 상태 |
| `profile/widgets/` | 태블릿 프로필 표시와 수정 모달 |
| `home/home.dart` | 기기 종류에 따라 휴대폰·태블릿 홈 분기 |
| `home/phone/screens/` | 휴대폰 홈, 방 참여, 닉네임, 대기 화면 |
| `home/tablet/screens/tablet_home.dart` | 태블릿 홈(방 생성·게임 선택) |
| `home/gamelist/` | Firestore `games` 목록과 보유 게임 조회 |
| `home/howtoplay/` | 홈의 안내 아이콘에서 펼쳐지는 플레이 방식 안내(태블릿 위치·자리 배치 연출) |
| `home/room/models/` | 방·플레이어·기기 모델 |
| `home/room/services/room_service.dart` | 방 생성·입장·퇴장 callable 호출 |
| `home/room/services/*_session_store.dart` | 재접속용 로컬 세션 저장 |
| `home/room/providers/room_provider.dart` | 방 상태 구독과 사용자 동작 |
| `theme/platform_theme.dart` | 앱 테마 |
| `widgets/platform_components.dart` | 플랫폼 화면 공용 컴포넌트 |

## lib/games

| 경로 | 의미 |
|---|---|
| `template_game.dart` | 모든 게임이 구현하는 플랫폼 연결 계약 |
| `game_registry.dart` | 앱이 제공하는 게임 목록 등록 지점 |
| `_game_template/` | 새 게임용 스캐폴드와 상세 가이드(`README.md`) |
| `<game>/<game>_game.dart` | 게임 식별자, 인원, 화면 방향, 퇴장 함수 이름 |
| `<game>/<game>_flow_config.dart` | 게임 진입·연출 흐름 설정 |
| `<game>/<game>_copy.dart` | 게임 안내 문구 |
| `<game>/controllers/` | 서버 상태 구독, 파생 상태, 명령 조정 |
| `<game>/providers/` | 불변 상태와 `autoDispose family` 세션 |
| `<game>/screens/` | 휴대폰·태블릿 진입 화면과 기기별 화면 레이어 |
| `<game>/services/<game>_command_service.dart` | callable 호출(쓰기) |
| `<game>/services/<game>_query_service.dart` | Realtime Database 구독(읽기) |
| `<game>/widgets/{phone,tablet}/` | 기기별 게임 전용 UI |
| `<game>/animations/` | 한 게임에서만 쓰는 애니메이션 |
| `<game>/sound/` | 게임 전용 효과음 정의 |
| `shared/game_flow/` | 휴대폰 공통 흐름(`GameScreenPhase`, `PhoneGameShell`), 중단·종료 처리 |
| `shared/services/` | 공용 재시도 정책, 게임 중단 명령, 방 서비스 계약 |
| `shared/models/` | 게임 방·플레이어 공통 모델 |
| `shared/player_layouts/` | 좌석 배치 모델과 편집기 |
| `shared/animations/`, `shared/widgets/` | 여러 게임이 쓰는 연출과 UI |
| `penalty/roulette.dart` | 벌칙 룰렛 위젯 |
| `mafia/` | **개발 중.** `GameRegistry` 미등록이며 서버 함수가 없습니다 |

현재 등록된 게임은 `liars_poker`와 `final_call` 두 개입니다.

## functions

| 경로 | 의미 |
|---|---|
| `src/index.ts` | 배포되는 모든 함수의 유일한 export 지점 |
| `src/room/realtime-room-functions.ts` | 방 생성·입장·좌석 저장 |
| `src/room/realtime-room-lifecycle.ts` | 방 종료·퇴장·게임 선택·상태 동기화·오래된 방 정리 |
| `src/room/controller-session.ts` | 태블릿(컨트롤러) 세션 검증 |
| `src/auth/` | 이메일 중복확인, Google 프로필 동기화 |
| `src/<game>/` | 게임별 상태 전이와 규칙 판정 |
| `src/<game>/common/` | 덱, 분배, 턴 순서, 검증 등 게임 내부 공용 모듈 |
| `src/game-interruption/` | 모든 게임이 공유하는 연결 끊김·재접속 처리 |
| `test/*.test.mjs` | 빌드된 `lib/`를 대상으로 하는 Node 테스트 |

### Cloud Function 이름 규칙

| 종류 | 규칙 | 예 |
|---|---|---|
| 게임 함수 | `game_<게임 id>_<동작>` | `game_liars_poker_submit_cards` |
| 게임 공용 함수 | `game_common_<영역>_<동작>` | `game_common_interruption_expire` |
| 방 함수 | camelCase | `createRealtimeRoom`, `leaveRealtimeRoom` |
| 인증 함수 | camelCase | `checkEmailDuplicate` |

게임 함수 이름의 `<게임 id>`는 `TemplateGame.id`와 `assets/games/<id>`, `functions/src/<id>`
와 같은 값을 씁니다. 배포된 callable 이름을 바꾸면 구버전 앱이 함수를 찾지 못하므로
서버와 클라이언트 호출부를 같은 커밋에서 고치고 함께 배포합니다. Realtime Database
트리거와 스케줄 함수의 이름을 바꿀 때는 배포 후 **구 함수를 반드시 삭제**해야
같은 이벤트가 두 번 처리되지 않습니다.

## 데이터 위치

| 데이터 | 위치 |
|---|---|
| 방, 플레이어, 게임 진행 상태 | Realtime Database `rooms/{roomCode}` |
| 모든 기기가 공유하는 게임 상태 | `rooms/{roomCode}/game/public` |
| 한 플레이어만 읽는 손패 | `rooms/{roomCode}/game/private/{uid}` |
| 클라이언트에 노출하지 않는 상태 | `rooms/{roomCode}/game/server` |
| 게임 스토어 목록 | Firestore `games` |
| 사용자 프로필과 보유 게임 | Firestore `users` |

클라이언트는 `rooms/{roomCode}/game`을 직접 쓰지 않습니다. 모든 쓰기는 callable을
거칩니다.

## 새 게임 추가 방법

1. `lib/games/_game_template`을 참고해 `lib/games/<game_id>`를 만듭니다.
2. `assets/games/<game_id>`에 에셋 폴더를 만들고 `pubspec.yaml`에 등록한 뒤
   `dart run build_runner build --delete-conflicting-outputs`를 실행합니다.
3. `TemplateGame`을 구현하고 `game_registry.dart`에만 등록합니다.
4. 서버 로직은 `functions/src/<game_id>/`에 만들고, 함수 이름은
   `game_<game_id>_<동작>`으로 짓습니다.
5. 플랫폼 화면에 게임 ID별 `if/switch`를 추가하지 않습니다.
6. 다른 게임도 재사용할 코드가 생기면 `lib/games/shared/`로 옮깁니다.

## 개발 전 확인 사항

- `.env.example`을 `.env.dev`로 복사하고 로컬 값을 입력합니다.
- Firebase 프로젝트와 Android/iOS 설정 파일이 올바른지 확인합니다.
- 모델에는 Firebase 원본 `Map`을 직접 퍼뜨리지 말고 변환 코드를 둡니다.
- PR 전에 아래를 실행합니다.

```bash
dart format lib test && flutter analyze && flutter test && (cd functions && npm test)
```
