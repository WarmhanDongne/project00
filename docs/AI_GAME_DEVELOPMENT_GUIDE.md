# Project00 AI 게임 개발 컨텍스트

> 대상 독자: 이 저장소를 처음 접한 코딩 AI.
>
> 목적: 저장소를 다시 전체 탐색하지 않고도 플랫폼과 게임의 경계, 실시간 데이터,
> 상태 머신, 애니메이션, 중간 문구, 새 게임 추가 지점을 정확히 파악하게 한다.
>
> 기준: 2026-08-17의 실제 코드. 이 문서와 코드가 충돌하면 **코드와 Cloud Functions
> 타입을 우선**하고, 확인한 차이를 이 문서에도 반영한다.

---

## 0. 가장 먼저 알아야 할 결론

Project00은 태블릿이 공용 보드와 진행자 역할을 하고, 각 휴대폰이 자신의 비공개
손패와 행동 UI를 담당하는 Flutter + Firebase 멀티 디바이스 보드게임 플랫폼이다.

```text
Firestore             게임 카탈로그, 사용자 프로필, 보유 게임
Firebase Auth         모든 기기의 안정적인 UID
Realtime Database     방, 참가자, 진행 중 게임의 실시간 상태
Cloud Functions       게임 규칙, 턴 검증, 카드 이동, 승패의 유일한 권위
Flutter/Riverpod      서버 상태를 화면용 불변 스냅샷으로 변환
StatefulWidget        애니메이션 재생 순서와 일시적인 UI 상태
```

가장 중요한 규칙은 다음 한 문장이다.

> **서버가 게임을 결정하고, Provider가 서버 상태를 번역하며, 위젯은 그 상태를
> 연출한다.**

클라이언트가 RTDB 게임 노드를 직접 수정하거나, 애니메이션 완료만으로 승패를
결정하거나, 위젯에서 같은 경로를 중복 구독하지 않는다.

---

## 1. 기술 스택과 런타임

| 영역 | 현재 기술 | 역할 |
|---|---|---|
| 앱 | Flutter / Dart | 휴대폰·태블릿 공용 앱 |
| 게임 상태 | `flutter_riverpod` | 게임 세션별 불변 상태와 수명주기 |
| 플랫폼 상태 | `provider`/`ChangeNotifier` | `RoomProvider`, 사운드 등 기존 플랫폼 상태 |
| 인증 | Firebase Auth, Google Sign-In | UID, 로그인, 익명/Google 인증 기반 접근 |
| 카탈로그 | Cloud Firestore | `games`, `users` 문서 |
| 실시간 상태 | Firebase Realtime Database | `rooms/{code}`와 게임 상태 스트림 |
| 명령 | Cloud Functions v2 callable | 검증된 원자적 게임 변경 |
| 백엔드 | TypeScript, Node 22 | 게임별 함수와 RTDB transaction |
| 에셋 | FlutterGen | `Assets.games...` 타입 안전 접근 |

Cloud Functions와 Flutter callable 리전은 모두 `asia-northeast3`이다. 다른 리전을
사용하면 함수가 없는 것처럼 보이거나 지연이 커질 수 있다.

---

## 2. 저장소 지도

```text
project00/
├── AGENTS.md                         # AI가 먼저 읽는 작업 규칙
├── docs/
│   ├── AI_GAME_DEVELOPMENT_GUIDE.md  # 이 문서
│   └── PROJECT_STRUCTURE.md          # 초기 일반 구조 문서(일부 내용은 오래됨)
├── assets/
│   ├── games/<game_id>/              # 게임별 이미지
│   ├── fonts/                        # BebasNeue, DigitalTimer
│   └── images/                       # 플랫폼/공용 이미지
├── lib/
│   ├── main.dart                     # Firebase, ProviderScope, SoundProvider 초기화
│   ├── core/
│   │   ├── app/app.dart              # Auth 상태에 따른 Login/Register/Home 진입
│   │   └── layout/                   # 기기 판별과 방향 정책
│   ├── firebase/                     # FlutterFire 공용 인스턴스/설정
│   ├── platform/                     # 로그인, 홈, 방, 게임 목록, 플랫폼 테마
│   ├── games/
│   │   ├── game_registry.dart        # 런타임 게임 등록 목록
│   │   ├── _game_template/           # 새 게임 스캐폴드와 상세 README
│   │   ├── shared/                   # 여러 게임이 공유하는 흐름/UI/애니메이션
│   │   ├── liars_poker/              # 완성도가 가장 높은 복합 예시
│   │   ├── final_call/                # 공용 PhoneGameShell 적용 예시
│   │   ├── mafia/                     # 현재 UI/애니메이션 테스트 중심, 정식 등록 아님
│   │   └── penalty/roulette.dart      # 프런트 룰렛 결과
│   └── gen/assets.gen.dart            # 생성 파일, 직접 수정 금지
├── functions/
│   ├── src/index.ts                   # 배포 함수 export 진입점
│   ├── src/room/                      # 방 생성/입장/자리 저장
│   ├── src/liars-poker/               # Liar's Poker 서버 상태 머신
│   └── src/final-call/                 # Final Call 서버 상태 머신
├── database.rules.json                # public/private/server 읽기 경계
├── firestore.rules
└── pubspec.yaml                       # 의존성, 에셋, FlutterGen, 폰트
```

### 2.1 파일을 어디에 둘지 결정하는 규칙

```text
한 게임에서만 사용       -> lib/games/<game_id>/
둘 이상의 게임이 사용     -> lib/games/shared/
로그인·홈·방·카탈로그      -> lib/platform/
기기/환경/앱 기반          -> lib/core/
서버 규칙                 -> functions/src/<game_id>/
게임 이미지               -> assets/games/<game_id>/
```

처음부터 공용화하지 않는다. 한 게임 내부에 두고, 실제 두 번째 사용처가 생겼을 때
파라미터화해서 `games/shared`로 이동한다.

---

## 3. 앱과 플랫폼 진입 흐름

### 3.1 앱 부팅

```text
main.dart
  ├─ WidgetsFlutterBinding.ensureInitialized
  ├─ 기기 크기로 phone/tablet 판별
  ├─ 플랫폼 기본 방향 잠금
  │    phone  -> portrait
  │    tablet -> landscape
  ├─ Firebase.initializeApp
  ├─ GoogleSignIn.initialize
  └─ ProviderScope
       └─ ChangeNotifierProvider<SoundProvider>
            └─ App
```

`App`은 `FirebaseAuth.userChanges()`를 본다.

```text
인증 확인 중 -> 로딩
로그인 없음  -> LoginScreen
displayName 없음 -> RegisterScreen
로그인 완료  -> Home
```

`MaterialApp.builder`는 `core/network/AppNetworkGuard`로 Navigator 전체를 감싼다.
이 레이어가 RTDB `.info/connected`를 앱에서 한 번만 구독하고, 2초 이상 실제 서버
연결이 끊기면 로그인·플랫폼·게임·dialog보다 위에 같은 `NetworkUnavailableModal`을
표시한다. 재연결되면 즉시 닫히고 `재시도`는 RTDB 연결을 다시 온라인으로 요청한다.
개별 게임이나 플랫폼 화면에 별도 연결 배너·구독을 추가하지 않는다. 모달은
`DeviceLayout.tabletBreakpoint`와 사용 가능한 높이를 함께 확인해 휴대폰 세로,
휴대폰 가로, 태블릿에서 크기를 조정한다.

`Home`은 `DeviceLayout.tabletBreakpoint == 600`을 기준으로 `PhoneHome` 또는
`TabletHome`을 선택한다.

### 3.2 플랫폼 방향 정책

파일: `lib/core/layout/app_orientation.dart`

| 화면/게임 | 방향 |
|---|---|
| 휴대폰 플랫폼(로그인·홈·방) | 세로 고정 |
| 태블릿 플랫폼 | 가로 고정 |
| **모든 태블릿 게임** | **항상 좌/우 가로 고정(게임별 예외 금지)** |
| Liar's Poker 휴대폰 | 세로 + 좌/우 가로 허용 |
| Final Call 휴대폰 | 좌/우 가로 고정 |

새 게임은 `TemplateGame.phoneOrientation`에 **휴대폰 방향만** 선언한다. 태블릿
게임은 반드시 `AppOrientation.lockTabletGameLandscape()`를 사용하며, 휴대폰용
`AppOrientation.applyPhoneGame()`을 태블릿 화면에서 호출하지 않는다. 이 조건은
iOS 태블릿에서 회전 상태 충돌로 검은 화면이 생기는 것을 막는 불변 조건이다.

`Info.plist`의 iPad 방향 목록은 iPadOS 26 scene 요구사항에 맞춰 모든 방향을
선언하되, 실제 태블릿 UI는 Flutter 정책으로 가로 고정한다. 앱 최초 방향 요청은
`Home.initState`나 `runApp` 전에 보내지 않고, `main.dart`가 lifecycle `resumed`
이후 한 번만 적용한다. `AppOrientation`은 네이티브 요청이 성공한 뒤에만 적용값을
캐시해야 한다. 이 순서를 바꾸면 unattached scene의 요청이 캐시에 남아 게임 화면이
검게 보일 수 있다.

게임 화면을 닫기 전에 플랫폼 방향으로 먼저 복원한다. 회전 요청과 Navigator 전환을
동시에 실행하면 iOS에서 검은 화면이 생긴 전력이 있다. 같은 방향 재요청은
`AppOrientation._apply`가 제거한다.

### 3.3 방 생성부터 게임 화면까지

```text
태블릿
  TabletHome
    -> RoomProvider.createRoom()
    -> callable createRealtimeRoom
    -> rooms/{code} 생성
    -> RoomProvider.listenRoom()
       ├─ selectedGame 구독
       └─ players 구독

휴대폰
  PhoneRoomJoin
    -> RoomProvider.joinRoom(code, nickname)
    -> callable joinRealtimeRoom
    -> rooms/{code}/players/{uid} 생성 또는 재접속
    -> PhoneRoomWaiting
       ├─ selectedGame 구독
       └─ game/public/status 구독

태블릿 게임 선택
  GamePreviewDialog
    -> 인원 검증
    -> RoomProvider.selectGame(gameId)
    -> PlayerLayoutEditor
    -> saveRealtimePlayerSeatIndexes
    -> TemplateGame.startGame(roomCode)
    -> game/public/status == playing
       ├─ 태블릿: buildTabletScreen(...)
       └─ 휴대폰: buildPhoneScreen(...)
```

`selectedGame`과 `game/public/status`는 다른 RTDB 경로라 도착 순서가 보장되지 않는다.
`PhoneRoomWaiting`은 두 값을 따로 기억하고 둘 다 준비된 순간 한 번만 화면을 연다.
Firestore의 썸네일/설명 조회가 느려도 게임 시작을 막지 않는다.

태블릿이 방을 만들면 Cloud Function이 `controllerUid`와
`controllerSessionId`를 함께 발급한다. 태블릿은 세션을 로컬에 보존하고 10초마다
`controllerPresence.lastSeen` heartbeat를 갱신한다. `onDisconnect`는 방 전체를
삭제하지 않고 presence의 `connected=false`만 기록한다. 순간 단절이나 background는
방 종료가 아니며, 앱이 다시 열리면 저장된 세션으로 `resumeRealtimeControllerRoom`을
호출해 방, 좌석, 진행 중 게임 상태를 복구한다.

방 생성·게임 선택·강퇴·명시적 퇴장·방 종료는 callable Function만 변경할 수 있다.
controller 명령은 UID와 session을 모두 검사한다. `dispose()`와 lifecycle에서는
heartbeat만 정리하며 방을 삭제하지 않는다. 명시적인 종료만 `closeRoom`을
사용하고, 장시간 heartbeat가 없거나 finished 보존 시간이 지난 방은 5분 주기의
`cleanupStaleRealtimeRooms`가 트랜잭션으로 다시 확인한 뒤 삭제한다.

### 3.4 플랫폼과 게임의 유일한 연결 계약

파일: `lib/games/template_game.dart`

각 게임은 `TemplateGame`을 구현한다.

```dart
abstract class TemplateGame {
  String get id;
  String get title;
  String get leaveFunctionName;
  Color get tableColor;
  ImageProvider? get tableBackgroundImage;
  ImageProvider? get layoutTableImage;
  ImageProvider? get layoutChairImage;

  Future<void> startGame(String roomCode);
  Stream<String?> watchStatus(String roomCode);
  Widget buildPhoneScreen(...);
  Widget buildTabletScreen(...);
}
```

등록 위치는 `lib/games/game_registry.dart` 한곳이다.

```dart
static const games = [LiarsPokerGame(), FinalCallGame()];
```

플랫폼에 `if (gameId == ...)`를 추가하는 방식은 금지한다. 현재 Mafia preview의
테스트 분기는 임시 개발 예외이며, 정식 게임으로 만들 때 제거하고 Registry 계약으로
옮겨야 한다.

---

## 4. 데이터 저장소별 책임

### 4.1 Firestore: 느리게 바뀌는 메타데이터

`games/{gameId}` 문서는 `GameInfo`로 파싱한다.

```text
name, description, imageUrl, enabled, genres,
minPlayers, maxPlayers, playTime, order, ruleVideoUrl,
createdAt, updatedAt
```

`users/{uid}`는 프로필과 `ownedGames`를 가진다. 그룹 보유 게임은 활성 참가자들의
`ownedGames` 합집합이다. Firestore 데이터는 게임 턴 진행의 권위가 아니다.

### 4.2 Realtime Database: 방과 현재 게임

```text
rooms/{ROOM_CODE}
├── roomCode
├── controllerUid                 # 방을 만든 태블릿 UID
├── controllerSessionId           # 클라이언트 읽기 금지, 오래된 태블릿 요청 차단
├── status                        # waiting/playing/finished/closed
├── controllerPresence
│   ├── connected
│   └── lastSeen
├── maxPlayers
├── selectedGame                  # Registry/Firestore game id
├── createdAt
├── players/{uid}
│   ├── uid
│   ├── nickname
│   ├── profileImageUrl
│   ├── accentColor
│   ├── isConnected
│   ├── lastSeen
│   ├── seatIndex
│   ├── role                      # player
│   ├── status                    # active
│   └── joinedAt
└── game
    ├── public                    # 참가자와 태블릿이 읽음
    ├── private/{uid}             # 해당 uid만 읽음
    └── server                    # Admin SDK만 사용, 클라이언트 읽기 금지
```

게임을 시작하거나 재시작할 때 `game`을 새 초기 상태로 교체한다. 방, 참가자,
좌석은 유지한다. 게임 종료와 홈 복귀 시 게임별 정책에 따라 `status=finished`를 먼저
전파하고 방은 기본 15분 동안 유지한다. 휴대폰이 종료를 인식하기 전에 노드를 지우지
않으며, 방의 최종 삭제는 서버 cleanup만 담당한다.

### 4.3 public/private/server 보안 경계

| 경로 | 내용 | 읽을 수 있는 주체 |
|---|---|---|
| `game/public` | 상태, phase, 턴, 공개 플레이어, 공개 결과 | 방 controller 또는 참가자 |
| `game/private/{uid}` | 해당 플레이어의 손패/임시 드로우 | 본인 UID만 |
| `game/server` | 덱, 제출 원본, pending hands, 멱등 명령 기록 | 클라이언트 불가 |

실제 카드 랭크처럼 아직 공개되면 안 되는 값은 `public`에 미리 쓰지 않는다. 예를 들어
Liar's Poker 제출은 공개 전 `cardCount`만 보이고, 판정 때 `actualRanks`가 추가된다.
Final Call은 최종 선택한 카드만 `roundResult.revealedHands`에 복사하며 나머지 손패는
끝까지 비공개다.

### 4.4 Functions: 게임의 유일한 쓰기 경로

Flutter 게임 서비스는 RTDB를 읽기만 하고, 변경은 callable function으로 요청한다.
함수는 보통 방 전체 또는 `game` 노드 transaction 안에서 다음을 수행한다.

1. 인증 UID 검증
2. 방 코드 정규화/검증
3. 방과 게임 존재 확인
4. controller/현재 턴/생존 여부/phase 검증
   - controller 명령은 `controllerUid + controllerSessionId`를 함께 검증
5. `commandId` 중복 확인
6. 카드와 상태를 원자적으로 변경
7. `revision`/`updatedAt` 증가
8. 처리 결과를 `server.processedCommands`에 저장

재시도 가능한 클라이언트 명령은 같은 `commandId`로 최초 요청 1회와 재전송 3회,
총 4회까지 호출된다. 공용 `CallableRetryPolicy`를 사용하며 네트워크가 응답 직후
끊겨도 서버에서 같은 행동이 두 번 실행되지 않게 하는 구조다. 규칙·권한 오류는
재전송하지 않는다.

---

## 5. Flutter 게임 내부 계층

표준 게임 폴더는 다음과 같다.

```text
lib/games/<game_id>/
├── <game_id>_game.dart              # TemplateGame 구현
├── <game_id>_copy.dart              # 게임 전용 사용자 문구
├── models/                          # RTDB map 파서와 도메인 값
├── services/
│   ├── <game>_command_service.dart  # callable 쓰기
│   ├── <game>_query_service.dart    # RTDB 읽기 스트림
│   └── <game>_service.dart          # command/query 파사드
├── providers/
│   ├── <game>_state.dart            # 불변 스냅샷
│   └── <game>_session_provider.dart # autoDispose.family
├── controllers/
│   ├── <game>_controller.dart       # 기본: phone/tablet 공용 서버 세션
│   └── <game>_<device>_controller.dart # 선택: 기기별 조정이 필요할 때만
├── screens/
│   ├── phone_game.dart              # 휴대폰 진입·세션·화면 phase 조정
│   ├── phone/                       # 휴대폰 화면 구성
│   ├── tablet_game.dart             # 태블릿 진입
│   └── tablet/                      # stage/layer/overlay/animation/helper
├── widgets/
│   ├── phone/
│   └── tablet/
├── animations/                      # 게임 전용 연출
└── loading/                         # 선택: 게임별 팁/프리로드
```

게임 폴더와 `phone/`, `tablet/` 폴더가 이미 범위를 나타내므로 하위 파일명은
`top_bar.dart`, `turn_timer.dart`, `result.dart`처럼 역할만 적는다. 반대로 외부에서
생성하는 화면과 Provider/Controller 타입은 `FinalCallPhoneGame`,
`LiarsPokerTabletController`처럼 게임 이름을 붙여 검색 충돌을 막는다. 컨트롤러를
`screens/` 아래에 두거나 `PhoneGameController`, `GameStatus` 같은 범용 공개 이름을
만들지 않는다.

### 5.1 Command/Query 분리

```text
UI action
  -> Controller method
    -> GameService.command
      -> Cloud Function
        -> RTDB transaction
          -> RTDB onValue
            -> GameService.query
              -> Controller parse/copyWith
                -> Riverpod state
                  -> UI rebuild
```

명령의 성공 응답을 받아 UI 상태를 임의로 확정하지 않는다. 최종 화면 상태는 RTDB
구독으로 돌아온 서버 스냅샷이 확정한다. 버튼 중복 방지는 `commandInFlight`로 한다.

### 5.2 Riverpod 세션 패턴

표준은 다음이다.

```dart
final gameSessionProvider = NotifierProvider.autoDispose.family<
  GameController,
  GameState,
  GameSessionArgs
>((args) => GameController(...));
```

`SessionArgs`는 최소 `roomCode`, `uid`, 동일 서비스 인스턴스, 기기 역할 옵션을 가진다.
equality/hashCode가 안정적이어야 같은 화면 rebuild에서 Provider가 새로 생기지 않는다.

컨트롤러 `build()`에서 구독을 시작하고 `ref.onDispose`에서 모든
`StreamSubscription`/Timer를 정리한다. RTDB map 파싱은 모델의 `fromMap` 또는
전용 parser로 모으고, 매 갱신마다 새 불변 state를 발행한다.

현재 구현 차이:

- Final Call: phone/tablet이 같은 `FinalCallController`를 사용하며 태블릿은
  `watchPrivateHand: false`다.
- Liar's Poker: 공개 상태를 다르게 연출해야 해서 phone/tablet 세션 Provider와
  state가 분리되어 있다. 태블릿 Controller는 서버 phase를
  `LiarsPokerTabletStage`로 번역한다.

새 게임 기본값은 하나의 서버 미러 Controller 공유다. 태블릿 연출이 여러 형제 파일에
걸쳐 복잡해질 때만 얇은 태블릿 오케스트레이션 상태를 추가한다.

### 5.3 Provider 상태와 위젯 로컬 상태의 경계

Provider에 둘 값:

- RTDB에서 온 `status`, `phase`, `round`, `revision`, `turnUid`, deadline
- 공개 플레이어와 개인 손패
- 현재 명령 실행 여부와 오류
- 이 값만으로 항상 다시 계산 가능한 파생 상태(`isMyTurn`, `canDraw`)

위젯 로컬에 둘 값:

- `AnimationController`
- 특정 round intro를 이미 보여줬는지
- 손패 펼치기 완료 여부
- 임시 카드 선택과 드래그 위치
- 한 번만 재생할 call bubble/판정/진입 연출
- 애니메이션 도중의 focus, scale, opacity

서버에 저장할 필요가 없고 재접속 시 복구할 필요도 없는 연출 플래그를 RTDB나 서버
state에 넣지 않는다.

---

## 6. 상태 용어: status, phase, revision, 화면 phase

이 네 가지는 서로 다르다.

### 6.1 `status`: 게임 전체 수명

현재 정식 게임의 공통 값은 다음과 같다.

```text
playing   게임 진행 중
finished  승자 확정, 수동 종료, 인원 부족 종료
```

`finishReason`은 `winner | manual | insufficientPlayers | interruptionVoteExpired`다.
UI는 `finished`만 보지 말고 종료 이유도 확인해야 한다.

두 게임 서버가 함께 지키는 불변 조건이 하나 있다.

> **승부가 나지 않은 모든 종료는 `winnerUid`를 null로 만들고 `finishReason`을 남긴다.**

| 종료 경로 | finishReason | winnerUid |
|---|---|---|
| 마지막 생존자 확정 | 없음 또는 `winner` | 생존자 uid |
| 태블릿 수동 종료(설정·결과 HOME) | `manual` | null |
| 인원 부족 | `insufficientPlayers` | null |
| 계속 진행 투표 만료 | `interruptionVoteExpired` | null |

그래서 휴대폰이 "게임 화면을 닫아야 하는가"를 판단할 때 **사유를 나열하지 않는다.**

```dart
// 금지: 서버에 사유가 하나만 늘어도 휴대폰이 결과 화면에 갇힌다
final shouldClose = game.isFinished &&
    (game.finishReason == 'manual' || game.finishReason == 'insufficientPlayers');

// 표준: shared/game_flow/game_finish.dart
final shouldClose = game.isFinished && !game.isNaturalResult;
```

새 게임의 Cloud Functions도 위 불변 조건을 지켜야 `isNaturalGameResult()`를 그대로
쓸 수 있다.

### 6.2 서버 `phase`: 게임 규칙의 세부 단계

게임마다 값이 다르다. 서버 함수의 허용 동작을 결정한다.

### 6.3 `revision`: 서버 변경 세대 번호

의미 있는 상태 변경 때 증가한다. 다음 용도로 쓴다.

- 재시작/새 라운드인데 round 숫자가 다시 같아진 경우 구분
- 오래된 비동기 결과 무시
- 이벤트/화면 key 보조
- 동일 snapshot과 새 snapshot 구분

`revision` 자체를 phase처럼 해석하지 않는다.

### 6.4 `GameScreenPhase`: 휴대폰이 무엇을 그릴지

파일: `lib/games/shared/game_flow/game_screen_phase.dart`

```text
connecting -> intro -> roundIntro -> playing -> result
                                         └----> closing
```

| 값 | 화면 책임 |
|---|---|
| `connecting` | 배경만, 상단바 숨김 |
| `intro` | `GAME START` |
| `roundIntro` | `ROUND N` |
| `playing` | 실제 게임 + 상단바 |
| `result` | 승자 화면 + 상단바 |
| `closing` | 인원 부족 등 종료 안내 |

서버의 `phase`를 그대로 이 enum에 대입하지 않는다. 게임별 `_resolvePhase()`가 번역한다.
손패가 비었거나 상대를 기다리는 순간도 게임 시작 후라면 `playing`이다. 이를
`connecting`으로 바꾸면 상단바와 퇴장 버튼까지 사라진다.

### 6.5 태블릿 연출 상태

Liar's Poker의 `LiarsPokerTabletStage`가 권장 예시다.

```text
waiting, dealing, roundStarting, playing,
cardsPlaying, cardsRevealing, penalty, result, finished
```

서버 phase와 달리 `cardsPlaying`, `cardsRevealing`, `roundStarting`은 태블릿에서만
필요한 애니메이션 단계다. `<Game>TabletGameLayer`는 enum을 exhaustive switch로
그린다.

---

## 7. Liar's Poker 실제 상태 머신

백엔드 타입: `functions/src/liars-poker/common/types.ts`

### 7.1 RTDB 핵심 구조

```text
game/public
├── status, finishReason, phase
├── round, revision, table
├── turnUid, turnDeadlineAt, isFirstTurnReady
├── lastPlay
├── roundPlays/{playId}
├── penaltyTargetUid, penaltyResult
├── winnerUid
└── players/{uid}
    ├── nickname, profileImageUrl, seatIndex
    ├── status                 # alive/eliminated
    ├── penaltyCount
    └── remainingCardCount

game/private/{uid}/hand/{cardId}
game/server
├── lastPlayCards
├── processedCommands
├── roundStarterUid
├── pendingHands
└── penaltyCountIncrementedBeforeRoulette
```

### 7.2 phase 흐름

```text
start/restart
  -> dealing
     태블릿 CardDealAnimation 완료
  -> completeLiarsPokerDealing
     pendingHands -> private
  -> playing
     첫 플레이어가 손패 공개 완료 후 readyLiarsPokerTurn
     turnDeadlineAt 설정
  -> submit 1~3장
     ├─ 손패 남음 -> playing, 다음 생존 플레이어
     └─ 손패 0장  -> lastCardChallenge, 다음 플레이어, 1:1은 10초

playing/lastCardChallenge
  -> LIAR
     직전 실제 카드 공개
  -> penalty
     태블릿 룰렛
  -> safe/eliminated
     ├─ 생존자 1명 -> finished/winner
     └─ 2명 이상  -> dealing(새 round, 새 손패)

lastCardChallenge
  -> PASS
     ├─ 1:1 -> PASS한 플레이어가 penalty
     └─ 3명 이상 -> dealing(새 round)
```

기본 턴은 30초, 1:1 마지막 카드 선택은 10초다. 테이블 랭크는 A/K/Q 중 하나며
JOKER는 어떤 테이블에서도 진실 카드로 인정한다.

### 7.3 공개 카드 이벤트

제출 순간 `lastPlay`/`roundPlays`에는 다음만 공개된다.

```text
playId, round, playerUid, cardCount, declaredRank,
revealed=false, submittedAt
```

LIAR 판정 뒤에만 `revealed=true`, `actualRanks`가 붙는다. `server.lastPlayCards`가
판정 전 실제 카드의 권위다. 태블릿은 `playId`를 stable event key로 사용해 새 제출과
새 공개를 구분한다.

### 7.4 휴대폰 상태와 문구

`LiarsPokerPhoneState`는 공개 상태, 개인 손패, hand deal version, 판정/벌칙 표시를
합친 불변 UI state다. 주요 파생 문구는
`LiarsPokerPhoneController.statusMessage`와
판정 계산부에서 나온다.

판정 문구는 대상에 따라 다르다.

| 대상 | 실제 제출 | 문구 | 색 |
|---|---|---|---|
| 패를 낸 플레이어 | 진실 | `진실이 증명되었습니다.` | 초록 |
| 패를 낸 플레이어 | 거짓 | `거짓이 밝혀졌습니다.` | 빨강 |
| LIAR를 외친 플레이어 | 성공 | `간파 성공!` | 초록 |
| LIAR를 외친 플레이어 | 실패 | `간파 실패!` | 빨강 |

기타 현재 문구 예:

- `상대의 선택을 기다리는 중...`
- `다음 라운드를 기다려주세요`
- `벌칙을 진행 중입니다`
- `마지막 카드가 라이어인지 결정하세요`
- `최대 3장만 선택할 수 있습니다`

이 문구를 변경할 때는 텍스트만 바꾸지 말고 `phone_game_screen.dart`의 색상 매핑과
표시 대상 조건도 함께 확인한다.

---

## 8. Final Call 실제 상태 머신

백엔드 타입: `functions/src/final-call/types.ts`

### 8.1 RTDB 핵심 구조

```text
game/public
├── gameType = final_call
├── status, finishReason, phase
├── round, revision
├── turnUid, turnDeadlineAt, callerUid
├── deckRemainingCount, discardCard
├── pendingDrawUid, pendingDrawSource
├── finalTurnPendingUids
├── players/{uid}
│   ├── nickname, profileImageUrl, seatIndex
│   ├── status                 # alive/eliminated
│   └── lives
├── roundResult
│   ├── scores, lifeLosses, lowestUids
│   ├── revealedHands          # 실제 최종 제출 카드만
│   ├── callerUid, automaticCall, resolvedAt
├── resultRevealCompletedAt
└── winnerUid

game/private/{uid}
├── hand/{cardId}
└── pendingDraw

game/server
├── deck
├── pendingHands
├── finalSubmissions/{uid}     # 선택된 카드만
├── processedCommands
└── roundStarterUid
```

### 8.2 phase 흐름

```text
start/restart
  -> dealing
     태블릿 CardDealAnimation 완료
  -> completeFinalCallDealing
     pendingHands -> private
  -> playing (30초 턴)
     ├─ draw(deck/discard)
     ├─ pendingDraw 생성
     └─ completeTurn(replaceCardId 또는 null)
          ├─ 교체: 선택한 손패를 discard로, 새 카드를 같은 슬롯에
          └─ 버리기: 새 카드가 discard

playing
  -> CALL
  -> callerSubmit
     CALL한 플레이어가 점수 조합 1~4장 제출
  -> finalTurns
     CALL하지 않은 플레이어가 순서대로 마지막 카드 교체
  -> finalSubmit
     방금 교체한 플레이어가 점수 조합 1~4장 제출
  -> finalTurns/finalSubmit 반복
  -> roundResult
     태블릿이 제출 카드만 순차 공개 + 생명 소멸
  -> completeResultReveal
     휴대폰 결과 공개 허용
  -> dealing(next round) 또는 finished(winner)
```

덱이 소진되면 자동 CALL이며 추가 교체 없이 서버가 각 손패에서 최고 조합을 선택한다.
일반 CALL에서는 **각 플레이어가 선택한 카드만** `finalSubmissions`와
`roundResult.revealedHands`에 들어간다. 전체 4장을 공개하면 규칙과 보안 모두 깨진다.

점수는 같은 색 카드 합과 같은 숫자 카드 합 중 큰 값이다. 최저 점수는 생명 1 감소,
CALL한 사람이 최저면 2 감소, 공동 최저는 모두 감소한다. 마지막 생존자가 승자다.

### 8.3 결과 공개 동기화

태블릿은 `_RevealedTable`에서 다음을 순서대로 재생한다.

1. 좌석 위치에 제출된 개수만큼 뒷면 배치
2. 플레이어 한 명씩 확대
3. 카드 한 장씩 뒤집기
4. 뒤집힐 때 점수 갱신
5. 최저 플레이어 하트 소멸
6. 애니메이션 완료 후 `completeFinalCallResultReveal`

휴대폰은 `resultRevealCompletedAt`이 오기 전까지 결과 화면으로 이동하지 않는다.
이 handshake를 제거하면 휴대폰 결과가 태블릿 공개보다 먼저 나온다.

---

## 9. 애니메이션 시스템

### 9.1 공용 애니메이션 카탈로그

| 파일/클래스 | 기본 시간 | 사용 목적 |
|---|---:|---|
| `game_entry_unroll.dart` / `GameEntryUnroll` | 900ms | 게임 진입 시 매트 펼침 |
| `mat_unroll_animation.dart` / `MatUnrollAnimation` | progress 기반 | 진입/종료 화면 마스크 |
| `phone_game_start_animation.dart` / `PhoneGameStartAnimation` | 1700ms | `GAME START` |
| `fade_hold_fade.dart` / `FadeHoldFade` | 1900ms | `ROUND N`, 테이블명, 짧은 판정 문구 |
| `card_deal.dart` / `CardDealAnimation` | 2800ms | 중앙 덱에서 좌석별 분배 |
| `board_element_entrance.dart` / `BoardElementEntrance` | 980ms | 탑뷰 보드 요소의 묵직한 등장 |
| `phone_control_entry_animation.dart` | 920ms | 두 게임 공용 상단바/조작부 입장 |
| `phone_result_dialog.dart` | 상태 기반 | 왕관+프로필 승자 화면 |
| `one_shot_timeline.dart` / `OneShotTimeline` | 주입 | 복합 일회성 연출의 controller 수명주기 |

공용 UI:

- `SharedPhoneGameTopBar`: 게임별 asset만 주입하는 휴대폰 상단바
- `TabletGameSideBar`: 룰/설정 아이콘과 등장 애니메이션
- `SharedPhoneExitModal`: 게임별 문/색을 주입하는 퇴장 UI
- `PhoneRippleDialog`: 아이콘 위치에서 퍼지고 돌아가는 오버레이
- `PhoneResultDialog`: 휴대폰 승자 발표

### 9.2 `PhoneGameShell` 표준 순서

```text
GameEntryUnroll
  -> GAME START
  -> ROUND N
  -> 게임별 카드 수신/펼치기
  -> contentRevealed = true
  -> 상단바/조작부 등장
  -> playing/result/closing
```

새 휴대폰 게임은 이 셸을 사용한다. 게임은 서버 상태를 `GameScreenPhase`로 번역하고
`background`, `topBar`, `content`, `result`를 주입한다.

`contentReady`는 실제 콘텐츠를 그릴 데이터가 있는지, `contentRevealed`는 손패 공개
연출이 끝났는지다. 둘은 서버 `phase`와 다르다.

### 9.3 애니메이션이 끊기지 않는 소유 규칙

1. `AnimationController`는 애니메이션 위젯의 State가 생성하고 dispose한다.
2. `build()` 안에서 `forward/reset`하지 않는다. `initState`, 의미 있는
   `didUpdateWidget`, post-frame callback에서 실행한다.
3. 초 단위 타이머 rebuild가 카드/버튼 애니메이션 State를 교체하지 않게 타이머를
   작은 위젯으로 격리한다.
4. 조건부 `if`로 애니메이션 위젯을 제거하면 State도 사라진다. 숨길 필요만 있으면
   stable slot + `Visibility/IgnorePointer/Opacity`를 고려한다.
5. `AnimatedSwitcher` 자식은 의미 있는 stable key를 사용한다.
6. 새 라운드/새 이벤트만 재생하려면 `round`, `handDealVersion`, `playId`, event
   version을 key로 사용한다.
7. 부모 rebuild와 애니메이션 tick을 분리하려면 `RepaintBoundary`와 child 캐시를 쓴다.
8. 네트워크 Future를 애니메이션 중간에 await해서 화면을 멈추지 않는다. 필요한 경우
   로컬 제출 연출을 먼저 완료하고, 실패 시 원복 애니메이션을 실행하되 서버 상태를
   성공으로 가정하지 않는다.

좋은 key 예:

```dart
ValueKey('deal-${game.round}-${game.revision}')
ValueKey('hand-${game.handDealVersion}')
ValueKey('play-${play.playId}')
ValueKey('discard-${event.version}')
```

나쁜 key 예:

```dart
UniqueKey()                    // 매 build마다 State 폐기
ValueKey(DateTime.now())       // 항상 재생
ValueKey(game.turnDeadlineAt)  // 타이머 변경이 unrelated UI까지 재생 가능
```

### 9.4 서버 phase와 애니메이션 완료 연결

애니메이션이 규칙의 다음 단계를 열어야 할 때는 명시적 완료 command를 둔다.

- Liar's Poker dealing 완료 → `completeLiarsPokerDealing`
- Final Call dealing 완료 → `completeFinalCallDealing`
- Final Call 결과 공개 완료 → `completeFinalCallResultReveal`

단순 opacity/slide 완료를 RTDB 필드로 계속 기록하지 않는다. 다른 기기가 반드시
기다려야 하는 경계만 서버 handshake로 만든다.

---

## 10. 게임 중간 문구와 words 설계

현재 문구는 세 종류다.

모든 문구는 `GameAnnouncement`로 표현하고 화면 `Stack`의 고정
`GameAnnouncementLayer` 슬롯에서 렌더링한다. 공통 문구는 `GameFlowCopy`, 게임별
문구는 `<game>_copy.dart`가 소유한다. 색상은 문자열 비교 대신
`GameAnnouncementTone`으로 전달한다.

개별 문구는 `GameAnnouncement.duration`, 같은 레이어의 문구를 일괄 조정할 때는
`GameAnnouncementLayer.displayDuration`을 사용한다. `PhoneGameShell`의 시작·라운드
문구는 `gameStartAnnouncementDuration`, `roundAnnouncementDuration`으로 조정한다.

### 10.1 진행 단계 문구

`GAME START`, `ROUND N`, 테이블명처럼 입력을 막고 순서대로 보여주는 문구다.

- `PhoneGameStartAnimation`
- `FadeHoldFade`
- font: `BebasNeue`
- 화면 중앙
- `IgnorePointer`로 입력 차단
- 완료 callback 뒤에 다음 연출 시작

### 10.2 상태 유지 문구

상대 선택 대기, 벌칙 진행, 다음 라운드 대기처럼 서버 상태가 유지되는 동안 보인다.
Controller의 파생 getter가 문구를 결정하고 화면은 렌더링만 한다.

```dart
String? get statusMessage {
  if (isFinished) return ...;
  if (phase == 'penalty') return ...;
  if (phase == 'lastCardChallenge') return ...;
  return null;
}
```

조건을 여러 화면에 복제하지 않는다. 문구의 의미는 Controller/Copy 계층, 위치와
애니메이션은 Widget 계층이 담당한다.

### 10.3 일회성 판정/이벤트 문구

거짓/진실 판정, CALL bubble, 오류처럼 이벤트가 발생했을 때 제한 시간 동안 보인다.

- 서버의 event identity(`playId`, `resolvedAt`, caller UID 변화)를 감지
- 이전 identity와 비교해서 새 이벤트일 때만 로컬 Timer/Animation 시작
- `FadeHoldFade` 또는 전용 overlay 사용
- 같은 snapshot 재수신으로 다시 재생하지 않음

### 10.4 새 게임 권장 words 파일

새 게임은 문구가 늘어나기 전에 `<game>_copy.dart`를 만든다.

```dart
abstract final class MyGameCopy {
  static const gameStart = 'GAME START';
  static String round(int value) => 'ROUND $value';
  static const waitingForOpponent = '상대의 선택을 기다리는 중...';
  static const connectionError = '서버 연결이 불안정합니다. 잠시 후 다시 시도해주세요.';
}
```

동적 대상 문구, 색상 의미도 한곳에서 관리할 수 있다.

```dart
enum VerdictTone { positive, negative, neutral }

class GameMessage {
  const GameMessage(this.text, this.tone);
  final String text;
  final VerdictTone tone;
}
```

단, 서버 응답 메시지를 UI 문구 원본으로 삼지 않는다. 서버 메시지는 오류 진단용이고,
게임 연출 문구는 클라이언트 copy가 담당한다.

### 10.5 문구 스타일 규칙

- 일반 안내: 존댓말 `~합니다`, `~해주세요`
- 다른 플레이어: `$nickname님`
- 버튼: 짧은 행동형 `제출`, `교체`, `나가기`
- 임팩트 판정: 짧은 문장/느낌표 허용
- 연출 영문: 대문자 + BebasNeue
- 오류: 사용자가 다음 행동을 알 수 있는 문장
- `기달리다`가 아니라 표준어 `기다리다`

---

## 11. 새 게임 추가 절차

### Step 1. 게임 계약 먼저 작성

코딩 전에 다음 표를 채운다.

```text
gameId:
인원(min/max):
기기 방향(phone/tablet):
전체 status:
서버 phase 목록:
각 phase에서 행동 가능한 주체:
턴 제한 시간:
공개 정보:
개인 정보:
서버 전용 정보:
승리 조건:
재접속 시 복구해야 할 정보:
기기간 반드시 기다려야 하는 애니메이션 경계:
```

### Step 2. 백엔드 타입과 상태 머신

`functions/src/<game-id>/types.ts`부터 만든다.

```ts
interface MyGameState {
  public: MyPublicState;
  private: Record<string, MyPrivatePlayer>;
  server: MyServerState;
}
```

그 후 다음을 구현한다.

- validation: auth, room code, controller, turn, phase
- game helpers: deck, score, next player, win condition
- start/restart
- 각 플레이어 command
- timeout
- leave-game
- end/clear 정책
- idempotency commands
- `functions/src/index.ts` export

서버 함수 이름은 `<verb><GameName>` 형태를 유지한다.

### Step 3. RTDB 보안 검토

기존 `database.rules.json`의 공통 `game/public/private/server` 구조를 그대로 쓰면
대부분 추가 규칙이 필요 없다. 새 경로를 만들면 다음을 확인한다.

- 다른 플레이어 private를 읽을 수 없는가
- server를 어떤 클라이언트도 읽을 수 없는가
- game 직접 쓰기가 막혀 있는가
- 방 참가자만 public을 읽는가

### Step 4. Flutter 서비스

```text
<game>_command_service.dart
  start/restart/end/leave/action/timeout callable

<game>_query_service.dart
  watchPublicGame(roomCode)
  watchPrivatePlayer(roomCode, uid)
  watchStatus(roomCode)

<game>_service.dart
  command + query 파사드
```

일시 오류 재시도는 공용 `CallableRetryPolicy`를 사용한다. 중복 효과가 있는 명령은
반드시 같은 commandId를 유지한 멱등성과 함께 쓰며, 최종 실패 문구는 최초 요청과
3회 재전송이 모두 실패한 뒤에만 표시한다.

### Step 5. 불변 모델과 Riverpod Controller

1. wire map을 파싱하는 모델 작성
2. 초기 state와 `copyWith` 작성
3. `SessionArgs` equality 작성
4. `NotifierProvider.autoDispose.family` 작성
5. 공개/개인 구독을 Controller 한곳에서 시작
6. 파생 getter `isMyTurn`, `canX`, `turnPlayer`, `statusMessage` 작성
7. command wrapper에 `commandInFlight`와 오류 처리
8. dispose에서 스트림과 Timer 정리

### Step 6. `TemplateGame`과 Registry

`<game>_game.dart`에서 id, title, leave function, 자리 배치 asset, start/watch/build를
구현하고 `GameRegistry.games`에 한 줄 추가한다.

`id`는 다음 모두와 정확히 같아야 한다.

- Firestore `games/{id}` 문서 ID
- RTDB `selectedGame`
- Cloud Function start validation
- `GameRegistry.find(id)`

### Step 7. 휴대폰 화면

`_game_template/screens/phone_game.dart`를 기준으로 한다.

1. 방향 잠금
2. UID와 SessionArgs 구성
3. Provider listen/watch
4. 서버 state → `GameScreenPhase` 변환
5. `PhoneGameShell`에 화면 전달
6. 카드 수신/선택/제출은 하위 위젯으로 분리
7. 퇴장 성공 시 방향 복원 후 `Navigator.pop(true)`

상단바를 손패/phase 조건으로 직접 제거하지 않는다. 셸의 `showsTopBar`가 책임진다.

### Step 8. 태블릿 화면

권장 분리:

```text
screens/tablet_game.dart                    진입/Provider/수명주기/전체 Stack
screens/tablet/tablet_game_stage.dart       `<Game>TabletStage` 연출 enum
screens/tablet/tablet_game_layer.dart       상태별 보드
screens/tablet/tablet_game_overlay.dart     sidebar/settings/result
screens/tablet/tablet_game_animation.dart   이벤트 애니메이션
screens/tablet/tablet_game_helper.dart      asset/좌표/표시 변환
```

플레이어 위치는 `player_layouts`의 seat index와 normalized position을 사용한다.
인덱스 배열 순서와 실제 `seatIndex`를 혼동하지 않는다.

### Step 9. 에셋과 Firestore

```text
assets/games/<game_id>/images/
├── background/
├── button/
├── cards/
├── icons/
├── layout/
├── modal/
└── other/
```

`pubspec.yaml`에 폴더를 등록한 후:

```bash
dart run build_runner build --delete-conflicting-outputs
```

코드에서는 문자열 경로 대신 `Assets.games.<game>...`을 사용한다. 그 후 Firestore
`games/{gameId}` 메타데이터와 Storage thumbnail URL을 등록한다.

### Step 10. 검증

```bash
dart format lib test
flutter analyze
flutter test
cd functions
npm test
```

Firebase 배포 전:

```bash
firebase deploy --only functions,database
```

수동 시나리오:

1. 태블릿 방 생성
2. 최소/최대 인원 휴대폰 입장
3. 중복 닉네임/잘못된 코드 오류
4. 좌석 저장과 게임 시작
5. 각 phase 정상 행동과 잘못된 행동 거절
6. 턴 timeout
7. 네트워크 재시도와 명령 중복 방지
8. 앱 종료 후 같은 UID 재접속
9. 게임 중 플레이어 퇴장과 턴 건너뛰기
10. 인원 부족 종료
11. 승자 결과의 기기간 순서
12. 재시작 시 방/좌석 유지, game 상태만 교체
13. 수동 종료 후 휴대폰과 태블릿 모두 플랫폼으로 복귀

---

## 12. 변경 영향 지도

| 원하는 변경 | 먼저 볼 파일 |
|---|---|
| 새 게임을 플랫폼에 표시 | `game_registry.dart`, `<game>_game.dart`, Firestore `games` |
| 게임 시작이 휴대폰에 안 옴 | `PhoneRoomWaiting`, `RoomProvider`, `RoomService.watchGameStatus`, start function |
| 턴/승패 규칙 | `functions/src/<game>/` |
| RTDB 필드 추가 | TS types → function writes → Dart model/state → controller parser → UI |
| 버튼 명령 | game widget → controller → command service → callable function |
| 손패 노출 | database rules, `private/{uid}`, query service |
| 게임 중 문구 | controller 파생 message/copy → `GameAnnouncement` → 고정 layer |
| intro/round 문구 | `PhoneGameShell`, `GameAnnouncementLayer`, game local intro flags |
| 카드 배분 | `CardDealAnimation`, dealing complete function, pendingHands |
| 카드 제출 애니메이션 | event ID/revision, game animation widget, 서버 제출 event |
| 태블릿 좌석 위치 | `player_layouts`, seatIndex, game helper |
| 결과 화면 순서 | result phase, result handshake field/function |
| 방향/검은 화면 | `AppOrientation`, 진입/퇴장 시점 |
| 프로필 지연 | room join/start의 profile copy, initial data wait, image precache |
| 게임 퇴장 | `TemplateGame.leaveFunctionName`, `RoomProvider.leaveGame`, game leave function |

RTDB 필드를 추가할 때는 한 계층만 바꾸면 안 된다. 다음 순서를 모두 확인한다.

```text
TypeScript type
  -> start/default value
  -> every transition cleanup/update
  -> database rule visibility
  -> Dart model/state
  -> controller parse/copyWith
  -> derived state
  -> phone/tablet UI
  -> restart/leave/end/timeout behavior
  -> tests
```

---

## 13. 금지 패턴과 자주 생기는 버그

### 금지: 클라이언트가 game 노드 직접 update

동시 행동, 권한, 비공개 카드, 승패가 깨진다. callable + transaction을 사용한다.

### 금지: 전체 Scaffold를 초 단위 Timer로 rebuild

카드/버튼 애니메이션의 State가 교체되거나 프레임이 끊긴다. 타이머를 작은 독립
위젯으로 격리한다.

### 금지: 서버 phase를 화면 위젯 존재 조건으로 과도하게 사용

`if (phase == dealing) SizedBox.shrink()`로 손패 위젯 자체를 제거하면 다음 생성 때
`initState`와 카드 애니메이션이 다시 실행된다. 의도한 새 round에만 key를 바꾼다.

### 금지: `UniqueKey`로 애니메이션 문제 덮기

rebuild마다 State가 초기화된다. round/playId/revision처럼 도메인 identity를 쓴다.

### 금지: public에 전체 손패/덱 기록

Rules가 읽기를 막아도 잘못된 경로 설계다. private/server로 분리한다.

### 금지: Firestore 메타데이터를 게임 시작 조건으로 사용

썸네일 조회 지연 때문에 시작을 놓친다. RTDB `selectedGame` ID와 public status가
시작 신호다.

### 금지: 공용 위젯이 자기를 감싼 화면의 레이아웃·라우트를 잠그는 것

같은 공용 위젯을 게임마다 다른 방식으로 붙이기 때문에, 위젯이 호스트에 부작용을
남기면 한 게임에서만 조용히 깨진다. 실제로 두 번 발생했다.

| 위젯 | 잘못된 형태 | 증상 |
|---|---|---|
| `GameInterruptionLayer` | 중단이 없을 때 `Positioned`가 아닌 `SizedBox.shrink()` 반환 | 느슨한 `Stack`의 유일한 non-positioned 자식이 되어 **게임 화면 전체가 0×0**. 배경까지 안 그려져 태블릿이 검은 화면이 되었다 |
| `PhoneResultDialog` | 위젯 안에 `PopScope(canPop: false)` | 파이널콜처럼 라우트 없이 화면에 직접 그리면 그 설정이 **게임 라우트**에 걸려, 태블릿이 게임을 끝내도 휴대폰이 `Navigator.maybePop()`으로 못 나갔다 |

규칙은 두 가지다.

- `Stack`에 놓이는 전체 화면 레이어는 **빈 상태에서도 `Positioned`를 반환**한다.
  화면 루트 `Stack`에는 `fit: StackFit.expand`를 명시한다.
- 뒤로 가기 차단(`PopScope`)은 위젯이 아니라 **띄우는 쪽**이 정한다.

두 규칙 모두 회귀 테스트가 있다: `test/game_interruption_layer_test.dart`,
`test/phone_result_dialog_test.dart`. `Navigator.maybePop()`은 `PopScope`가 막아도
"처리했다"는 뜻으로 `true`를 반환하므로, **반환값 검사로는 이 버그를 잡을 수 없다.**
화면에 무엇이 남았는지로 검증한다.

### 주의: RTDB null

Realtime Database는 null 필드를 저장하지 않고 키를 제거한다. 파서는 `null`과
필드 부재를 동일하게 처리해야 한다. transaction 첫 callback의 null은 원격 데이터가
없다는 뜻이 아닐 수 있으므로 그대로 반환해 재호출을 기다린다.

### 주의: 재접속

재접속 identity는 닉네임이 아니라 Firebase UID다. 기존 UID 참가자는 seat와 game
private 상태를 유지해야 한다. `joinRealtimeRoom`의 existing player merge를 보존한다.
휴대폰은 마지막 방 코드·UID·닉네임·색상을 `PlayerRoomSessionStore`에 보존하고 앱
재실행 시 실제 참가자 노드가 남아 있는지 먼저 확인한 뒤 `joinRealtimeRoom`으로
presence와 중단 상태를 복원한다. 직접 퇴장·강퇴·방 종료 때는 저장 세션을 지워
자동 재입장을 막는다. 저장 정보만 믿고 참가자 노드가 없는 방에 새 플레이어를 만들지
않는다.

게임 중 연결 끊김·직접 퇴장은 `game/public/interruption`으로 턴을 일시 정지하고
60초 동안 재접속을 기다린다. 같은 UID가 돌아오면 저장한 턴 잔여 시간을 복원한다.
돌아오지 않으면 게임별 최소 인원을 확인해 해당 플레이어를 제외하고 계속하거나
`insufficientPlayers`로 종료한다. 태블릿의 공용 `GameInterruptionLayer`는 프로필,
닉네임, 사유, 남은 시간과 `제외하고 계속하기` 버튼을 표시하며, 버튼 활성 여부는
서버의 `canContinue`만 따른다. 새 게임은 중앙 연결 감지의 최소 인원 매핑과 게임별
제외 어댑터를 함께 등록한다.

### 주의: 프로필 이미지

방 참가 시 Firestore/Auth 프로필 URL을 room player에 복사하고, 게임 시작 시 public
player로 복사한다. 게임 화면에서 매 프레임 Firestore를 다시 조회하지 않는다.

---

## 14. 현재 구현의 예외와 기술 부채

1. `docs/PROJECT_STRUCTURE.md`는 초기 골격 문서라 현재 실제 파일 구조와 다른 설명이
   있다. 게임 작업은 이 문서와 `_game_template/README.md`를 우선한다.
2. Liar's Poker 휴대폰은 오랜 세로/가로 연출 안정화 때문에 아직 자체 화면 슬롯을
   사용한다. 새 게임은 Final Call의 `PhoneGameShell` 적용 방식을 기준으로 한다.
3. Final Call 태블릿은 phone과 같은 Controller를 공유하고 서버 phase를
   `FinalCallTabletStage`로 번역한다. 새 복합 태블릿 게임도 게임별 typed stage와
   exhaustive switch를 사용한다.
4. `PhoneControlEntryAnimation`과 `PhoneCardReceiveAnimation`은 두 게임이 함께
   사용하므로 `games/shared/animations`가 소유한다. 게임별 경로에는 기존 import
   호환을 위한 export만 둔다.
5. `PhoneResultDialog`와 일부 공용 카드 연출은 Liar's Poker asset에 의존할 수 있다.
   새 게임 고유 디자인이 필요하면 asset을 파라미터화한 뒤 공유한다.
6. Mafia는 `GameRegistry`에 등록되지 않은 테스트 UI다. 서버 상태 머신, services,
   provider, TemplateGame 계약이 완성되기 전에는 정식 게임으로 간주하지 않는다.
7. 플랫폼은 `RoomProvider(ChangeNotifier)`, 게임은 Riverpod을 사용한다. 새 게임에서
   플랫폼 전체를 Riverpod으로 재작성하지 말고 기존 경계에 맞춘다.

---

## 15. AI 작업 시작 템플릿

새 작업을 받을 때 다음 순서로 조사한다.

```text
1. git status --short
2. AGENTS.md와 이 문서 읽기
3. GameRegistry와 대상 <game>_game.dart 확인
4. 대상 functions types/state machine 확인
5. Dart state/controller/services 확인
6. phone/tablet 화면에서 해당 상태 소비 위치 확인
7. shared에 이미 있는 animation/widget 확인
8. 변경 영향 지도의 모든 계층을 작업 계획에 포함
9. 최소 범위 수정
10. format/analyze/test
```

새 게임 생성 요청을 받았을 때 AI가 먼저 확정해야 하는 질문:

- 게임 ID와 표시 이름은 무엇인가?
- phone/tablet 중 어느 기기에서 어떤 행동을 하는가?
- 최소/최대 인원과 방향 정책은?
- 턴 시간과 timeout 기본 행동은?
- phase 목록과 각 phase의 허용 command는?
- 공개/개인/서버 정보는 각각 무엇인가?
- 승리/공동 승리/탈락/퇴장 규칙은?
- 재접속 시 어떤 화면과 애니메이션 단계로 복원할 것인가?
- 필요한 이미지가 모두 존재하는가? 임의 생성이 허용되는가?
- 태블릿 연출 완료를 휴대폰이 기다려야 하는 지점은 어디인가?

사용자가 이미 답한 내용은 다시 묻지 않는다. 코드와 asset에서 안전하게 확인할 수 있는
내용도 질문하지 않는다. 규칙이나 디자인을 임의로 만들면 결과가 달라지는 항목만 묻는다.

---

## 16. 빠른 참조 파일

### 플랫폼

- `lib/main.dart`
- `lib/core/app/app.dart`
- `lib/core/layout/app_orientation.dart`
- `lib/platform/home/home.dart`
- `lib/platform/home/room/providers/room_provider.dart`
- `lib/platform/home/room/services/room_service.dart`
- `lib/platform/home/phone/screens/phone_room_waiting.dart`
- `lib/platform/home/tablet/widgets/tablet_game_preview_modal.dart`

### 게임 확장 계약

- `lib/games/game_registry.dart`
- `lib/games/template_game.dart`
- `lib/games/_game_template/README.md`
- `lib/games/_game_template/screens/phone_game.dart`

### 공용 흐름과 연출

- `lib/games/shared/game_flow/game_screen_phase.dart`
- `lib/games/shared/game_flow/phone_game_shell.dart`
- `lib/games/shared/game_flow/game_finish.dart` — 종료 시 휴대폰이 나갈지 남을지 판단하는 공용 규칙
- `lib/games/shared/animations/`
- `lib/games/shared/widgets/`
- `lib/games/shared/player_layouts/`
- `tool/README.md` — 진입 연출용 테이블·의자 이미지를 게임 배경으로 채워 만드는 도구

### Liar's Poker 기준

- `functions/src/liars-poker/common/types.ts`
- `lib/games/liars_poker/providers/`
- `lib/games/liars_poker/controllers/liars_poker_phone_controller.dart`
- `lib/games/liars_poker/controllers/liars_poker_tablet_controller.dart`
- `lib/games/liars_poker/screens/tablet/tablet_game_stage.dart`
- `lib/games/liars_poker/screens/tablet_game.dart`

### Final Call 기준

- `functions/src/final-call/types.ts`
- `functions/src/final-call/game.ts`
- `lib/games/final_call/providers/`
- `lib/games/final_call/controllers/final_call_controller.dart`
- `lib/games/final_call/screens/phone_game.dart`
- `lib/games/final_call/screens/tablet/tablet_game_layer.dart`

### 백엔드/보안

- `functions/src/index.ts`
- `functions/src/room/realtime-room-functions.ts`
- `database.rules.json`
- `firebase.json`
