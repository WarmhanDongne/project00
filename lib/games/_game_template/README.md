# 새 게임 추가 가이드

이 문서는 라이어스포커(`liars_poker`, 가장 완성된 참고 게임)와 파이널콜(`final_call`, 두 번째 참고 게임)을 실제로 조사해서 정리한, 새 게임을 만들 때 따라야 할 파일 구조·서비스/프로바이더 연결·화면 흐름·애니메이션·문구 컨벤션입니다. 복사해서 시작할 스캐폴드는 이 폴더(`_game_template/`)에 이미 있습니다 — `services/`, `screens/`, `example_game.dart`. 플랫폼 공용 계약은 복사하지 않고 `lib/games/template_game.dart`를 import합니다.

## 1. 파일 구조

```
lib/games/<my_game>/
  <my_game>_game.dart        # TemplateGame 구현체 (GameRegistry에 등록할 것)
  <my_game>_copy.dart        # 게임 전용 사용자 문구와 동적 문구 함수
  models/                    # 게임 전용 데이터 클래스 (fromMap 파싱 포함, §3 참고)
  controllers/
    <my_game>_controller.dart          # 기본: phone/tablet 공용 서버 세션
    <my_game>_<device>_controller.dart # 선택: 기기별 조정이 필요한 경우만
  services/
    <my_game>_command_service.dart   # 쓰기 전용 — Cloud Functions httpsCallable
    <my_game>_query_service.dart     # 읽기 전용 — Realtime Database 스트림
    <my_game>_service.dart           # 위 둘을 묶는 파사드
  providers/
    <my_game>_session_provider.dart  # Riverpod NotifierProvider.autoDispose.family
    <my_game>_state.dart             # 불변 상태 클래스 (+ 모델 fromMap)
  screens/
    phone_game.dart             # 휴대폰 진입점
    tablet_game.dart            # 태블릿 진입점
    phone/                      # 휴대폰 화면 구성
      phone_game_screen.dart
    tablet/                     # 태블릿 화면 구성
      tablet_game_stage.dart    # <Game>TabletStage enum
      tablet_game_layer.dart
      tablet_game_overlay.dart
      tablet_game_animation.dart
      tablet_game_helper.dart
  widgets/
    phone/                      # 손패, 턴 전환, 상단바, 타이머, 결과 등
    tablet/                     # 룰북, 설정, 결과 오버레이 등
  animations/                   # 이 게임 전용 애니메이션 (재사용 가능한 건 games/shared/animations 후보)
  loading/                      # (선택) 로딩 화면 팁 문구 등
```

게임 폴더와 `phone/`, `tablet/` 폴더가 이미 범위를 설명하므로 그 안의 파일은
`top_bar.dart`, `turn_timer.dart`, `result.dart`처럼 역할 중심으로 이름을 짓습니다.
공개 화면·컨트롤러 타입에는 반드시 게임 이름을 붙입니다. 예:
`MyGamePhoneGame`, `MyGameTabletGame`, `MyGameController`. `PhoneGame`,
`PhoneGameController`, `GameStatus` 같은 범용 공개 타입은 만들지 않습니다.

라이어스포커와 파이널콜이 이 구조의 실제 예시입니다. `_game_template/`는 이 표준
중 `services/`, `screens/`, `example_game.dart`를 컴파일 가능한 스켈레톤으로
제공하고, 나머지 폴더는 위 트리에 맞춰 게임 요구사항에 따라 추가합니다.

에셋도 같은 규칙을 따릅니다: `assets/games/<my_game>/{animations,images,sounds}`.

진입 연출에 쓰는 `images/layout/layout_table.png`, `layout_chair.png`는 손으로
칠하지 말고 [`tool/README.md`](../../../tool/README.md)의 프롬프트를 쓰세요. 가운데가
투명한 템플릿을 넘기면 그 게임의 `background.png`로 채워 저장합니다. 이 면이
배경과 어긋나면 테이블 줌인이 끝나는 순간 화면이 바뀐 느낌이 납니다.

## 2. Provider / Service 연결 구조

### Command/Query 서비스 분리

모든 게임은 쓰기(Command, Cloud Functions)와 읽기(Query, Realtime Database 스트림)를 분리하고, `XService(command, query)` 파사드로 묶습니다. `_game_template/services/`가 이 모양의 빈 스켈레톤입니다. 새 필드를 노출할 때는 `XQueryService`에 `Stream<DatabaseEvent> watchXxx(roomCode)` 메서드를 추가하세요.

### 세션 Provider + 컨트롤러

`NotifierProvider.autoDispose.family<Controller, State, SessionArgs>`가 표준입니다. `SessionArgs`(roomCode, uid/service 등)를 키로 컨트롤러를 만들고, 컨트롤러의 `build()`에서 `service.query`를 구독해 `ref.onDispose`로 해제합니다.

**컨트롤러 상태 설계 기준** (`lib/games/template_game.dart` 문서 주석과 동일):
- 서버 상태를 미러링하는 컨트롤러는 게임당 **하나**로 통일하고 phone/tablet이 같은 소스를 구독하는 게 기본값입니다(파이널콜 방식).
- 화면 전용 연출·애니메이션 상태는 위젯 로컬(`StatefulWidget`)에 둡니다.
- 화면(주로 태블릿)이 여러 형제 위젯 파일로 쪼개져 그 연출 상태를 공유해야 할 때만(라이어스포커의 `screens/tablet/*` 6개 파일 사례) 서버 상태와 분리된 얇은 오케스트레이션 컨트롤러를 추가로 둡니다.

### DTO/Model 분리

RTDB에서 온 `Map`을 파싱하는 책임은 **모델 클래스 자신**이 `fromMap`(또는 nullable인 경우 `static` 메서드)으로 갖습니다. 컨트롤러는 상태 전이만 담당하고 파싱은 하지 않습니다. 예: `PhoneGamePlayer.fromMap(key, map)`, `FinalCallCard.fromMap(map)`. 별도 "DTO" 클래스를 wire 포맷용으로 또 만들 필요는 없습니다 — 지금 규모에서는 과합니다.

### 플랫폼 연결 지점 (건드릴 필요 없음)

`GameRegistry.games`에 `<MyGame>Game()` 인스턴스 하나만 추가하면 아래는 자동으로 연결됩니다. 게임별 분기 코드를 플랫폼 쪽에 새로 추가하지 마세요:
- `platform/home/phone/screens/phone_room_waiting.dart` — `TemplateGame.watchStatus`/`buildPhoneScreen` 호출
- `platform/home/tablet/widgets/tablet_game_preview_modal.dart` — `TemplateGame.startGame`/`buildTabletScreen` 호출
- `platform/home/room/providers/room_provider.dart` — `leaveGame(gameId)`가 `TemplateGame.leaveFunctionName`으로 라우팅

## 3. 화면 흐름 — 공용 셸(PhoneGameShell) 표준

**휴대폰 화면 분기는 직접 짜지 마세요.** 게임마다 다시 짜다가 진입 연출 순서와
퇴장 버튼이 어긋났고, 실제로 "손패를 모두 제출하면 상단바가 사라져 게임에서
나갈 수 없는" 버그가 났습니다. 이제 `shared/game_flow/`의 두 파일이 표준입니다.

### 3.1 게임이 하는 일은 "번역" 하나뿐

`shared/game_flow/game_screen_phase.dart`의 `GameScreenPhase` 6단계로 서버 상태를
번역하는 함수 하나만 만들면 됩니다.

| 단계 | 화면 | 상단바·퇴장 |
|---|---|---|
| `connecting` | 배경만 | 감춤 (아직 게임에 들어오지 않음) |
| `intro` | `GAME START` | 감춤 |
| `roundIntro` | `ROUND N` | 감춤 |
| `playing` | 게임 진행 화면 | **항상 표시** |
| `result` | 결과 화면 | 표시 |
| `closing` | 종료 안내 문구 | 감춤 (곧 자동 퇴장) |

```dart
GameScreenPhase _resolvePhase(MyController game) {
  if (game.loading) return GameScreenPhase.connecting;
  if (game.isFinished && game.finishReason == 'insufficientPlayers') {
    return GameScreenPhase.closing;
  }
  if (!gameStartCompleted) return GameScreenPhase.intro;
  if (announcedRound != game.round) return GameScreenPhase.roundIntro;
  if (game.isFinished) return GameScreenPhase.result;
  return GameScreenPhase.playing;
}
```

> **중요**: 손패가 비거나 서버 응답을 기다리는 순간을 `connecting`이나 별도
> 분기로 빼지 마세요. 게임이 시작된 뒤라면 전부 `playing`입니다. 그릴 내용이
> 없으면 `contentReady: false`를 넘기면 됩니다 — 셸이 배경만 그리면서
> **상단바(퇴장)는 유지**합니다.

#### 게임이 끝났을 때 나갈지 남을지

태블릿이 게임을 끝내면 휴대폰도 게임 화면을 닫아야 합니다. 이 판단은
`shared/game_flow/game_finish.dart`의 `isNaturalGameResult()`로 하세요.

```dart
final shouldCloseGame = game.isFinished && !game.isNaturalResult;
```

**나가야 하는 사유를 나열하지 마세요.** `finishReason == 'manual' || ...` 식으로
쓰면 서버에 종료 사유가 하나만 늘어도 휴대폰이 결과 화면에 갇힙니다. 파이널콜이
실제로 이 문제를 겪었습니다. 대신 서버가 지키는 불변 조건을 그대로 씁니다.

> **승부가 나지 않은 모든 종료는 `winnerUid`를 null로 만들고 `finishReason`을 남긴다.**

새 게임의 Cloud Functions도 이 불변 조건을 지켜야 합니다. 마지막 생존자를 확정할
때만 `winnerUid`를 채우고, 수동 종료·인원 부족·투표 만료에서는 반드시 null로
비우세요.

### 3.2 셸에 넘기는 것

```dart
PhoneGameShell(
  phase: _resolvePhase(game),
  roundNumber: game.round,
  background: <게임 배경>,
  topBar: <SharedPhoneGameTopBar로 만든 상단바>,   // 표시 시점은 셸이 제어
  content: <진행 화면>,
  result: <결과 화면>,
  contentReady: game.hand.isNotEmpty,             // 그릴 내용이 있는지
  contentRevealed: revealedRound == game.round,   // 손패 펼치기가 끝났는지
  onIntroCompleted: ...,
  onRoundIntroCompleted: ...,
)
```

- `contentRevealed`가 false면 상단바를 아직 띄우지 않습니다. 카드 펼치는 도중에
  상단바가 먼저 나타나 연출이 깨지는 걸 막습니다. 공개 단계가 없는 게임은
  기본값(true)을 그대로 두세요.
- 상단바는 화면 위에 겹쳐 그려집니다. 진행 화면은 같은 높이(보통 52)를 빈
  공간으로 남겨 두세요 — 그래야 상단바가 나타나도 카드 위치가 밀리지 않습니다.
  (파이널 콜의 `finalCallPhoneTopBarHeight` 참고)

### 3.3 등장 연출은 이미 붙어 있음

셸이 `GameEntryUnroll`(진입 매트) → `PhoneGameStartAnimation` → `FadeHoldFade`
(ROUND N) → `PhoneControlEntryAnimation`(상단바) 순으로 자동 재생합니다. 새
애니메이션을 만들지 말고 이 흐름에 얹으세요.

### 3.4 태블릿

태블릿도 게임별 typed stage enum과 exhaustive switch를 사용합니다. Liar's Poker의
`LiarsPokerTabletStage`, `FinalCallTabletStage`처럼 서버 phase 문자열을 화면
진입점에서 한 번만 번역하세요. 하위 layer가 서버 문자열을 다시 해석하면 안 됩니다.
보드 요소 등장은 `shared/animations/board_element_entrance.dart`를 재사용합니다.

### 3.5 두 게임의 현재 위치

| | 라이어스 포커 | 파이널 콜 |
|---|---|---|
| 휴대폰 | 자체 슬롯 방식 (셸 미적용, 안정적이라 유지) | **셸 적용 완료 — 참고 구현** |
| 태블릿 | `LiarsPokerTabletStage` enum + switch | `FinalCallTabletStage` enum + switch |

새 게임은 **휴대폰은 파이널 콜, 태블릿은 라이어스 포커**를 참고하세요.

## 4. 애니메이션 카탈로그

**공용으로 재사용되는 애니메이션/위젯** (`games/shared/`에 있으며, 새 게임도 바로 import해서 재사용하면 됩니다):

| 파일 | 클래스 | 트리거 | 시간 | 목적 |
|---|---|---|---|---|
| `shared/animations/phone_game_start_animation.dart` | `PhoneGameStartAnimation` | 게임 진입/첫 손패 준비 완료 | 1700ms | `'GAME START'` 등장→퇴장 |
| `shared/animations/fade_hold_fade.dart` | `FadeHoldFade` | `'ROUND N'`, 테이블명, 판정 문구 등 모든 짧은 텍스트 안내 | 1900ms(기본, 판정은 2900ms) | Fade In → Hold → Fade Out 공용 텍스트 연출 |
| `shared/animations/card_deal.dart` | `CardDealAnimation` | 태블릿 `dealing` phase | 2800ms | 중앙 덱 → 좌석 카드 배분 |
| `shared/widgets/phone_result_dialog.dart` | `PhoneResultDialog` | 최종 승자 확정 | — | 왕관 + 우승자 프로필 다이얼로그 |
| `shared/animations/mat_unroll_animation.dart` | `MatUnrollAnimation` | 게임 진입(셸이 자동) / 종료 시 화면 전환 | 900ms / 820ms(역재생) | 매트를 감고 펼치는 화면 마스킹 |
| `shared/animations/game_entry_unroll.dart` | `GameEntryUnroll` | 게임 화면 진입 (셸이 자동 적용) | 900ms | 태블릿 테이블 확대와 맞춘 배경 등장 |
| `shared/animations/board_element_entrance.dart` | `BoardEntranceCurves` | 태블릿 보드 요소 등장 | 980ms | 바닥에서 솟아오르는 공통 곡선 |
| `shared/animations/phone_card_receive_animation.dart` | `PhoneCardReceiveAnimation` | 휴대폰 손패 수신 | 게임별 설정 | 카드팩 진입·탭·공개·펼치기 |
| `shared/animations/phone_control_entry_animation.dart` | `PhoneControlEntryAnimation` | 손패 공개 완료 후 | 920ms | 상단바·조작부 순차 등장 |
| `shared/widgets/game_announcement_layer.dart` | `GameAnnouncementLayer` | 모든 문구 단계 | 모델별 | GAME START·ROUND·상태·판정의 고정 슬롯 |
| `shared/widgets/game_interruption_layer.dart` | `GameInterruptionLayer` | 플레이어 연결 끊김·퇴장 | 60초 | 전체 화면 암전·프로필·재접속 대기·제외 진행 |
| `shared/animations/one_shot_timeline.dart` | `OneShotTimeline` | 복합 일회성 연출 | 주입 | controller 시작·완료·dispose 공통 수명주기 |

> **참고**: `CardDealAnimation`의 기본 카드 뒷면 에셋과 `PhoneResultDialog`의 왕관 테두리 에셋은 여전히 `Assets.games.liarsPoker...` 경로를 참조합니다(코드 위치만 옮겼고 에셋 파일 자체와 `assets.gen.dart` 생성 결과는 건드리지 않았습니다). `CardDealAnimation`은 `cardAsset` 파라미터로 다른 게임의 카드 뒷면을 넘길 수 있지만, `PhoneResultDialog`의 왕관 이미지는 아직 파라미터화되어 있지 않아 모든 게임의 결과 화면에 라이어스포커 왕관이 그대로 노출됩니다. 다른 게임 전용 왕관 이미지가 필요해지면 이 위젯에 이미지 파라미터를 추가하세요.

**게임 전용 애니메이션** (직접 만들어야 함, 참고용):

| 게임 | 파일:클래스 | 트리거 | 시간 | 목적 |
|---|---|---|---|---|
| 라이어스포커 | `tablet_round_start_reveal.dart:RoundStartReveal` | tablet 라운드 시작 | 980ms | 테이블·잔여카드·턴조명 등장 |
| 라이어스포커 | `tablet_card_play_animation.dart:CardPlayAnimation` | 카드 제출/라이어 공개 | throw 540ms/장, reveal 900ms | 좌석→중앙 투척 및 뒤집기 |
| 파이널콜 | `animations/tablet_center_card_reveal.dart:FinalCallCenterCardReveal` | 라운드 중/결과 중 중앙 카드 | 680ms(+400ms 딜레이) | 덱→공개카드 뒤집기 이동 |
| 파이널콜 | `tablet_game_animation.dart:FinalCallTabletCallAnimation` | CALL 선언 | 상태 지속 | CALL 말풍선 유지 |
| 파이널콜 | `tablet_game_animation.dart:FinalCallTabletDiscardAnimation` | 카드 버림 이벤트 | 760ms | 버린 카드 포물선 던지기 |

## 5. 문구 컨벤션

문구는 `GameAnnouncement`로 만들고 화면 `Stack`의 `GameAnnouncementLayer` 한 슬롯에
전달합니다. `GAME START`, `ROUND N`, 지속 상태, 일회성 판정은 같은 렌더러를 쓰되
`GameAnnouncementKind`와 `GameAnnouncementTone`으로 의미를 구분합니다. 공통 문구는
`GameFlowCopy`, 게임 문구는 `<game>_copy.dart`가 소유합니다. 문자열 값으로 색상을
판단하지 마세요.

문구별 시간은 `GameAnnouncement.duration`, 레이어 전체 시간은
`GameAnnouncementLayer.displayDuration`, 공용 휴대폰 셸의 시작·라운드 시간은
`gameStartAnnouncementDuration`과 `roundAnnouncementDuration`으로 설정합니다.

화면 조작이 필요 없는 안내는 `GameAnnouncement(showScrim: true)`로 암전할 수 있으며
이 경우에도 포인터는 항상 게임 UI로 통과합니다. 연결 끊김처럼 게임을 멈추고 투표를
받아야 하는 상태는 별도 공용 모델 `GameInterruption`과
`GameInterruptionLayer`를 사용합니다. 새 게임은 `game/public/interruption`을 세션
컨트롤러에서 파싱하고 `GameInterruptionCommandService`로만 투표·제외·만료 명령을
보냅니다. 화면 위젯에서 RTDB를 별도로 구독하거나 게임 상태를 직접 쓰지 마세요.

태블릿은 `GameInterruptionPresentation.tabletController`를 사용합니다. 서버는
중단 시 턴 타이머를 멈추고 60초 동안 같은 UID의 재접속을 기다립니다. 재접속하면
남은 턴 시간을 복원하고, 만료되면 해당 게임의 최소 인원을 확인해 플레이어를 제외한
뒤 계속하거나 `insufficientPlayers`로 종료합니다. `제외하고 계속하기` 버튼은
`canContinue`일 때만 활성화합니다.

- **톤**: 기본은 존댓말 평서형(`~습니다/~해주세요/~하세요`). 3인칭 대상은 `~님` 존칭(`'$turnNickname님의 결정을 기다리는 중'`, `'$winner님이 승리했습니다'`).
- **판정처럼 게임적 임팩트가 필요한 순간만 예외**: 짧은 영문 라벨(`'SURVIVED'`/`'FAIL'`) 또는 느낌표(`'간파 성공!'`/`'간파 실패!'`) — 단, 같은 판정이라도 당사자에게는 서술형 마침표(`'거짓이 밝혀졌습니다.'`)를 씁니다. 청중(도전자 vs 당사자)에 따라 톤이 갈리는 걸 참고하세요.
- **연출용 영문 대문자 텍스트**(`'GAME START'`, `'ROUND N'`, `'WINNER'`, `'FINAL CALL'`)는 BebasNeue 폰트로 한글 문구와 분리해서 순수 연출용으로만 사용합니다.
- **버튼 라벨**: 2~4자 한글 동사형(`'제출'`, `'교체'`, `'다시하기'`, `'나가기'`, `'닫기'`) 또는 게임 고유 영문 명령(`'CALL'`, `'FOLD'`).
- **에러/토스트**: 정중한 완료형 문장(`'게임에서 퇴장하지 못했습니다.'`, `'게임 정보를 불러오지 못했습니다: $error'`).
- **규칙 설명(룰북)**: 격식체(`~합니다/~됩니다`), 굵게 강조는 마크다운 스타일(`**CALL**`, `**3개**`).

## 6. 새 게임 추가 체크리스트

1. `_game_template/` 폴더 구조를 `games/<my_game>/`로 복사하고 `template`/`Template`을 게임 id로 바꿉니다.
2. `<my_game>_game.dart`에서 `TemplateGame`을 구현합니다 — `id`, `title`, `leaveFunctionName`, `phoneOrientation`, `startGame`, `watchStatus`, `buildPhoneScreen`, `buildTabletScreen`. `phoneOrientation`은 휴대폰 정책만 선언합니다. **모든 태블릿 게임은 예외 없이 가로 고정**이므로 태블릿용 게임별 방향 옵션을 추가하지 마세요.
3. `services/`에 실제 Cloud Function 이름(Command)과 RTDB 경로(Query)를 채웁니다.
4. `providers/`에 `XSessionArgs` + `NotifierProvider.autoDispose.family` 컨트롤러를 만들고, §2의 상태 설계 기준에 따라 phone/tablet을 하나로 할지 나눌지 정합니다.
5. **휴대폰**: `screens/phone_game.dart`에서 `AppOrientation.applyPhoneGame(phoneOrientation)`을 적용하고 `_resolvePhase()`(§3.1)만 작성한 뒤 나머지는 `PhoneGameShell`에 넘깁니다. 화면 분기·퇴장 버튼·진입 연출을 직접 만들지 마세요. **태블릿**: 진입 즉시 `AppOrientation.lockTabletGameLandscape()`를 적용하고 `<Game>TabletStage` enum + `switch`(§3.4)로 구성합니다. §4의 공용 애니메이션을 먼저 재사용할 수 있는지 확인하세요.
6. 모델 클래스에 `fromMap`을 직접 두고, 컨트롤러는 파싱하지 않습니다(§2 DTO/Model 원칙).
7. `lib/games/game_registry.dart`의 `GameRegistry.games`에 `const <MyGame>Game()`을 추가합니다 — 플랫폼 쪽 코드는 수정하지 않습니다.
8. Firestore `games` 컬렉션에 게임 메타데이터 문서(이름/설명/인원/이미지 등)를 추가합니다.
9. `GameInterruption`을 공개 상태에 연결하고 휴대폰·태블릿 최상위 `Stack`에
   `GameInterruptionLayer`를 둡니다. 서버에는 해당 게임의 플레이어 제외·다음 턴
   어댑터를 연결합니다.
10. `flutter analyze` 통과 확인 후 기기에서 방 생성 → 시작 → 진행 → 연결 끊김 →
    재연결 → 퇴장 → 계속 진행 투표까지 수동 스모크 테스트.
