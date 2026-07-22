# 프로젝트 구조 설명서

이 문서는 새 개발자가 파일의 위치와 책임을 빠르게 파악하기 위한 안내서입니다. 현재 파일 중 상당수는 구조를 잡기 위한 최소 골격이며, 서비스 인터페이스는 실제 Firebase 구현체가 아닙니다.

## 폴더를 나눈 의도

이 프로젝트 구조의 핵심 목적은 **앱 자체 기능**, **여러 곳에서 재사용하는 기능**, **각 게임의 기능**이 서로 뒤섞이지 않게 하는 것입니다. 파일 이름보다 아래의 사용 의도를 먼저 보고 위치를 결정합니다.

| 폴더 | 사용 의도 | 여기에 넣는 것 | 여기에 넣지 않는 것 |
|---|---|---|---|
| `lib/core/` | 모든 코드의 가장 아래에서 사용하는 기반 계층 | 환경 설정, 상수, 공통 예외, UI와 무관한 변환 함수 | 화면, 위젯, 특정 게임 규칙, Firebase 화면 로직 |
| `lib/platform/` | 게임이 없어도 앱 운영에 필요한 기능 | 앱 시작, 라우팅, 테마, 로그인, 사용자, 스토어, 설정, Firebase 연결 | 특정 게임의 카드·턴·승패 규칙 |
| `lib/shared/` | 둘 이상의 기능 또는 게임에서 재사용 | 공용 버튼, 입력창, 검증기, 게임 룸/플레이어 공통 기능 | 한 화면이나 한 게임에서만 쓰는 코드 |
| `lib/games/` | 게임별 기능을 독립적으로 관리 | 게임 규칙, 상태, 화면, 저장소, 게임 전용 위젯 | 로그인, 앱 설정, 전체 게임 목록 UI |
| `assets/` | 코드가 아닌 앱 리소스를 용도별로 관리 | 이미지, 폰트, 소리, 애니메이션, 번역 파일 | Dart 코드와 Firebase 설정 파일 |
| `test/` | 기능이 의도대로 동작하는지 자동 검증 | 단위 테스트, 위젯 테스트, 통합 테스트 | 앱에서 직접 실행하는 기능 코드 |

### `core`와 `shared`의 차이

- `core`는 UI나 특정 기능을 몰라도 사용할 수 있는 가장 기초적인 코드입니다.
- `shared`는 Flutter 위젯이나 게임 모델처럼 실제 앱 기능에서 함께 재사용하는 코드입니다.
- 예: 날짜 문자열 변환은 `core/utils`, 공용 버튼은 `shared/widgets`, 공용 게임 룸 모델은 `shared/game_kit`입니다.

### `platform/widgets`와 `shared/widgets`의 차이

- `platform/widgets`는 로그인, Hub, 설정처럼 **앱 플랫폼 화면끼리** 공유합니다.
- `shared/widgets`는 플랫폼 화면과 게임을 포함해 **앱 전체에서** 사용할 수 있습니다.
- 예: 하단 내비게이션은 `platform/widgets`, 일반 확인 팝업은 `shared/widgets`입니다. 

### 기능 폴더 안의 하위 폴더 의도

| 하위 폴더 | 사용 의도 |
|---|---|
| `screens/` | 라우터에서 열 수 있는 한 화면 단위 |
| `widgets/` | 해당 기능이나 화면에서만 쓰는 작은 UI 단위 |
| `models/` | 데이터를 표현하는 객체와 상태 |
| `providers/` | 화면 상태와 사용자 동작을 관리하고 UI에 변경을 알림 |
| `repositories/` | 화면/상태 코드가 Firebase 등 데이터 저장 위치를 직접 알지 않도록 분리 |
| `services/` | Firebase, 네트워크, 매치메이킹 등 외부 기능과 실제 작업 수행 |

### 코드 위치를 결정하는 순서

새 파일을 만들기 전에 다음 순서로 판단합니다.

1. 특정 게임에서만 사용하는가? `games/<game_id>`에 둡니다.
2. 여러 게임에서 사용하는가? `shared/game_kit`에 둡니다.
3. 로그인, 사용자, 스토어, 설정 등 앱 운영 기능인가? `platform/<feature>`에 둡니다.
4. 앱 전체에서 재사용하는 UI인가? `shared/widgets`에 둡니다.
5. UI와 무관한 상수, 예외, 변환 도구인가? `core`에 둡니다.
6. 처음에는 가장 좁은 범위에 두고, 실제로 재사용될 때 상위 공용 폴더로 이동합니다.

## 최상위 폴더

| 경로 | 의미 |
|---|---|
| `android/` | Android 네이티브 설정, 권한, Gradle 및 Firebase 설정 |
| `ios/` | iOS 네이티브 설정, 권한, Xcode 및 Firebase 설정 |
| `web/` | Flutter Web 시작 파일, 아이콘, manifest |
| `assets/` | 이미지, 소리, 폰트, 애니메이션, 번역 원본 |
| `lib/` | 실제 Flutter/Dart 애플리케이션 코드 |
| `test/` | 단위 테스트와 위젯 테스트 |
| `functions/` | Firebase Cloud Functions 백엔드 코드 |

## 루트 설정 파일

| 파일 | 의미 |
|---|---|
| `pubspec.yaml` | 패키지 의존성, 앱 버전, 에셋 등록 |
| `pubspec.lock` | 실제 설치된 패키지 버전. 앱 프로젝트이므로 Git에 포함 |
| `analysis_options.yaml` | Dart 정적 분석 및 lint 규칙 |
| `l10n.yaml` | Flutter 다국어 코드 생성 설정 |
| `firebase.json` | Firebase CLI와 배포 대상 설정 |
| `.firebaserc` | Firebase 프로젝트 별칭 설정 |
| `.env.example` | 팀에 공유할 환경변수 키와 예시 값 |
| `.env.dev` | 개발자 로컬 환경값. Git에 포함하지 않음 |

## 앱 시작 흐름

```text
lib/main.dart
  -> platform/app/bootstrap.dart
     -> Flutter 바인딩 초기화
     -> Firebase 초기화
     -> platform/app/app.dart 실행
        -> 테마 적용
        -> router/app_router.dart로 화면 이동
```

| 파일 | 의미 |
|---|---|
| `lib/main.dart` | 앱의 유일한 실행 진입점 |
| `lib/firebase_options.dart` | FlutterFire CLI가 생성한 플랫폼별 Firebase 옵션 |
| `platform/app/bootstrap.dart` | 앱 실행 전 Firebase 등 필수 서비스 초기화 |
| `platform/app/app.dart` | 최상위 `MaterialApp`, 테마와 라우터 연결 |

## assets

| 경로 | 저장 대상 |
|---|---|
| `assets/images/logo/` | 앱 및 브랜드 로고 |
| `assets/images/icons/` | 앱 공용 아이콘 이미지 |
| `assets/images/backgrounds/` | 앱 공용 배경 이미지 |
| `assets/images/button/` | 이미지 기반 공용 버튼 리소스 |
| `assets/games/liars_bar/` | Liar's Bar 전용 이미지, 소리, 애니메이션 |
| `assets/games/_game_template/` | 새 게임용 에셋 구조 참고 위치 |
| `assets/fonts/` | 커스텀 폰트 |
| `assets/sounds/` | 여러 화면이나 게임이 공유하는 사운드 |
| `assets/lottie/` | 공용 Lottie 애니메이션 |
| `assets/l10n/` | `.arb` 번역 원본 파일 |

에셋을 추가할 때 `pubspec.yaml`에 해당 상위 경로가 등록되어 있는지 확인합니다.

## lib/core

앱의 특정 화면이나 Flutter UI에 종속되지 않는 가장 기초적인 코드입니다.

| 파일 | 의미 |
|---|---|
| `config/env.dart` | `.env` 값 접근 지점 |
| `constants/app_constants.dart` | 앱 이름 등 앱 전체 고정값 |
| `constants/asset_paths.dart` | 에셋 경로 상수 |
| `constants/firebase_constants.dart` | Firebase URL 등 Firebase 고정 설정 |
| `error/app_exception.dart` | 앱에서 공통으로 사용할 예외 타입 |
| `utils/formatters.dart` | 문자열과 표시 값 변환 도구 |

## lib/platform

게임과 무관하게 앱 자체를 구성하는 기능입니다.

### router와 theme

| 파일 | 의미 |
|---|---|
| `router/route_names.dart` | 화면 경로 문자열을 한곳에서 관리 |
| `router/app_router.dart` | 경로에 맞는 화면을 생성 |
| `theme/app_colors.dart` | 앱 공용 색상 |
| `theme/app_theme.dart` | 밝은/어두운 Material 테마 |

### firebase

| 파일 | 의미 |
|---|---|
| `firebase/realtime_database_service.dart` | 설정된 Realtime Database 공용 인스턴스 |
| `firebase/firebase_auth_service.dart` | 인증 기능이 따라야 할 인터페이스 골격 |
| `firebase/firestore_service.dart` | Firestore 접근 인터페이스 골격 |
| `firebase/firebase_storage_service.dart` | 파일 업로드 인터페이스 골격 |
| `firebase/firebase_functions_service.dart` | Callable Functions 인터페이스 골격 |
| `firebase/firebase_messaging_service.dart` | 푸시 메시징 인터페이스 골격 |

`firebase_auth`, `cloud_firestore`, `firebase_storage`, `cloud_functions`, `firebase_messaging` 패키지는 실제 기능을 구현할 때 필요한 것만 추가합니다.

### auth, user, hub, settings

| 경로/파일 | 의미 |
|---|---|
| `auth/screens/login_screen.dart` | 로그인 화면 |
| `auth/widgets/` | 로그인 화면 전용 입력과 소셜 로그인 버튼 |
| `auth/providers/auth_provider.dart` | 로그인 상태 골격 |
| `user/models/user_model.dart` | 사용자 도메인 모델 |
| `user/repositories/user_repository.dart` | 사용자 저장/조회 계약 |
| `user/providers/user_provider.dart` | 현재 사용자 상태 골격 |
| `hub/screens/home_screen.dart` | 앱 홈/로비 |
| `hub/screens/game_store_screen.dart` | 게임 목록 화면 |
| `hub/screens/game_detail_screen.dart` | 게임 소개 및 시작 화면 |
| `hub/widgets/` | 게임 카드, 검색, 카테고리 등 Hub 전용 UI |
| `hub/providers/game_store_provider.dart` | 게임 검색/목록 상태 골격 |
| `settings/screens/settings_screen.dart` | 앱 설정 화면 |
| `settings/widgets/settings_tile.dart` | 설정 항목 UI |

### platform/widgets

로그인, Hub, 설정 등 플랫폼 화면 여러 곳에서 공유하는 UI입니다.

| 파일 | 의미 |
|---|---|
| `widgets/app_bar/platform_app_bar.dart` | 플랫폼 공통 상단바 |
| `widgets/navigation/bottom_nav_bar.dart` | 하단 내비게이션 |
| `widgets/layout/platform_scaffold.dart` | 플랫폼 화면 공통 레이아웃 |

## lib/shared

플랫폼과 여러 게임에서 함께 재사용할 코드입니다.

| 파일/경로 | 의미 |
|---|---|
| `widgets/buttons/primary_button.dart` | 공용 주요 버튼 |
| `widgets/dialogs/confirm_dialog.dart` | 공용 확인 팝업 |
| `widgets/inputs/app_text_field.dart` | 공용 텍스트 입력 |
| `widgets/loading/loading_indicator.dart` | 공용 로딩 표시 |
| `utils/extensions.dart` | 여러 기능에서 쓰는 Dart extension |
| `utils/validators.dart` | 입력값 검증 함수 |
| `game_kit/models/` | 게임 룸과 플레이어 공통 모델 |
| `game_kit/services/` | 매치메이킹과 실시간 룸 서비스 계약 |
| `game_kit/widgets/` | 플레이어 링, 방 코드, 턴 타이머 등 게임 공통 UI |

## lib/games

각 게임이 독립적인 기능 단위가 되는 영역입니다.

| 파일/경로 | 의미 |
|---|---|
| `game_registry.dart` | 앱에서 제공하는 게임 목록 등록 |
| `_game_template/template_game.dart` | 모든 게임이 제공해야 할 기본 정보 계약 |
| `_game_template/widgets/` | 새 게임 생성 시 참고할 위젯 위치 |
| `liars_bar/liars_bar_game.dart` | Liar's Bar 식별자와 표시 이름 |
| `liars_bar/models/liars_bar_state.dart` | 게임 단계와 현재 턴 상태 |
| `liars_bar/providers/liars_bar_provider.dart` | 게임 화면 상태 골격 |
| `liars_bar/repositories/liars_bar_repository.dart` | 게임 데이터 통신 계약 |
| `liars_bar/screens/liars_bar_room_screen.dart` | 게임 대기실 |
| `liars_bar/screens/liars_bar_game_screen.dart` | 실제 플레이 화면 |
| `liars_bar/screens/liars_bar_result_screen.dart` | 결과 화면 |
| `liars_bar/widgets/` | 탄창, 카드 패, Liar 호출 버튼, 좌석 등 전용 UI |

## 새 게임 추가 방법

1. `lib/games/_game_template`을 참고해 `lib/games/<game_id>`를 만듭니다.
2. `assets/games/<game_id>`에 게임 전용 에셋 폴더를 만듭니다.
3. 게임 정보 클래스를 `TemplateGame` 기반으로 작성합니다.
4. `game_registry.dart`에 새 게임을 등록합니다.
5. 필요한 화면 경로를 `route_names.dart`와 `app_router.dart`에 추가합니다.
6. 다른 게임도 재사용할 코드가 생기면 `shared/game_kit`으로 이동합니다.

## 파일 배치 판단 기준

```text
특정 게임에서만 사용? -> games/<game_id>
여러 게임에서 사용?   -> shared/game_kit
앱 화면 여러 곳에서 사용? -> platform/widgets 또는 shared/widgets
Firebase/로그인/설정 기능? -> platform
UI와 무관한 기반 코드? -> core
```

## 개발 전 확인 사항

- `.env.example`을 `.env.dev`로 복사하고 로컬 값을 입력합니다.
- Firebase 프로젝트와 Android/iOS 설정 파일이 올바른지 확인합니다.
- Firebase Realtime Database 보안 규칙을 개발/운영 환경에 맞게 설정합니다.
- 실제 Firebase 기능을 구현할 때 필요한 FlutterFire 패키지만 추가합니다.
- 모델에는 Firebase 원본 `Map`을 직접 퍼뜨리지 말고 변환 코드를 둡니다.
- PR 전에 `dart format lib test`, `flutter analyze`, `flutter test`를 실행합니다.
