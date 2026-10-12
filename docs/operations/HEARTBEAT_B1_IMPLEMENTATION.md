# B1-C 구현·검증 결과

2026-10-13 KST · 로컬 후보 · 운영 접근/배포/commit/push 없음

**구현 후보는 완성됐고, 최종 FULL 검증 승인을 기다린다.** FULL 미실행 상태에서는 완료로 판정하지 않는다.
로비 heartbeat는 유지한다. 10초 송신과 정상 peer가 관찰하는 조건부 age > 20초 판정도 유지한다.

## 변경 내용

`R=rooms/{code}`, `C=R/connections/{uid}/{connectionId}`.

| 작업 | 구현과 목적 |
| --- | --- |
| W1 | current-presence.ts에서 instance/role/member/current id·seq를 같은 snapshot에서 검증. ghost와 room deadline 모두 fresh current leaf를 사용해 P1 두 경합 보호 |
| W2 | 태블릿 playing N개 peer, 폰 controller 한 개+본인 leaf. room/member/id/seq scope 변경 때 unknown·cancel·old callback fencing. peer 오류는 한 번만 재구독. current leaf 최소 Rules read |
| W3 | 정상 heartbeat는 C/lastSeen server timestamp만 set. 서버 create/allocate CAS가 true와 요약 seed. false 후 client true/HB는 Rules로 거절. background false+timestamp/onDisconnect false-only 유지 |
| W4 | syncRealtimeRoomConnection의 ref를 C/connected로 축소하고 false만 root CAS 처리(retry). stale 신고에 관측 target id/seq/time 포함. frozen controller summary 시각과의 동시 일치 요구 제거 |
| W5 | 모든 room root runPrimedTransaction에 cleanupSignal 갱신 통합. 남은 직접 root transaction 2곳도 같은 helper 사용. syncRoomCleanupQueue는 R/cleanupSignal만 읽고 작은 큐 CAS. 신호 세대/revision과 due worker의 job CAS 보호 |
| W6 | 신규 create/capability 2, B1 방 변경 guard. transport flag를 game/ready domain fingerprint에서 제외. 구 APK의 client true 복원·old target 쓰기 차단 |
| W7 | 신규 B1/P1 tests와 session manifest/exact order 등록. 별도 E13 branch의 harness 파일만 선별 재사용. 실제 Rules·Functions·JS SDK·CAS·4게임·복구·정리 검증 |

신호 계획에는 room instance/generation/status, controller tuple·connected, cleanupAt/retainUntil/
cleanupPending/terminalAt이 들어간다. 정상 시각 변경·카드·ready·profile은 revision을 바꾸지 않는다.
큐는 advisory index다. due root CAS에서 최신 canonical 시각과 명시 기한을 다시 확인하고
더 새 job/revision/backoff를 이전 작업으로 덮어쓰지 않는다. 기존 scan100/due300/ghost500,
5분 주기·부분 실패 처리·terminal request/slot/mapping reconciliation과 tombstone을 보존했다.
cursor는 놓친 false projection만 추가 root CAS로 보완한다. 정상 true HB는 이 CAS를 시작하지 않는다.

백그라운드로 의도적으로 false를 보낸 동안 본인 관찰자가 자동 CAS 복구하지 않도록 막았다.
foreground 본인 false는 단일 회차 복구를 시작한다. ready의 accepted/current public·own private·
frame/assets/필수 전체 barrier 및 게임 규칙은 변경하지 않았다.

## 변경 파일

- 서버: `functions/src/room/{current-presence,cleanup-signal,room-transaction,room-cleanup,ghost-player-policy,session-contract,session-functions,create-room,realtime-room-functions,realtime-room-lifecycle}.ts`
- 중단: `functions/src/game-interruption/{functions,recovery-state,controller-presence,expire-scheduler,game-command-transaction,leave-request}.ts`
- Rules: `database.rules.json`
- 앱: `lib/platform/home/room/{models/room_player,services/room_service,services/controller_presence,services/player_presence,providers/room_provider}.dart`, `packages/game_kit/lib/recovery/models/room_session_identity.dart`
- 회귀: 새 `functions/test/b1-current-presence.test.mjs`, `test/b1_presence_observation_test.dart`; 기존 retention/allocation·heartbeat/join·6개 fake service signature 테스트와 session manifest/exact-order
- 통합: `firebase.e13.json`, `tool/emulator/{run.mjs,backend.test.mjs,client.cjs,functions.cjs,README.md}`
- 문서: 이 보고서, Engineering 네트워크/Functions 계약, HEARTBEAT-B1-01 상세·TASKS·10월 기록

게임별 Dart/TS reducer와 기존 auth/account-room-cleanup 변경을 다시 쓰지 않았다.
baseline20개 중 B1과 겹치지 않은11개는 SHA-256 동일, 겹친9개는 기존 작업 위에 통합했다.
`build/b1-implementation/preservation.json`에 비교를 남겼다.
baseline의 tracked15/untracked5 파일을 `build/b1-implementation/baseline/`과 binary diff에 보존했다.
겹친 create/cleanup/retention 문서·테스트에 B1을 추가했고 미배포 사용자 작업을 삭제하지 않았다.
branch `codex/e01-validation-wiring`, HEAD `9fb446262f3f0ce34c06c7030d2304dbf52490c4`, staged 0을 유지한다.

## 검증과 증빙

| 명령·검증 | 결과 |
| --- | --- |
| npm --prefix functions run build / lint | PASS, 각각 exit0 |
| node --test functions/test/*.test.mjs | 최종 전체468건 PASS/exit0. 새 B1 파일14건 포함 |
| .\tool\invoke_mosigame.ps1 test session --json | PASS/exit0, Functions155건과 Flutter29경로(새 foreground/background·관찰자 회귀 포함). working-tree mutation PASS |
| .\tool\invoke_mosigame.ps1 test auth --json | PASS/exit0, 5단계와 working-tree mutation PASS |
| node tool/emulator/run.mjs | 최종13 시나리오 PASS/exit0, server timestamp marker 포함. 포트 해제/source hash·Git state 비교 PASS |
| .\tool\invoke_mosigame.ps1 validate --full | 미실행, skill에 따라 최종 후보 사용자 승인 필요 |

실행 환경은 Windows/Flutter3.47.5/Dart3.13.4/Node22.23.2/Java21이다. SDK 설치/업그레이드와 dependency 추가는 없다.
guard 실행에는 기존 SDK cache/log 접근 권한을 사용했고 SDK 파일/ACL을 변경하지 않았다.

통합 검증은 고정 demo project와 loopback Auth/RTDB/Firestore/Functions만 사용한다.
실행 중 Rules가 candidate와 같은지 검증하며 클라이언트 Admin mode는 꺼져 있다.
steady HB에서는 dispatch가 활성화돼 있고, 실제 false/close 호출을 positive control로 확인한다.
counter는 실제 emulator export를 감싼 handler에 붙인다. 첫 getter-only re-export 계측 실패를
고친 뒤 positive control까지 통과했다. 초기에 보인 함수 수79는 재사용 harness의 옛 기대값이며,
현재 소스는80(70callable/5RTDB/4schedule/1HTTP)이다. export 추가가 아니다.

검증한 경계: old tuple·onDisconnect·membership 교체, current-only fresh P1 보호,
실제 conditional root put을 보류한 동안 peer heartbeat를 써 server hash mismatch와 callback
재실행 강제, latest leaf 보존, 놓친 false의 cursor repair, 구 target/타인/부모/private/server
read/write 거절, false 이후 HB 거절, strict20s/last-normal/none/0/턴 상한, 네 게임 barrier,
재접속, 제외 동시 HB, terminal/cursor/backoff/legacy replay 유지다.
Scheduler handler는 emulator 데이터에 명시 호출했으며 Cloud Scheduler 전달을 검증한 것은 아니다.

## 비용: 측정과 추정

확정한 구조 효과는 정상 HB가 sync/queue/root transaction을 새로 시작하지 않는다는 점이다.
작은 방과 64KiB 합성 이력이 있는 방 각각40회, 합계80회 HB에 sync0/queue0·signal 변화0을 확인했다.
실제 false와 close는 필요한 handler와 queue를 실행했다.

최종 계측은 `build/e13/b1-measurement.json`이다. 앱과 같은 server timestamp marker로 쓰고
root JSON3,064B/68,635B에서 한 폰 SDK 수신3,674B/3,680B를 측정했다. 작은 방의 이 폰 송신은
3,034B다. 각 라운드는 tablet20회+phone20회 쓰기이며 기기2대만 계측했다. 이것은
**한 폰+controller lastSeen leaf 하나**의 JS SDK 프로토콜 counter다. 전체 방 전송량·TLS·
billable download·FlutterFire와 같지 않다.
기존 구현과 같은 wire 조건의 before/after 측정도 아니므로 총 다운로드 감소율을 실측이라고 표현하지 않는다.

참가자100명/일×3h×30일, 4명방+tablet1 기준 정상 HB405만회/월이다.
이전 약 sync1+queue2/HB 구조에서 **HB 성분 약1,215만 함수 요청/월 제거**가 추정된다.
client timestamp 쓰기405만회는 남는다. 쓰기 횟수당 RTDB 요금을 계산하지 않는다.
사전 보고서 다운로드 가정8~64KiB/HB→0.5~2KiB/HB는 월약33~265GB→2~8GB의 민감도이며
이번 계측으로 확정하지 않는다. 게임·입퇴장·재접속·scan·원래 root CAS 다운로드는 별도다.
본인/peer 구독·timestamp 확인 비용도 남고 root transaction이 HB와 재경합할 수 있다.

현재 시각을 overwrite하므로 HB 횟수만큼 저장량이 늘지 않는다. 추가 signal/marker는 소형이다.
기존 connection/operation 이력 GC는 범위 밖이다. Functions 실행 자원/요청·로그 비용은 별도이고
RTDB/Functions 전체 무과금이나 서비스 최대 인원을 보장하지 않는다.

## 남은 위험과 후속

1. FULL 미실행은 완료 차단이다. 기존 실기기 미완료 게임/준비 문제가 이번 테스트만으로 해결됐다고 보지 않는다.
2. 실제 native Wi-Fi/전원 종료/background/.info=true 읽기 실패, 예약 실패·재등록과 latency는 tablet1+phone2 후속 검증이다. peer 부재에서20초 독립 server watchdog을 추가하지 않았다.
3. 운영 Functions/Rules와 로컬의 revision 일치는 미확인이고 배포하지 않았다. retarget 가능한 ref 변경인지 CLI/배포 도구에서 별도 확인한다. 필요하면 새 narrow export2개+구 broad export 제거의 후보를 별도 승인한다.
4. 기존 활성 legacy 방은 drain해야 한다. 신규 create는 capability2를 요구한다. 서버 공통 helper/전체 lifecycle writer/Rules/신규 앱을 같이 적용하며 두 트리거만 단독 배포하지 않는다. 전체 영향을 받는 game/ready/session/account-close/cleanup export의 배포 목록을 최종 compiled diff로 확정한다.
5. 롤백은 신규 입장을 먼저 중지하고 B1 방을 drain한다. canonical/P1 보호·capability fingerprint·B1 Rules를 유지한다. frozen 요약의 방에 옛 deadline helper나 옛 APK를 즉시 복원하지 않는다. 넓은 trigger 복원은 비용 증가를 동반하며 별도 승인한다.
6. 실제 과금은 동일 인원/시간/게임/초기 이력으로 운영 또는 격리 cloud에서 sent bytes, service request count, CPU/memory duration, storage/log 지표를 비교한다. Monitoring read와 제한 Logging read/Functions 설정 read, 금액은 SKU CSV면 된다. metadata·aggregate만 조회하고 raw RTDB/private payload는 불필요하다. 이번에는 실행하지 않았다.

**쉽게 말하면:** 각 기기는 생존 시각 하나만 보낸다. 정상 Ping마다 방 전체를 읽고 정리 큐를
돌리던 연결을 끊었다. 실제 장애·복구·게임·정리에서만 서버의 기존 CAS·timer·ready 판정을 사용한다.
