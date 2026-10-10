# LP 실기기 후속 수정 후보

2026-10-10 KST. SESSION-RECONNECT-02 / TEST-REGRESSION-01.
[실기기 원인·설계](NETWORK_SESSION_LP_DEVICE_FOLLOWUP_DESIGN.md),
[작업 목록](TASKS.md), [세션 계약](../engineering/NETWORK_SESSION_CONTRACT.md).
사용자 `작업 진행해줘`로 설계 구현에 착수했다. 최종 FULL 승인·새 APK·서버 반영·실기기 결과는
각각 기록하며 직전 후보 FULL을 이번 수정의 통과로 재사용하지 않는다.

## 수정

- 같은 UID/방/세션·접속 세대/현재 connection의 진행·완료 복구를 공유한다.
  guard·foreground lifecycle·SDK true가 같은 Future를 기다리고, identity 저장과 해당 접속의
  heartbeat 확인 뒤 game 준비를 재개한다. 주기 heartbeat는 제한 owner 밖에서 계속 실행한다.
  현재 Navigator route만 안내를 소유하고 퇴장/dispose는 자신의 reconnect callback만 정리한다.
- pending join은 원래 결과를 재생하고 fetchRealtimeRoomSession으로 현재 참가·접속을 확인해
  채택한다. 같은 복구에서 추가 join을 무조건 만들지 않는다. 다른 명시 프로필 수정은 새 논리
  요청으로 적용한다. 제거 membership을 새 참가자로 만들지 않는다. identity/pending 저장에
  owner 검사와 현재 UID/방/참가 검사를 적용하고, disconnect는 당시 접속을 캡처한다.
- heartbeat permission-denied 원래 분류를 보존하고 episode당 한 번 제한 복구로 보낸다.
  ready의 명시 staleConnection은 같은 준비 예산으로 접속 재확인을 요청한다. generic 권한
  거절을 무한 join/heartbeat 반복이나 rules 완화로 바꾸지 않는다.
- localUsable만으로 준비 감시를 끝내지 않는다. 자신의 현재 ready accepted까지 같은 30초
  owner를 유지한다. 서비스의 기존 6회/요청 8초/전체 30초에서 동일 commandId·reportSeq·domain을
  재사용하고 operation_status applied 뒤 원래 응답을 받는다. controller는 중첩 재시도하지 않는다.
  ignored/reconciled는 ready 확인이 아니다. 최종 실패/소진은 sticky 오류·명시 재시도이며 늦은
  ack가 입력을 열지 못한다. 자신의 accepted 뒤 타인 pause 대기는 자기 실패 deadline이 아니다.
- 보고 순서는 프로세스 시간 기반 seed와 공용 단조 카운터라 controller 재생성 뒤 1로 돌아가지
  않는다. 방/참가/접속 전체 변경은 이전 ack를 무효화한다. persistent JSON은 유지한다.
  기기 시계를 과거로 크게 돌리는 상황은 이번 실기기 범위 밖이며 ignored를 우회하지 않는다.
- LP draw는 gameInstance/phaseSeq/대상과 개별 coordinator가 소유한다. 동일 penalty public/ready/
  pause는 보존한다. 완료 callback은 scope를 캡처해 한 번만 resolve하고 pause 중 완료는 현재
  ready까지 보관한다. 실패 재시도도 원래 draw/resolve ID다. 새 penalty/종료/새 게임의 이전 Future가
  새 pending·오류·retry를 바꾸지 못한다.
- debug 준비 기록에 세대·접속 seq·보고 순서·결과 분류·현재 여부·local/server/pause를 추가했다.
  오류 details는 지정한 안전한 reason 이름만 남긴다. UID·실제 세션 ID·손패는 기록하지 않는다.

타이머의 최초 서버 pause remaining 보존과 1대1 truthful/lastCardChallenge 확률은 바꾸지 않았다.
서버 ready의 8.75~9.36초 지연과 정확한 A 접속 불일치 주체는 원인 미확정이다.
로컬 수정·회귀 통과가 해당 실기기 지연까지 해결했다는 증거는 아니다.

## 회귀·검증

실제 LP controller의 public 중 완료/pause→ready/원래 draw 재시도/새 penalty와 늦은 작업/
controller 재생성, 실제 RoomService의 pending/current/제거 membership/owner 소진/프로필 수정,
준비 controller·위젯의 ack deadline/late ack/ignored/접속보다 먼저 온 데이터/타인 대기/새 membership/
기존 실패 UI 재시도·메뉴/현재 route, 실제 A/B/태블릿 callable 준비 및 새 LP penaltyCount=0를 검증한다.
기존 SDK 재실행·룰렛 ledger·네 게임 시작 회귀를 유지한다.

| command | status / exit | 범위 |
| --- | --- | --- |
| `.\tool\invoke_mosigame.ps1 test session --json` 중간 2회 | PASS / 0 | 5/5, Functions 90, mutation 없음. 마지막 UI/콜백 호환 정리 전 |
| `flutter test --no-pub` 영향 파일 직접 실행 | PASS / 0 | 준비 19, guard+룰렛 14, 방/전송/manifest 34, 마지막 방/UI/룰렛 20, 프로필 포함 방 5 |
| `flutter analyze --no-pub` 중간 후보 | PASS / 0 | 마지막 호환·UI 정리의 최종 분석은 아래 갱신 |
| `dart format --output=none --set-exit-if-changed` 변경 20개 | PASS / 0 | 0 changed |
| `git diff --check` | PASS / 0 | tracked 공백 오류 없음 |
| 최종 session·분석 | PASS / 0 | guarded session 5/5, Flutter 156·Functions 90, mutation 없음. 최종 await 보완 뒤 방 5/5·분석 no issues |
| `validate --full` | 사용자 지시로 보류 | 관련 검사 통과 후보로 실기기 테스트 우선, FULL PASS로 표현하지 않음 |
| 새 APK | PASS / 0 | debug APK 빌드·복사 hash·앱 식별자/버전 확인 완료 |
| Functions 배포·사후 metadata | PASS / 0 | 승인된 기존 63개 업데이트 성공·ACTIVE, 전체 79 이름 유지 |
| 기기 설치·실기기 | 사용자 직접 시험 대기 | 새 동일 APK를 A/B/태블릿 모두 설치, FULL은 보류 |

처음 전송 테스트의 결과 확인 호출 수 가정 4회 FAIL/exit 1은 모든 조회가 원래 operationId임을
검증하도록 고쳤다. 분석 style 경고 FAIL/exit 1은 블록·import 정리 후 PASS다.
formatter의 일시적 Windows mapped-file 부분 쓰기 실패(exit 0)는 후속 정상 format/0 changed로
해소했다. 설정/테스트 오류를 제품 실패 원인으로 바꾸지 않는다.

## 서버 반영 범위

직전 서버 수정은 room-transaction/start-game-transaction/LP finish-penalty다. 실제 경로 확인으로
module closure 69개에서 validateRealtimeRoom, fetchRealtimeRoomGroupEntitlements,
fetchRealtimeRoomSession, game_common_operation_status(읽기/결과 확인),
selectRealtimeRoomGame, cleanupGhostRoomPlayers(변경 wrapper를 쓰지 않는 독립 transaction)를 제외했다.
**후보 63개: 방/접속 12, 네 게임 43, 공용/주기 8.** Oct9 저장 inventory에서 63/63 이름이 존재한다.
이전 inventory와 구분하여 배포 직전·직후 실제 목록·region/runtime을 대조했고 아래 결과에 기록했다. Auth/IAM/rules,
새 함수·함수 삭제는 포함하지 않으며 조회 전용 gcloud configuration은 배포에 사용하지 않는다.
후보 목록:

```text
createRealtimeRoom
joinRealtimeRoom
saveRealtimePlayerSeatIndexes
beginRealtimeRoomSeating
syncRoomCleanupQueue
cleanupStaleRealtimeRooms
closeRoom
leaveRealtimeRoom
removeRealtimeRoomPlayer
resumeRealtimeControllerRoom
syncRealtimeRoomGameStatus
syncRealtimeRoomConnection
game_liars_poker_start_game
game_liars_poker_complete_dealing
game_liars_poker_ready_turn
game_liars_poker_submit_cards
game_liars_poker_call_liar
game_liars_poker_pass_challenge
game_liars_poker_prepare_penalty
game_liars_poker_resolve_penalty
game_liars_poker_force_timeout
game_liars_poker_end_game
game_liars_poker_leave_game
game_holdem_start_game
game_holdem_complete_dealing
game_holdem_act
game_holdem_timeout_turn
game_holdem_complete_result
game_holdem_end_game
game_holdem_leave_game
game_final_call_start_game
game_final_call_complete_dealing
game_final_call_draw_card
game_final_call_complete_turn
game_final_call_timeout_turn
game_final_call_declare
game_final_call_submit_hand
game_final_call_complete_result_reveal
game_final_call_start_next_round
game_final_call_end_game
game_final_call_clear_game
game_final_call_leave_game
game_mafia_start_game
game_mafia_confirm_role
game_mafia_complete_role_reveal
game_mafia_submit_night_action
game_mafia_timeout_night
game_mafia_complete_morning
game_mafia_end_discussion
game_mafia_timeout_day
game_mafia_submit_vote
game_mafia_timeout_vote
game_mafia_complete_vote_result
game_mafia_end_game
game_mafia_leave_game
game_common_interruption_exclude_player
game_common_interruption_expire
game_common_interruption_on_connection_changed
game_common_interruption_report_stale_player
game_common_interruption_wait_more
game_common_recovery_report
cleanupExpiredGameInterruptions
game_common_controller_presence_changed
```


사용자 지시로 FULL은 보류했다. 후속은 새 debug APK→Functions 반영/metadata 확인→A/B/태블릿 동일 APK hash 설치→
새 방 반복 시험이다. 정상 시작·첫 룰렛·종료/재시작, A 분배/턴/룰렛 중 단절·복구,
자기 실패/타인 대기 UI, 권한 거절 재발, 최초 pause 타이머 보존과 규칙상 첫 원판을 새 로그로 확인한다.
현재 USB는 마지막에 연결한 B이며 설치 전 역할을 맞춘다. 이번 구현은 운영 로그/RTDB를 추가 조회하지 않았다.

## 작업 트리

branch codex/e01-validation-wiring, HEAD e787a10de8723d66b08c84b173a07ddbf267b113.
착수 modified 16/untracked 8, staged 없음을 보존했다. ignored
build/network-session-investigation/lp-followup-implementation/baseline.json에 경로 hash가 있다.
기존 사용자 변경을 reset/stash/restore/delete/stage하지 않았다. commit/push는 하지 않았다.
현재 modified 29/untracked 11/staged 0. 착수 24경로 모두 존재하며 12경로 hash 동일, 12경로는 이번 범위의 소스·회귀·문서 보완이다. FULL/APK/배포/실기기 evidence는 진행에 따라 추가한다.

## 최종 관련 검사와 FULL 보류

- `.\tool\invoke_mosigame.ps1 test session --json`: PASS/exit 0, 5/5,
  Flutter 156/156·Functions 90/90, 83331ms. 2026-10-10 13:57:33 KST 시작,
  tracked/untracked snapshot 변화 없음. 마지막 명시 프로필 요청의 await 보완 전 실행이다.
- 마지막 await 보완 후 `flutter test --no-pub test/room_join_recovery_test.dart`:
  PASS/exit 0, 5/5. `flutter analyze --no-pub`: PASS/exit 0, no issues, 36.3초.
- 보완 전 분석의 `unawaited_return_in_try_block` 1건(FAIL/exit 1)을 await로 고쳤다.
  마지막 파일 format은 restricted 캐시 권한 오류(exit 1) 뒤 같은 명령을 정상 접근 환경에서
  재실행하여 0 changed/PASS/exit 0이다. 파일·환경 설정을 우회 수정하지 않았다.
- Skill의 최종 후보 승인 절차에 따라 사용자에게 FULL 1회 실행을 요청했다.
  후속 사용자 “검증 보류하고 내가 실기기로 테스트” 지시로 FULL을 보류했다. 새 APK 빌드는 PASS/exit 0이며 설치·Functions 배포·실기기 재검증은 미실행이다.

실기기 재시험은 A/B/태블릿 세 기기에 새 APK의 같은 hash를 설치하고 서버 반영을 확인한 뒤
새 방에서 시작한다. 테스트별 KST 시작/종료 시각과 역할을 기록한다. 정상 시작→첫 룰렛→종료→
재시작을 반복하고 A의 분배 직후/턴 중/룰렛 완료 전 단절을 각각 시험한다. 현재 route에만
자기 네트워크 안내가 나오고 A의 현재 접속 heartbeat·자기 ready accepted 뒤 게임이 재개되는지,
태블릿과 B의 타인 대기 및 A의 준비 실패/재시도 안내가 구분되는지 확인한다. 최초 서버 pause의
남은 시간이 유지되는지 확인하며 고정 25초 복구나 모든 첫 룰렛의 동일 확률을 기대하지 않는다.
로그는 시험 직후 각 기기에서 새로 추출하며 과거 로그를 이번 검증의 evidence로 쓰지 않는다.
## 실기기 우선 후보 APK

사용자 FULL 보류 지시에 따라 `flutter build apk --debug --no-pub`를 실행했다.
PASS/exit 0, assembleDebug 63.0초. Kotlin plugin의 향후 호환 안내가 있었지만 이번 빌드는 성공했다.
`npm --prefix functions run lint` PASS/exit 0이며 관련 서버 build/90회 회귀는 위 session 결과다.

[새 APK](../../build/device-test/lp-followup-implementation-20261010/mosigame-lp-recovery-20261010-debug.apk)
와 [산출물 기록](../../build/device-test/lp-followup-implementation-20261010/artifact.json)은 ignored 로컬 산출물이다.
앱 com.warmhandongne.msg, 버전 1.0.0+2, 274003026 bytes.
SHA-256: 6336BB536C4FD0AE0205A3F3AF746C7DACBF00BDC29EB80FD4430EE63FE08D91.
기존 테스트 APK와 hash가 다르므로 세 기기 모두 이 파일로 교체한다. AAPT metadata 확인 PASS/exit 0.
APK 준비 시점에 Functions는 미반영이었다. 공용 트랜잭션 영향을 받는 위 기존 63개를 대상으로
현재 배포 metadata 목록 확인 후 업데이트할 수 있도록 명시 승인을 요청했고, 후속 승인으로 반영했다. 목록·region/runtime이
예상과 다르면 범위를 임의로 확대하지 않는다. Auth/IAM/rules/DB migration/함수 삭제는 포함하지 않는다.
FULL 미실행과 직접 실기기 시험 미실행을 PASS로 바꾸지 않는다.
APK 준비 시점에 제품 파일/lockfile의 추가 변경 없이 문서와 ignored 산출물만 갱신했다. branch/HEAD 동일,
modified 29/untracked 11/staged 0이며 해당 시점 commit/push/production 접근·배포는 미실행이었다. 후속 배포는 아래 기록과 구분한다.
## 승인된 서버 반영·실기기 인계

사용자 “기존 Functions 63개 업데이트 배포 승인”을 받아 수행했다. FULL은 계속 보류했다.
Firebase CLI의 기존 배포 인증으로 프로젝트 project0000-ec01e를 명시했다. 조회 전용 gcloud
configuration·Firebase MCP·RTDB/게임 payload·Auth 사용자 데이터는 사용하지 않았다.

1. `firebase functions:list --project project0000-ec01e --json`: PASS/exit 0.
   운영 전체 79개 중 승인 대상 63개가 존재하고 ACTIVE, Node 22/gcfv2,
   서울 58·싱가포르 5였다. 이전 기록과 대상별 이름/region/runtime/platform 63/63 일치.
2. `firebase deploy --project project0000-ec01e --only <위 63개 각각의 functions:이름을 쉼표로 결합> --non-interactive`:
   PASS/exit 0. predeploy ESLint·TypeScript build PASS. 승인된 업데이트 성공 63/63,
   성공 누락·범위 밖 업데이트 0, 함수 생성·삭제 없음. dependency 변경 없음.
3. 같은 metadata 목록 사후 조회 PASS/exit 0, 2026-10-10 14:13:59 KST.
   63/63 ACTIVE와 region/runtime/platform 동일, 전체 79개 이름 유지.
   안전한 함수 hash 63개 존재하며 Oct9 저장 inventory와 63개 모두 다르다.
   Oct9 hash 비교를 현재 배포 직전 hash 비교로 표현하지 않는다.

정제 결과는 ignored build/network-session-investigation/lp-followup-implementation/ 아래
`deploy-inventory-before.json`, `deploy-safe.log`, `deploy-inventory-after.json`, `deploy-result.json`에 있다.
새 APK artifact.json에도 DEPLOYED_AND_VERIFIED와 시각을 기록했다.
[사용자 시험 체크리스트](../../build/device-test/lp-followup-implementation-20261010/TEST_CHECKLIST.md)를 준비했다.
앱 버전 표시는 기존 1.0.0+2와 같으므로 새 파일명/hash를 기준으로 A/B/태블릿을 모두 교체한다.

관련 자동 회귀·분석·APK 빌드·서버 배포는 PASS지만 FULL은 사용자 보류/미실행이며
현재 실기기 설치·UX·네트워크 재시험은 사용자 수행 대기다. 전체 태스크 완료나 실기기 PASS를
선언하지 않는다. branch/HEAD 동일, modified 29/untracked 11/staged 0 유지, commit/push 없음.