# 2026-10-11 네트워크 실기기 후속 구현 진행 기록

## 범위와 소스

사용자의 개발 진행 요청으로 테스트 9–20 조사 후 수정 계획을 시작했다.
branch `codex/e01-validation-wiring`, HEAD `c8b6a74`이며 fetch 후
`origin/develop`도 같은 commit이었다. 사용자가 보고한 디벨럽1 병합을 원격
develop에서 확인하지 못했으므로 임의 병합이나 checkout은 하지 않았다.
조사 evidence는 ignored `build/device-test/network-9-20-20261011/investigation.md`에 있다.

시작 전 기존 변경은 `docs/operations/NETWORK_SESSION_REAL_DEVICE_TEST.md` 하나였다.
그 파일을 수정하거나 stage하지 않았다.

## 적용한 미검증 후보

- `game_session_controller.dart`: 복구 요청 내부에서 신원 변경 알림이 발생해도
  새 게임 구독은 세션 시작 zone에 바인딩한다. 이전 bounded recovery 요청의
  만료 owner가 후속 구독 콜백에 전파되지 않게 하는 후보이다.
- 같은 파일: 재구독에서 화면 준비를 무효화하고, 같은 context가 다시 도착해도
  새 subscription generation에 맞는 준비 frame을 예약한다.
- `room_provider.dart`: controller/player 주기 heartbeat를 생성 시 세션 zone으로
  돌린다. controller 복구가 null이고 저장된 controller session도 없어진 경우
  같은 방에 한해 기존 종료 경로로 정리한다.
- `room_service.dart`: pending controller resume 결과 유실 시 현재 신원을 먼저
  조회한다. 이미 증가한 connectionSeq는 채택하고, 미적용 요청은 기존 operationId로
  재전송 후 재조회한다. 방 instance가 다르거나 종료된 방은 기존 오류 정리 경로를 사용한다.
- 준비 frame/구독 owner 회귀 2건, pending resume 미적용/종료 회귀 2건을 추가하고
  기존 current identity 채택 회귀의 조회 기대값을 수정했다.

새 public API, persistent shape, dependency, Firebase rules를 변경하지 않았다.
서버 타이머 상한, LP 시작 배경 화면, 남은 시나리오 검증은 아직 구현하지 않았다.
현재 코드를 설치/배포 가능한 완료 후보로 취급하지 않는다.

## 검증 및 중단 근거

명령: Windows guarded `.\tool\invoke_mosigame.ps1 test session`.

1. 첫 실행: Flutter 테스트 진행 후 기존 `same sequence in a new room membership
   invalidates an old ready acknowledgement`에서 진행이 멈췄다. 수동 중단 exit 1.
2. shared store load를 setUp에서 미리 수행하는 보정을 시도했으나 같은 위치에서
   재현됐다. 수동 중단 exit 1. 효과 없는 setUp 보정은 제거했다.
3. 임시 checkpoint로 첫 `RoomSessionIdentityStore.instance.save`가 반환하지 않는
   위치까지 확인했다. 수동 중단 exit 1. 임시 print는 제거했다.

각 실행을 PASS로 기록하지 않는다. 전체 suite와 Functions 단계의 완료 결과는 없다.
새 준비 회귀 2건과 controller service 회귀가 실행 중 통과했으나 전체 검증을 대체하지 않는다.
store의 직렬 Future queue와 widget FakeAsync zone 간 상호작용이 조사 대상이다.
이 지점의 실제 제품 장애 원인이나 새 수정의 회귀 여부는 아직 확정하지 않았다.

첫 format은 SDK telemetry 파일 접근 거부로 exit 1이었다(소스 format은 반영됨).
후속 `dart.exe --disable-analytics format` 관련 파일 실행은 exit 0이었다.
최종 파일 포맷 재확인 결과는 후속 명령 evidence로 확인한다.

Skill의 "Stop and report instead of guessing when the same failure repeats"에 따라
추가 제품 변경과 추측성 테스트 보정을 중단했다. 테스트를 삭제/skip하거나
기대값을 약화하지 않았다. FULL은 사용자의 기존 보류를 유지해 실행하지 않았다.
새 APK, 배포, production 조회, commit/stage/push는 수행하지 않았다.

다음 작업은 테스트 정지 원인을 재현 가능한 최소 사례로 확정하고 해당 검증부터
복구하는 것이다. 그 뒤 남은 구현 및 session/FULL/실기기 검증을 진행해야 한다.

## 후속: 신원 저장 대기 원인 확정 및 검증 복구

사용자가 중단 지점 조사를 재개하도록 요청했다. 신원 저장 구현을 바꾸지 않고
테스트 비동기 실행 영역의 문제를 확정했다.

- 이 파일에 앞서 추가한 두 위젯 테스트가 기존 신원 변경 테스트보다 먼저 실행된다.
  첫 테스트의 `startSession`이 `RoomSessionIdentityStore.instance`를 처음 생성하면서
  `_writes = Future.value()`가 그 테스트의 FakeAsync zone에 소속된다.
- Dart SDK `future_impl.dart`의 완료된 Future에 대한 `_addListener`는 그 Future의
  `_zone.scheduleMicrotask`로 후속 콜백을 예약한다. 따라서 다음 테스트의
  `save`가 `_writes.catchError(...).then(...)`을 연결해도 이전 테스트의 가상 시간
  영역에 작업이 예약된다. Flutter는 현재 테스트 영역만 flush하므로 작업이 실행되지 않는다.
- ignored `identity_queue_zone_probe.dart`로 재현했다. 두 번째 clock을 flush한 뒤
  `completed=false, firstPending=1, secondPending=0`, 첫 번째 clock까지 flush하면
  `completed=true`였다. Dart `run` exit 0. 초기 직접 script 호출은 CLI 전용
  `--disable-analytics`를 VM에 전달해 exit 1이었으며, 정식 `dart run`으로 바로잡았다.
- `setUpAll`에서 singleton/load를 초기화하는 것만으로는 해결되지 않았다.
  실제 zone에서 생성한 Future를 위젯 FakeAsync 안에서 그대로 await하면 실제 작업 완료 뒤
  다시 가상 영역을 flush할 계기가 필요하다. 그 검증 실행도 수동 중단 exit 1이다.
- 최종 보정: 공유 store 초기화는 `setUpAll`, 해당 위젯 테스트의 저장 2회와 삭제는
  `tester.runAsync`로 실행한다. Flutter binding의 pending async task 경로가 실제 작업 완료를
  기다린 뒤 현재 가상 영역을 flush한다. 신원 교체 후 입력 차단 기대값은 그대로 유지했다.

확인한 문제는 새 테스트 순서가 드러낸 기존 테스트의 공유 singleton/FakeAsync 의존성이다.
이를 실기기의 신원 저장 고착이나 Firebase 권한 거부 원인으로 확대하지 않는다.
이번 보정은 `game_readiness_contract_test.dart`의 테스트 실행 환경에만 적용했다.

최종 `.\tool\invoke_mosigame.ps1 test session`: PASS, exit 0, 5/5 단계.
Flutter 165/165, Functions 99/99, working-tree-mutation PASS이다.
포맷 확인: `dart.exe --disable-analytics format
packages/game_kit/test/recovery/providers/game_readiness_contract_test.dart`, exit 0,
0 changed. 위의 이전 중단 기록은 역사로 보존하며 현재 session 검증 실패는 해소됐다.

branch/HEAD는 `codex/e01-validation-wiring` / `c8b6a74` 그대로다. 기존 사용자 시험 문서와
이전 제품 후보 변경은 보존했다. 이번 추가 변경은 준비 테스트 보정과 작업 기록이다.
LP 시작 배경·타이머 등 미구현 범위는 여전히 남아 있으므로 전체 개발 완료 후보는 아니다.
FULL 기존 보류 유지, APK·배포·production 조회·stage/commit/push는 수행하지 않았다.

## 후속: develop 병합 확인 및 복구·타이머 후보 보완

사용자가 develop과 병합하면서 작업을 이어가도록 요청했다.
`git fetch origin develop` exit 0 후 HEAD와 `origin/develop`의 양방향 차이가 0/0,
파일 diff 없음이었다. `git merge origin/develop`은 Git metadata 권한 거부로 처음 실패했고,
승인된 권한으로 재실행해 Already up to date/exit 0이었다. 새 merge commit과 충돌은 없다.
branch `codex/e01-validation-wiring`, HEAD `c8b6a74`를 유지했다.
로컬 develop은 `151eff8`이며 최신 원격 develop을 기준으로 확인했다.
원격 develop에서 디벨럽1 두 커밋을 임의로 추가 병합하지 않았다.

추가 구현:

- player의 재시작 직후 heartbeat도 주기 timer와 같은 세션 zone에서 실행한다.
  기존 32초 실제 시간 회귀를 중첩 parent owner에서 복구하는 경우로 강화해, 원래
  복구 확인 heartbeat 외에는 만료된 owner를 상속하지 않음을 확인했다.
- provider의 null controller 복구는 token 제거가 확인된 경우에만 같은 방을 정리한다.
  token을 유지한 null 응답은 방 종료 증거로 취급하지 않는 양쪽 회귀를 추가했다.
- 서버 timer 기준 heartbeat가 현재 턴 시작 이전이면 deadline에서 역산한 턴 제한까지
  보존한다. LP playing 30초/lastCardChallenge 10초, Final Call 30초는 기존 서버 상수다.
  다른 게임의 긴 단계, 이미 지난 마감, 마감 없음, 추가 단절의 최초 timer 보존은 유지한다.
  네 제한 사례의 pause→다중 failure→전체 ready→resume과 기타 시간 회귀를 추가했다.
- LP 태블릿 waiting의 announcement를 명시적으로 비활성화했다. 현재 소스의 안내 문구는
  이미 비어 있었고 게임 배경은 계속 렌더링됐으므로, 실기기에서 본 별도 준비 화면의
  회귀 원인을 이 flag로 확정하지 않는다. 기존 정상 대기 UI 계약을 명시한 보완이다.
  로비 책의 에셋/선택 준비 badge는 게임 첫 상태 대기와 다른 경로이며 변경하지 않았다.

검증:

| 명령 | 결과 |
| --- | --- |
| `.\tool\invoke_mosigame.ps1 test session` | 5/5 PASS, exit 0; Flutter 167, Functions 104; working-tree-mutation PASS |
| Functions 폴더 `npm.cmd run lint` | PASS, exit 0 |
| `dart.exe flutter_tools.snapshot analyze --no-pub` 수정 Dart 파일 7개 | 첫 실행 테스트 중괄호 info 2개, exit 1; 보정 후 No issues found, exit 0 |
| `dart.exe --disable-analytics format` 관련 Dart 파일 | PASS, exit 0; 최종 보정 2개 파일 0 changed |

분석 대상은 room_provider, room_service, game_session_controller,
game_readiness_contract_test, LP tablet_board, controller_room_recovery_test,
room_recovery_heartbeat_test다. 중괄호 보정은 테스트 동작/기대값을 바꾸지 않았다.
검증 후 기술 계약·TASKS·상세·일지 기록만 갱신했다. 원래 사용자 시험 기록의
120 additions/18 deletions를 보존했고 stage/commit/push는 하지 않았다.

남은 실제 확인:

1. 새 APK에서 태블릿 잠금/foreground와 시작 중 단절 후 모든 기기 ready가 완료되는지.
2. 응답 유실/접속 교체 뒤 heartbeat가 서버 현재 접속을 쓰며 같은 권한 거부가 재발하지 않는지.
3. LP 시작에서 게임 배경 대기를 유지하는지. 테스트 APK commit과 현재 소스 일치는 아직 입증되지 않았다.
4. 서버 반영 후 복구 시간이 LP 30/10초 또는 Final Call 30초를 넘지 않는지.
5. 0초 고착은 기존 로그 구간이 없어 원인 미확인이다. 정상 만료와 clock 보정/서버 deadline
   오류를 구분할 새 재현 evidence가 필요하다. 임의로 30초로 초기화하지 않았다.
6. 방 종료 직후 재생성과 옛 cleanup 도착은 실제 병합된 소스/APK에서 재시험해야 한다.

공용 서버 복구 파일 변경은 관련 Functions 반영이 있어야 운영 동작에 적용된다.
이번 턴에 배포 승인을 요청하거나 실행하지 않았으며 배포 대상 산정도 완료하지 않았다.
FULL은 기존 사용자 보류를 유지했다. APK/실기기는 사용자 담당 대기이며 전체 완료로
판정하지 않는다. 운영 데이터 조회·쓰기·migration도 수행하지 않았다.

## 2026-10-11 — 디벨럽1 통합본 자동 테스트

- 대상 branch `codex/e01-validation-wiring`, HEAD `b84ca12`.
  부모 `9a26728`의 네트워크 수정과 `0c5cc01`의 디벨럽1 변경을 포함한다.
- 실행 전후 staged/unstaged/untracked 상태는 모두 비어 있었다. 아래 결과를
  기록하기 위해 이 문서와 월별 일지만 이후 수정했다. 제품 코드 수정은 없다.

| 명령 | status / exit code / 확인 범위 |
| --- | --- |
| `.\tool\invoke_mosigame.ps1 test session` | PASS / 0 / 5단계 모두 PASS; Flutter 172, Functions 107; working-tree-mutation PASS |
| `flutter test --no-pub test/room_action_fast_path_test.dart test/room_action_timing_test.dart test/table_background_transition_test.dart` | PASS / 0 / Flutter 23; 생성·종료·퇴장 미확정 ID 재사용, 실패한 초기 presence 재시도, 계측 Zone, 착석 준비와 배경 전환 |

Final Call 전용 동작·애니메이션 테스트는 사용자 요청으로 보류했다. session suite의
공통 서버 계약 테스트에 포함된 Final Call 케이스는 suite를 변경하지 않고 실행했다.
실기기 단절·잠금·시작 응답 유실 및 옛 cleanup 도착을 검증한 결과는 아니다.
`validate --full`은 기존 보류 상태로 미실행이다. develop 병합·push·배포는 하지 않았다.
