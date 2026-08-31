# Auth·network·session 기술 참조

## 목적과 근거 범위

이 문서는 향후 에이전트가 로그인·네트워크·방 세션을 변경할 때 읽을 tracked context다.
최종 계약은 [`ENGINEERING_CONTRACT.md`](../engineering/ENGINEERING_CONTRACT.md)와
[`ARCHITECTURE.md`](../engineering/ARCHITECTURE.md), 실제 코드·테스트가 정한다. 아래의 수동 자료는
2026-08-27 실제 기기 관찰 근거일 뿐 API나 상태 계약을 새로 정의하지 않는다.

최신 사용자 검증은 2026-08-31 라이어스포커 / Medium Tablet Android 에뮬레이터 +
Galaxy A32·A35, `1.0.0-sessionfix.20260831+1` debug APK의 세 시나리오 전체 통과다.
반복 단절·시간 보존·태블릿 복구·퇴장 명단·winner 이후 복귀의 통과를 보고 환경에서
확정했다. 물리 태블릿·iOS·다른 게임의 새 수동 검증을 뜻하지 않는다. 아래 과거 실패
관찰과 에이전트의 당시 실행 한계는 이력으로 보존하며 최신 판정은 출시 차단 문서를 따른다.

## 책임 경계

| 구성요소 | 책임 | 기준 데이터가 아닌 것 |
| --- | --- | --- |
| Flutter 클라이언트 | 화면, 로컬 복원 의도, 구독, heartbeat, `onDisconnect` 예약, callable 호출 | 게임 판정·권한·최종 상태 결정 |
| Firebase Auth | 로그인 사용자 UID와 인증 자격 | 온보딩 완료 여부, 방 멤버십 |
| Firestore | `users/{uid}` 프로필과 `userOnboarding/{uid}` 단계 조회 | 실시간 방·게임 상태 |
| RTDB | `rooms/{code}`의 방, 참가자, presence, 선택 게임과 게임 상태 | 권한 있는 명령의 검증·복잡한 전이 |
| Cloud Functions | Auth/방/게임 명령 검증, 원자적 전이, 예약 정리, 중단·종료 판정 | 클라이언트 화면의 임시 UI 상태 |

클라이언트 직접 쓰기는 heartbeat와 미리 허용된 presence 보조 동작에 한정된다. 참가,
퇴장, 게임 선택, 종료 정리 등 중요한 전이는 callable 또는 RTDB trigger가 책임진다.

## 상태 기준값과 저장 위치

| 상태 | 기준값/경로 | 로컬 보조 저장 |
| --- | --- | --- |
| 로그인 | `FirebaseAuth.currentUser`, `userChanges()` | Firebase Auth SDK |
| 온보딩 | Firestore `userOnboarding/{uid}.state` | 없음 |
| 프로필 | Firestore `users/{uid}` | 화면 provider 캐시 |
| 이메일 링크 | Firebase Auth 링크 | SharedPreferences `auth.pendingEmail`, `auth.emailLinkCooldownUntil` |
| 태블릿 방 | RTDB `rooms/{code}`, `controllerRooms/{uid}` | 방 코드와 controller session ID |
| 휴대폰 참가 | RTDB `rooms/{code}/players/{uid}` | UID, 방 코드, 닉네임, 캐릭터 |
| 태블릿 연결 | `rooms/{code}/controllerPresence/{connected,lastSeen}` | provider 타이머 |
| 참가자 연결 | `rooms/{code}/players/{uid}/{isConnected,lastSeen}` | provider heartbeat 상태 |
| 게임 | `rooms/{code}/selectedGame`, `rooms/{code}/game/{public,private}` | 현재 route/provider |
| Firebase 연결 | RTDB `.info/connected` | `RealtimeConnectionMonitor`의 최신 값 |
| 개발 진단 | `[dev_error]` 구조화 콘솔/ADB 로그 | 개발 빌드 프로세스 로그 |

서버 시각이 필요한 `lastSeen`, deadline, cleanup 시각은 클라이언트 시계가 아니라
`ServerValue.timestamp` 또는 Functions의 서버 시각을 사용한다.

## 로그인과 온보딩 흐름

`AuthGate`는 `FirebaseAuth.userChanges()`와 온보딩 문서 스트림을 결합한다.

1. 사용자가 없으면 `LoginScreen`/`RegisterScreen`으로 간다.
2. 이메일 링크는 `AuthService.sendSignInLinkToEmail`로 발송하고 링크 완료 뒤
   `beginOnboarding` callable을 호출한다.
3. Google은 SDK credential을 Firebase Auth에 연결하고 `syncGoogleUserProfile`,
   Apple은 nonce 검증 뒤 `syncAppleUserProfile` callable을 호출한다.
4. `settingPassword`는 가입 화면, `settingProfile`은 프로필 화면,
   `complete`는 플랫폼 홈으로 보낸다.
5. `completeOnboardingProfile`은 프로필과 온보딩 완료를 서버에서 함께 반영한다.

중요 파일:

- `lib/platform/auth/widgets/auth_gate.dart`: 인증·온보딩 route 결정
- `lib/platform/auth/services/auth_service.dart`: 이메일 링크, Google, Apple 인증
- `lib/platform/auth/services/onboarding_service.dart`: 온보딩 callable과 문서 구독
- `lib/platform/auth/services/pending_email_store.dart`: 이메일 링크 로컬 상태
- `lib/platform/auth/models/onboarding_state.dart`: 단계 모델
- `functions/src/auth/onboarding.ts`: 온보딩 시작·완료 전이
- `functions/src/auth/sync-google-profile.ts`, `sync-apple-profile.ts`: 소셜 프로필 동기화
- `functions/src/auth/require-complete-onboarding.ts`: 서버 명령의 완료 조건

## 방 세션 생성·저장·복원

### 태블릿

`RoomService.createRoom`과 Functions가 방을 만들고, `ControllerRoomSessionStore`가 방
코드와 session ID를 저장한다. `RoomProvider.restoreControllerRoom`은 서버 방과 세션을
대조한다. `paused`/`detached`는 heartbeat를 멈추거나 명시적 disconnected 표시를
보낼 수 있지만 방 종료로 간주하지 않는다. `closeRoom` 성공 때만 저장 세션을 지운다.

### 휴대폰

참가는 callable 성공 뒤 `PlayerRoomSessionStore`에 UID·방 코드·닉네임·캐릭터를
저장하고 `players/{uid}`에 `onDisconnect`를 예약한다. 시작 시
`SessionReturnPrompt`가 먼저 동의를 받고, 동의한 경우에만 `restorePlayerRoom`이 서버
노드를 확인·재참가하고 heartbeat를 시작한다. 거절은 로컬 저장만 지운다.

중요 파일:

- `lib/platform/home/room/services/room_service.dart`: Firebase I/O와 callable 경계
- `lib/platform/home/room/providers/room_provider.dart`: 구독, lifecycle, 복구, 오류 상태
- `controller_room_session_store.dart`, `player_room_session_store.dart`: 로컬 복원 정보
- `lib/platform/home/phone/widgets/session_return_prompt.dart`: 복원 동의 순서
- `functions/src/room/realtime-room-functions.ts`: 방 생성·참가
- `functions/src/room/controller-session.ts`: controller session 검증
- `functions/src/room/realtime-room-lifecycle.ts`: 선택·종료·퇴장·보존 정리

## heartbeat, presence, onDisconnect, 복구

태블릿과 휴대폰 heartbeat 주기는 10초다. 태블릿 화면은 마지막 서버 heartbeat가
20초를 넘으면 disconnected로 해석한다. 휴대폰의 `onDisconnect`는 Firebase 서버가
기존 연결 종료를 판정한 뒤 `isConnected: false`와 `lastSeen`을 기록한다.

`.info/connected`가 false가 되면 provider는 서버 단절을 기억한다. true로 돌아오면
태블릿은 같은 controller session으로 `markControllerConnected`, 휴대폰은 저장된
프로필로 재참가 확인을 수행하고 presence와 `onDisconnect`를 복원한다. 복구 명령의
클라이언트 제한시간은 8초다. `RealtimeConnectionMonitor`는 앱 전체에서 같은 RTDB
연결 스트림을 공유한다.

2026-08-31 보완: 복구 중 다음 단절·재연결이 겹치면 최신 연결의 presence를 다시
복원한다. 방 삭제 확인은 응답 시 세션·연결 세대와 방 존재 이벤트를 다시 대조하고,
오프라인이나 오래된 조회 결과로 세션을 종료하지 않는다. 퇴장 시작은 기존 복구를
무효화하며 완료된 옛 복구가 heartbeat를 다시 시작하지 못하게 한다.
오프라인 heartbeat 쓰기는 건너뛴다. 자동 복구의 기존 `preserveProfile: true` 요청은
서버에서 현재 참가자가 없는 경우 신규 가입으로 바뀌지 않는다.

presence의 `isConnected`/`lastSeen` 직접 쓰기는 현재 서버 참가자의 nickname이 있고,
status가 active(또는 구형 데이터의 status 생략)이며 방이 closed가 아닐 때만 허용한다.
따라서 퇴장 뒤 도착한 heartbeat/onDisconnect가 삭제된 참가자 노드를 다시 만들 수 없다.

태블릿은 기존 players 구독의 `lastSeen`을 서버 시각으로 판정한다. 20초를 초과한
관측값마다 `game_common_interruption_report_stale_player`를 한 번만 호출한다. callable은
controller UID/session을 확인하고 방 transaction에서 최신 `lastSeen`, `isConnected`,
게임 상태를 다시 검사한 뒤 presence 변경과 중단 시작을 원자적으로 수행한다. 정상
heartbeat에는 Function invocation이 없으며 새 Scheduler도 추가하지 않는다.

## 게임 중 중단과 타이머

`functions/src/game-interruption/functions.ts`의 RTDB trigger가 플레이어
`isConnected: true -> false`를 공용 중단 상태로 승격한다. `state.ts`는 중단 시작 때
`turnDeadlineAt`을 null로 만들고 남은 시간을 저장하며, 복구 시 새 deadline을 계산한다.
컨트롤러 단절은 `controller-presence.ts`가 별도의 pause 원인으로 합성한다. 두 원인이
겹쳐도 한 원인의 복구가 다른 원인을 지우지 않아야 한다.

먼저 복구한 원인은 보관한 남은 시간을 아직 남아 있는 중단에 넘기고 deadline은 null로
유지한다. 마지막 중단만 deadline을 복원한다. controller pause에는 서버 전용 선택 필드
`startedAt`을 함께 저장해 RTDB가 null뿐인 객체를 제거해 버리는 경우도 막는다.
이 필드가 없는 기존 데이터도 읽을 수 있다. 참가자·controller trigger는 transaction의
최신 presence와 이벤트 값이 다르면 무시하며 controller transaction은 기존
`runPrimedTransaction`으로 서버의 첫 스냅샷을 확보한다.

UI의 `game_interruption_layer.dart`는 기다리기, 즉시 종료, 재연결/게임 나가기 흐름을
표시한다. `tablet_room_panel.dart`는 참가자 `isConnected`가 false일 때 `연결 끊김`을
표시한다.

2026-08-27 수동 기록의 “끊긴 참가자 턴인데 타이머가 계속됨”은 기록된 `isConnected: true`와
약 3분 뒤 중단 UI가 함께 관찰됐다. 코드상 중단 trigger 뒤에는 deadline을 비우므로,
현재 근거는 “서버 단절 판정 전 타이머 진행”을 가리킨다. trigger 이후에도 진행하는지
판단하려면 같은 시각의 단일 RTDB 경로와 화면 녹화가 추가로 필요하다.

2026-08-31에는 단절 24초 → 팝업 15초 → 약 5초 뒤 복구 10초라는 별도 실패 보고를
받았다. 팝업의 기기 역할·종류와 서버 중단 시각은 미확인이다. 따라서 과거의 “감지 전
진행” 설명만으로 새 보고를 해소하지 않는다. 두 복원 함수가 상대 중단을 확인하지 않고
deadline을 쓰던 경로와 늦은 연결 이벤트가 새 중단을 취소하던 경로는 회귀 테스트로
재현해 수정했다. 이후 수정 APK 테스트에서 사용자는 태블릿 중단 화면 뒤 30초 기다렸다가
복구해 6초가 남았고 서버가 멈춘 시간부터 재개한 것으로 보인다고 보고하며 전체 통과를
확정했다. 중단 직전 수치는 추정하지 않는다. 이 방식의 사용자 이해도는
[GAME-PAUSE-UX-01](../planning/TASKS.md#game-pause-ux-01--단절-후-남은-시간-재개-안내)로
분리하며 시간 보존 실패로 기록하지 않는다.
최종 판정은 [완료·검증 근거](../planning/COMPLETED_TASKS.md), 당시 원인 후보와 수정 계획은
[조사 기록](../planning/logs/2026-08.md#batch-0831-initial)을 따른다.

## 종료, selectedGame, 대기실 복귀

게임 공개 상태가 `finished`가 되면 RTDB trigger가 방 status도 `finished`로 맞춘다.
이 동기화는 최신 방·게임 상태를 확인하는 primed transaction에서 수행한다. 이미
waiting으로 정리됐거나 closed/삭제된 방에는 이전 이벤트를 적용하지 않는다. 같은
finished 이벤트의 중복 처리로 보존 기한을 연장하지 않고 playing 전환은 이전 cleanupAt도
제거한다.
정상 route 종료는 `restoreRoomToWaiting`을 호출한다. 이는 기존
`selectRealtimeRoomGame(gameId: null)` 계약을 사용해 다음을 한 트랜잭션으로 정리한다.

- 방 status를 `waiting`으로 변경
- `selectedGame`, 게임 public/private 데이터 제거
- `finishedAt`, `finishReason` 등 종료 필드 제거

기존에는 결과 route를 닫기 전에 태블릿이 종료되면 재시작 시 `playing`만 route 복원
대상이어서 `finished`가 남을 수 있었다. 태블릿 홈은 이제 복원된 게임 상태와 방 상태가
모두 `finished`일 때 같은 기존 정리 명령을 호출한다. 서버 계약은 변경하지 않는다.

다만 2026-08-30 실기기 점검에서는 태블릿이 대기실로 돌아온 뒤에도 휴대폰 winner
화면이 남았다. 위 코드 경로와 자동 테스트가 존재한다는 사실만으로 기기 간 종료 동기화가
완료됐다고 판단하지 않으며, 출시 차단 `FINISH-SYNC-01`로 추적한다.

2026-08-31 추가 메모에서도 게임 종료 후 `홈으로 나가기`를 누르면 일부 휴대폰만 그룹에
복귀하거나 두 대 모두 검정 화면에 남는다고 확인됐다. 종료가 겹치는 경우의 실기기 실패로
기록하며, 버튼을 누른 기기와 강제 종료·재시작의 상세 순서를 임의로 추정하지 않는다.

추가 자동 재현에서는 게임 route의 pop 애니메이션 중 두 번째 종료가 들어오면
`popUntil`이 이미 비활성인 route를 찾으면서 아래 대기실·홈까지 제거했다. 공통
`exitGameRoute`는 mounted뿐 아니라 route의 isActive도 확인하고 한 번만 닫는다.
라이어스포커·마피아의 비정상 종료도 같은 함수를 사용한다. 수정 전 실패한 두 widget
테스트는 통과했으며, 이후 수정 APK의 종료·그룹 복귀와 winner 직후 태블릿 재시작도
사용자가 모두 통과로 확인했다. 태블릿 역할은 Medium Tablet 에뮬레이터였다.
강제 종료 동안 winner 아래 `태블릿 오류 화면`이 나타나는 관찰은 사용자가 추후 개선으로
지정했다. 정확한 화면 문구·route는 미확인이며
[WINNER-CONNECTION-LAYER-01](../planning/TASKS.md#winner-connection-layer-01--winner-아래-태블릿-연결-안내-겹침)에서
추적한다. winner 잔류나 검정 화면 재발로 해석하지 않는다.

## 퇴장·강퇴·방 종료 계약

- `leaveRealtimeRoom`: 게임 중이 아닐 때 본인 `players/{uid}`만 제거한다.
- 게임별 `*_leave_game`: 게임 명단과 방 참가자를 함께 정리하고, 필요하면 중단·다음 턴
  또는 인원 부족 종료를 계산한다.
- `removePlayer`: 컨트롤러가 지정 UID를 방에서 제거한다.
- `closeRoom`: 컨트롤러만 방을 닫고 mapping을 해제하며 보존 후 삭제 대상으로 만든다.

클라이언트 `leaveRoom`과 `leaveGame`은 성공 뒤 heartbeat와 로컬 세션을 함께 지운다.
따라서 게임 나가기를 대기실 복귀로 바꾸려면 세 게임의 roster/private state, 방
participant status, 재접속·강퇴·중단 계약을 먼저 설계하고 승인받아야 한다.

## DevErrorLog와 사용자 오류

`dev_error_overlay.dart`는 호환성을 위한 무표시 경계이며 debug를 포함해 배지·목록·오류
원문·stack trace를 렌더링하지 않는다. `DevErrorLog`는 개인정보 없는 `context`,
`errorType`, 첫 프로젝트 frame을 `[dev_error]` 한 줄로 콘솔과 ADB logcat에 남긴다.
release의 예상하지 못한 오류는 기존 Crashlytics가 맡고, 정상 퇴장 중 늦은 구독 오류와
성공한 재연결의 heartbeat 실패는 사용자 오류나 Crashlytics 오류로 승격하지 않는다.

```powershell
adb logcat -v time | Select-String -Pattern '\[dev_error\]|room_connection'
```

## 자동 테스트가 보장하는 범위

- `test/auth/`: AuthGate, 이메일 링크 오류, Google 버튼, 온보딩 단계, 플랫폼 parity
- `test/controller_presence_test.dart`: heartbeat 유예와 controller 표시 판정
- `test/player_presence_test.dart`: 참가자 20초 경계, lastSeen 변환, 후보 중복 억제
- `test/restorable_player_session_test.dart`, `session_return_prompt_test.dart`: 휴대폰 저장·동의
- `test/controller_room_lifecycle_test.dart`: 태블릿 저장·종료 lifecycle
- `test/app_network_guard_test.dart`, `game_reconnect_screen_test.dart`: 연결 UI·복구 화면
- `test/room_leave_*`: 성공·실패 때 세션과 UI 계약
- `test/tablet_room_reset_test.dart`: 강퇴/방 초기화 및 끊긴 참가자 표시
- `test/room_restore_to_waiting_test.dart`: 종료 후 정리와 재시작 시 finished 정리
- `test/game_route_exit_test.dart`: 다중 다이얼로그와 중복 종료 시 대기실·홈 보존
- `test/phone_home_layout_test.dart`: Galaxy S20+ 논리 폭에서 홈 제목 영역 overflow 방지
- `functions/test/controller-presence-timer.test.mjs`, `game-interruption*.test.mjs`:
  중단 원인 합성, deadline 정지·복구, 만료 처리
- `functions/test/room-lifecycle.test.mjs`: 방 상태·선택 게임·보존·퇴장 서버 전이
- `functions/test/room-presence-rules.test.mjs`: 실제 presence rules 표현식을 mock
  snapshot으로 평가. Firebase Rules 엔진·에뮬레이터 통합 검사는 아님

이 테스트는 실제 Firebase 연결 종료 시간, 네이티브 로그인 SDK, 제조사 글꼴/상태바,
백그라운드 제약을 보장하지 않는다. Project CLI의 targeted/FULL 검증을 실행하지 않은
결과는 저장소 전체 PASS로 표현해서는 안 된다.

## 2026-08-27 수동 자료 인용과 판정

카카오톡 다운로드가 원래 파일명을 바꿨으므로 파일명 자체를 시나리오 ID로 사용하지
않는다. 아래 매핑은 사진에 직접 보이는 내용만 기록한다.

| 첨부 파일 | 직접 확인되는 내용 | 처리 |
| --- | --- | --- |
| `KakaoTalk_20260830_015302923_01.jpg` 및 동일 화면 clipboard PNG | Galaxy S20+ 홈의 `RIGHT OVERFLOWED BY 43 PIXELS` | 고정 Row를 줄바꿈 가능한 header로 변경, widget 회귀 테스트 추가 |
| `KakaoTalk_20260830_015302923.jpg` | 휴대폰 winner 화면이 남음 | finished 재시작 정리 경로 추가 |
| `KakaoTalk_20260830_015302923_02.jpg` | 참가자 이탈, 0초, 인원 부족 즉시 종료 안내 | 기존 중단/즉시 종료 흐름의 증거 |
| `KakaoTalk_20260830_015302923_03.jpg` | 보라색 게임 화면의 `나가기` 버튼 | 원래 시나리오명은 단정하지 않음 |
| `KakaoTalk_20260830_015302923_04.jpg` | 태블릿 재연결 화면과 `오류 2 (+2)` 배지 | 복구 UI는 동작; 배지 원문 없이는 오류 원인 미확정 |
| 카카오톡 MP4 3개 | 파일명과 원래 시나리오의 대응 불명 | 동영상 묶음으로만 보존; 수동 기록의 시간선을 근거로 사용 |

수동 기록상 방 `R5PVH`에서 강제 종료 후 `isConnected: false`와 서버 정리가 관찰됐고,
비행기 모드 사례에서는 약 2분 40초~3분 뒤 중단 UI가 나타났다. 당시 한 확인값이
`isConnected: true`로 기록돼 있어 단절 판정 지연과 UI 표시 누락을 구분했다.
production RTDB를 다시 읽지 않아도 이 원인 분류와 안전한 UI 수정에는 충분하다.

## 알려진 문제·미검증 범위

- 과거 같은 세션의 두 번째 단절 뒤 휴대폰과 태블릿의 방 상태가 갈라졌으나, 수정 APK의
  2026-08-31 최종 테스트에서 반복 단절·복구를 모두 통과했다. `SESSION-RECONNECT-01`은
  보고 환경에서 통과·차단 해제로 갱신했고 과거 실패를 현행 상태로 재사용하지 않는다.
- 휴대폰 자체 네트워크 단절과 태블릿 controller stale 안내의 구분·불필요한 교대 표시
  없음은 2026-08-31 사용자 확인으로 `NET-UI-01` 실기기 통과를 확정했다. winner 아래
  태블릿 안내 겹침은 별도 출시 후 개선이며 기존 판정을 취소하지 않는다.
- 회원가입 이메일 입력 화면의 앱 내 뒤로가기 실패와 Android 시스템 뒤로가기 앱 정지는
  `AUTH-BACK-01`에서 수정했다. 2026-08-31 사용자가 회원가입 체크의 성공을 추가
  확인해 실기기 통과로 정정했다. 설치 빌드 식별과 전체 자동 검증은 별도 근거다.
- production의 `closed` 방이 `cleanupAt`을 약 3일 넘겨 남았던 사례는
  `ROOM-CLEANUP-01`의 rules·지정 함수 보완 배포 뒤 후보 28개/삭제 28개/실패 0개 및
  승인된 단일 상태 경로의 null 결과로 정리를 확인했다. 이번 작업의 재조회는 아니다.
  2026-08-31 보고된 퇴장 참가자 잔류와 같은 원인이라고 단정하지 않는다.
- 네트워크 복구 체감 시간은 OS/Firebase 재연결 시간과 앱의 8초 복구 시도를 합친다.
  세션을 보존하며 복구에 성공한 경우의 순수 체감 시간만 P2 관찰 항목이며, 보류 근거·
  착수 조건·완료 기준은
  [`NET-RECOVERY-01`](../planning/TASKS.md#net-recovery-01--네트워크-복구-체감-지연)에서
  관리한다.
- 과거 DevErrorLog 배지 사진의 두 오류 원문은 미확정이며 새 빌드에서는 화면에 표시하지 않는다.
- 2026-08-31 사용자 확인으로 이번 실기기 테스트 중 DevErrorLog 배지·오류 원문·
  stack trace 미노출을 통과 확정했다. 과거 오류 원인의 확정과는 별개다.
- 게임 나가기는 현재 그룹 퇴장까지 수행한다.
- 이메일 링크와 Google 로그인은 실기기에서 성공했고 Apple 로그인은 팀원의 실기기
  확인에서 성공했다. 인증 설정이나 관련 코드가 바뀌면 다시 확인한다.
- 정상 카드 배부에서는 20초 초기 상태 비상 탈출 UI가 나타나지 않음을 확인했다.
- A32·A35에서는 작은 화면 overflow가 재현되지 않았다. 2026-08-31 사용자는 실제
  S20+의 이전 UT 성공과 기존 깨짐의 글씨/화면 확대 설정 연관성을 설명했다. 빌드와
  설정값은 미제공이므로 최신 수정 빌드 확인과 구분한다. 확대 설정 대응은
  [출시 후 개선](../planning/TASKS.md#accessibility-scale-01--글씨화면-확대-설정-대응)에 기록한다.
- iOS 네이티브 `onDisconnect` 오류와 실제 태블릿/휴대폰 중첩 종료의 수정 후 재검증은
  에이전트가 직접 실행하지 못했다. 사용자가 실행한 태블릿 역할은 Android 에뮬레이터이므로
  물리 태블릿·iOS의 검증 근거로 확대하지 않는다.
- 에뮬레이터와 production Firebase를 사용하지 않은 자동 검사만으로 실제 연결 만료
  시간을 판정할 수 없다.

기존 출시 차단 항목의 최종 변경과 판정은
[`완료 작업과 검증 근거`](../planning/COMPLETED_TASKS.md)를 따른다. 새 미해결 항목과
출시 판정 조건은 [작업 목록](../planning/TASKS.md)에서 관리한다.

## 승인이 필요한 개선 후보

1. 게임 나가기를 그룹 대기실 복귀로 변경: 모든 게임의 leave API, roster/private
   data와 interruption state machine 변경 필요.
2. finished 정리를 controller 재진입이 아닌 서버가 수행: 결과 보존 시간과
   `selectedGame` 의미 변경 필요.
3. waiting ghost 정리 유예 단축: 60초 복귀 보장과 scheduled cleanup 주기 재검토 필요.

이 항목은 public API, persistent data 또는 중요한 state machine에 닿으므로 증상만으로
구현하지 않는다.
