# game_kit 채택 규칙

새 게임을 만들 때 **무엇을 반드시 써야 하고, 무엇이 선택인지**를 정한다.

이 문서가 없던 동안 세 게임이 각자 다른 추상화를 골라서 빠져나갔고, 그 결과
"어느 쪽이 맞는 방식인지"를 코드만 봐서는 알 수 없었다. `game_template`으로
시작하는 사람이 마피아를 따라 할지 라이어스포커를 따라 할지 고를 수 없다면
그건 규칙이 없는 것이다.

## 1. 필수 — 안 쓰면 같은 버그를 다시 만든다

| 항목 | 파일 | 안 쓰면 생기는 일 |
| --- | --- | --- |
| 세션 컨트롤러 | `game_flow/game_session_controller.dart` | 방이 사라져도 화면이 마지막 상태에 굳는다 |
| 상태 계약 | `game_flow/game_session_state.dart` | 위 컨트롤러를 쓸 수 없다 |
| 남은 시간 | `widgets/game_turn_countdown.dart` | 서버 상태가 안 바뀌는 동안 타이머가 멈춘 것처럼 보인다 |
| 초읽기 껍데기 | `widgets/game_turn_countdown_face.dart` | 내 차례가 끝나도 초읽기 소리가 다음 사람까지 이어진다 |
| 서버 시각 | `core/time/server_clock.dart` | 기기 시계가 틀리면 마감이 어긋난다 |
| 명령 서비스 | `services/game_command_service.dart` | `commandId` 멱등 처리와 재시도 정책이 빠진다 |
| 상태 조회 | `services/game_query_service.dart` | 공개/개인 데이터 경계가 게임마다 달라진다 |
| 끊김 처리 | `services/game_interruption_command_service.dart` | 참가자가 끊겼을 때 판이 멈춘다 |
| 에셋 접근 | `core/assets/game_image.dart` · `game_asset_store.dart` | 다운로드 게임으로 전환할 때 그 화면만 깨진다 |
| 오류 문구 | `core/error/user_error_message.dart` | 영어 원문·stack trace가 사용자 화면에 뜬다 |

**`Assets....image()`를 직접 부르지 않는다.** 반드시 `Assets....game`([GameImage])을
거친다. 번들 게임과 다운로드 게임이 같은 코드로 동작해야 한다.

## 2. 권장 — 형태가 맞으면 쓴다

| 항목 | 파일 | 맞는 경우 |
| --- | --- | --- |
| 휴대폰 셸 | `game_flow/phone_game_shell.dart` | 상단바·나가기·룰 버튼이 표준 배치인 게임 |
| 화면 단계 | `game_flow/game_screen_phase.dart` | 연결→플레이→결과→종료 흐름을 그대로 쓰는 게임 |
| 흐름 설정 | `game_flow/game_flow_config.dart` | GAME START·ROUND N 연출이 있는 게임 |
| 자동 완료 | `game_flow/game_flow_auto_complete.dart` | 연출이 끝나면 서버에 알려야 하는 게임 |
| 공용 모달 | `widgets/phone_exit_modal.dart` · `tablet_game_settings_dialog.dart` · `tablet_game_rulebook_dialog.dart` | 거의 모든 게임 |

권장 항목을 **쓰지 않기로 했다면 그 이유를 파일 맨 위 주석에 남긴다.** 라이어스
포커가 `PhoneGameShell`을 쓰지 않는 이유가 `phone/phone_board.dart`와 내부 State에 적혀 있는 것이
좋은 예다. 이유 없이 빠지면 다음 사람은 실수인지 결정인지 알 수 없다.

## 2-1. 기기별 조율판

`game_<id>.dart`는 플랫폼 등록과 두 기기 진입점을 연결합니다. 실제 수정할
화면 흐름은 `phone/phone_board.dart`, `tablet/tablet_board.dart`에 나눕니다.

```text
lib/
  game_<id>.dart                 게임 등록·화면 방향·두 board 연결
  game_copy.dart                 문구
  game_theme.dart                공통 디자인 값
  game_sounds.dart               효과음
  phone/phone_board.dart         휴대폰 화면 생성·안내·연출 시간
  tablet/tablet_board.dart       태블릿 단계·화면 선택·연출 시간
  {phone,tablet}/screens/        상세 화면
  {phone,tablet}/widgets/        화면 구성 위젯
  {phone,tablet}/animations/     기기 전용 연출
  {phone,tablet}/providers/      기기 전용 단계/상태 (필요할 때만)
  {phone,tablet}/services/       기기 전용 처리 (필요할 때만)
  {phone,tablet}/src/            세션 수명·타이머 내부 구현
  shared/models/                DTO·불변 게임 상태
  shared/providers/             공통 세션·컨트롤러
  shared/services/              공통 서버 명령·조회
  shared/{widgets,animations}/  해당 게임의 양쪽 기기가 공유하는 구현
  gen/                          생성기 소유 에셋 참조 (직접 수정 금지)
```

화면 흐름에는 시점과 서버 status, 표시 화면, 문구/연출 ON/OFF와 시간,
입력 차단·Scrim, 완료 조건 및 서버와 클라이언트 책임을 설명합니다.
실제로 사용되는 설정만 선언하며 서버 제한시간을 연출 시간과 섞지 않습니다.
마피아의 서버 제한시간 미러는 `shared/models/server_timing.dart`에 유지합니다.

`GameFlowStep.screenWidget`과 `animation.widget`은 탐색용 타입 설명입니다.
타입만 바꾸면 위젯이 교체되는 것으로 안내하지 않습니다. 실제 화면 교체는
board의 화면 생성 함수 또는 단계 switch에서 합니다. 상세 위젯은 인원·좌석·콜백을
받으며, 기존 key와 StatefulWidget 수명을 보존해 단계 사이 재생·깜빡임을 막습니다.

한 위젯 인스턴스를 여러 단계가 유지하면 `sharedWith`에 적고,
`flowConfig.widgetOwnerOf(stage)`로 주인 단계의 연출 시간을 읽습니다.
같은 구독을 phone/tablet 서비스에 복제하지 않습니다. 기기 전용 코드가
없는 폴더의 README는 확장 위치와 공통 구현 위치를 설명합니다.
여러 게임이 공유할 구현은 game_kit에 두고, 게임 패키지끼리 import하지 않습니다.

## 3. 게임이 직접 갖는 것

- **색**: 두 곳 이상 쓰는 색만 `game_<id>/lib/game_theme.dart`에 모은다. 한 번만
  쓰는 그러데이션 stop까지 올리면 쓰는 자리에서 멀어지기만 하고 고칠 일은 그
  화면 하나뿐이라, 오히려 읽기가 나빠진다. 게임마다 아트 방향이 달라 **공용
  팔레트는 만들지 않는다**(세 게임에 걸쳐 같은 색은 5개뿐이었다).
- **그림자·모달 덮개**: 아트와 무관하므로 공용이다 →
  `game_kit/core/theme/game_shadow_colors.dart`
- **타이머 생김새**: 게임마다 다르다. 껍데기만 공용([GameTurnCountdownFace]),
  얼굴은 게임이 그린다.
- **스냅샷 해석**: `applyPublicValue` · `handlePrivateEvent` 는 게임이 구현한다.
  공용 코드가 남의 게임 필드를 해석하려 들면 게임이 늘 때마다 공용 파일이
  부풀어 오른다.

## 4. 파일·폴더 이름 규칙

패키지와 폴더가 이미 제공하는 문맥을 파일명에 반복하지 않는다.
파일명은 `snake_case.dart`를 쓰고, **게임명·기기명이 아닌 파일의
실제 역할**을 남긴다.

```text
shared/providers/game_controller.dart       # 패키지가 게임명을 제공
shared/models/game_state.dart
shared/services/command_service.dart
shared/services/query_service.dart
phone/screens/game_screen.dart          # phone 폴더 안에서 phone_ 반복 금지
tablet/providers/game_stage.dart          # tablet 폴더 안에서 tablet_ 반복 금지
phone/widgets/top_bar.dart
```

다음 형태는 사용하지 않는다.

```text
controllers/final_call_controller.dart
screens/phone/phone_game_screen.dart
screens/tablet/tablet_game_stage.dart
widgets/phone/mafia_phone_layout.dart
```

기기 폴더 안의 파일명에 기기명을 반복하지 않습니다. 예외는 편집기 탭에서도
역할이 구분되어야 하는 `phone/phone_board.dart`, `tablet/tablet_board.dart`뿐입니다.
패키지명은 공식 진입점 `game_<id>.dart`에만 유지합니다. `gen/assets.gen.dart`는
생성 파일이므로 직접 이름을 바꾸거나 수정하지 않습니다.

## 5. 현재 채택 현황

| | 마피아 | 라이어스포커 | 파이널콜 |
| --- | :-: | :-: | :-: |
| `GameSessionController` | ✅ | ✅ | ✅ |
| `GameSessionState` | ✅ | ✅ | ✅ |
| `GameTurnCountdownFace` | — | ✅ | ✅ |
| `PhoneGameShell` | ✅ | ⛔ 의도적 제외 | ✅ |
| `GameScreenPhase` | ✅ | ⛔ 의도적 제외 | ✅ |
| `GameFlowConfig` | ⛔ 해당 없음 | ✅ | ✅ |
| 색 토큰 파일 | ✅ | ✅ | ✅ |
| 기기별 board | ✅ | ✅ | ✅ |

**라이어스포커는 훅 세 개를 재정의해 붙었습니다.** 공용 뼈대가 게임마다 다를 수
있는 자리를 열어 둔 덕입니다. 상속하면서 무엇을 바꾸는지가 곧 그 게임이 남들과
다른 점이라, 훅 목록이 그대로 설명이 됩니다.

| 훅 | 라이어스포커가 바꾼 이유 |
| --- | --- |
| `watchPrivateStream()` | 개인 상태 전체가 아니라 `private/{uid}/hand` 만 구독한다 |
| `handleSubscriptionError()` | 태블릿은 SnackBar로 알리고, 초기 데이터 대기를 풀어 줘야 한다 |
| `excludeInterruptedPlayerAndContinue()` | 진행자 버튼이라 게임 조작을 잠그면 안 된다 — 메뉴 명령 플래그를 쓴다 |

초안을 쌓는 `_draft` 는 남아 있지만 **더 이상 [state]의 사본이 아닙니다.** 발행
직후 비워서 다음 읽기가 현재 `state` 에서 다시 시작합니다. 그래야 공용 뼈대가
`state` 를 바꿨을 때(명령 진행 표시·오류 문구) 게임 코드가 그 값을 봅니다.
사본을 계속 들고 있으면 두 값이 갈라져, 공용 뼈대가 쓴 내용이 다음 발행에
덮여 사라집니다.

**남은 것 하나**: `_sameHandCards` 등 손으로 쓴 비교 함수 4개(약 90줄). 상태에
`==` 가 생겨 같은 일을 하므로 지울 수 있지만, 실기기에서 한 번 확인한 뒤에
빼는 편이 안전합니다.

## 6. 새 게임 체크리스트

- [ ] `game_template` 복사 후 `pubspec.yaml`의 `name`·`description` 수정
- [ ] 상태 클래스가 `GameSessionState<T>`를 구현하고 `==`/`hashCode`를 갖는다
- [ ] 컨트롤러가 `GameSessionController<T>`를 상속하고
      `applyPublicValue`·`handlePrivateEvent`만 구현한다
- [ ] 이미지 접근이 전부 `Assets....game`을 거친다
- [ ] 두 곳 이상 쓰는 색이 `game_theme.dart`에 있다
- [ ] `phone_board.dart`와 `tablet_board.dart`에서 각 기기의 실제 흐름을 수정할 수 있다 (2-1 참고)
- [ ] 패키지·기기 폴더의 이름을 파일명에 반복하지 않았다
- [ ] `game_<id>.dart`와 `gen/assets.gen.dart` 외에 예외적인 게임명 접두사가 없다
- [ ] 권장 항목 중 쓰지 않기로 한 것에 이유 주석이 있다
- [ ] `python3 tool/check_package_boundaries.py` 가 위반 0건
- [ ] 다운로드 게임이면 `requiredAssetVersion`을 1 이상으로 올린다
      (0이면 번들 게임으로 남는다 — `template_game.dart` 기본값)
