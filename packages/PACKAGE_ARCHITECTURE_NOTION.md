# Mosigame 게임 패키지 구조 정리와 개선 방향

> 작성 기준: 2026-10-03  
> 브랜치: `jinsung/refactor-code-review`  
> 기준 HEAD: `93892c0b295697fbeefdeb52f66ff673f2745852`  
> 범위: `packages/` 내부 구조만 분석. 앱 플랫폼 `lib/`와 서버 `functions/`는 변경하지 않음.

---

## 1. 한 문장 목표

게임을 수정하는 개발자는 `game_<name>.dart`, `phone/phone_board.dart`,
`tablet/tablet_board.dart`부터 읽어 게임 흐름과 화면을 이해하고, 상세 구현은
`screen → widget/animation → provider/service` 순서로 필요할 때만 내려가도록 한다.

동시에 라이어스 포커, 파이널 콜, 마피아의 플레이 방식과 UI 차이는 유지하되,
연결 복구·오류·공용 메뉴·안내·애니메이션 기반처럼 게임 규칙과 무관한 기능은
`game_kit`에서 재사용한다.

---

## 2. 지금까지 대화에서 확정된 개발 방향

### 2.1 사람이 자주 수정하는 파일은 위에 둔다

게임별 최상단에는 다음 파일을 둔다.

| 파일 | 담당 내용 |
|---|---|
| `game_<name>.dart` | 플랫폼에 게임 등록, 휴대폰·태블릿 보드 연결 |
| `game_copy.dart` | 사용자에게 표시되는 문구 |
| `game_theme.dart` | 색상과 디자인 기준 |
| `game_sounds.dart` | 효과음·배경음악 연결 |
| `game_assets.dart` | 생성된 에셋을 실행 코드에 연결 |
| `phone/phone_board.dart` | 휴대폰 단계 순서, 문구, 시간, 화면 연결 |
| `tablet/tablet_board.dart` | 태블릿 단계 순서, 문구, 시간, 화면 연결 |

개발자가 게임 진행을 바꿀 때 처음부터 Firebase 파싱 코드나 애니메이션 내부 구현을
읽지 않아도 되는 구조를 목표로 한다.

### 2.2 기기 차이를 먼저 분리한다

휴대폰과 태블릿은 화면 크기뿐 아니라 역할이 다르므로 `phone/`, `tablet/`으로
먼저 나눈다.

- 휴대폰: 개인 손패, 역할, 선택, 행동 제출
- 태블릿: 전체 진행, 공용 연출, 결과 발표, 설정·룰북
- 두 기기 공통: DTO, 서버 상태, 명령·조회, 공용 규칙

기기 폴더 안에서는 파일명에 `phone_`, `tablet_`을 다시 반복하지 않는다.
예외는 진입점을 바로 찾기 위한 `phone_board.dart`, `tablet_board.dart` 두 파일이다.

### 2.3 게임 UI는 달라도 구조는 같게 만든다

세 게임의 화면을 강제로 같은 디자인으로 만들지는 않는다. 대신 다음 구조와 계약을
같게 맞춘다.

```text
game_<name>.dart
├── phone/
│   ├── phone_board.dart
│   ├── providers/
│   ├── screens/
│   ├── widgets/
│   ├── animations/
│   ├── services/
│   └── src/board_state.dart
├── tablet/
│   ├── tablet_board.dart
│   ├── providers/
│   ├── screens/
│   ├── widgets/
│   ├── animations/
│   ├── services/
│   └── src/board_state.dart
└── shared/
    ├── models/
    ├── providers/
    ├── services/
    ├── widgets/
    └── animations/
```

### 2.4 게임 규칙과 화면 연출을 분리한다

- 서버: 카드, 역할, 턴 검증, 승패, 중요한 상태 전환의 기준
- controller/provider: 서버 상태를 클라이언트 읽기 모델로 변환
- board: 현재 상태에 어떤 화면을 연결할지 결정
- screen/widget: 실제 UI 표시와 사용자 입력
- animation: 시각적 재생만 담당
- presentation timing: 문구와 애니메이션 유지 시간

클라이언트 애니메이션이 끝났다는 이유만으로 승패나 게임 규칙을 직접 바꾸지 않는다.
서버 완료 명령이 필요한 단계는 문구나 애니메이션을 꺼도 완료 콜백을 유지한다.

### 2.5 안정성 기능은 정상 게임 흐름과 분리한다

연결 단절, 요청 재시도, 앱 백그라운드, 플레이어 이탈은 정상 게임 화면과 다른
관심사다. 따라서 현재 작업 트리에서는 `game_kit`에 다음 구조를 추가했다.

```text
game_kit/lib/
├── recovery/
│   ├── models/       # 중단·세션 복구 상태
│   ├── providers/    # 세션 구독과 복구 조율
│   ├── services/     # 재시도·연결 감지·진행 명령
│   └── widgets/      # 연결 대기·요청 실패·이탈 레이어
└── errors/
    ├── models/       # 예외 형태
    ├── services/     # 사용자 문구 변환
    └── widgets/      # 오류 전용 UI
```

기존 import 경로는 패키지 밖 코드와 팀원 브랜치를 깨지 않도록 호환 export로 남겨
두었다. 실제 구현은 새 폴더에만 존재한다.

### 2.6 두 명이 협업하므로 소유 범위를 명확히 한다

- 현재 담당 범위는 `packages/`다.
- 플랫폼 `lib/`, 서버 `functions/` 수정이 필요하면 TODO로 남기고 별도 협의한다.
- 다른 개발자의 파일을 함께 수정하지 않아 merge conflict 범위를 줄인다.
- 큰 구조 변경은 기능 변경과 분리된 커밋으로 남긴다.

---

## 3. 구조가 변화한 과정

### 이전 구조

- `screens/phone`, `widgets/phone`, 최상단 `controllers`, `providers`, `services`가
  게임마다 조금씩 다른 이름과 위치로 존재했다.
- 휴대폰·태블릿 흐름, 서버 구독, 애니메이션 타이머가 한 파일에 섞여 있었다.
- 같은 의미의 화면과 애니메이션도 게임마다 다른 위치와 이름을 사용했다.
- 연결 오류와 재접속 UI가 각 `board_state.dart`에 반복됐다.

### 1단계 — 게임 패키지 구조 통일

- 세 게임을 `phone / tablet / shared` 구조로 통일했다.
- `game_<name>.dart`는 등록, `phone_board/tablet_board`는 기기별 흐름을 담당하게 했다.
- 서버 DTO·provider·service는 `shared`로 옮겼다.
- 새 게임도 같은 구조로 시작하도록 `game_template`을 맞췄다.

### 2단계 — 화면 흐름을 board에서 읽을 수 있게 변경

- `GameFlowConfig`, `GameFlowStep`, 기기별 stage enum을 사용했다.
- 문구 표시 여부, 유지 시간, 애니메이션 사용 여부, 입력 차단, scrim 같은 설정을
  흐름 파일에서 확인할 수 있게 했다.
- `board_state.dart`는 구독·타이머·lifecycle을 소유하고, board는 사람이 읽는 설정과
  화면 연결을 담당하도록 분리했다.

### 3단계 — 공용 UI와 연출 재사용

- 안내 문구, 상단바, 태블릿 사이드바·설정·룰북, 결과 UI 기반을 `game_kit`으로 이동했다.
- 카드 분배와 휴대폰 카드 수신 연출을 공용화하고 게임별 에셋·좌석만 전달하게 했다.
- 라이어스 포커와 파이널 콜은 구조를 맞추되 플레이 규칙과 고유 UI는 유지했다.

### 4단계 — 게임 진행 안정성 보강

- 진행 명령 중복 방지와 재시도, stale 응답 무시, 에셋 사전 로딩을 보강했다.
- 네트워크·백그라운드·게임 중단 동안 주요 연출 시간을 멈추는 공용 presentation
  clock/sequence를 추가했다.
- 마피아 아침·개표·처형·관전 전환을 구체적인 단계로 정리했다.

### 5단계 — 복구와 오류를 독립 영역으로 분리

- `recovery/`와 `errors/`를 만들었다.
- `GameRecoveryLayer`가 요청 상태, 연결 대기, 플레이어 이탈 UI를 같은 순서로 조립한다.
- 라이어스 포커·파이널 콜의 휴대폰/태블릿과 마피아 휴대폰에서 공용 레이어를 사용한다.
- 마피아 태블릿은 비정상 종료 안내의 z-order가 별도로 필요해 같은 recovery 위젯을
  직접 조립한다.

---

## 4. 현재 구조 점검 결과

### 4.1 잘 되어 있는 부분

| 항목 | 상태 | 근거 |
|---|---|---|
| 패키지 경계 | 좋음 | 경계 검사 결과 위반 0건 |
| 세 게임 기본 구조 | 좋음 | 모두 `phone/tablet/shared` 사용 |
| 수정 진입점 | 좋음 | 게임별 board와 README에서 위치 안내 |
| 서버 상태 소유권 | 좋음 | 세션 controller/provider 한 곳에서 구독 |
| 명령·조회 분리 | 좋음 | `command_service`, `query_service` 분리 |
| 기기별 stage | 좋음 | 휴대폰·태블릿 stage enum 분리 |
| 공용 UI | 좋음 | `game_kit` 상단바·사이드바·안내·분배 연출 재사용 |
| 복구·오류 분리 | 적용됨 | `recovery/`, `errors/`, 호환 export 추가 |
| 새 게임 확장 | 좋음 | `game_template`이 동일한 board/shared 구조 제공 |

패키지 경계 검사에서 확인된 비생성 Dart 파일 수:

| 패키지 | 파일 수 |
|---|---:|
| `game_kit` | 150 |
| `game_mafia` | 60 |
| `game_liars_poker` | 50 |
| `game_final_call` | 41 |
| `game_template` | 17 |

### 4.2 이번 작업에서 적용한 구조

#### P1. 게임별 controller에서 서버 파싱을 분리

mapper 분리 후 controller 크기:

- 라이어스 포커 `game_controller.dart`: 약 930줄
- 마피아 `game_controller.dart`: 약 540줄
- 파이널 콜 `game_controller.dart`: 약 355줄

기존 controller는 다음 세 역할을 함께 가지고 있었다.

1. 공개·개인 Firebase 값 파싱
2. 현재 화면에서 사용할 파생 상태 계산
3. 서버 명령 실행

적용한 구조:

```text
shared/
├── models/
│   ├── game_state.dart
│   └── game_models.dart
├── providers/
│   └── game_controller.dart       # 구독 수명과 상태 조율만
└── services/
    ├── public_state_mapper.dart   # public snapshot → DTO
    ├── private_state_mapper.dart  # private snapshot → DTO
    ├── command_service.dart
    └── query_service.dart
```

주의: controller를 여러 provider로 나누지는 않는다. RTDB 구독과 현재 게임 상태의
소유자는 계속 한 곳이어야 한다. **파싱 함수만 순수 mapper로 추출**하는 방향이 적절하다.

#### P1. `game_kit/widgets`를 기기별로 분리

실제 구현을 `shared/phone/tablet`으로 옮겼다. 기존 `game_kit/lib/widgets/`에는
패키지 밖 소비자와 팀원 브랜치를 위한 호환 export만 남겼다.

적용한 구조:

```text
game_kit/lib/
├── shared/widgets/
│   ├── game_announcement_layer.dart
│   ├── game_card_face.dart
│   └── game_turn_countdown.dart
├── phone/widgets/
│   ├── exit_modal.dart
│   ├── game_top_bar.dart
│   ├── result_dialog.dart
│   └── rule_dialog.dart
└── tablet/widgets/
    ├── game_side_bar.dart
    ├── menu_overlay.dart
    ├── modal_frame.dart
    ├── rulebook_dialog.dart
    └── settings_dialog.dart
```

패키지 내부 import는 새 경로로 전환했다. 패키지 밖 import까지 바꿀 수 있는 시점에
호환 파일을 제거한다.

#### P1. 사운드 영역 통합

`core/sound/`와 최상단 `sound/`에 나뉘어 있던 실제 구현을 최상단 `sound/`로
통합했다. 이전 `core/sound/` 경로는 호환 export로 유지한다.

적용한 구조:

```text
game_kit/lib/sound/
├── models/
├── providers/sound_provider.dart
├── services/sound_service.dart
├── app_sounds.dart
├── sound_effects.dart
├── countdown_tick_cue.dart
└── game_background_music.dart
```

사운드 재생 정책은 공통으로 유지하고 게임별 파일에는 어떤 음원을 쓸지만 남긴다.

#### P2. 좌석 배치 영역을 역할별로 분리

한 폴더에 섞여 있던 자리 모델, 계산 서비스, 편집 화면을 역할별로 구분했다.
`player_layout_editor.dart` 내부의 하나의 편집 화면은 약 1,025줄이어도 유지했다.

적용한 구조:

```text
player_layouts/
├── models/player_layout.dart
├── services/layout_factory.dart
├── services/slot_positions.dart
├── services/seating_roster_guard.dart
└── widgets/player_layout_editor.dart
```

편집 화면 내부의 private painter까지 파일 수만 늘리기 위해 분리할 필요는 없다.

#### P2. 모호한 파일 이름 구체화

| 이전 이름 | 변경한 이름 |
|---|---|
| LP `tablet/screens/game_helper.dart` | `card_presentation.dart` |
| FC `tablet/screens/game_helper.dart` | `seat_geometry.dart` |
| LP `tablet/animations/game_animation.dart` | `submitted_card_pile_animation.dart` |
| FC `tablet/animations/game_animation.dart` | `call_and_discard_animation.dart` 또는 기능별 2개 파일 |
| `tablet/widgets/rolebook.dart` | `rulebook.dart` |
| LP `RoleBook` | `LiarsPokerTabletRulebook` |

`helper`, `utils`, `common`처럼 책임을 알 수 없는 이름은 새 코드에서 사용하지 않는다.

#### P2. 게임 문구의 위치 통일

라이어스 포커와 파이널 콜의 긴 태블릿 룰북 문구도 `game_copy.dart`로 이동했다.
위젯은 문구를 배치하고 이미지·영상만 연결한다.

권장 원칙:

- 화면에 표시되는 원문: `game_copy.dart`
- 동적 문구 조합: `game_copy.dart`의 함수
- 위젯: 받은 문구를 배치만 함
- 서버 오류 원문 변환: `game_kit/errors/services/`

#### P2. controller 태블릿 세션 저장소를 recovery에 포함

`controller_room_session_store.dart`를 `recovery/services/`로 이동했다. 플랫폼에서
이전 경로를 사용할 수 있으므로 `session/`에는 호환 export를 남겼다.

#### P3. `game_template`의 빈 역할 폴더를 더 명확하게 표시

`widgets/`, `shared/animations/`, `shared/widgets/`에 역할 README를 추가하고,
새 controller가 public/private mapper를 기본 구조로 사용하도록 갱신했다.

적용 원칙:

- 각 역할 폴더에 짧은 README 제공
- 실제 기능이 없으면 빈 Dart 클래스를 만들지 않음
- 공용 가능성을 먼저 `game_kit`에서 확인하라는 체크리스트 추가
- recovery/errors를 게임마다 복제하지 말라는 규칙 명시

### 4.3 추가로 남은 검증과 협의

#### 마피아 README 기록 분리 — 적용 완료

마피아 README에 섞여 있던 현재 수정 위치와 과거 Figma·설계 기록을 분리했다.

```text
lib/README.md                 # 지금 수정할 위치만
docs/DESIGN_DECISIONS.md      # 현재 구조와 책임을 결정한 이유
docs/HISTORY.md               # 기존 조사·화면 명세·Figma 기록 보존
```

세 게임 mapper에는 Firebase 연결 없이 Map 변환 결과를 확인하는 단위 테스트를
추가했다. 구조상 남은 항목은 패키지 밖 호환 import 제거 시점 협의다.

### 4.4 길어도 분리하지 않는 편이 좋은 파일

| 대상 | 유지 이유 |
|---|---|
| `game_state.dart` | 한 시점의 불변 상태를 한 객체로 확인할 수 있어야 함 |
| `board_state.dart` | 구독·타이머·lifecycle 소유자가 여러 개로 갈라지면 중복 실행 위험 |
| 하나의 AnimationController를 공유하는 연출 파일 | 타임라인을 여러 파일로 나누면 순서를 추적하기 어려움 |
| 결과 화면의 private painter/widget | 외부 재사용이 없고 하나의 시각 컴포넌트를 구성함 |
| `role_catalog.dart` | 역할 정의를 한곳에서 검색하는 이점이 큼 |

파일이 길다는 이유만으로 나누지 않는다. 서로 독립적으로 테스트·교체 가능한 책임이
두 개 이상일 때만 분리한다.

---

## 5. 권장 최종 구조

```text
packages/
├── game_kit/
│   └── lib/
│       ├── recovery/        # 연결·세션 복구·재시도·이탈
│       ├── errors/          # 예외·오류 문구·오류 UI
│       ├── game_flow/       # 정상 게임 단계와 발표 설정
│       ├── shared/          # 기기 공통 UI·애니메이션
│       ├── phone/           # 휴대폰 공용 UI·애니메이션
│       ├── tablet/          # 태블릿 공용 UI·애니메이션
│       ├── sound/           # 공용 오디오
│       ├── player_layouts/  # 좌석 모델·계산·편집 UI
│       └── core/            # 앱 전반의 낮은 수준 기반만
│
├── game_liars_poker/
├── game_final_call/
├── game_mafia/
└── game_template/
```

게임 패키지의 최종 형태:

```text
game_<name>/lib/
├── game_<name>.dart
├── game_copy.dart
├── game_theme.dart
├── game_sounds.dart
├── game_assets.dart
├── phone/
│   ├── phone_board.dart
│   ├── providers/game_stage.dart
│   ├── screens/
│   ├── widgets/
│   ├── animations/
│   ├── services/            # 정말 기기 전용일 때만
│   └── src/board_state.dart
├── tablet/
│   ├── tablet_board.dart
│   ├── providers/game_stage.dart
│   ├── screens/
│   ├── widgets/
│   ├── animations/
│   ├── services/            # 정말 기기 전용일 때만
│   └── src/board_state.dart
└── shared/
    ├── models/
    ├── providers/game_controller.dart
    ├── services/
    │   ├── public_state_mapper.dart
    │   ├── private_state_mapper.dart
    │   ├── command_service.dart
    │   └── query_service.dart
    ├── widgets/
    └── animations/
```

---

## 6. 개발자가 코드를 읽는 순서

### 게임 흐름이나 화면을 수정할 때

1. `game_<name>.dart`
2. `phone/phone_board.dart` 또는 `tablet/tablet_board.dart`
3. `providers/game_stage.dart`
4. board가 연결한 `screens/`
5. 화면이 사용하는 `widgets/`, `animations/`
6. 서버 상태가 궁금할 때만 `shared/models/`, `shared/providers/`
7. 서버 요청이 궁금할 때만 `shared/services/`

### 연결·오류 상황을 수정할 때

1. `game_kit/recovery/recovery.dart`
2. `recovery/widgets/game_recovery_layer.dart`
3. `recovery/providers/game_session_controller.dart`
4. `recovery/services/`
5. 사용자 오류 문구는 `errors/`

### 새로운 게임을 추가할 때

1. `game_template` 복사
2. 게임 등록 정보와 기기 방향 설정
3. public/private 상태 모델 작성
4. command/query service 작성
5. stage enum과 phone/tablet board 작성
6. 공용 UI·연출을 `game_kit`에서 먼저 검색
7. 게임 고유 화면만 새로 작성
8. 재연결·오류 UI는 `GameRecoveryLayer` 사용
9. 서버 상태와 클라이언트 연출 상태를 섞지 않았는지 확인

---

## 7. 리팩터링 우선순위

### 이번 작업에서 완료

1. `game_kit/widgets`를 `shared/phone/tablet`으로 이동하고 호환 export 유지
2. `core/sound`와 `sound` 통합
3. 세 게임 controller의 public/private mapper 추출
4. `player_layouts`를 models/services/widgets로 구분
5. 모호한 `game_helper`, `game_animation`, `rolebook` 이름 정리
6. 라이어스 포커·파이널 콜 태블릿 문구를 `game_copy.dart`로 이동
7. controller session 저장소를 recovery로 이동
8. `game_template` mapper·역할별 README 갱신

### 다음 커밋으로 추천

1. 현재 `recovery/errors`와 이번 구조 변경을 검토 가능한 단위로 커밋
2. 패키지 밖 담당자와 호환 export 제거 시점 협의

### 패키지 밖 협의 후

10. 호환 export를 사용하는 플랫폼 import를 새 경로로 변경
11. 더 이상 사용하는 곳이 없으면 호환 파일 제거
12. 실제 앱 재실행 세션 복구와 서버 상태 epoch 검증 연결

---

## 8. 구조 변경 체크리스트

- [ ] 이 파일은 휴대폰, 태블릿, 공통 중 어디에 속하는가?
- [ ] 화면, 위젯, 애니메이션, provider, service 중 역할이 무엇인가?
- [ ] `helper`, `utils`, `common`보다 기능이 드러나는 이름인가?
- [ ] 서버 규칙을 클라이언트가 새로 판단하고 있지 않은가?
- [ ] 같은 RTDB 구독을 새 provider에서 중복 생성하지 않았는가?
- [ ] 문구·Duration·ON/OFF 값을 board 또는 timing 파일에서 찾을 수 있는가?
- [ ] 두 게임 이상에서 동일한 동작이면 `game_kit`으로 올릴 수 있는가?
- [ ] 디자인만 비슷하고 규칙이 다른 코드를 무리하게 공용화하지 않았는가?
- [ ] 기존 import 소비자를 위한 호환 계획이 있는가?
- [ ] 새 게임도 같은 구조를 따르도록 `game_template`을 함께 갱신했는가?
- [ ] 패키지 밖 수정이 필요하면 먼저 협의했는가?
- [ ] 구조 변경과 기능 변경을 가능한 한 별도 커밋으로 나눴는가?

---

## 9. 현재 결론

현재 패키지는 처음의 게임별 제각각 구조에서 벗어나, 기기별 board와 공통 shared
영역을 중심으로 상당히 통일됐다. 이번 `recovery/errors` 분리로 정상 게임 흐름과
장애 대응도 구분되기 시작했다.

이번 작업에서 긴 controller의 순수 Firebase 파싱, `game_kit`의 기기별 공용 위젯,
사운드, 좌석 배치, 세션 복구 저장소를 역할별 경로로 구분했다. 기존 경로에는
호환 export를 남겨 패키지 밖 코드를 수정하지 않았다.

최종적으로 추구하는 구조는 다음 문장으로 정리할 수 있다.

> **게임의 진행 순서는 board에서 읽고, 실제 화면은 screen에서 수정하며, 서버 상태는
> provider/service에서 관리하고, 연결·오류·공용 연출은 game_kit에서 재사용한다.**
