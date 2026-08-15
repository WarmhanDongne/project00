# 새 게임 추가 가이드

이 문서는 라이어스포커(`liars_poker`, 가장 완성된 참고 게임)와 파이널콜(`final_call`, 두 번째 참고 게임)을 실제로 조사해서 정리한, 새 게임을 만들 때 따라야 할 파일 구조·서비스/프로바이더 연결·화면 흐름·애니메이션·문구 컨벤션입니다. 복사해서 시작할 스캐폴드는 이 폴더(`_game_template/`)에 이미 있습니다 — `template_game.dart`, `services/`, `screens/`, `example_game.dart`.

## 1. 파일 구조

```
lib/games/<my_game>/
  <my_game>_game.dart        # TemplateGame 구현체 (GameRegistry에 등록할 것)
  models/                    # 게임 전용 데이터 클래스 (fromMap 파싱 포함, §3 참고)
  services/
    <my_game>_command_service.dart   # 쓰기 전용 — Cloud Functions httpsCallable
    <my_game>_query_service.dart     # 읽기 전용 — Realtime Database 스트림
    <my_game>_service.dart           # 위 둘을 묶는 파사드
  providers/
    <my_game>_session_provider.dart  # Riverpod NotifierProvider.autoDispose.family
    <my_game>_state.dart             # 불변 상태 클래스 (+ 모델 fromMap)
  screens/
    <my_game>.dart              # (선택) phone/tablet LayoutBuilder 조합 위젯
    phone_game.dart             # 휴대폰 진입점
    tablet_game.dart            # 태블릿 진입점
    phone/                      # 휴대폰 컨트롤러 + 화면
    tablet/                     # 태블릿 컨트롤러 + 레이어별 화면(layer/overlay/animation/helper/penalty...)
  widgets/
    phone/                      # 손패, 턴 전환, 상단바, 타이머, 결과 등
    tablet/                     # 룰북, 설정, 결과 오버레이 등
  animations/                   # 이 게임 전용 애니메이션 (재사용 가능한 건 games/shared/animations 후보)
  loading/                      # (선택) 로딩 화면 팁 문구 등
```

라이어스포커가 이 구조를 가장 완전하게 채운 예시이고, 파이널콜은 `models/`(대신 `models/final_call_models.dart` 단일 파일)와 `repositories/`가 없는 축약형입니다. `_game_template/`는 이 표준 구조 중 `services/`, `screens/`, `example_game.dart`만 실제로 컴파일되는 스켈레톤으로 채워뒀습니다 — 복사해서 이름만 바꾸면 됩니다.

에셋도 같은 규칙을 따릅니다: `assets/games/<my_game>/{animations,images,sounds}`.

## 2. Provider / Service 연결 구조

### Command/Query 서비스 분리

모든 게임은 쓰기(Command, Cloud Functions)와 읽기(Query, Realtime Database 스트림)를 분리하고, `XService(command, query)` 파사드로 묶습니다. `_game_template/services/`가 이 모양의 빈 스켈레톤입니다. 새 필드를 노출할 때는 `XQueryService`에 `Stream<DatabaseEvent> watchXxx(roomCode)` 메서드를 추가하세요.

### 세션 Provider + 컨트롤러

`NotifierProvider.autoDispose.family<Controller, State, SessionArgs>`가 표준입니다. `SessionArgs`(roomCode, uid/service 등)를 키로 컨트롤러를 만들고, 컨트롤러의 `build()`에서 `service.query`를 구독해 `ref.onDispose`로 해제합니다.

**컨트롤러 상태 설계 기준** (`template_game.dart` 문서 주석과 동일):
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

## 3. 화면 흐름 (6단계)

두 게임을 실제로 플레이 순서대로 조사한 결과입니다. 모든 게임이 6단계를 똑같이 다 가질 필요는 없습니다(파이널콜은 좌석배치가 없음) — 자기 게임에 맞게 생략/합칠 수 있습니다.

| 단계 | 라이어스포커 | 파이널콜 |
|---|---|---|
| **준비화면** | `GameLoadingScreen`(공용, `shared/widgets/game_loading_screen.dart`)이 phone/tablet 공통 진입점. `prepare`로 초기 상태·손패·이미지를 준비하는 동안 `MatUnrollAnimation`으로 감싼 로딩 매트를 최소 2초 유지. 태블릿은 대기 중 `'게임 시작 대기 중'` 표시 | 별도 로딩 화면 없음. `game.loading \|\| hand.isEmpty` 동안 배경 이미지만 띄운 빈 화면으로 대기. 좌석배치(`playerLayout`) 자체를 쓰지 않음 |
| **시작화면** | phone: `PhoneGameStartAnimation`(`'GAME START'`, 1.7초) → `PhoneCardReceiveAnimation`(손패 진입). tablet: `CardDealAnimation`(2.8초, 중앙덱→좌석), 2라운드부터는 `FadeHoldFade`로 `'ROUND N'` 먼저 표시 | phone: liars_poker의 `PhoneGameStartAnimation` 재사용 → `FadeHoldFade`로 `'ROUND N'`. tablet: 별도 연출 없이 `CardDealAnimation`(liars_poker 재사용)이 시작 겸 딜 연출 |
| **진행화면** | tablet: `RoundStartReveal`(980ms)이 테이블 랭크·잔여 카드 수·턴 조명 등장. phone: 상단바 + `controller.statusMessage` + `TurnActionSwitcher`(내 턴/남 턴 슬라이드 전환) | phone: 손패 + `FinalCallTurnActionSwitcher` 좌우 분할, 상단바(생명·룰북·퇴장). tablet: 중앙 덱/공개카드 + 좌석별 생명을 원형 배치 |
| **선택화면** | phone: `PhoneHandCardStack`에서 탭 선택(최대 3장) → 위로 드래그 제출. `LiarAccusation` 버튼이 'Liar'↔'제출' 플립. tablet: 제출 카드는 `CardPlayAnimation`으로 좌석→중앙 투척 | phone: CALL/새 카드 버튼 → `FinalCallCardChangeDialog`(덱/공개카드 선택) → 교체 확정. CALL 후 마지막 턴은 자동으로 다이얼로그가 열림. tablet: 선택 UI 없음(관전), CALL 위치에 말풍선만 표시 |
| **판정화면** | LIAR 선언 시 `CardPlayAnimation.reveal()`(900ms 플립)로 카드 공개. phone은 1초 지연 후 `liarVerdictMessage`를 `FadeHoldFade`(2900ms)로 표시. tablet은 `TabletGamePenalty`가 룰렛 표시 | CALL 이후 `_FinalSubmitAction`에서 조합 선택 후 제출. 카드 공개·점수 계산은 태블릿 전용 — `_RevealedTable`이 플레이어 순서대로 카드 플립+점수+생명 소멸을 순차 재생 |
| **결과화면** | phone: `PhonePenaltyStatus`(생존/탈락 스탬프) → 최종 승자는 `PhoneResultDialog`(왕관). tablet: `Result`(`'다시하기'`/`'나가기'`). 종료 시 `MatUnrollAnimation` 역재생 후 방으로 복귀 | phone: 태블릿 공개 연출이 끝날 때까지 대기 후 `PhoneResultDialog`(liars_poker 재사용). tablet: `FinalCallResultOverlay`(`'다시하기'`/`'홈으로'`) |

## 4. 애니메이션 카탈로그

**공용으로 재사용되는 애니메이션/위젯** (`games/shared/`에 있으며, 새 게임도 바로 import해서 재사용하면 됩니다):

| 파일 | 클래스 | 트리거 | 시간 | 목적 |
|---|---|---|---|---|
| `shared/animations/phone_game_start_animation.dart` | `PhoneGameStartAnimation` | 게임 진입/첫 손패 준비 완료 | 1700ms | `'GAME START'` 등장→퇴장 |
| `shared/animations/fade_hold_fade.dart` | `FadeHoldFade` | `'ROUND N'`, 테이블명, 판정 문구 등 모든 짧은 텍스트 안내 | 1900ms(기본, 판정은 2900ms) | Fade In → Hold → Fade Out 공용 텍스트 연출 |
| `shared/animations/card_deal.dart` | `CardDealAnimation` | 태블릿 `dealing` phase | 2800ms | 중앙 덱 → 좌석 카드 배분 |
| `shared/widgets/phone_result_dialog.dart` | `PhoneResultDialog` | 최종 승자 확정 | — | 왕관 + 우승자 프로필 다이얼로그 |
| `shared/animations/mat_unroll_animation.dart` | `MatUnrollAnimation` | 로딩 완료 / 게임 종료 시 화면 전환 | 900ms / 820ms(역재생) | 매트를 감고 펼치는 화면 마스킹 |

> **참고**: `CardDealAnimation`의 기본 카드 뒷면 에셋과 `PhoneResultDialog`의 왕관 테두리 에셋은 여전히 `Assets.games.liarsPoker...` 경로를 참조합니다(코드 위치만 옮겼고 에셋 파일 자체와 `assets.gen.dart` 생성 결과는 건드리지 않았습니다). `CardDealAnimation`은 `cardAsset` 파라미터로 다른 게임의 카드 뒷면을 넘길 수 있지만, `PhoneResultDialog`의 왕관 이미지는 아직 파라미터화되어 있지 않아 모든 게임의 결과 화면에 라이어스포커 왕관이 그대로 노출됩니다. 다른 게임 전용 왕관 이미지가 필요해지면 이 위젯에 이미지 파라미터를 추가하세요.

**게임 전용 애니메이션** (직접 만들어야 함, 참고용):

| 게임 | 파일:클래스 | 트리거 | 시간 | 목적 |
|---|---|---|---|---|
| 라이어스포커 | `round_start_reveal.dart:RoundStartReveal` | tablet 라운드 시작 | 980ms | 테이블·잔여카드·턴조명 등장 |
| 라이어스포커 | `card_play_animation.dart:CardPlayAnimation` | 카드 제출/라이어 공개 | throw 540ms/장, reveal 900ms | 좌석→중앙 투척 및 뒤집기 |
| 라이어스포커 | `phone_card_receive_animation.dart:PhoneCardReceiveAnimation` | phone 손패 배분 | 2200ms(분할) | 손패 진입·회전 공개 |
| 라이어스포커 | `phone_control_entry_animation.dart:PhoneControlEntryAnimation` | 손패 공개 완료 후 | 920ms(구간분할) | 상단바·버튼 순차 등장 |
| 파이널콜 | `animations/tablet_center_card_reveal.dart:FinalCallCenterCardReveal` | 라운드 중/결과 중 중앙 카드 | 680ms(+400ms 딜레이) | 덱→공개카드 뒤집기 이동 |
| 파이널콜 | `tablet_game_animation.dart:FinalCallTabletCallAnimation` | CALL 선언 | 상태 지속 | CALL 말풍선 유지 |
| 파이널콜 | `tablet_game_animation.dart:FinalCallTabletDiscardAnimation` | 카드 버림 이벤트 | 760ms | 버린 카드 포물선 던지기 |

## 5. 문구 컨벤션

- **톤**: 기본은 존댓말 평서형(`~습니다/~해주세요/~하세요`). 3인칭 대상은 `~님` 존칭(`'$turnNickname님의 결정을 기다리는 중'`, `'$winner님이 승리했습니다'`).
- **판정처럼 게임적 임팩트가 필요한 순간만 예외**: 짧은 영문 라벨(`'SURVIVED'`/`'FAIL'`) 또는 느낌표(`'간파 성공!'`/`'간파 실패!'`) — 단, 같은 판정이라도 당사자에게는 서술형 마침표(`'거짓이 밝혀졌습니다.'`)를 씁니다. 청중(도전자 vs 당사자)에 따라 톤이 갈리는 걸 참고하세요.
- **연출용 영문 대문자 텍스트**(`'GAME START'`, `'ROUND N'`, `'WINNER'`, `'FINAL CALL'`)는 BebasNeue 폰트로 한글 문구와 분리해서 순수 연출용으로만 사용합니다.
- **버튼 라벨**: 2~4자 한글 동사형(`'제출'`, `'교체'`, `'다시하기'`, `'나가기'`, `'닫기'`) 또는 게임 고유 영문 명령(`'CALL'`, `'PASS'`).
- **에러/토스트**: 정중한 완료형 문장(`'게임에서 퇴장하지 못했습니다.'`, `'게임 정보를 불러오지 못했습니다: $error'`).
- **규칙 설명(룰북)**: 격식체(`~합니다/~됩니다`), 굵게 강조는 마크다운 스타일(`**CALL**`, `**3개**`).

## 6. 새 게임 추가 체크리스트

1. `_game_template/` 폴더 구조를 `games/<my_game>/`로 복사하고 `template`/`Template`을 게임 id로 바꿉니다.
2. `<my_game>_game.dart`에서 `TemplateGame`을 구현합니다 — `id`, `title`, `leaveFunctionName`, `startGame`, `watchStatus`, `buildPhoneScreen`, `buildTabletScreen`.
3. `services/`에 실제 Cloud Function 이름(Command)과 RTDB 경로(Query)를 채웁니다.
4. `providers/`에 `XSessionArgs` + `NotifierProvider.autoDispose.family` 컨트롤러를 만들고, §2의 상태 설계 기준에 따라 phone/tablet을 하나로 할지 나눌지 정합니다.
5. §3의 6단계 중 이 게임에 필요한 화면만 골라 `screens/phone/`, `screens/tablet/`을 채웁니다. §4의 공용 애니메이션(`PhoneGameStartAnimation`, `FadeHoldFade`, `CardDealAnimation`, `PhoneResultDialog`, `MatUnrollAnimation`)을 먼저 재사용할 수 있는지 확인하세요.
6. 모델 클래스에 `fromMap`을 직접 두고, 컨트롤러는 파싱하지 않습니다(§2 DTO/Model 원칙).
7. `lib/games/game_registry.dart`의 `GameRegistry.games`에 `const <MyGame>Game()`을 추가합니다 — 플랫폼 쪽 코드는 수정하지 않습니다.
8. Firestore `games` 컬렉션에 게임 메타데이터 문서(이름/설명/인원/이미지 등)를 추가합니다.
9. `flutter analyze` 통과 확인 후 기기에서 방 생성 → 시작 → 진행 → 퇴장까지 수동 스모크 테스트.
