# Template 수정 위치

- 게임 등록·기기 연결: `game_template.dart`
- 휴대폰 흐름·문구·시간·화면 생성 함수: `phone/phone_board.dart`
- 태블릿 흐름·문구·시간·실제 화면 선택: `tablet/tablet_board.dart`
- 기기별 상세 화면/위젯/연출: `phone/` 또는 `tablet/`의 `screens`, `widgets`, `animations`
- DTO·서버 읽기 상태: `shared/models/`
- 단일 세션 구독·명령 상태: `shared/providers/`
- 서버 명령/조회: `shared/services/`
- 문구·디자인·소리: `game_copy.dart`, `game_theme.dart`, `game_sounds.dart` (해당 파일이 있는 게임)
- 세션 수명·타이머·재접속 내부 처리: 기기별 `src/board_state.dart`
- 자동 생성 에셋: `gen/` — 직접 편집하지 않고 패키지의 생성 절차 사용

board의 `screenWidget` 타입은 코드 탐색용 설명입니다. 실제 위젯 교체는
board의 화면 생성 함수 또는 단계 switch를 수정합니다. 서버 status와 승패를
board에서 새로 계산하지 마세요. 문구/연출을 생략해도 서버 완료 명령이 필요한
단계는 완료 콜백을 보존해야 합니다.

기기 폴더 안에서 기기명을 반복하는 파일은 `phone_board.dart`,
`tablet_board.dart` 두 진입점만 허용합니다. 새 기기별 Provider/Service가
필요하기 전에는 공통 세션을 사용하며 빈 코드·중복 구독을 만들지 않습니다.

## 복사해서 시작할 때

이미 들어 있는 것 — 세 게임과 같은 모양입니다.

- `shared/models/game_state.dart` — 공용 뼈대 계약(명령 진행·오류·방 삭제)을 채운 불변 상태
- `shared/providers/game_controller.dart` — `GameSessionController` 상속. 채울 곳은 `applyPublicValue`·`handlePrivateEvent` 두 곳
- `shared/providers/session_provider.dart` — Provider와 화면 연결 사용 예(다시 그리기는 `ref.watch`, 부수효과는 `listenManual`)
- `game_copy.dart`, `game_theme.dart`

일부러 없는 것 — 실제 에셋이 생긴 뒤에 만듭니다.

- `game_assets.dart`, `gen/` — `flutter_gen` 생성물이 있어야 함
- `game_sounds.dart`, `shared/services/asset_preloader.dart` — 소리·이미지 파일이 있어야 함

화면(`phone/src`, `tablet/src`)은 아직 가짜 값으로 그립니다. 서버 상태를 붙이는
방법은 각 `board_state.dart` 맨 위 주석에 있습니다.
