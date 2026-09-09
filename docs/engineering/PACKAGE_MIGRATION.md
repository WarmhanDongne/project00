# 고정 플랫폼 앱과 게임별 패키지·다운로드 계획

라이어스포커·파이널콜·마피아는 앱에 번들하고, **그 다음 게임부터는 앱 안에서
받아서 플레이**하는 구조의 기준 문서다. 2026-09-09에 확인한 `origin/develop`
`d1c40aa`는 플랫폼을 앱에 두고 공용 기반을 `game_kit`으로 합친 5개 workspace
package 구조다. 9월 7일의 7개 패키지 분리는 중간 단계였으며
[당시 기록](../planning/logs/2026-09.md#package-migration-01)에 보존한다. 현재 경계 상태는
`python3 tool/check_package_boundaries.py`의 위반 수로 판정한다.

다운로드 게임 기반은 영구 캐시와 Firebase Storage 경계까지 구현했다. 다운로드 버튼,
실제 Storage 업로드·Rules, 신작 게임과 Shorebird 배포 리허설은 제품 작업 시 진행한다.
코드와 다르면 코드를 먼저 조사하고 차이를 보고한다.

`다운로드`는 사용자 관점에서 게임 에셋을 선택적으로 받는다는 뜻이다. Flutter
Dart package를 Firebase에서 받아 동적 로드한다는 뜻이 아니다. 플랫폼·인증·방·홈은
하나의 Mosigame 앱에 고정 내장되고, 게임 코드만 각 `game_<game>` package로 경계를
갖는다.

## 현재 코드 구조

패키지 배치와 다운로드 기반은 구현됐고, 실제 다운로드 UI·운영 전송·기기 검증은
남아 있다. 현재 배치는 아래와 같다.

```text
project00/                    앱 = 플랫폼 + 셸
├─ lib/main.dart · app.dart
├─ lib/games/game_registry.dart
├─ lib/game_assets/           런타임 게임 에셋 다운로드
├─ lib/platform/              인증 · 방 · 홈 · 프로필 · 테마
└─ packages/                  게임 관련만
   ├─ game_kit/               공용 기반 — core·firebase·계약·셸·연출
   ├─ game_template/          새 게임 복사용 스켈레톤
   ├─ game_liars_poker/       번들 게임
   ├─ game_final_call/        번들 게임
   └─ game_mafia/             번들 게임
```

의존 규칙은 `python3 tool/check_package_boundaries.py` 가 강제한다(현재 위반 0건).

```text
game_<게임>  ──▶  game_kit          게임은 game_kit 만 본다
앱 lib/      ──▶  game_kit + 게임들  앱은 전부 본다
game_kit     ──▶  (내부 패키지 없음) Flutter·Firebase 등 외부 의존성은 있다
```

**게임 package 는 앱(`project00`)과 플랫폼을 의존하지 않는다.** 그래서 게임만
따로 떼어 Shorebird 패치로 추가할 수 있다.

## 1. 결정적 제약 — Shorebird가 무엇을 못 하는가

이 설계는 Shorebird의 두 가지 한계가 정한다. 먼저 확인하지 않으면 전체가 틀어진다.

| Shorebird 패치 | 가능 | 근거 |
| --- | --- | --- |
| Dart 코드 변경·추가(새 클래스·새 파일) | O | 새 게임 코드를 패치로 보낼 수 있다 |
| 순수 Dart 패키지 추가 | O | 새 게임 패키지가 순수 Dart면 패치 가능 |
| **에셋(이미지·사운드) 추가·변경** | **X** | 공식 문서: asset patching is not yet supported |
| **네이티브 코드·플러그인 추가** | **X** | 스토어 바이너리에 네이티브 부분이 없어 크래시 |

여기서 두 가지가 따라 나온다.

- **새 게임의 코드는 Shorebird 패치로, 에셋은 런타임 다운로드로 간다.** 에셋을
  패치에 실을 수 없으므로 다른 선택지가 없다.
- **새 게임은 새 네이티브 플러그인을 쓸 수 없다.** 앞으로 필요할 플러그인은
  지금 번들에 들어 있어야 한다. 순수 Dart 패키지만 추가할 수 있다.

세 번째로 성능 주의사항이 있다. iOS에서 **패치된 코드는 AOT가 아니라 Dart
인터프리터로 실행된다.** 패치로만 배포한 새 게임은 그 게임 코드 전체가 여기
해당한다. 태블릿 연출이 무거우면 체감될 수 있다. 완화책:

- 애니메이션·레이아웃 프리미티브는 `game_kit`에 두고 새 게임은 얇게 유지한다
  (`game_kit`은 패치에 포함되지 않으므로 AOT로 남는다).
- 패치로 나간 게임은 다음 정식 릴리스에 접어 넣어 AOT로 되돌린다.

스토어 정책상 코드 업데이트 자체는 양쪽 다 허용하지만, 앱의 **본래 목적을 바꾸는**
기능 추가는 금지다. 미니게임 플랫폼에 미니게임을 더하는 것은 목적에 부합한다.

## 2. 새 게임의 진입점과 의존 방향

[`game_template`](../../packages/game_template/lib/example_game.dart)을 복사해
`packages/game_<신작>/`을 만들고 package 이름·import·게임 식별자를 맞춘다.
루트 workspace와 앱 의존성에 등록하고
[`GameRegistry`](../../lib/games/game_registry.dart)에 게임을 추가한다.
플랫폼은 주입된 `GameCatalog`를 사용하므로 게임별 분기를 넣지 않는다.

공용 계약은 [`TemplateGame`](../../packages/game_kit/lib/template_game.dart)과
[`GameRoomContext`](../../packages/game_kit/lib/models/game_room_context.dart)에 있다.
게임은 `game_kit`을 사용하며 `project00`과 다른 게임 패키지를 의존하지 않는다.
의존 방향은 pubspec 선언과 경계 검사로 확인한다.

스켈레톤 자체는 앱 의존성이 없고 실행 게임으로 등록되지 않는다. 복사본을 다운로드
게임으로 등록할 때는 템플릿의 `flutter.assets`와 FlutterGen 설정을 제거하고 §4·§6의
무에셋 규칙을 적용한다. 서버 command는 `functions/src/<game>/`에서 구현한다.

## 3. 구조 검사와 에셋 소유권

```text
python3 tool/check_package_boundaries.py
```

루트 앱은 부트스트랩·조립·레지스트리와 플랫폼을 소유한다. 공용 코드·에셋은
`game_kit`, 게임 3종의 코드·에셋은 각 게임 패키지가 소유한다. 플랫폼 에셋과 생성물은
루트 `assets/`와 `lib/gen/`에 있다. 각 에셋 소유 패키지는 자기 `assets.gen.dart`를
생성한다. 패키지 에셋은 `GameImage`가 package 이름을
보존하며, 사운드는 `packages/<package>/assets/...` 번들 키를 그대로 재생한다.

경계 검사는 이제 가상 배치가 아니라 루트와 모든 `packages/*/lib`를 직접 스캔한다.
금지 import, pubspec 역방향 의존, 루트 레거시 소스의 재등장을 함께 검사하며 CI 기준은
`--max 0`이다.

## 4. 에셋 — 번들 게임과 다운로드 게임

`packages/game_kit/lib/core/assets/game_asset_store.dart`가 번들·다운로드 에셋의 단일 해석
지점이다. 앱 시작 때 `initializeGameAssets`가 Application Support 아래의 영구 캐시와
현재 Shorebird patch 번호를 연결하지만 네트워크 요청은 하지 않는다. 향후 소유 게임
버튼이 `downloadGame(gameId)`을 명시적으로 호출할 때만 Firebase Storage에서 받고,
`prepareGame(gameId)`은 진입 직전 이미 설치된 파일의 SHA-256만 확인한다.
`imageProviderFor` / `soundSourceFor` / `cacheableAssetPath`가 번들과 캐시를 나눈다. 게임 화면은
`Assets....game`(`GameImage`)나 원격 핸들만 쓰므로 **화면 코드를 고치지
않고** 저장 위치를 바꿀 수 있다.

### 번들 게임 3종

각 패키지가 자기 `assets/`를 갖고 자기 `assets.gen.dart`를 생성한다
(`flutter_gen`의 패키지별 설정). 참조 경로는 `packages/<패키지명>/...`이 된다.
이렇게 해야 `gen/assets.gen.dart` 위반 61건이 사라진다.

### 다운로드 게임

**pubspec에 에셋을 한 줄도 넣지 않는다.** 넣는 순간 Shorebird 패치가 아니라
정식 릴리스가 필요해진다. 대신 논리 경로만 선언한다.

```dart
// GameImage에 추가할 두 번째 생성자
GameImage.remote(
  gameId: 'new_game',
  assetVersion: 3,
  logicalPath: 'images/background.webp',
)
```

`GameAssetStore`가 다운로드 캐시에서 해석하고, 없거나 손상됐으면 휴대폰의 게임 진입,
태블릿 시작·복구를 막는다. 번들 게임은 기존 패키지 에셋을 계속 사용하지만 다운로드
게임은 폴백할 번들이 없다.

Firebase Storage 경로는 다음으로 고정한다.

```text
game-assets/<gameId>/manifest.json
game-assets/<gameId>/<assetVersion>/<logicalPath>
```

캐시 로직은 `GameAssetSource` 계약으로 파일 전송을 분리한다. `game_kit` 패키지에는
별도 Firebase 서비스도 포함돼 있다. 앱 셸의
`FirebaseGameAssetSource`가 로그인 사용자의 Firebase 자격 증명으로 Storage 파일을
직접 로컬 `.part`에 받는다. Functions가 파일을 중계하지 않는다.

### 매니페스트

```json
{
  "gameId": "new_game",
  "assetVersion": 3,
  "requiredPatchNumber": 12,
  "files": [
    {"path": "images/background.webp", "sha256": "...", "bytes": 812345, "device": "both"},
    {"path": "images/background_phone.webp", "sha256": "...", "bytes": 402111, "device": "phone"}
  ]
}
```

`<appSupport>/mosigame/games/<gameId>/<assetVersion>/`에 받는다. 파일과 검증에 사용한
`.manifest.json`을 함께 보존하고 모든 파일의 SHA-256이 맞은 뒤 `.complete`를 쓴다.
앱 재실행 뒤에는 로컬 매니페스트로 검증하므로 네트워크 없이 캐시를 재사용할 수 있다.

**버전 결합이 이 설계에서 가장 깨지기 쉬운 곳이다.** 코드는 Shorebird 패치로,
에셋은 매니페스트로 따로 오기 때문에 둘이 어긋나면 게임이 조용히 깨진다.
그래서 매니페스트에 `requiredPatchNumber`를 두고, 게임 코드에는
`requiredAssetVersion`을 둔다. 둘 중 하나라도 맞지 않으면 게임 목록에서
"업데이트 필요"로 표시하고 진입을 막는다. 이 판정은 기존
`isGamePlayableOnThisBuild` 한 곳에 함께 넣는다.

### 기기별 분리는 나중에

`device` 필드는 지금 넣되 **필터링은 켜지 않는다.** 실측 결과 기기별로 갈라서
아껴지는 용량은 2.4MB 미만이고, 게임 단위 분리(마피아만 18.31MB)가 10배 크다.
폴더를 `{phone,tablet,shared}`로 재배치하는 것은 이득 대비 비용이 맞지 않는다.
매니페스트 태그로 충분하고, 필요해지면 그때 필터를 켠다.

## 5. 단계와 통과 기준

각 단계 끝에서 `dart run :mosigame validate --full`과 경계 검사를 통과해야
다음으로 넘어간다. **어느 단계에서 멈춰도 앱은 동작하는 상태로 남는다.**

| 단계 | 내용 | 통과 기준 |
| --- | --- | --- |
| 0 | **완료** 경계 청소 | 코드·에셋 경계 118 → 0 |
| 0a | **완료** `room_character` → `core/constants/` | 118 → 106 (−12) |
| 0b | **완료** `core/app/app.dart` → `lib/app.dart` | 앱 조립 책임 분리 |
| 0c | **완료** 플랫폼의 `GameRegistry` 의존 제거(`GameCatalog` 주입) | 정적 레지스트리 참조 0 |
| 0d | **완료** `TemplateGame`: `RoomProvider` → `GameRoomContext` | 게임의 플랫폼 provider 참조 0 |
| 0e | **완료** 플랫폼이 쓰는 shared 조각을 계약/소유 계층으로 재배치 | 코드 계층 위반 0 |
| 0f | **완료** 게임별 에셋 소유권과 패키지별 생성 전환 | −61 |
| 0g | **완료** core의 생성 에셋 역방향 참조 제거 | −3 |
| 1 | **구조 구현** 패키지 5개 + `resolution: workspace` | 현재 후보의 pub get·FULL 결과는 월별 기록에서 확인 |
| 2–3 | **구조 구현** core·Firebase·계약·공용 UI를 `game_kit`에 통합 | 내부 패키지 의존 방향과 경계 검사 |
| 4 | **구조 구현** 플랫폼을 앱 `lib/platform/`에 유지 | 게임 패키지의 앱 참조 금지 |
| 5 | **완료** 게임 3개와 패키지별 에셋 물리 이동 | analyze·경계 검사 통과, 앱 실행 확인 남음 |
| 6 | **구조 구현** 영구 캐시·Firebase Storage source·SHA-256·재시작 검증·수동 다운로드 API | 자동 테스트 통과, 실제 Storage/기기 전송은 다운로드 UI 작업 때 확인 |
| 7 | **추가 준비 완료 / 실제 리허설 보류** `requiredAssetVersion > 0` 게임의 자동 등록과 무에셋 패키지 규칙 | 실제 신작 선정 후 스토어 기준 빌드→staging patch→기기 확인 필요 |

단계 6의 저장·검증 경로는 메모리 source를 사용한 자동 테스트로 다운로드, 동시 요청,
손상 거부, patch/asset 불일치, 재실행·오프라인 캐시 재사용까지 확인한다. 실제 Firebase
Storage 전송과 기기 저장 권한은 다운로드 버튼을 붙일 때 번들 게임 하나의 복제
매니페스트로 먼저 리허설한다. 신작으로 처음 시험하면 실패 원인이 다운로드인지 새
게임인지 구분되지 않는다.

## 6. 신작 게임의 하드 룰

이 규칙 중 하나라도 어기면 패치가 아니라 정식 릴리스가 필요해진다.

1. **pubspec에 에셋 항목 0개.** 모든 리소스는 매니페스트로 받는다.
2. **새 네이티브 플러그인 금지.** 순수 Dart 패키지만 추가할 수 있다.
   필요한 플러그인은 미리 번들에 넣어 릴리스해 둔다.
3. **`assets.gen.dart` 사용 금지.** `GameImage.remote`만 쓴다.
4. **`game_kit`의 공개 API를 바꾸지 않는다.** 바꾸면 번들 게임
   3종도 함께 패치돼야 하고 패치 크기와 위험이 커진다.
5. **연출은 `game_kit`의 프리미티브를 재사용한다.** iOS에서 패치 코드는
   인터프리터로 돈다.

## 7. 하지 않기로 한 것

- **melos 도입.** Dart 3.6+의 pub workspaces로 충분하다(이 저장소 SDK는
  `^3.12.2`). 스크립트 러너가 필요해지면 그때 얹는다. Project CLI가 이미 있다.
- **에셋 폴더의 기기별 재배치.** §4 참조.
- **Dart 코드의 기기별 분리.** Flutter deferred components는 Android 전용이고
  iOS는 지원하지 않는다. 태블릿이 아이패드인 이상 불가능하다.
