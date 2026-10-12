# Cloud Functions 정리

2026-10-13 B1·디벨럽1 통합 후보 index.ts export 81개: onCall 71, RTDB trigger 5, onSchedule 4, HTTP 1.
production 배포 상태를 조회한 수치가 아니다. 게임 규칙·승패·턴·방 수명은 서버가 결정한다.
[현재 네트워크·세션 계약](NETWORK_SESSION_CONTRACT.md)을 함께 따른다.

## 1. 이름과 리전

게임은 game_<id>_<동작>, 공용은 game_common_<영역>_<동작>, 방·인증은 기존 camelCase다.
callable/schedule/HTTP는 asia-northeast3, RTDB 트리거는 asia-southeast1이다.
현재 후보의 기존 네트워크 투표/finish_now 제거와 소비자 변경은 채택한 기술안에 따른다.
실제 반영·기존 데이터·함수 삭제/혼합 상태는 별도 승인된 배포 계획에서 확인한다.

## 2. 방과 인증

room/ callable 12개: createRealtimeRoom, validateRealtimeRoom, joinRealtimeRoom,
beginRealtimeRoomSeating, saveRealtimePlayerSeatIndexes, selectRealtimeRoomGame,
fetchRealtimeRoomGroupEntitlements, resumeRealtimeControllerRoom, removeRealtimeRoomPlayer,
leaveRealtimeRoom, closeRoom, fetchRealtimeRoomSession.
같은 operation 재생, room/member/current connection와 sequence CAS, 요청 방의 구매 자격을 검증한다.

auth/ callable 9개: beginOnboarding, advanceOnboarding, completeOnboardingProfile,
recoverLegacyOnboarding, checkEmailDuplicate, syncGoogleUserProfile, syncAppleUserProfile, deleteAccount,
completeGuestOnboarding.
추가로 `completeGuestOnboarding`은 Firebase 익명 토큰과 provider 없는 Auth 계정을
함께 검증하고, 현재 약관 동의·자동 닉네임·`anonymous/complete` 온보딩을 한 transaction에
저장한다. 이 완료 문서가 생기기 전에는 기존 방 생성·검증·참가 가드가 게스트를 거절한다.
기본 무료 게임은 기존 그룹 접근 규칙을 따르고, 유료 게임은 기존 `ownedGames` 검사를
그대로 받는다. 2026-10-13 운영 Firebase Authentication의 Anonymous provider가
활성 상태임을 확인하고 `completeGuestOnboarding`을 `asia-northeast3`의 Node.js 22
2nd Gen callable로 배포했다. 인증 없는 요청은 HTTP 401 `UNAUTHENTICATED`로 거절된다.
registerProfile은 별도 HTTP다.
completeOnboardingProfile은 처음 가입을 마칠 때 현재 `SIGNUP_TERMS_VERSION`의 필수 동의
(`consents`: age14·terms·privacy, 선택 marketing)가 없으면 `failed-precondition`으로 거절하고,
`users/{uid}.consents`(동의 항목·`agreedAt`·`marketingUpdatedAt`)와
`userOnboarding/{uid}.consentVersion`을 저장한다. 이 검사는 동의를 보내지 않는 이전 앱의
가입 완료를 막으므로 Functions와 앱을 함께 배포한다.

2026-10-12 비밀번호 우선 이메일 인증 복원 후보(미배포): `beginOnboarding`에
`{provider: "legacyPassword"}`를 보내면 password provider를 확인하고 미인증 계정도
`settingProfile`로 준비한다. 이는 서비스 이용 허용이 아닌 미완료 가입 상태다.
Firebase `emailVerified`가 true가 될 때까지 앱은 인증 대기 화면을 표시하며,
`completeOnboardingProfile`도 legacyPassword 계정의 이메일 인증 여부를 확인한다.
기존 인자 없는 링크 가입은 `emailLink/settingPassword`로 유지하고, 기존 문서 상태는
덮어쓰지 않는다. 새 앱 배포 전에 위 두 함수를 함께 배포해야 한다. 한쪽만 반영하면
미인증 가입 준비 실패 또는 이메일 인증 검증 누락이 생긴다. production 조회·배포는
별도 승인이 필요하며, 이 후보에서 수행하지 않았다.

## 3. 네 게임

| 게임 | callable 목록 |
| --- | --- |
| Liar's Poker (11) | start_game, complete_dealing, ready_turn, submit_cards, call_liar, pass_challenge, prepare_penalty, resolve_penalty, force_timeout, end_game, leave_game |
| Final Call (12) | start_game, complete_dealing, draw_card, complete_turn, timeout_turn, declare, submit_hand, complete_result_reveal, start_next_round, end_game, clear_game, leave_game |
| Mafia (13) | start_game, confirm_role, complete_role_reveal, submit_night_action, timeout_night, complete_morning, end_discussion, timeout_day, submit_vote, timeout_vote, complete_vote_result, end_game, leave_game |
| Holdem (7) | start_game, complete_dealing, act, timeout_turn, complete_result, end_game, leave_game |

각 이름 앞에 game_liars_poker_, game_final_call_, game_mafia_, game_holdem_을 붙인다.
complete_*는 연출 완료, timeout_*는 서버 deadline 확인을 요청한다.
모든 현재 명령은 공용 transaction/context/ledger 검증을 사용한다.
Mafia 고유 투표는 유지하지만 네트워크 제외 투표는 없다. 자기 퇴장은 원래 membership만 제거한다.

## 4. 게임 공용 — 중단·준비·결과 확인

| callable | 역할 |
| --- | --- |
| game_common_recovery_report | 현재 접속 ready/failed·reportSeq 및 필수 barrier |
| game_common_operation_status | 미확정 작업의 applied/stale/notApplied 최소 상태 |
| game_common_interruption_report_stale_player | 관찰한 현재 접속 heartbeat 실패 신고 |
| game_common_interruption_report_stale_controller | 참가자가 관찰한 진행 기기 heartbeat 정체를 서버 현재 접속과 재검증 |
| game_common_interruption_exclude_player | controller 실제 reducer preview/제외 |
| game_common_interruption_wait_more | 만료된 현재 incident를 한 번 30초 연장 |
| game_common_interruption_expire | 결정 대기 표시, 자동 제외/종료 없음 |

connected=true만으로 타이머를 재개하지 않는다.
vote_to_continue/finish_now는 현재 index export와 소비자에서 제거했다.

## 5. RTDB 트리거와 주기 작업

| RTDB 함수 (싱가포르) | 경로·역할 |
| --- | --- |
| syncRealtimeRoomConnection | rooms/{room}/connections/{uid}/{connectionId}/connected, false 상태 전환만 현재 root CAS로 요약·중단 반영(retry). 시각-only heartbeat는 호출하지 않음 |
| game_common_interruption_on_connection_changed | players/{uid}/isConnected, 현재 phone 단절 cause의 멱등 안전망 |
| game_common_controller_presence_changed | controllerPresence/connected, controller 단절 cause의 멱등 안전망 |
| syncRealtimeRoomGameStatus | game/public/status, 현재 game 상태를 방에 반영 |
| syncRoomCleanupQueue | rooms/{room}/cleanupSignal, 소형 현재 signal만 재조회 후 세대·revision을 확인해 due queue 갱신 |

| schedule 함수 (서울·Asia/Seoul) | 주기·역할 |
| --- | --- |
| cleanupExpiredGameInterruptions | 1분, 만료를 결정 대기로 표시 |
| cleanupGhostRoomPlayers | 5분, 별도 cursor로 회당 500방 순회·최대 10개 transaction, 현재 상태 재검증 후 유령 참가자 정리 |
| cleanupStaleRealtimeRooms | 5분, due index + 지속 cursor, generation 조건부 방/예약/매핑 정리 |
| cleanupIncompleteAccounts | 매일 03:30, 현재 삭제 비활성·보고만 수행 |

2026-10-12 정리 후보는 확정 종료된 생성 요청의 transport 정보를 축약하고 terminal
재생 표시와 방 할당 세대를 유지한다. 계정 탈퇴는 객체/문자열 매핑의 같은 소유 방만
조건부로 닫고 해당 요청·슬롯 정리 후 매핑을 제거한다. UID 전체 생성 요청 삭제는 하지 않는다.
고아 예약 자동 해제와 접속/작업 결과 TTL은 보류다. 운영 관찰·검증·미배포 현황은
[RTDB 정리 검토](../operations/RTDB_RETENTION_REVIEW.md)를 따른다.

아래 기존 정리 제안은 현재 작업의 구현·승인이 아니다.

## 7. 정리할 것

### C1. `registerProfile` — 쓰지 않는 HTTP 엔드포인트

79개 중 유일한 `onRequest` 다. Firebase ID 토큰을 제대로 검증하므로 보안 구멍은
아니지만, **Dart 쪽에서 부르는 곳이 0곳**이고 하는 일이 `syncGoogleUserProfile` 과
겹친다. `index.ts` 주석에도 "삭제 여부는 따로 결정한 뒤 정리하세요"로 남아 있다.

→ 삭제. 함수 하나가 줄면 배포 시간과 콜드스타트 표면이 줄어든다.

### C2. `cleanupIncompleteAccounts` 가 실제로는 아무것도 안 지운다

매일 03:30에 도는데 삭제가 의도적으로 비활성이다(production 로그와 retention 확인
전까지). 지금은 보고만 한다. **"정리되고 있다"고 착각하기 쉬운 상태**다.

→ 켤 것인지, 함수를 내릴 것인지 결정이 필요하다.

### C3. 게임당 callable 11~13개 — 게임 수만큼 곱해진다

마피아 13 · 파이널콜 12 · 라이어스 11. 게임 10개면 callable 120개 이상이고
`index.ts` 는 손으로 관리하는 export 목록이다. 실제로 머지 충돌을 줄이려고 export
블록을 일부러 분리해 둔 흔적이 있다.

→ 신규 게임부터 단일 엔드포인트로. `game_command({game, room, command, commandId, payload})`
하나면 게임이 늘어도 함수 수가 그대로이고, Spring 이행 때
`POST /rooms/{code}/commands` 와 1:1로 맞는다. 기존 게임은 배포된 이름이 contract 라
그대로 둔다.

### C4. 이름 규칙이 두 가지

게임은 `game_<id>_<동작>`(snake), 방·인증은 `createRealtimeRoom`(camel). 배포된 이름을
못 바꿔서 생긴 것이라 의도적이지만 새로 합류하는 사람은 헷갈린다.

→ 코드 대신 문서로 정리하고, **새 함수는 방·인증도 snake 로** 통일한다.

### C5. `mafia/game.ts` 1,320줄 — 규칙과 DB 호출이 섞여 있다

서버에서 가장 큰 파일이다. 게임 규칙과 `admin.database()` 호출이 한 파일에 있어서
Spring Boot 로 옮길 때 번역이 아니라 재작성이 된다.

→ 규칙을 `reduce(state, command) → {state, events}` 순수 함수로 분리. 트랜잭션·멱등·
권한은 런타임(Functions/Spring)이 담당. 기존 서버 테스트 22개를 그대로 재사용할 수
있고 Java 이식이 기계적이 된다.

## 8. 배포

```bash
nvm use                          # Node 22
cd functions && npm install
npm run lint && npm run build    # predeploy 가 eslint + tsc 를 강제한다

# 사용자 승인 후, 저장소 루트에서
./functions/node_modules/.bin/firebase deploy --only functions
```

RTDB 트리거를 옮기거나 이름을 바꿀 때는 **구·신 함수가 같은 이벤트를 중복 처리하지
않게** 해야 한다. 배포 직후 잠깐 둘 다 살아 있는 구간이 생긴다.


## 2026-10-10 로비 지연 개선 후보 (`디벨럽1`)

기존 `createRealtimeRoom`은 확인된 종료 allocation의 completed 생성 슬롯을 조건부
교체해 cleanup 주기 전 재생성을 허용한다. 다른 세대/미확정 생성은 보존한다.
`createRealtimeRoom`, `closeRoom`, `game_common_operation_status`는 고정 단계별
`room_action_timing` 로그를 남긴다. payload·식별자·오류 원문은 넣지 않는다.
새 export/리전/minInstances/DB schema 변경은 없다. 2026-10-10 사용자 승인으로
`createRealtimeRoom`만 `project0000-ec01e`에 배포했다(서울/Node22, CLI 성공·exit0).
나머지 두 함수의 timing은 미배포다. 실제 재생성·속도 재측정은 대기이며
[범위·측정 절차](../operations/ROOM_ACTION_LATENCY.md)를 따른다.

## 2026-10-11 최초 준비·동일 계정 세션 조회 배포

사용자 승인 후 recovery.purpose와 동일 계정 역할 조회 수정의 대상14개를
project0000-ec01e에 배포했다. 각 게임 start_game4개, joinRealtimeRoom,
resumeRealtimeControllerRoom, syncRealtimeRoomConnection,
game_common_controller_presence_changed, game_common_recovery_report,
game_common_interruption_report_stale_player, game_common_interruption_report_stale_controller,
game_common_interruption_on_connection_changed, fetchRealtimeRoomSession,
game_common_operation_status의 CLI 업데이트 모두 성공(exit0). predeploy eslint/tsc도 통과했다.
위 과거 기록의 game_common_operation_status timing 미배포는 이 배포로 갱신되며 closeRoom의
운영 일치는 이번 배포 범위에 포함하지 않았다. 새 APK와 실기기36/37의 통과는 별도 판정한다.
[배포 근거·남은 검증](../planning/tasks/NETWORK_SESSION_20261011_IMPLEMENTATION.md)을 따른다.

## 2026-10-13 — B1·디벨럽1 통합 Functions/Rules 배포

사용자가 기존 게임 종료·B1 APK 준비와 Rules 동시 배포를 확인하고, 새 retry 정책의
재시도 과금 가능성 및 정확한81개 함수의 `--force` 배포를 명시 승인했다.
`codex/b1-develop1-integration`의 `4e9df2e`에서 project0000-ec01e에 Rules와81개 Functions를
배포했다. 두 배포 exit0, 배포 전후 소스·Git 상태 동일이다. stable Rules의 예약 설정 경로만
읽어 로컬 JSON과 일치를 확인했고 방·사용자·게임 데이터는 조회하지 않았다.

운영 함수81개는 모두 ACTIVE/Node22, 소스 리전과 일치한다. syncRealtimeRoomConnection은
`rooms/{roomCode}/connections/{uid}/{connectionId}/connected`, syncRoomCleanupQueue는
`rooms/{roomCode}/cleanupSignal`로 갱신됐으며 둘 다 retry=true를 확인했다. 신규 이름이나
소스에 없는 함수 삭제는 없다. 초기에 CLI retry 확인에서 중단됐고 강제 옵션 자동 승인이
거부됐으나, 사용자 명시 승인 후 동일 소스로 배포 성공했다.

배포 후 승인 FULL은 flutter-analyze의 기존 테스트 보조 코드 중괄호 INFO8개로 FAIL/exit1이다.
포맷·preflight·mutation은 PASS, 이후 전체 테스트 단계는 미실행이다. 제품/테스트 코드는
자동 수정하지 않았고 FULL PASS/출시 완료로 판정하지 않는다. 실기기와 실제 비용 측정은
별도 후속이다. [배포·검증 기록](../operations/HEARTBEAT_B1_IMPLEMENTATION.md#2026-10-13--운영-배포full-검증)을 따른다.
