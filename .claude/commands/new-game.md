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
2. `docs/AI_GAME_DEVELOPMENT_GUIDE.md` — 상태 머신·Riverpod·Cloud Functions 상세
3. `lib/games/_game_template/README.md` — 스캐폴드
4. `lib/games/mafia/README.md` — **결정 기록의 모범.** 인터뷰 결과를 게임별
   README에 이런 식으로 남긴다(확정 표 + ⚠️ 미결 항목)

## 사용자의 작업 방식 (마피아 제작으로 확인된 협업 흐름)

이 순서를 알고 있어야 헛돈을 안 쓴다. **최초 배선은 시작일 뿐, 수정 라운드가
본편이다.**

1. **인터뷰 → README 기록.** 규칙이 확정되면 `lib/games/<id>/README.md`에
   결정 표를 만들고, 미정 사항은 ⚠️로 남긴다. 이후 모든 수정도 여기 반영한다.
2. **화면은 사용자가 만든다.** Figma 링크나 이미지 파일로 오고, **한 번에 다
   오지 않는다.** 없는 화면은 임의로 디자인하지 말고 요청하거나 shared로 채울지
   묻는다. 채팅에 붙인 이미지는 디스크의 파일로 받아야 읽을 수 있다.
   - 태블릿 Figma 시안은 **−90° 회전 상태로 제작**되어 있다. 좌표·정렬을 읽을 때
     회전을 되돌려 생각한다. 디자인 공간은 화면마다 다를 수 있으니(휴대폰
     402×874, 태블릿 1194×834가 기본, 역할 배치는 1280×800이었다) 시안 프레임
     크기를 직접 읽는다.
   - 시안 자체의 오류(마피아에서 영매↔자경단원 그림이 뒤바뀜)를 발견하면
     그림의 뜻에 맞게 넣고, 사용자에게 알리고, README에 ⚠️로 남긴다.
3. **배선 → 사용자 검수 → 수정 지시 반복.** 사용자는 시뮬레이터·실기기에서
   보고 잘라낸 스크린샷과 함께 짧은 지시를 보낸다("이부분 x1 지워줘",
   "tip쪽 아이콘 이걸로", "문구 아래로"). 수정이 싸게 먹히도록 처음부터:
   - 문구는 전부 `<id>_copy.dart`에 (화면 코드에 문자열 리터럴 금지)
   - 타이밍은 `<id>_flow_config.dart`의 상수 클래스 하나에 (예: `MafiaTiming`).
     휴대폰 연출이 태블릿 연출 시간에 의존하면 **같은 상수를 참조**한다 —
     리터럴 복사는 반드시 어긋난다(마피아에서 60000 리터럴이 드리프트 사고).
     연습(practice) 모드가 있으면 그 엔진도 같은 상수를 쓴다.
   - 위치·크기는 디자인 공간 좌표(rect 상수)로 두고 화면 크기로 스케일한다.
4. **에셋은 늦게 온다.** 파일이 없어도 경로 상수와 배선을 먼저 해 두고, 필요한
   파일명·경로를 목록으로 요청한다. 도착한 원본 이름은 제멋대로다
   (`Take3-1_Liar!.wav` 등) — 프로젝트 규칙으로 개명해서 넣는다.
5. **배포·업로드는 사용자가 실행한다.** 함수 배포, Storage 업로드, Firestore
   문서 수정은 계획(무엇을 어디에)만 정리해 전달한다.
6. **취향 질문은 모아서 묻는다** (연출 속도·방향·정지 시간 등). 사용자는
   일부만 답하기도 한다 — 답 없는 항목은 작업을 막지 말고 기본값으로 진행하되
   미결 목록으로 계속 들고 다닌다.
7. **검증은 위젯 테스트로.** 색·좌표·타이밍을 회전된 스크린샷 눈대중으로
   판정하지 마라(회색으로 오독한 전례). 테스트로 값을 찍는 게 정확하고,
   수정 라운드마다 회귀를 잡아 준다.

## 구조 기준

기존 세 게임(라이어스 포커, 파이널콜, 마피아)이 같은 표준을 따른다:
**컨트롤러 1개 공유**(phone/tablet이 `watchPrivate`/`watchPrivateHand` 플래그로
역할 구분), **providers 2파일**(game_state + session_provider), **models/ 분리**.
새 게임도 동일하게 만든다.

휴대폰 흐름만 게임 특성에 따라 갈린다:
- 기본값: **GameScreenPhase + PhoneGameShell** (Final Call 방식)
- 예외: 가로·세로 회전을 지원하고 안내 문구가 손패 연출에 결합된 게임은
  Liar's Poker처럼 자체 슬롯 레이아웃을 쓴다. 예외를 택하면 그 이유를
  화면 주석에 남긴다.

아래 3가지 준비 작업은 빠뜨리기 쉽다. **새 게임에는 반드시 넣는다**:

1. **에셋 preload** — `loading/<id>_loading.dart`에서 이미지·프로필 `precacheImage`
   (LP: `lib/games/liars_poker/loading/liars_poker_loading.dart` 참고)
2. **게임 사운드 정의 + preloadTargets** — `sound/<id>_sounds.dart`
   (마피아 `mafia_sounds.dart`가 최신 모범: 효과음 + 내레이션 + 헬퍼)
3. **핵심 callable warmup** — 첫 조작 함수의 콜드스타트 제거
   (서버 함수에 `if (request.data?.warmup === true) return {success:true, type:"warmup"}`
   조기 반환. LP `warmUpGameplayCommands`, FC `draw-card.ts` 참고)

## 0단계 — 인터뷰 (답을 받기 전에 코드를 시작하지 마라)

아래를 모두 확인하고 **결과를 `lib/games/<id>/README.md`에 기록한다.**
화면 파일을 이미 받았어도 답이 안 나오는 항목은 물어본다:

1. **게임 id** (snake_case). 이 값 하나가 `TemplateGame.id` = `assets/games/<id>/` = `functions/src/<id>/` = 함수 접두사 `game_<id>_`로 전부 쓰인다.
2. **인원** — 최소/최대 또는 고정. 팀전인가? (`game-interruption/functions.ts`의 `MINIMUM_PLAYER_COUNTS`에도 추가해야 한다)
3. **휴대폰 화면 방향** — 세로/가로/둘 다 (`PhoneGameOrientation`)
4. **턴 구조** — 턴 제한시간? 타임아웃 시 서버가 뭘 하나(자동 제출/스킵/탈락)?
5. **라운드 구조와 승패 조건** — 언제 게임이 끝나나? 동점 처리?
6. **탈락자** 발생하나? 탈락자 관전 모드가 필요한가? (마피아: 사망자는 전원
   신분 열람 + "보여주지 마세요" 문구)
7. **비공개 정보** — 손패·역할처럼 본인만 봐야 하는 것 → `game/private/{uid}` 설계
8. **벌칙/미니게임** 있나? (룰렛 등)
9. **에셋** — 이미지/사운드 파일이 준비됐나? 룰 영상 URL? 없으면 어떤 파일이 어떤 경로에 필요한지 목록으로 요청
10. **받을 화면 목록** — 휴대폰/태블릿 각각 어떤 화면을 줄 것인지
11. **시작 전 설정이 있나?** — 자리 배치만으로 충분한가, 아니면 게임별 설정
    화면이 필요한가(마피아: 역할 배치). 필요하면 `buildStartSetupScreen`을 쓴다
    (아래 3.5단계).

## 1단계 — 서버 먼저 (functions/src/<id>/)

- 함수 이름 규칙: `game_<id>_<동작>` (예: `game_dutch_start_game`). 공용은 `game_common_*`, 방·인증은 camelCase 유지.
- 최소 함수 세트: `start_game`(restart 겸용), `complete_dealing`, `leave_game`, `end_game` + 게임 고유 조작들
- 모든 조작 함수: `commandId` 멱등 처리 (`server.processedCommands`), 트랜잭션, `revision` 증가
- 상태 3분할: `game/public`(전원 공개) / `game/private/{uid}`(본인만) / `game/server`(클라이언트 차단 — RTDB 규칙이 이미 막고 있음)
- **비공개 행동을 소리·연출로 알려야 하면 익명 cue를 쓴다.** `public`에
  `{id: 증가 카운터, action: 종류}`만 올린다 — **누가 했는지(uid)는 절대 싣지
  않는다.** 마피아 `bumpNightActionCue`(`mafia/game.ts`) + 클라이언트
  `mafia_night_cue_speaker.dart` 쌍 참고.
- **시작 옵션은 서버가 다시 검사한다.** `buildStartSetupScreen`이 보내는
  `options`는 클라이언트 화면과 같은 규칙으로 서버에서 재검증하고
  (`mafia/validation.ts`의 `mafiaComposition` 참고), `server`에 저장해 두었다가
  **재시작 때 재사용**한다(마피아 `start-game.ts`: restart면
  `room.game?.server?.composition` 폴백).
- region: callable은 `asia-northeast3`, RTDB 트리거는 `asia-southeast1` (인스턴스 리전 제약)
- `src/index.ts`에 export (도메인별 섹션 주석 유지), `functions/test/*.test.mjs` 작성
- ⚠️ 배포된 callable 이름은 바꾸면 구버전 앱이 못 찾는다. 이름은 처음부터 규칙대로.
- ⚠️ 함수 배포(`firebase deploy`)는 사용자가 직접 실행한다. 배포 계획(생성/삭제 목록)만 정리해서 전달.
- ⚠️ **서버가 쓰고 클라이언트가 읽는 문자열 enum은 대조 테스트를 만든다.**
  서버에만 값을 추가하면 클라이언트 파서가 null을 돌려주며 조용히 죽는다
  (온보딩 `apple` 누락 → 무한 로딩 사고). Dart 테스트가 TS 소스를 직접 읽어
  두 목록을 비교하는 `test/auth/onboarding_parity_test.dart` 방식을 따른다.

## 2단계 — 클라이언트 뼈대

```
lib/games/<id>/
  <id>_game.dart          TemplateGame 구현 (id, 인원, 방향, leaveFunctionName='game_<id>_leave_game')
  <id>_flow_config.dart   단계 전환 타이밍 상수 클래스 (<Id>Timing) — 타이밍의 단일 출처
  <id>_copy.dart          사용자 문구 + phoneRules. 연출 문구는 비트 리스트로 (아래 4단계)
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
  sound/<id>_sounds.dart  효과음·내레이션 경로 + preloadTargets
  sound/<id>_bgm_plan.dart  (BGM이 상태 따라 갈리면) 상태 → 트랙 함수 + 페이드 상수
  loading/<id>_loading.dart  에셋 preload + (선택) 로딩 팁
  dev/                    (선택) 서버 없이 흐름을 돌려 보는 연습 모드 (mafia/dev 참고)
```

등록은 `game_registry.dart`에 한 줄. **플랫폼 화면에 게임 id 분기(if/switch)를 추가하지 마라.**

## 3단계 — 받은 화면 연결

1. 받은 화면마다 `화면 → GameScreenPhase/태블릿 stage` 매핑 표를 먼저 만들어 **사용자에게 확인받는다**.
2. 매핑에 구멍이 있으면(연결 중/대기/재접속/중단/결과 등) 그 화면을 요청하거나, shared 위젯으로 채울지 물어본다.
3. 서버 상태 해석은 한 곳에서만: 휴대폰 `_resolvePhase`, 태블릿 `_resolveStage`. 하위 위젯은 서버 문자열을 다시 추측하지 않는다.
4. 서버 미러 상태는 불변 provider, 연출·애니메이션 상태는 위젯 로컬 `State`. 섞지 마라.
5. RTDB 구독은 세션 컨트롤러 한 곳. 위젯마다 구독 만들지 마라.
6. 시안에서 요소가 겹치면 **시안의 페인트 순서대로 그린다** (마피아 역할 배치:
   중립 패널을 마피아 패널보다 먼저 그려야 겹침이 시안과 같아진다).

## 3.5단계 — 게임별 시작 설정 화면 (필요한 게임만)

자리 배치 대신 게임별 준비 화면이 필요하면 `TemplateGame.buildStartSetupScreen`을
override한다. 모범: `mafia/screens/tablet/tablet_role_setup_screen.dart` (역할 배치).

- 계약: `onPrepare(layout, options:)`가 자리 저장 + `startGame`까지 부른다(실패
  false). `onComplete`가 게임 화면 진입, `onCancel`이 게임 선택 해제.
- 고른 설정은 `startGame(roomCode, options:)`의 `options` 맵으로 서버까지 간다.
  서버 재검증은 1단계 참고.
- 뒤로가기는 shared `GameSetupBackButton` + `PopScope` → `onCancel`. 자리 배치
  화면(`PlayerLayoutEditor`)과 똑같은 위치·크기를 쓴다.
- **필수 항목은 잠근다**: 끌 수 없는 선택지는 `onTap: null` + 항상 선택 상태 +
  Semantics에 `(필수 ...)` 라벨 (마피아: 마피아·시민 잠금).
- 선택/비선택 시각 규칙(마피아 확정): 선택 = 원색 + 검정 라벨, 비선택 =
  `ColorFiltered` 그레이스케일 + 회색 라벨.

## 4단계 — 애니메이션 연결 지점

| 시점 | 사용할 것 | 주의 |
|---|---|---|
| 게임 진입 | `shared/animations/game_entry_unroll.dart` 등 | |
| 카드 분배 | `shared/animations/card_deal.dart` | 분배음이 착지 시점에 자동 재생됨. 커스텀 금지 |
| 휴대폰 손패 수신 | `shared/animations/phone_card_receive_animation.dart` | 태블릿 분배 연출이 **끝난 뒤** 들어오게 타이밍 상수를 공유 |
| 턴·단계 제한시간 | `shared/widgets/game_turn_countdown.dart` | **남은 시간을 직접 계산하지 마라.** `GameTurnCountdown`이 세고, 게임은 시각만 입힌다(`nowMillis` 주입으로 테스트 가능) |
| 안내 문구 (ROUND 등) | `GameAnnouncementLayer` | **화면 정중앙 보정 필수** — 손패 영역 기준으로 놓으면 위로 치우친다. LP의 `announcementCenterOffset` 참고 |
| 결과 | 게임별 result + shared `phone_result_dialog` | |
| 종료/HOME | **즉시 화면 닫기** | 정리 장면(프로필 사라지는 모습) 노출 금지. FC의 `stageBeforeExit` 유지 기법 참고 |

- **긴 안내 문구는 비트(beat)로 쪼갠다.** copy 파일에 `List<String>`
  (`deathBeats`, `executedBeats` …)로 두고, 게임 고유 연출 위젯이 비트를
  차례로 보여 준다(마피아 `animations/ejection_text.dart` — Among Us 사출풍).
  한 문장짜리 상수와 비트 리스트를 섞어 두지 말 것 — 전부 리스트로 통일.
- 새 라운드에 위젯 key를 갈아끼울 때, `initState`/`dispose`에서 외부 `Listenable`을 건드리면 빌드 중 notify로 죽을 수 있다. 알림은 프레임 이후로 미룬다.
- 연출 타이밍이 취향 문제로 갈리면(속도·방향·정지 시간) 구현 전에 사용자에게 물어본다.
- 비트 전환처럼 Timer + 애니메이션이 섞인 연출의 테스트는
  `test/support/ejection_beats.dart`의 `pumpUntilText` 패턴을 쓴다.

## 5단계 — 필수 버튼·기능 체크리스트 (빠지면 미완성)

**휴대폰**
- [ ] 상단바: 팁(룰) / 설정 / 나가기 버튼 (`shared/widgets/phone_game_top_bar.dart` 계열)
- [ ] 룰 다이얼로그 — `<id>_copy.dart`의 `phoneRules` (마크다운 불가, 문장만)
- [ ] 나가기 모달 → `RoomService.leaveGame`(= `leaveFunctionName`) 경유. 직접 pop 금지
- [ ] 턴 타이머 (제한시간 있으면) — `GameTurnCountdown` + `ServerClock` 보정
- [ ] 턴 액션(제출/선언 등) 활성·비활성 — 서버 권한 상태 기준
- [ ] 대기 문구 (상대 턴, 다음 라운드 대기)
- [ ] 결과 다이얼로그
- [ ] 중단(interruption) 레이어 — `shared/widgets/game_interruption_layer.dart`
- [ ] 재접속 복원 — 세션 스토어 + `initiallyPlayed`류 복원 시 연출·소리 생략
  (익명 cue 스피커도 첫 동기화 값은 무시해야 한다 — 6단계)

**태블릿**
- [ ] 룰북 — `TabletGameRulebookDialog` (마크다운 + 카드 이미지 + 룰 영상)
- [ ] 설정 다이얼로그 — 게임 재시작 / 게임 종료
- [ ] 사이드바 — `shared/widgets/tablet_game_side_bar.dart`
- [ ] 좌석 배치 또는 게임별 시작 설정 화면 (3.5단계)
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
- **"어떤 행동이 완료됐을 때" 나는 소리는 자동 재생이 아니라 서버 cue로 만든다.**
  서버가 `public`의 익명 cue(1단계)를 올리면, 클라이언트 "스피커"가 재생한다.
  스피커 규칙(마피아 `sound/mafia_night_cue_speaker.dart`): ① 같은 id는 한 번만
  ② **첫 동기화 값은 재생하지 않는다** — 재접속 때 과거 소리가 다시 나면 안 된다.
  단, "동기화됨" 플래그는 처리한 id와 별개로 둔다(cue 없이 접속한 뒤 첫 cue를
  삼키는 버그 방지).
- **내레이션(음성) 파일은 `voice_<뜻>.m4a`로 개명**해서 넣는다
  (`voice_night`, `voice_win_citizen` …). 진영·결과별 선택은
  `winVoiceFor(faction)` 같은 헬퍼로 sounds 파일에 둔다.
- BGM은 `GameBackgroundMusic` 재사용. 직접 `playBgm` 호출하지 마라 (정지 누락 위험)
  - 상태에 따라 트랙이 바뀌거나 무음 구간이 있으면 `sound/<id>_bgm_plan.dart`에
    `상태 → 트랙(null=무음)` 함수와 페이드 상수를 둔다. 끊을 때는 뚝 끊지 말고
    `GameBackgroundMusic.fadeOut(duration)` (마피아: 밤에만 BGM, 아침엔 1.6초 페이드)
  - 여러 게임이 같은 곡을 쓰면 **파일은 공용 1개**, 게임별로는 상수만 참조
- `preloadTargets`에 등록하고 게임 진입 preload에서 `SoundProvider.preloadEffects` 호출 — 안 하면 첫 재생이 늦는다. 내레이션도 포함.
- 사운드 파일이 저장소에 없으면 **필요한 파일명과 경로를 목록으로 사용자에게 요청**하고, 배선은 미리 해 둔다
- 오디오 변환: 이 머신엔 mp3 인코더가 없다. `afconvert -f m4af -d aac`로 m4a를 만든다

## 7단계 — 에셋

- `assets/games/<id>/images/...`, `assets/sounds/<id>/` 구조
- **이미지는 WebP가 기본.** PNG로 받으면 `cwebp -q 92 -m 6 -alpha_q 100`으로
  변환해서 넣는다(문자 있는 이미지도 q92면 안전 확인됨). 아주 작은 아이콘만 PNG 허용.
  flutter_gen 게터 이름은 확장자를 뺀 파일명에서 나오므로 확장자만 바꾸면
  `Assets.*` 참조는 그대로 살아 있다 — 대신 **경로 문자열 하드코딩이 있으면 그게 깨진다.**
- 파일명 규칙이 있는 에셋(카드 등)은 규칙 테스트를 만든다
  (`test/mafia_role_card_naming_test.dart`: `role_<id>.webp` ↔ 역할 카탈로그 대조)
- ⚠️ `pubspec.yaml` 에셋 등록은 **하위 폴더를 포함하지 않는다.** 폴더마다 한 줄씩 등록
- 등록 후 `dart run build_runner build --delete-conflicting-outputs` — `lib/gen/assets.gen.dart` 직접 수정 금지
- ⚠️ **게임 코드에서 이미지는 반드시 `Assets....game`([GameImage])으로 접근**한다.
  `Assets....image()` 직접 호출 금지 — 서버 에셋 전환 시 그 화면만 깨진다.
  소리는 기존대로 경로 문자열(`SoundService`가 해석). 게임 진입 preload에서
  `GameAssetStore.instance.prepareGame('<id>')` 호출(실패는 삼킴)
- **게임 구성품 사진**(모달 미리보기)은 앱에 넣지 않는다: 사용자가 Storage
  `games/<id>/component.webp`에 올리고 Firestore 게임 문서 `componentImageUrl`에
  URL을 적는다. 앱은 그 URL을 그리되, 비어 있거나 실패하면 코드로 그리는
  `buildTabletPreviewArtwork`로 폴백한다 (`game_info.dart`의 `componentImageUrl` 주석 참고)
- 서버에 게임 문서를 등록할 때 `minAppVersion`에 그 게임이 포함된 앱 버전을
  적는다. 구버전 앱에서는 시작 대신 업데이트 안내가 표시된다

## 반드시 사용자에게 물어봐야 하는 순간

- 화면 매핑에 없는 상태가 필요할 때 (새 화면 요청 vs shared로 대체)
- 규칙 엣지케이스가 미정일 때 — 동점, 타임아웃, 중도 퇴장, 최소 인원 미달
- 에셋 파일이 저장소에 없을 때
- 시안에 모순·오류가 보일 때 (아이콘 뒤바뀜, 조작 없는 요소 등)
- 연출 타이밍·방향이 취향 문제일 때
- Cloud Function 배포가 필요한 시점 (배포는 사용자가 실행)

## 완료 전 검증

```bash
dart format lib test && flutter analyze && flutter test && (cd functions && npm test)
```

- 서버가 쓰고 클라이언트가 읽는 문자열 값(phase, provider, cue 종류 등)은
  대조 테스트가 있는지 확인 (1단계 ⚠️)
- 실기기: 방 생성 → 휴대폰 입장 → 좌석 저장(또는 시작 설정) → 시작 → 턴 진행
  → **재접속** → 결과 → 재시작 → 종료 → 퇴장. 재시작이 시작 설정(options)을
  기억하는지도 본다.
- 새 함수가 `firebase functions:list`에 규칙대로 떴는지도 확인을 요청한다.
