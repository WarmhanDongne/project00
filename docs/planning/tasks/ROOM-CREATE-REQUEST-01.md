# ROOM-CREATE-REQUEST-01

방 생성 요청 기록 잔류

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

- **등록일·상태:** 2026-08-31 사용자 전달 사항. 미해결·수정 방향 검토 대기.
  기존 항목의 통과·차단 해제와 별도로 관리하며, 앞선 FULL PASS나 배포·실기기 결과로
  이 항목까지 해결됐다고 판단하지 않는다.
- **목적:** 방은 생성됐지만 앱이 응답을 받지 못해 재시도할 때, 요청 기록으로 중복 방
  생성을 막는다. 중복 방지 자체는 필요한 동작이다.
- **현재 문제:** 방과 요청 기록을 따로 삭제하므로 중간에 실패하면 요청 기록만 남을
  수 있다는 사용자 보고다.
- **사용자 보고와 코드 확인의 차이:** 방 없이 남은 요청 기록을 재정리하는 처리가 없다는
  최초 보고와 달리 `functions/src/room/realtime-room-lifecycle.ts`에는
  `cleanupDeletedRoomCreationRequest`가 있다. `/rooms/{roomCode}` 삭제 시 방 데이터의
  reservation 경로를 제거하며 `retry: true`다. 이번 통합 시 코드 존재도 재확인했다.
  삭제 트리거 존재만으로 이미 남은 요청·부분 실패·운영 잔류 전체 해결을 판정하지 않는다.
- **검토할 점:** 방 생성·재시도 정책을 기준으로 별도 요청 기록을 유지하는 방식이
  꼭 필요한지 재검토한다. 유지한다면 부분 실패 뒤 정리·재처리 방안도 함께 검토한다.
  요청 기록 삭제나 대체 방식은 아직 결정하지 않았다.
- **확인 범위·다음 작업:** 코드의 삭제 트리거 존재와 최초 보고의 차이를 확인했다.
  부분 실패 후 재시도, 트리거 이전의 기존 잔류 요청, 방 데이터에 reservation 정보가
  없는 경우를 구분해 재현·검증한다. 운영 데이터 규모 조회·배포 여부·운영 정리 효과는
  미확인이다. 중복 생성 방지와 요청 기록 유지 정책을 보존하고 처리 방안을 정한다.

기존 `ROOM-CLEANUP-01`의 종료·유령 방 정리 문제와 구분한다. 해당 항목의 해결 기록과
통과 판정은 유지한다.

- 완료 조건: 중복 방 생성 방지와 잔류 기록 처리 방안을 확정하고 부분 실패·재시도·정리
  경로를 검증한다. 이전 ROOM-CLEANUP-01 통과를 이 문제의 해결 근거로 사용하지 않는다.

## 2026-10-08 newgui 999c3e9 기준 추가 조사

- 조사 기준: `origin/newgui`의 `999c3e99086b9f917ea941cd8f283b8ac40f3f85`를
  checkout 변경 없이 비교했다. 정적 확인만 수행했고 운영 데이터 조회·정리·배포나
  새 테스트·실기기 재현은 하지 않았다.
- UI 개편 뒤에도 [생성 요청 예약과 방 생성](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/room/realtime-room-functions.ts#L161),
  [방 삭제 후 예약 정리 트리거](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/room/realtime-room-lifecycle.ts#L610)는
  남아 있다. 트리거 존재와 실제 운영 잔류 해결 여부를 계속 구분한다.
- 확인할 실패 구간은 방 생성 전 예약만 저장된 경우, 방 생성 후 응답 유실·재시도,
  방 삭제와 매핑·예약 정리 사이의 부분 실패, 기존 고아 예약, reservation 정보가
  없는 방, 삭제 트리거 실패다. 중복 방 생성 방지와 기존 요청 기록 유지 정책을 보존한다.
- [방 정리 스케줄](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/room/realtime-room-lifecycle.ts#L647)의
  후보 제한·처리량은 [COST-01](COST-01.md), 방·controller 매핑·예약 정합성은
  [CORE-REVIEW-01](CORE-REVIEW-01.md)과 연결한다. 완료된 ROOM-CLEANUP-01의 당시
  범위를 이 신규 실패 구간이나 처리량 검증으로 확대하지 않는다.
- 요청 기록 삭제·대체 방식, persistent data 변경과 운영 조회·정리·배포는 기존
  승인 경계를 유지한다. 이 조사만으로 처리 정책이나 운영 해결을 확정하지 않는다.

## 2026-10-12 정리 1~4단계 후보

사용자 승인으로 운영 로그 관찰, 유령 참가자 전체 페이지 순회, 계정 탈퇴 객체 매핑 정리,
확정 종료 생성 요청 축약을 구현했다. 최소 종료 표시와 할당 세대는 보존한다.
고아 예약 자동 해제와 접속·작업 결과 TTL은 사용자가 보류했다. 이번 범위는 과거
고아 요청 전체 해결·운영 정리 완료를 뜻하지 않는다.

운영 표본의 방 정리 요약 50회에서 completed7/failed0을 확인했고, 유령 참가자 함수의
HTTP200은 제거 건수 증거와 구분했다. 신규 회귀는 500방 초과 순회, 재접속/게임 시작 경합,
옛 cleanup과 새 세대, 종료 요청 재생, 부분 실패·backoff 보존, 탈퇴 매핑 교체를 다룬다.
상세 범위·명령·개별 결과·배포 대상은 [RTDB 정리 기록](../../operations/RTDB_RETENTION_REVIEW.md)에 있다.

Functions 관련 57개·build/lint PASS(exit0), session Flutter212/Functions123,
auth Flutter52/Functions25 테스트 단계 PASS(exit0). 두 CLI 전체 결과는 동시에 진행된
다른 문서 작업으로 mutation FAIL(exit1)이다.

사용자의 `풀 실행해` 승인 후 `tool/invoke_mosigame.ps1 validate --full --json`을 실행했다.
2026-10-12 04:41 KST 결과는 FAIL(exit1): preflight PASS, dart-format FAIL,
working-tree-mutation PASS다. 기존 미수정 파일 `lib/platform/home/tablet/screens/tablet_home.dart`와
`test/lobby_music_test.dart`의 포맷 차이로 중단돼 이후 분석·테스트는 실행되지 않았다.
포맷 검사는 output=none이며 실제 파일 수정은 없다. 배포·운영 삭제·migration·commit/push는 하지 않았다.

사용자의 실패 원인 제거·재실행 요청으로 위 두 파일의 줄바꿈만 수정했다. 재검사173파일
PASS(exit0) 후 04:46 KST FULL은 Flutter 테스트448 PASS/1 FAIL로 중단됐다. 최근 커밋
4bbd31e/9fb4462의 session manifest 추가4개(Flutter3/Functions1)가 목록 검증 기대값에
누락된 원인이며, `test/mosigame_cli/test_suites_test.dart`의 exact-order 기대값만 보완했다.
해당 `flutter test --no-pub test/mosigame_cli/test_suites_test.dart` 20개 PASS(exit0).

04:50~04:56 KST 최종 guarded `validate --full --json`은 12단계 모두 PASS(exit0, 342530ms).
루트 Flutter449, game_kit117, LP15, Final Call16, Mafia58, Holdem32, Functions454개
PASS이며 Functions skip0이다. 정적 분석·lint·mutation도 PASS다. 배포·운영 관찰은 남았고
고아 예약 해제·이력 GC 보류는 유지한다. 기존 변경을 보존했고 branch/HEAD는
codex/e01-validation-wiring/9fb4462, staged 없음이다. 결과 기록은 검증 종료 후 추가했다.

## 2026-10-12 — 배포 전 안정성 후속 검토

LP 실기기 검증 채팅의 정리 후보에 대한 사용자 요청 검토에서 유령 참가자 정리의
leaf-only 재접속 경합을 재현했다. 현재 connection이 연결됐어도 요약 갱신이 늦으면
참가 신원이 제거된다. 기존 정책에도 있었으나 전체 페이지 순회로 적용 대상이 확대된다.
또한 최근 controller heartbeat의 요약 반영이 늦으면 대기 방 전체가 종료되는 기존 경합도 재현했다.
FULL PASS는 이 누락 경합들의 안전성 근거가 아니다. 정리 후보 배포 전에 현재 connection
신원/heartbeat 보호를 참가자·controller 양쪽에 보완하고 회귀를 추가해야 한다. 코드 수정·배포는 이번 검토에서 하지 않았다.

계정 삭제의 소유 방/세대 보호와 terminal 요청 축약에서는 새 차단 결함을 재현하지 않았다.
최소 종료 표시·세대와 미확정 기록 보존, 고아 예약 해제·이력 GC 보류를 유지한다.
[검토 근거·보완 설계](../ROOM_ACTION_LATENCY_PLAN_20261012.md#7-2026-10-12-functions-안정성-검토와-계획-수정)와
[실행 기록](../logs/2026-10.md#room-action-function-review-20261012)을 따른다.
