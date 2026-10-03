# Mafia 수정 위치

마피아도 라이어스 포커·파이널 콜과 같은 `phone / tablet / shared` 구조를 사용합니다.
게임 규칙과 서버 상태를 화면에서 다시 계산하지 않고, 서버가 보낸 상태를 기기별
board가 화면으로 연결합니다.

## 가장 먼저 볼 파일

| 수정 목적 | 파일 |
|---|---|
| 게임 등록·기기 연결 | `game_mafia.dart` |
| 사용자 문구 | `game_copy.dart` |
| 색상·디자인 기준 | `game_theme.dart` |
| 효과음·배경음악 연결 | `game_sounds.dart` |
| 휴대폰 진행 순서 | `phone/phone_board.dart` |
| 태블릿 진행 순서 | `tablet/tablet_board.dart` |

## 상세 구현 위치

```text
phone/
├── providers/game_stage.dart   # 휴대폰 화면 단계
├── screens/                    # 단계별 전체 화면
├── widgets/                    # 휴대폰 전용 작은 UI
├── animations/                 # 휴대폰 전용 연출
└── src/board_state.dart        # 구독·타이머·lifecycle

tablet/
├── providers/game_stage.dart   # 태블릿 화면 단계
├── screens/                    # 단계별 전체 화면
├── widgets/                    # 태블릿 전용 작은 UI
├── animations/                 # 태블릿 전용 연출
└── src/board_state.dart        # 구독·타이머·lifecycle

shared/
├── models/                     # 불변 게임 상태와 DTO
├── providers/                  # 단일 세션 controller/provider
├── services/
│   ├── public_state_mapper.dart
│   ├── private_state_mapper.dart
│   ├── command_service.dart
│   └── query_service.dart
├── widgets/                    # 두 기기가 함께 쓰는 게임 전용 UI
└── animations/                 # 두 기기가 함께 쓰는 게임 전용 연출
```

## 수정 원칙

- 화면 순서·문구·연출 시간은 먼저 기기별 board에서 찾습니다.
- RTDB Map 변환은 mapper, 구독 수명과 상태 발행은 controller가 담당합니다.
- 같은 RTDB 경로를 구독하는 provider를 추가로 만들지 않습니다.
- 연결·재시도·이탈·오류 UI는 `game_kit/recovery`, `game_kit/errors`를 사용합니다.
- 공용 사이드바·설정·룰북은 `game_kit/tablet/widgets`를 사용합니다.
- 문구나 애니메이션을 끄더라도 서버 완료 명령에 필요한 callback은 유지합니다.
- 자동 생성된 `gen/` 파일은 직접 수정하지 않습니다.

과거 화면 명세와 Figma 대조 기록은 [`../docs/HISTORY.md`](../docs/HISTORY.md)에
보존되어 있습니다.

## 게임 시작 전 신분 선택

- `tablet/screens/role_setup_screen.dart`는 추천 조합의 신분별 인원수를 유지한 채
  신분 한 종류를 카드 한 장으로 표시합니다. 선택된 시민은 남은 인원을 채웁니다.
- 기존 카드 그림은 `tablet/widgets/role_setup_card.dart`에서 비율을 보존해 잘라
  표시합니다. 카드 아래 `×`로 삭제하고 오른쪽 `+`로 2열 선택 목록을 엽니다.
- 신분을 고르면 오른쪽 끝에 추가되고 목록은 다시 `+`로 접힙니다. 폭이 부족하면
  카드 영역만 두 줄로 바뀌며 `+` 영역은 두 줄의 전체 높이를 차지합니다.
  한 줄은 최대 6종이며, 간격을 뺀 카드 폭이 160px 미만이어도 두 줄로 전환합니다.
- 시민 이외의 역할 카드를 누르거나 위아래로 드래그하면 그림을 어둡게 하고 중앙에서
  인원수를 조절합니다. 아래로 밀면 증가, 위로 밀면 감소하며 최소 1명과 참여 인원
  상한을 지킵니다. 시민은 남은 인원에 맞춰 자동 조정합니다.
- 손을 뗀 뒤 2초 동안 조작이 없으면 원래 카드로 돌아갑니다. 다시 누르면 타이머를
  초기화하며 누르는 동안에는 복귀하지 않습니다. 변경은 즉시 로컬 구성에 반영합니다.
- 인원 불일치·마피아 진영 부재·시작부터 승리가 확정되는 구성을 안내하고 시작을 막습니다.
  제출/취소 중 편집을 막으며, 서버 요청 실패 시 편집과 재시도를 다시 허용합니다.
- 화면 동작 회귀 검증은 `../test/tablet/role_setup_screen_test.dart`에 있습니다.

- 상단 기본/확장/자유 프리셋과 진영별 합계, `이번 판 규칙`에서 변론·찬반 투표 및
  처형 신분 공개 범위를 선택합니다. 기본값은 기존 확장 구성·즉시 처형·직업 공개입니다.
- 선택 규칙 모델은 `shared/models/game_rules.dart`, 변론·찬반·공개 범위 화면은
  `shared/widgets/trial_view.dart`, 관전 숨김은 `shared/widgets/private_peek.dart`입니다.
- 서버 데이터·호환성·기본 규칙은 [구조 결정](../docs/DESIGN_DECISIONS.md#선택-가능한-규칙-2026-10-04)에 있습니다.
