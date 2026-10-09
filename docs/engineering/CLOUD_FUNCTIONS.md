# Cloud Functions 정리

2026-10-09 로컬 후보 index.ts export 79개: onCall 69, RTDB trigger 5, onSchedule 4, HTTP 1.
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

auth/ callable 8개: beginOnboarding, advanceOnboarding, completeOnboardingProfile,
recoverLegacyOnboarding, checkEmailDuplicate, syncGoogleUserProfile, syncAppleUserProfile, deleteAccount.
registerProfile은 별도 HTTP다.

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
| game_common_interruption_exclude_player | controller 실제 reducer preview/제외 |
| game_common_interruption_wait_more | 만료된 현재 incident를 한 번 30초 연장 |
| game_common_interruption_expire | 결정 대기 표시, 자동 제외/종료 없음 |

connected=true만으로 타이머를 재개하지 않는다.
vote_to_continue/finish_now는 현재 index export와 소비자에서 제거했다.

## 5. RTDB 트리거와 주기 작업

| RTDB 함수 (싱가포르) | 경로·역할 |
| --- | --- |
| syncRealtimeRoomConnection | rooms/{room}/connections/{uid}/{connectionId}, 현재 접속만 요약에 반영 |
| game_common_interruption_on_connection_changed | players/{uid}/isConnected, 현재 phone 단절 cause |
| game_common_controller_presence_changed | controllerPresence/connected, controller 단절 cause |
| syncRealtimeRoomGameStatus | game/public/status, 현재 game 상태를 방에 반영 |
| syncRoomCleanupQueue | rooms/{room}, 현재 allocation 재조회 후 due queue 갱신 |

| schedule 함수 (서울·Asia/Seoul) | 주기·역할 |
| --- | --- |
| cleanupExpiredGameInterruptions | 1분, 만료를 결정 대기로 표시 |
| cleanupGhostRoomPlayers | 5분, 대기/종료 방의 오래 끊긴 참가자 정리 |
| cleanupStaleRealtimeRooms | 5분, due index + 지속 cursor, generation 조건부 방/예약/매핑 정리 |
| cleanupIncompleteAccounts | 매일 03:30, 현재 삭제 비활성·보고만 수행 |

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
