---
description: 새 게임을 표준 구조로 추가 — 화면을 받아 매끄럽게 연결하고 애니메이션을 배선
argument-hint: [게임 이름 또는 설명]
---

# 새 게임 추가 가이드

사용자가 새 게임을 추가하려 합니다: $ARGUMENTS

너의 역할: 사용자가 주는 화면(screen)들을 이 프로젝트의 표준 게임 구조에
매끄럽게 연결하고, 단계 전환마다 적절한 애니메이션을 배선하는 것.
모르는 것은 추측하지 말고 사용자에게 물어본다.

## 시작 전 필독

1. `AGENTS.md` — 변경 전 필수 원칙 10가지
2. `AI_GAME_DEVELOPMENT_GUIDE.md` — 상태 머신·Riverpod·Cloud Functions 상세
3. `lib/games/_game_template/README.md` — 스캐폴드

2번 문서는 저장소에 포함되지 않는다. 없으면 건너뛰고 `AGENTS.md`와 코드를 기준으로 한다.

## 구조 기준

두 게임 모두 같은 표준을 따른다: **컨트롤러 1개 공유**(phone/tablet이
`watchPrivateHand`로 역할 구분), **providers 2파일**(game_state +
session_provider), **models/ 분리**. 새 게임도 동일하게 만든다.

휴대폰 흐름만 게임 특성에 따라 갈린다:
- 기본값: **GameScreenPhase + PhoneGameShell** (Final Call 방식)
- 예외: 가로·세로 회전을 지원하고 안내 문구가 손패 연출에 결합된 게임은
  Liar's Poker처럼 자체 슬롯 레이아웃을 쓴다. 예외를 택하면 그 이유를
  화면 주석에 남긴다.

아래 3가지 준비 작업은 Liar's Poker에는 있고 Final Call에는 빠져 있다.
**새 게임에는 반드시 넣는다**:

1. **에셋 preload** — `loading/<id>_loading.dart`에서 이미지·프로필 `precacheImage`
   (LP: `lib/games/liars_poker/loading/liars_poker_loading.dart` 참고)
2. **게임 사운드 정의 + preloadTargets** — `sound/<id>_sounds.dart`
   (FC의 `final_call_sounds.dart`는 빈 파일이다. LP 것을 참고)
3. **핵심 callable warmup** — 첫 조작 함수의 콜드스타트 제거
   (LP `warmUpGameplayCommands` 참고. 서버 함수에 `{warmup: true}` 조기 반환 추가)

## 0단계 — 인터뷰 (답을 받기 전에 코드를 시작하지 마라)

아래를 모두 확인한다. 화면 파일을 이미 받았어도 답이 안 나오는 항목은 물어본다:

1. **게임 id** (snake_case). 이 값 하나가 `TemplateGame.id` = `assets/games/<id>/` = `functions/src/<id>/` = 함수 접두사 `game_<id>_`로 전부 쓰인다.
2. **인원** — 최소/최대 또는 고정. 팀전인가? (`game-interruption/functions.ts`의 `MINIMUM_PLAYER_COUNTS`에도 추가해야 한다)
3. **휴대폰 화면 방향** — 세로/가로/둘 다 (`PhoneGameOrientation`)
4. **턴 구조** — 턴 제한시간? 타임아웃 시 서버가 뭘 하나(자동 제출/스킵/탈락)?
5. **라운드 구조와 승패 조건** — 언제 게임이 끝나나? 동점 처리?
6. **탈락자** 발생하나? 탈락자 관전 모드가 필요한가?
7. **비공개 정보** — 손패처럼 본인만 봐야 하는 것 → `game/private/{uid}` 설계
8. **벌칙/미니게임** 있나? (룰렛 등)
9. **에셋** — 이미지/사운드 파일이 준비됐나? 룰 영상 URL? 없으면 어떤 파일이 어떤 경로에 필요한지 목록으로 요청
10. **받을 화면 목록** — 휴대폰/태블릿 각각 어떤 화면을 줄 것인지

## 1단계 — 서버 먼저 (functions/src/<id>/)

- 함수 이름 규칙: `game_<id>_<동작>` (예: `game_dutch_start_game`). 공용은 `game_common_*`, 방·인증은 camelCase 유지.
- 최소 함수 세트: `start_game`(restart 겸용), `complete_dealing`, `leave_game`, `end_game` + 게임 고유 조작들
- 모든 조작 함수: `commandId` 멱등 처리 (`server.processedCommands`), 트랜잭션, `revision` 증가
- 상태 3분할: `game/public`(전원 공개) / `game/private/{uid}`(본인만) / `game/server`(클라이언트 차단 — RTDB 규칙이 이미 막고 있음)
- region: callable은 `asia-northeast3`, RTDB 트리거는 `asia-southeast1` (인스턴스 리전 제약)
- `src/index.ts`에 export (도메인별 섹션 주석 유지), `functions/test/*.test.mjs` 작성
- ⚠️ 배포된 callable 이름은 바꾸면 구버전 앱이 못 찾는다. 이름은 처음부터 규칙대로.
- ⚠️ 함수 배포(`firebase deploy`)는 사용자가 직접 실행한다. 배포 계획(생성/삭제 목록)만 정리해서 전달.

## 2단계 — 클라이언트 뼈대

```
lib/games/<id>/
  <id>_game.dart          TemplateGame 구현 (id, 인원, 방향, leaveFunctionName='game_<id>_leave_game')
  <id>_flow_config.dart   단계 전환 타이밍·안내 문구 흐름
  <id>_copy.dart          사용자 문구 + phoneRules (휴대폰 룰 다이얼로그 문구)
  models/                 카드·플레이어 등 도메인 모델
  providers/              <id>_game_state.dart(불변) + <id>_session_provider.dart(autoDispose.family)
  controllers/            <id>_controller.dart — 딱 1개, phone/tablet 공용
  services/               <id>_command_service.dart(callable 쓰기) / <id>_query_service.dart(RTDB 구독)
  screens/phone_game.dart           GameScreenPhase 번역 + PhoneGameShell
  screens/phone/phone_game_screen.dart
  screens/tablet_game.dart          typed stage enum + _resolveStage 한 곳
  screens/tablet/                   stage, layer, overlay, helper, animation
  widgets/phone/  widgets/tablet/
  animations/             이 게임 전용 연출만 (2게임 이상 쓰면 shared로)
  sound/<id>_sounds.dart  효과음 경로 + preloadTargets
  loading/<id>_loading.dart  에셋 preload + (선택) 로딩 팁
```

등록은 `game_registry.dart`에 한 줄. **플랫폼 화면에 게임 id 분기(if/switch)를 추가하지 마라.**

## 3단계 — 받은 화면 연결

1. 받은 화면마다 `화면 → GameScreenPhase/태블릿 stage` 매핑 표를 먼저 만들어 **사용자에게 확인받는다**.
2. 매핑에 구멍이 있으면(연결 중/대기/재접속/중단/결과 등) 그 화면을 요청하거나, shared 위젯으로 채울지 물어본다.
3. 서버 상태 해석은 한 곳에서만: 휴대폰 `_resolvePhase`, 태블릿 `_resolveStage`. 하위 위젯은 서버 문자열을 다시 추측하지 않는다.
4. 서버 미러 상태는 불변 provider, 연출·애니메이션 상태는 위젯 로컬 `State`. 섞지 마라.
5. RTDB 구독은 세션 컨트롤러 한 곳. 위젯마다 구독 만들지 마라.

## 4단계 — 애니메이션 연결 지점

| 시점 | 사용할 것 | 주의 |
|---|---|---|
| 게임 진입 | `shared/animations/game_entry_unroll.dart` 등 | |
| 카드 분배 | `shared/animations/card_deal.dart` | 분배음이 착지 시점에 자동 재생됨. 커스텀 금지 |
| 휴대폰 손패 수신 | `shared/animations/phone_card_receive_animation.dart` | |
| 안내 문구 (ROUND 등) | `GameAnnouncementLayer` | **화면 정중앙 보정 필수** — 손패 영역 기준으로 놓으면 위로 치우친다. LP의 `announcementCenterOffset` 참고 |
| 결과 | 게임별 result + shared `phone_result_dialog` | |
| 종료/HOME | **즉시 화면 닫기** | 정리 장면(프로필 사라지는 모습) 노출 금지. FC의 `stageBeforeExit` 유지 기법 참고 |

- 새 라운드에 위젯 key를 갈아끼울 때, `initState`/`dispose`에서 외부 `Listenable`을 건드리면 빌드 중 notify로 죽을 수 있다. 알림은 프레임 이후로 미룬다.
- 연출 타이밍이 취향 문제로 갈리면(속도·방향·정지 시간) 구현 전에 사용자에게 물어본다.

## 5단계 — 필수 버튼·기능 체크리스트 (빠지면 미완성)

**휴대폰**
- [ ] 상단바: 팁(룰) / 설정 / 나가기 버튼 (`shared/widgets/phone_game_top_bar.dart` 계열)
- [ ] 룰 다이얼로그 — `<id>_copy.dart`의 `phoneRules` (마크다운 불가, 문장만)
- [ ] 나가기 모달 → `RoomService.leaveGame`(= `leaveFunctionName`) 경유. 직접 pop 금지
- [ ] 턴 타이머 (제한시간 있으면) — `ServerClock` 보정 사용
- [ ] 턴 액션(제출/선언 등) 활성·비활성 — 서버 권한 상태 기준
- [ ] 대기 문구 (상대 턴, 다음 라운드 대기)
- [ ] 결과 다이얼로그
- [ ] 중단(interruption) 레이어 — `shared/widgets/game_interruption_layer.dart`
- [ ] 재접속 복원 — 세션 스토어 + `initiallyPlayed`류 복원 시 연출·소리 생략

**태블릿**
- [ ] 룰북 — `TabletGameRulebookDialog` (마크다운 + 카드 이미지 + 룰 영상)
- [ ] 설정 다이얼로그 — 게임 재시작 / 게임 종료
- [ ] 사이드바 — `shared/widgets/tablet_game_side_bar.dart`
- [ ] 좌석 배치 — `shared/player_layouts/` (저장된 좌석 좌표 사용)
- [ ] 결과 화면 — 재시작 + HOME 버튼, HOME은 서버 end 성공 후 즉시 닫기
- [ ] 중단 처리 — 투표/제외/만료 (`game_common_interruption_*` 호출)
- [ ] BGM — `shared/sound/game_background_music.dart`: 분배 시작에 start, dispose에 stop
- [ ] 가로 고정 + 전체화면 진입/복원 (`AppOrientation`, `AppSystemUi`)

**서버·공통**
- [ ] `game_common_interruption` 연결 확인 (연결 끊김 → 투표 → 제외/만료)
- [ ] `functions/src/game-interruption/functions.ts`의 `MINIMUM_PLAYER_COUNTS`에 인원 추가
- [ ] warmup 대상 함수 지정

## 6단계 — 사운드

- 효과음은 연출 **시작이 아니라 착지·접촉 시점**에 재생 (기존 lead 상수 패턴 참고)
- `preloadTargets`에 등록하고 게임 진입 preload에서 `SoundProvider.preloadEffects` 호출 — 안 하면 첫 재생이 늦는다
- BGM은 `GameBackgroundMusic` 재사용. 직접 `playBgm` 호출하지 마라 (정지 누락 위험)
- 사운드 파일이 저장소에 없으면 **필요한 파일명과 경로를 목록으로 사용자에게 요청**하고, 배선은 미리 해 둔다

## 7단계 — 에셋

- `assets/games/<id>/images/...`, `assets/sounds/<id>/` 구조
- ⚠️ `pubspec.yaml` 에셋 등록은 **하위 폴더를 포함하지 않는다.** 폴더마다 한 줄씩 등록
- 등록 후 `dart run build_runner build --delete-conflicting-outputs` — `lib/gen/assets.gen.dart` 직접 수정 금지
- ⚠️ **게임 코드에서 이미지는 반드시 `Assets....game`([GameImage])으로 접근**한다.
  `Assets....image()` 직접 호출 금지 — 서버 에셋 전환 시 그 화면만 깨진다.
  소리는 기존대로 경로 문자열(`SoundService`가 해석). 게임 진입 preload에서
  `GameAssetStore.instance.prepareGame('<id>')` 호출(실패는 삼킴)
- 서버에 게임 문서를 등록할 때 `minAppVersion`에 그 게임이 포함된 앱 버전을
  적는다. 구버전 앱에서는 시작 대신 업데이트 안내가 표시된다

## 반드시 사용자에게 물어봐야 하는 순간

- 화면 매핑에 없는 상태가 필요할 때 (새 화면 요청 vs shared로 대체)
- 규칙 엣지케이스가 미정일 때 — 동점, 타임아웃, 중도 퇴장, 최소 인원 미달
- 에셋 파일이 저장소에 없을 때
- 연출 타이밍·방향이 취향 문제일 때
- Cloud Function 배포가 필요한 시점 (배포는 사용자가 실행)

## 완료 전 검증

```bash
dart format lib test && flutter analyze && flutter test && (cd functions && npm test)
```

실기기: 방 생성 → 휴대폰 입장 → 좌석 저장 → 시작 → 턴 진행 → **재접속** → 결과 → 재시작 → 종료 → 퇴장.
새 함수가 `firebase functions:list`에 규칙대로 떴는지도 확인을 요청한다.
