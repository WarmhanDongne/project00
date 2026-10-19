# 새 게임 제작·연결 가이드

이 문서는 Mosigame에 새 게임 하나를 추가할 때 따라야 하는 전체 순서다. Flutter 패키지,
휴대폰·태블릿 화면, 서버 상태와 callable, Firebase 보안 경계, Firestore 카탈로그,
검증과 공개 순서를 한곳에서 연결한다.

세부 구현 규칙은 [game_kit 채택 규칙](GAME_KIT_ADOPTION.md), 패키지·다운로드 방식은
[Package Migration](PACKAGE_MIGRATION.md), 서버 함수 이름과 배포 방식은
[Cloud Functions](CLOUD_FUNCTIONS.md)를 따른다. 실제 출발점은
[`game_template`](../../packages/game_template/lib/README.md)이다.

## 1. 공개 전 기본 원칙

- 게임 ID는 영문 소문자 `snake_case` 하나로 정하고 패키지, 앱 registry, RTDB
  `selectedGame`·`gameType`, callable 접두사와 Firestore 문서에서 동일하게 사용한다.
- Firestore 문서 ID는 `games/{gameId}`다. 기존 `liars`/`liars_poker` 호환은 과거 이전을
  위한 예외이며 새 게임에서 별도 catalog ID를 만들지 않는다.
- 새 카탈로그 문서는 항상 `enabled: false`, `storeVisible: false`로 먼저 저장한다.
  코드·서버·앱 배포와 검증이 끝나기 전에는 어느 목록에도 공개하지 않는다.
- `visible`이라는 필드는 없다. 상점 진열 필드의 정확한 이름은 `storeVisible`이다.
- 게임 규칙, 턴, 승패, 비공개 정보와 중요한 상태 전이는 Cloud Functions가 결정한다.
  Flutter는 callable로 명령을 보내고 허용된 상태를 화면에 표시한다.
- 클라이언트는 `rooms/{roomCode}/game`을 직접 쓰지 않는다. RTDB rules도 이를 막는다.

## 2. 구현 순서

### 2.1 게임 계약을 먼저 적는다

코드를 만들기 전에 다음을 작업 문서에 고정한다.

- `gameId`, 한국어·영어·중국어 간체·번체 이름
- 최소·최대 또는 허용 인원 목록
- 전체 `status`와 세부 `phase` 상태도
- 각 phase에서 가능한 명령, 호출 주체, 입력값과 거절 조건
- 승리·무승부·인원 부족·수동 종료 조건
- 공개 상태, 사용자별 비공개 상태, 서버 전용 상태의 필드
- 턴 제한시간과 시간 초과 처리, 재연결·퇴장·제외 시 처리
- 휴대폰과 태블릿이 각 단계에서 보여 줄 화면과 애니메이션 완료 조건

서버 제한시간과 화면 연출 시간은 분리한다. 화면 애니메이션이 끝났다는 사실이 서버
규칙상 상태 전이를 일으켜야 한다면 별도 완료 callable과 멱등 키를 설계한다.

### 2.2 Flutter 게임 패키지를 만든다

1. `packages/game_template`을 `packages/game_<gameId>`로 복사한다.
2. 패키지의 `pubspec.yaml`에서 `name`, `description`과 import의 `game_template`을 바꾼다.
3. 루트 `pubspec.yaml`의 `workspace`와 `dependencies`에 패키지를 추가한다.
4. `lib/game_<gameId>.dart`에서 `TemplateGame` 구현을 완성한다.
5. 루트 [`GameRegistry`](../../lib/games/game_registry.dart)에 import와 게임 인스턴스를
   추가한다.

`TemplateGame` 연결 항목은 다음과 같다.

| 항목 | 역할 |
| --- | --- |
| `id` | Firestore·RTDB·함수와 공유하는 안정적인 게임 ID |
| `title` | 패키지 내부 fallback 이름. 로비 표시는 Firestore 다국어 정보를 우선 사용 |
| `leaveFunctionName` | 게임 도중 퇴장 callable |
| `phoneOrientation` | 휴대폰 게임 화면 방향 |
| `tableColor`, 배경·자리 이미지 | 로비에서 게임 진입 후 사용할 시각 테마 |
| `startGame` | 자리 설정 완료 뒤 서버 시작 callable 호출 |
| `watchStatus` | `game/public/status` 구독 |
| `buildStartSetupScreen` | 게임별 시작 설정이 있을 때만 구현 |
| `buildPhoneScreen` | 휴대폰 게임 route의 최상위 화면 |
| `buildTabletScreen` | 진행 태블릿 게임 route의 최상위 화면 |

번들 게임의 `requiredAssetVersion`은 0이다. 다운로드형 게임은
[Package Migration](PACKAGE_MIGRATION.md)의 manifest·에셋 규칙에 따라 1 이상을 사용한다.

### 2.3 화면과 상태를 연결한다

화면은 다음 책임으로 나눈다.

```text
lib/game_<gameId>.dart              플랫폼 등록과 두 기기 진입점
lib/phone/phone_board.dart          휴대폰 phase → 화면·문구·연출 연결
lib/tablet/tablet_board.dart        태블릿 phase → 화면·문구·연출 연결
lib/{phone,tablet}/screens/         단계별 화면
lib/{phone,tablet}/widgets/         화면 구성 요소
lib/{phone,tablet}/animations/      기기별 연출
lib/{phone,tablet}/src/board_state.dart
                                    세션 수명·화면 단계 번역
lib/shared/models/game_state.dart   불변 클라이언트 상태
lib/shared/providers/               세션 controller/provider
lib/shared/services/                명령·조회·snapshot mapper
```

- `phone_board.dart`와 `tablet_board.dart`가 실제 화면 교체 지점이다.
  `GameFlowStep.screenWidget` 설명만 바꿔서는 화면이 연결되지 않는다.
- 서버의 `status/phase`를 `game_stage.dart`의 기기별 표시 단계로 변환하고, board의 화면
  생성 함수 또는 switch에서 실제 `Screen`을 반환한다.
- 같은 화면을 여러 phase가 공유하면 StatefulWidget의 key와 인스턴스 수명을 보존한다.
  단계가 바뀔 때마다 새 route를 push하거나 구독을 다시 만들지 않는다.
- build에는 `ref.watch`, 소리·모달·단발 애니메이션 같은 부수효과에는 `listenManual`을
  사용한다. 방·UID·기기 역할당 controller 하나만 만든다.
- 휴대폰은 자신의 `game/private/{uid}`를 함께 구독하고 태블릿은 공개 상태만 구독한다.
- 앱 공용 문구는 앱 ARB, 게임 패키지 문구는 `GameLocale`과 게임별 copy getter로
  `ko`, `en`, `zh-Hans`, `zh-Hant`를 제공한다.
- 이미지 접근은 `GameImage`를 거친다. 다른 게임 패키지를 import하지 않고, 여러 게임이
  공유할 구현만 `game_kit`에 둔다.

새 표지·책등·자리 배치 테마가 필요하면 `MosiGameArt`와 `MosiSeatTheme`의 ID 매핑도
검토한다. 매핑을 추가하지 않으면 공용 fallback 디자인이 사용되는지 화면으로 확인한다.

## 3. 서버 통신과 데이터 규칙

### 3.1 RTDB 데이터 경계

게임 상태는 `rooms/{roomCode}/game` 아래에서 다음처럼 나눈다.

```text
game/
  public/                 방 참가자와 진행 태블릿이 읽을 수 있는 상태
    gameType
    status
    phase
    revision
    updatedAt
    ...
  private/{uid}/          해당 UID만 읽는 손패·역할 등
    ...
  server/                 클라이언트가 읽거나 쓰지 못하는 덱·정답·명령 기록 등
    processedCommands/
    ...
```

공개 화면을 만드는 데 필요하지 않은 정보는 `public`에 두지 않는다. 개인 카드·역할은
`private/{uid}`, 덱 순서·정답·검증 자료는 `server`가 소유한다. RTDB rules의 공통
`public/private/server` 경계는 새 게임에도 그대로 적용되므로 게임별 client write rule을
추가하지 않는다.

### 3.2 Cloud Functions 구성

`functions/src/<gameId>/`에 최소한 다음 책임을 둔다.

- 타입과 순수 규칙·검증 함수
- `game_<gameId>_start_game`
- 플레이어 행동 callable
- 애니메이션 완료가 서버 단계에 영향을 줄 때의 완료 callable
- 턴 시간 초과 처리
- 결과·다음 라운드·게임 종료
- `game_<gameId>_leave_game`
- 참가자 제외와 인원 부족 종료 adapter

모든 배포 함수는 `functions/src/index.ts`에서 명시적으로 export한다. 함수 이름은 배포 후
public API이므로 임의로 바꾸지 않는다.

각 상태 변경 callable은 다음 순서를 지킨다.

1. Firebase Auth와 호출 역할을 확인한다.
2. `roomCode`, room instance, controller session 또는 player membership을 확인한다.
3. 현재 `selectedGame`, status, phase, turn UID와 revision을 확인한다.
4. payload의 타입·범위·소유권을 검증한다.
5. RTDB transaction 안에서 최신 상태를 다시 검사하고 한 번에 갱신한다.
6. 재시도 가능한 명령은 `commandId` 결과를 `server`에 기록해 멱등 처리한다.
7. 서버 시각으로 deadline과 `updatedAt`을 저장한다.
8. 클라이언트에는 필요한 결과만 반환하고 private/server payload를 로그에 남기지 않는다.

Flutter 명령은 `GameCommandService.invoke`를 사용한다. `retryTransientFailure: true`는 서버가
같은 `commandId`를 멱등 처리하는 명령에만 켠다. 조회는 `GameQueryService`의
`publicRef`, `privateRef`, `watchPublicGame`, `watchPrivatePlayer`를 사용한다.

새 게임은 공통 복구 코드의 하드코딩 지점도 확인해야 한다.

- `functions/src/game-interruption/game-adapters.ts`: 참가자 제외 후 계속 진행
- `functions/src/game-interruption/finish-now-resolution.ts`: 인원 부족 즉시 종료
- 게임별 타이머가 있으면 recovery state의 deadline/turn limit 처리
- `packages/game_kit/lib/services/game_command_service.dart`: 진단용 명령 이름

지원하지 않은 상태로 공개하면 단절 후 제외·종료가 실패할 수 있으므로 정상 플레이만으로
완료 판정하지 않는다.

## 4. Firestore 게임 카탈로그

Firestore는 게임 코드나 진행 상태를 저장하는 곳이 아니다. `games/{gameId}`는 로비·상점에
표시할 메타데이터와 공개 여부만 소유한다. 클라이언트 쓰기는 `firestore.rules`에서
금지되어 있으므로 Firebase Console 또는 승인된 Admin 스크립트로 등록한다.

### 4.1 새 문서의 필수 형태

새 게임은 아래 필드를 모두 저장한다. 첫 등록에서 `enabled`와 `storeVisible`은 반드시
`false`다.

```yaml
# 문서 경로: games/example_game
name: "예시 게임"                         # 구버전용 한국어
localizedNames:
  ko: "예시 게임"
  en: "EXAMPLE GAME"
  zh-Hans: "示例游戏"
  zh-Hant: "範例遊戲"

description: "게임을 한 문단으로 소개합니다."
localizedDescriptions:
  ko: "게임을 한 문단으로 소개합니다."
  en: "Describe the game in one short paragraph."
  zh-Hans: "用一个简短段落介绍游戏。"
  zh-Hant: "用一個簡短段落介紹遊戲。"

rules: "한국어 전체 규칙"
localizedRules:
  ko: "한국어 전체 규칙"
  en: "Full rules in English"
  zh-Hans: "简体中文完整规则"
  zh-Hant: "繁體中文完整規則"

genres: ["카드", "전략"]                 # 구버전용 한국어
localizedGenres:
  ko: ["카드", "전략"]
  en: ["Cards", "Strategy"]
  zh-Hans: ["卡牌", "策略"]
  zh-Hant: ["卡牌", "策略"]

minPlayers: 2
maxPlayers: 6
playTime: 20                              # 분
order: 5                                  # 로비·상점 정렬
accessType: "paid"                        # "free" 또는 "paid"를 명시
enabled: false                            # 첫 등록 기본값
storeVisible: false                       # 첫 등록 기본값
minAppVersion: "1.0.0"                    # 이 게임 코드가 포함된 최소 앱 버전
```

필드 형식은 Firestore에서 다음 타입을 사용한다.

| 필드 | Firestore 타입 |
| --- | --- |
| 이름·소개·규칙 map 값 | string |
| `genres`, locale별 장르 | array<string> |
| `localizedNames` 등 | map |
| `minPlayers`, `maxPlayers`, `playTime`, `order` | number/integer |
| `enabled`, `storeVisible` | boolean |
| `accessType`, `minAppVersion` | string |

`imageUrl`, `componentImageUrl`, `ruleVideoUrl`은 원격 자료가 있을 때만 추가한다.
비소모성 상품 연결이 생기면 `storeProductIds.appStore`와
`storeProductIds.googlePlay`을 추가할 수 있지만, 현재 비활성 결제 gateway에서는 과금이나
소유권 부여가 일어나지 않는다.

### 4.2 Console에서 저장하는 순서

1. Firebase project `project0000-ec01e`의 Firestore `games` 컬렉션을 연다.
2. 문서 ID를 정확한 `gameId`로 생성한다.
3. 위 네 locale map과 한국어 legacy 필드, 인원·시간·정렬·접근 필드를 입력한다.
4. `enabled`를 boolean `false`, `storeVisible`을 boolean `false`로 저장한다.
5. 문서를 다시 열어 두 값의 타입과 네 locale 키를 확인한다.
6. 비공개 상태에서 앱·서버·권한·실기기 검증을 마친다.

필드를 생략하지 않는다. 현재 앱과 서버는 Firestore snapshot에서 `enabled == true`일 때만
실행 가능하다고 판단한다. `storeVisible`도 정확히 `true`일 때만 상점에 나타난다.

### 4.3 공개 조합

| `enabled` | `storeVisible` | `accessType` | 결과 |
| ---: | ---: | --- | --- |
| false | false | free/paid | 완전 비공개. 새 게임 첫 등록 상태 |
| false | true | free/paid | 상점에 출시 예정으로만 표시 |
| true | false | free | 모든 계정의 개인 게임 목록에 표시, 상점에는 숨김 |
| true | false | paid | `ownedGames` 보유 계정만 표시, 상점에는 숨김 |
| true | true | free | 개인 게임 목록과 상점에 표시 |
| true | true | paid | 보유자는 실행, 미보유자는 상점에서 구매 준비 상태 |

실제 결제가 없는 현재 단계에서 제한 테스트가 필요하면 `enabled: true`,
`accessType: paid`, `storeVisible: false`로 바꾼 뒤 테스트 계정의
`users/{uid}.ownedGames` 배열에 `gameId`를 추가한다. 이 변경도 운영 데이터 변경이므로
대상 계정·문서·검증 범위를 확인하고 승인된 절차로 수행한다.

## 5. 공개 순서

1. 게임 계약과 작업 ID를 만든다.
2. Flutter package, 양 기기 화면과 서버 순수 규칙을 구현한다.
3. Functions와 앱의 ID·callable·status 대응 테스트를 통과시킨다.
4. Firestore 문서를 `enabled: false`, `storeVisible: false`로 등록한다.
5. 필요한 Functions와 rules 배포 범위를 검토하고 별도 승인을 받는다.
6. 새 앱/패치를 배포하고 비공개 계정으로 양 기기·재접속·퇴장을 검증한다.
7. 출시 예정 진열이 필요할 때만 `storeVisible: true`로 바꾼다.
8. 실제 플레이 공개 준비가 끝난 뒤 마지막 단계에서 `enabled: true`로 바꾼다.

Firestore 문서를 먼저 활성화하지 않는다. catalog에는 게임이 있어도 현재 앱의
`GameRegistry`나 서버 callable에 코드가 없으면 선택·시작·복구가 실패한다.

## 6. 필수 검증

- Flutter: package 단위 모델·mapper·controller·phone/tablet widget 테스트
- Functions: 순수 규칙, 인증/역할, 잘못된 phase, 중복 command, timeout, 종료 테스트
- 통합: 목록 → 선택 → 자리 배치 → 시작 → 플레이 → 결과 → 다시하기/종료
- 권한: 다른 사용자의 private 상태 차단, client game write 차단
- 복구: 휴대폰·태블릿 단절, 앱 재실행, 참가자 제외, 인원 부족 종료
- locale: `ko`, `en`, `zh-Hans`, `zh-Hant`의 목록·상세·규칙·게임 화면
- 레이아웃: 휴대폰/태블릿, 작은 화면, 긴 번역, 화면 회전 정책
- 에셋: 번들 또는 다운로드 manifest, 오프라인 캐시와 버전 불일치

빠른 검사 뒤 저장소 루트에서 관련 Project CLI suite를 실행하고, 최종 후보는 사용자 승인
후 `dart run :mosigame validate --full`을 실행한다. 운영 Firebase 등록, Functions/rules
배포, migration과 실제 공개 플래그 변경은 각각 별도 승인과 기록을 남긴다.

## 7. 완료 체크리스트

- [ ] 하나의 `gameId`가 package/registry/RTDB/Functions/Firestore에서 일치한다.
- [ ] `game_template` 기반 package와 루트 workspace/dependency/registry 연결이 끝났다.
- [ ] 휴대폰·태블릿 board가 모든 서버 phase를 실제 Screen으로 연결한다.
- [ ] 공개·개인·서버 상태가 분리되고 클라이언트 직접 쓰기가 없다.
- [ ] 모든 재시도 명령이 서버 `commandId` 멱등 처리를 갖는다.
- [ ] start/action/timeout/result/end/leave와 interruption adapter가 연결됐다.
- [ ] 네 언어 이름·소개·규칙·장르가 Firestore 문서에 있다.
- [ ] Firestore 첫 저장값이 `enabled: false`, `storeVisible: false`다.
- [ ] 무료/유료 `accessType`과 테스트 소유권 정책을 명시했다.
- [ ] 패키지 경계 검사와 관련 Flutter/Functions/Project CLI 검사가 통과했다.
- [ ] 승인된 앱·서버 배포와 실제 기기 검증 뒤에만 공개 플래그를 변경했다.
