# Cloud Functions 정리

배포된 함수 **69개** 전부. 게임 규칙·승패·턴 마감·방 수명주기는 전부 여기서 결정한다.

| 종류 | 개수 |
| --- | --- |
| `onCall` 호출형 | 60 |
| `onSchedule` 주기 | 4 |
| RTDB 트리거 | 4 |
| `onRequest` HTTP | 1 |

## 1. 이름 규칙과 리전

```text
game_<게임 id>_<동작>      예: game_liars_poker_submit_cards
game_common_<영역>_<동작>   예: game_common_interruption_expire
방·인증                    기존 camelCase 유지: createRealtimeRoom, beginOnboarding
```

**리전이 두 개다. 모르면 배포가 조용히 안 붙는다.**

| 대상 | 리전 |
| --- | --- |
| `onCall` · `onSchedule` · `onRequest` | `asia-northeast3` (서울) |
| RTDB 트리거 4개 | `asia-southeast1` (싱가포르 — RTDB 인스턴스가 있는 곳) |

**배포된 callable 이름은 구버전 앱의 public contract다.** 바꾸면 스토어에 이미 나간
앱이 함수를 찾지 못한다. 바꿔야 하면 클라이언트 호출부를 같은 커밋에서 함께 고쳐
함께 배포하거나, 옛 이름을 얇은 shim으로 남긴다.

## 2. 방 — 게임 이전의 모든 것

`functions/src/room/` · onCall 11개

| 함수 | 하는 일 |
| --- | --- |
| `createRealtimeRoom` | 태블릿이 방을 만들고 방 코드·컨트롤러 세션 발급. Admin SDK라 RTDB 보안 규칙을 우회 |
| `validateRealtimeRoom` | 입력한 방 코드가 유효한지 확인 (참가 전 사전 검사) |
| `joinRealtimeRoom` | 휴대폰 참가·재접속. 기존 uid는 좌석과 게임 데이터를 유지하고 연결 상태만 복구 |
| `beginRealtimeRoomSeating` | 좌석 배치 단계 시작 |
| `saveRealtimePlayerSeatIndexes` | 태블릿이 정한 좌석 번호 저장 |
| `selectRealtimeRoomGame` | 이 방에서 플레이할 게임 선택 |
| `fetchRealtimeRoomGroupEntitlements` | 방 참가자들이 합쳐서 보유한 유료 게임 ID를 서버가 계산. 클라이언트가 남의 `/users` 문서를 읽지 않게 하는 경계 |
| `resumeRealtimeControllerRoom` | 태블릿이 앱을 다시 켰을 때 자기 방으로 복귀 |
| `removeRealtimeRoomPlayer` | 태블릿이 특정 참가자를 내보냄 |
| `leaveRealtimeRoom` | 참가자가 스스로 방을 나감 |
| `closeRoom` | 방을 닫음 (전원 퇴장) |

## 3. 인증 · 온보딩

`functions/src/auth/` · onCall 8개

| 함수 | 하는 일 |
| --- | --- |
| `beginOnboarding` | 가입 절차 시작 (상태 문서 생성) |
| `advanceOnboarding` | 다음 단계로 진행 |
| `completeOnboardingProfile` | 닉네임·프로필 확정하고 온보딩 완료 |
| `recoverLegacyOnboarding` | 온보딩 문서가 없는 구버전 계정을 현재 스키마로 복구 |
| `checkEmailDuplicate` | 가입 전 이메일 중복 확인 |
| `syncGoogleUserProfile` | 구글 로그인 사용자의 닉네임·사진을 Firestore에 병합 |
| `syncAppleUserProfile` | 애플용. 애플은 이름을 최초 승인 때 한 번만 주고 사진은 아예 안 줘서, 비어 있는 값이 기존 값을 덮지 않도록 병합 |
| `deleteAccount` | 계정 삭제 |

## 4. 게임

세 게임 모두 같은 뼈대다 — **시작 → 연출 완료 알림 → 조작 → 타임아웃 → 종료/퇴장.**
`complete_*` 는 태블릿 연출이 끝났다는 신호, `timeout_*` 는 제한시간이 지났다는 신호다.

### 마피아 (13)

`functions/src/mafia/`

| 함수 | 하는 일 |
| --- | --- |
| `game_mafia_start_game` | 역할 배분하고 게임 시작. 역할 구성은 태블릿이 고른 값 |
| `game_mafia_confirm_role` | 내 역할 카드를 확인했다고 알림. 전원 확인하면 곧바로 밤으로 |
| `game_mafia_complete_role_reveal` | 태블릿 배분 연출 종료. **미확인자가 있어도 넘어감** — 한 명 때문에 판이 멈추지 않게 |
| `game_mafia_submit_night_action` | 밤 행동 대상 제출. 마감 전엔 여러 번 바꿀 수 있음 |
| `game_mafia_timeout_night` | 밤 마감. 안 고른 사람은 아무 일도 안 한 것으로 처리 |
| `game_mafia_complete_morning` | 아침 발표 연출 종료. **여기서 첫 번째 승패 판정** |
| `game_mafia_end_discussion` | 토론 조기 종료에 한 표. 생존자 과반수가 누르면 투표로 |
| `game_mafia_timeout_day` | 토론 시간 종료 → 투표 |
| `game_mafia_submit_vote` | 비밀 투표. 누가 누굴 찍었는지는 `server` 에만, public 엔 제출 인원수만 |
| `game_mafia_timeout_vote` | 투표 마감. 미제출은 기권 |
| `game_mafia_complete_vote_result` | 개표·처형 연출 종료. **여기서 두 번째 승패 판정** |
| `game_mafia_end_game` | 게임 종료 |
| `game_mafia_leave_game` | 방에서는 즉시 나가되, 사망자는 바로 / 생존자는 남은 사람 투표 뒤 제외 |

### 파이널콜 (12)

`functions/src/final-call/`

| 함수 | 하는 일 |
| --- | --- |
| `game_final_call_start_game` | 게임 시작 · 다시하기 (`restart` 플래그) |
| `game_final_call_complete_dealing` | 태블릿 카드 분배 연출 종료 |
| `game_final_call_draw_card` | 카드 뽑기 |
| `game_final_call_complete_turn` | 턴 종료 |
| `game_final_call_timeout_turn` | 턴 마감. 단계별로 다르게 해결 (callerSubmit / finalSubmit / playing / finalTurns) |
| `game_final_call_declare` | CALL 선언 |
| `game_final_call_submit_hand` | 최종 핸드 제출 |
| `game_final_call_complete_result_reveal` | 태블릿 최종 공개 연출 종료 → 휴대폰 결과 화면 |
| `game_final_call_start_next_round` | 다음 라운드 |
| `game_final_call_end_game` | 게임 종료. finished 상태를 먼저 전달해 전 기기가 인식 |
| `game_final_call_clear_game` | 방·참가자는 유지하고 `rooms/{code}/game` 만 삭제 |
| `game_final_call_leave_game` | 게임 도중 퇴장 |

### 라이어스포커 (11)

`functions/src/liars-poker/`

| 함수 | 하는 일 |
| --- | --- |
| `game_liars_poker_start_game` | 태블릿이 새 판 시작 · 다시하기 |
| `game_liars_poker_complete_dealing` | 카드 분배 연출 종료 |
| `game_liars_poker_ready_turn` | 카드를 펼쳐 첫 턴 타이머 시작 |
| `game_liars_poker_submit_cards` | 카드 제출 |
| `game_liars_poker_call_liar` | LIAR 선언 |
| `game_liars_poker_pass_challenge` | 마지막 카드 도전 포기 (FOLD) |
| `game_liars_poker_prepare_penalty` | 벌칙 룰렛 준비 |
| `game_liars_poker_resolve_penalty` | 룰렛 결과 전달 |
| `game_liars_poker_force_timeout` | **백스톱.** 턴 플레이어 휴대폰이 잠기면 아무도 턴을 못 넘기므로 태블릿이 강제 해결. 마감 전 호출은 `notExpired` 로 거절 |
| `game_liars_poker_end_game` | 게임 종료 |
| `game_liars_poker_leave_game` | 게임 도중 퇴장 |

## 5. 게임 공용 — 끊김 처리

`functions/src/game-interruption/` · onCall 5개

이 저장소에서 **게임 횡단 관심사를 서버에서 공용화한 유일한 사례**다. 새 게임은
끊김 처리를 다시 구현하지 않고 이 모듈을 그대로 쓴다.

| 함수 | 하는 일 |
| --- | --- |
| `game_common_interruption_report_stale_player` | heartbeat 가 끊긴 참가자를 신고 |
| `game_common_interruption_vote_to_continue` | 기다리고 계속하는 쪽에 투표 |
| `game_common_interruption_exclude_player` | 태블릿 진행자가 끊긴 사람을 제외하고 즉시 계속 |
| `game_common_interruption_expire` | 마감(60초)이 지난 중단을 정리 — 즉시 반응 경로 |
| `game_common_interruption_finish_now` | 인원 부족이 확정되면 60초를 기다리지 않고 즉시 정상 종료 |

## 6. 화면이 죽어도 도는 것

### RTDB 트리거 (4) — `asia-southeast1`

| 함수 | 감시 경로 | 하는 일 |
| --- | --- | --- |
| `game_common_interruption_on_connection_changed` | `/rooms/{room}/players/{uid}/isConnected` | 참가자 접속이 끊기면 공용 게임 중단 상태로 승격 |
| `game_common_controller_presence_changed` | `/rooms/{room}/controllerPresence/connected` | **태블릿이 끊긴 동안 서버 턴 마감을 멈춤** |
| `syncRealtimeRoomGameStatus` | `/rooms/{room}/game/public/status` | 게임 상태를 방 상태에 반영 (대기실 복귀 판정) |
| `cleanupDeletedRoomCreationRequest` | `/rooms/{room}` (삭제 시) | 방이 먼저 사라졌을 때 남은 생성 요청 기록을 재시도 가능하게 정리 |

### 주기 실행 (4) — 전부 `Asia/Seoul`

| 함수 | 주기 | 하는 일 |
| --- | --- | --- |
| `cleanupExpiredGameInterruptions` | 1분 | 중단 만료를 부르는 곳이 화면 타이머뿐이던 구멍의 백스톱. 모두가 앱을 닫아도 서버가 정리 |
| `cleanupGhostRoomPlayers` | 5분 | 게임이 끝났거나 대기실로 돌아온 방의 오래 끊긴 참가자 제거. 유예는 재접속 유예(60초)보다 충분히 길게 |
| `cleanupStaleRealtimeRooms` | 5분 | 버려진 방 정리 (`cleanupAt` 인덱스 사용) |
| `cleanupIncompleteAccounts` | 매일 03:30 | 온보딩 미완료 계정 — **지금은 보고만 하고 실제 삭제는 꺼져 있다** |

## 7. 정리할 것

### C1. `registerProfile` — 쓰지 않는 HTTP 엔드포인트

69개 중 유일한 `onRequest` 다. Firebase ID 토큰을 제대로 검증하므로 보안 구멍은
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
`POST /rooms/{code}/commands` 와 1:1로 맞는다. 기존 3게임은 배포된 이름이 contract 라
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
