# Mosigame Architecture Reference

이 문서는 구조, 게임, 플랫폼, Firebase, auth/session 작업에서만 읽는 on-demand
reference다. 모든 작업의 공통 규칙은 [`ENGINEERING_CONTRACT.md`](ENGINEERING_CONTRACT.md)에
있다. 이 설명과 코드가 다르면 코드를 먼저 조사하고 차이를 보고한다.

## Runtime responsibilities

- Flutter(`lib/`)는 화면, 입력, 로컬 연출과 서버 상태의 읽기 모델을 담당한다.
- Firebase Authentication과 Firestore는 계정·프로필 같은 플랫폼 데이터를 담당한다.
- Realtime Database는 방, 접속 상태와 게임 상태를 전달한다.
- Cloud Functions(`functions/src/`)는 게임 command, 중요한 상태 전이와 서버 검증을
  담당한다.
- Firebase rules는 읽기/쓰기 가능 범위를 제한한다. 서비스 책임을 바꿀 때는 client,
  Functions, rules와 테스트를 함께 조사한다.

## Repository map

```text
lib/core/                  앱 공통 기반, 진단, 레이아웃, 사운드, 시간
lib/firebase/              Firebase 설정과 공통 Firebase 서비스
lib/platform/              인증, 프로필, 방/홈, 테마와 플랫폼 UI
lib/games/                 게임 계약, registry, 게임별 구현과 게임 공용 UI
lib/games/shared/          여러 게임이 공유하는 화면·연출·모델
functions/src/auth/        인증·온보딩 서버 작업
functions/src/room/        방 lifecycle과 접속 상태 서버 작업
functions/src/<game>/      게임별 타입, 검증과 상태 전이
test/                      Flutter/Project CLI 테스트
functions/test/            Functions 테스트
tool/mosigame_cli/         Mosigame Project CLI 구현
```

실제 파일과 등록 상태를 확인하지 않은 폴더나 기능을 존재한다고 가정하지 않는다.

## Game extension contract

- 새 게임은 [`TemplateGame`](../../lib/games/template_game.dart)을 구현하고
  [`GameRegistry`](../../lib/games/game_registry.dart)에만 등록한다. 플랫폼 화면에 게임
  ID별 분기를 추가하지 않는다.
- 구현 전 [`게임 템플릿 가이드`](../../lib/games/_game_template/README.md)와 가장 가까운
  기존 게임을 확인한다.
- 쓰기는 `<game>_command_service.dart`에서 callable Function으로 요청하고, 읽기는
  `<game>_query_service.dart`의 RTDB stream으로 받는다.
- 서버 상태를 미러링하는 구독과 불변 상태는 게임 세션 controller/provider 한곳이
  소유한다. 위젯마다 별도 RTDB 구독을 만들지 않는다.
- 서버 미러 상태와 화면 연출 상태를 섞지 않는다. 재생 여부와
  `AnimationController`는 화면 로컬 상태가 소유한다.
- `status`, 서버 `phase`, `GameScreenPhase`, 태블릿 연출 상태는 서로 다른 개념이다.
- 휴대폰 공통 흐름은 `GameScreenPhase`와 `PhoneGameShell`을 먼저 확인한다. 태블릿
  상태 분기는 타입이 있는 enum과 exhaustive `switch`를 우선한다.
- 공유 상단바, 사이드바, 결과, 퇴장 UI와 애니메이션은 `lib/games/shared/`를 먼저
  확인한다.

## Data and compatibility boundaries

게임 데이터는 다음 의미 경계를 유지한다.

```text
game/public          방 참가자에게 공개할 상태
game/private/{uid}   해당 사용자만 읽을 상태
game/server          클라이언트에 노출하지 않는 서버 상태
```

- Flutter가 `rooms/{roomCode}/game`의 게임 상태를 직접 쓰지 않는다.
- retry 가능한 게임 command는 동일한 `commandId`를 유지하고 서버에서 멱등하게
  처리한다.
- 배포된 callable 이름은 기존 앱의 public contract다. 동작 교체가 필요하면 호환
  전략과 배포 영향을 먼저 결정한다.
- RTDB trigger나 scheduled function을 옮길 때는 구·신 함수가 같은 이벤트를 중복
  처리하지 않게 한다.
- 자리/역할 구성은 참가자 퇴장에 따른 배치 무효화 contract를 먼저 반영한 뒤 UI를
  변경한다.
- 생성된 `lib/gen/assets.gen.dart`를 직접 편집하지 않는다. 에셋 원본을 등록하고
  저장소의 생성 절차를 사용한다.

## Task-specific entry points

- 새 게임: `lib/games/_game_template/README.md`, 가장 가까운 게임의 README·구현,
  `functions/src/<game>/`
- session/room: `lib/platform/home/`, `functions/src/room/`, 관련 테스트와
  `dart run :mosigame test session`
- auth/onboarding: `lib/platform/auth/`, `functions/src/auth/`, 관련 테스트와
  `dart run :mosigame test auth`
- Project CLI: `bin/mosigame.dart`, `tool/mosigame_cli/`, `test/mosigame_cli/`

외부 개인 notes, 날짜별 결과, 로컬 장비 절차는 이 architecture의 source of truth가
아니다. 필요한 제품 계약이 코드와 tracked 문서에서 확인되지 않으면 추측하지 않고
승인을 요청한다.
