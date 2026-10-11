# 2026-10-11 네트워크 실기기 후속 구현 진행 기록

## 2026-10-12 00:37 Final Call·00:40 LP 후속 조사 및 구현

사용자가 A/B/T 로그 우선 수집, 서버 로그 시간·건수 제한 없는 조회, 원인 조사와
계획·구현을 승인했다. LP 보고 시각은 00:40 KST이며 조회용 두 역할 유지도 확인했다.
기기 변경마다 연결 확인을 받고 A(SM-A356E), B(SM-A325N), T(SM-P610) 순으로 읽었다.
세 기기 모두 debug이며 설치 APK SHA256은
`69561913E206C89392805AAA06A786B965B3FE80574323DD2D89891D71C9BEC8`이다.
원시 로그는 저장하지 않고 정제한 메타데이터만 ignored build 아래에 보관했다.

### 근거와 원인

- 00:25~00:55 KST의 관련 함수10개를 조회했다. Final Call 시작4건은 HTTP200이며
  complete_dealing 요청은0건이다. LP 시작2건/분배 완료1건, recovery_report20건,
  접속 sync570건도 HTTP200이다. 관련 함수 ERROR 로그는0건이다. HTTP200은 ready의
  accepted 판정을 대신하지 않는다. B/T의 ready_report_returned accepted를 기기에서 확인했다.
- Final Call 분배 연출 완료는 interruption이 있으면 false만 반환하며, 진행 명령의
  네 차례 재시도 뒤 전체 ready 해제를 다시 관찰하지 않았다. 최초 준비 pause에서도
  완료 요청이 전송되지 않는 경로가 있어 서버 오류 없이 dealing에 남을 수 있다.
- A는 00:39:35와00:42:23의 첫 공개 상태 수신 직후 준비 timeout/ready=false를 기록했다.
  방 단위 GameRecoverySession은 화면보다 오래 유지되는데 새 controller 생성 시 이전
  preparationBatch를 재사용했다. 같은 게임 재진입/첫 private·screen 콜백이 보존된 공개
  상태를 먼저 보면 이미 소진된 예산으로 즉시 실패할 수 있다. 회귀 테스트로 재현했다.
  이전 접속의 쓰기 권한 거부도 수집됐지만 이것만으로 이번 timeout의 서버 원인으로
  확정하지 않았다. 앱 재시작·새 방 이후00:44의 정상 LP 시작/분배 완료도 기록돼 있다.
- 초기 방향은 Firebase 초기화 전 화면 크기로 isTablet을 저장하고 나중에 적용했다.
  초기 크기가 아직0이면 phone으로 분류하고, 게임 진입에서 가로 잠금이 재적용된다.
  코드 경로는 확인했으나 실패 당시 최초 metrics 수치는 로그에 없어 실기기 재확인이 필요하다.

### 계획과 반영

1. 초기 방향: resumed와 유효한 view 크기를 함께 확인한 시점에 판별한다. 첫 프레임과
   metrics 변경에서도 재확인하며, 방향 적용 전의 임시0 크기를 캐시하지 않는다.
2. 준비 예산: 새 controller는 새 화면 예산을 사용하되 진행 중인 방 복구의 기존30초
   예산을 공유한다. 같은 화면의 sticky failure·ready·입력 잠금은 유지한다.
3. Final Call: 연출 완료를 시작 시각/라운드로 기억하고 canSend가 열린 뒤 완료 명령을
   보낸다. 준비 대기는 전송 재시도 예산을 소모하지 않고 새 판/라운드·dispose는 옛 완료를
   무효화한다. 회귀2개를 기존 session suite에도 등록했다.

이번 추가 수정은 클라이언트만 바꾸며 새 Functions 배포 대상은 없다. 기존 사용자 변경,
운영 시험 문서 체크와 서버 변경은 보존한다. 홀덤 전용 조사/16번/FULL 보류는 유지하고
이번 요청으로 Final Call 조사·수정·관련 자동 검증은 재개했다.

### 검증 및 실기기 확인

- 준비 회귀23개 PASS/exit0, Final Call 완료 대기·옛 라운드 배제2개 PASS/exit0.
- 최초 분석에서 새 테스트의 unused import1건을 확인해 제거했다. 변경5파일의
  `flutter analyze --no-pub`는 문제0/PASS/exit0이다. 최종 guarded
  `test session`은 Flutter199/Functions123와 working-tree-mutation 모두 PASS/exit0이다.
  `git diff --check`도 exit0이다. 기존 변경은 보존했고 예상 밖 mutation은 없다.
  FULL은 아직 실행하지 않았고 최종 후보에 대한 승인 여부를 요청했다.
- `flutter build apk --debug` PASS/exit0, 결과는
  `build/app/outputs/flutter-apk/app-debug.apk`, SHA256
  `1BFA8D63CA3A59FD47BC2C0A3F6426C90BFC4A07593F6B7872081ED34E2F3E3D`이다.
  기기에는 설치하지 않았다. branch `codex/e01-validation-wiring`, HEAD `3247b20` 유지,
  staged0·수정23·untracked2이며 시작 전 수정19·untracked1을 보존했다. commit/push 없음.
- 새 APK로 갤럭시 탭 cold start부터 가로인지 확인하고, 같은 방에서 FC→LP→FC를 반복한다.
  설정 완료 뒤 모든 준비가 끝나면 FC 첫 턴이 열리고 LP 준비 실패가 발생하지 않아야 한다.
  FC 분배 중 단절→복구는 같은 판을 유지하고 준비 전 입력 금지·준비 후 완료 전송을 확인한다.
  이전 라운드/게임의 늦은 연출 완료가 새 판을 진행시키지 않아야 한다.

## 2026-10-12 정리 기준 요약

현재 상태·다음 행동의 원본은 [작업 목록](../TASKS.md)의 SESSION-RECONNECT-02다.
아래 조사·미검증·미배포 설명은 각 기록 시점의 이력이며 최신 판정과 구분한다.

- 유효한 수정: controller/player 역할 분리·저장 방 복구 우선·동일 계정 세션 조회 구분,
  정상 최초 준비의 recovery.purpose 표시 분리. 서버 대상14개는 10/11 배포 성공했다.
- 최신 사용자 관찰: `11:57` 동일 계정 A/T에서 A만 탈퇴 성공, `11:59` LP 준비 안내 없이
  정상 시작 성공. 사용자가 실기기 문서37번의 추방·마지막 참가자·저장 방 복구 세 체크를
  완료로 갱신했다. 이어36번 LP 체크도 완료로 갱신했다. [실기기37 기록](../../operations/NETWORK_SESSION_REAL_DEVICE_TEST.md#37-동일-계정-휴대폰-추방-후-태블릿-방-유지복구)을 사용자 확인 근거로 보존한다.
  LP 정상 시작 성공은 채팅/문서 보고를 근거로 하며 다른 게임36의 통과로 확대하지 않는다.
- 앞선 `23:44~23:48` 실패 재조사는 실제 태블릿에 이전 release APK가 설치된 사실을
  확인한 뒤 사용자 요청으로 중단했다. 보고한 debug hash를 설치 hash로 취급하지 않는다.
  그 재시험은 최신 debug 수정의 실패 증거로 사용하지 않는다.
- 이번 정리: debug 종료 계측은 실제 clearRoom에서 사유/역할/접속을 한 번 기록한다.
  기능·재시도·DB 계약은 변경하지 않는다. 이번 클라이언트 계측 정리는 서버 배포 대상이 없다.
- 남은 범위: 다른 게임36, 기존 응답 유실·옛 cleanup 등의 서버 진단은 37번 체크 통과로
  대체하지 않는다. FULL/Final Call 전용/16번 보류 및 홀덤 단일 기기 조사 제외 유지.
- 정리 검증: guarded session2회 모두 Flutter196/Functions123 통과, RoomProvider 분석 문제0/exit0.
  두 실행 중 사용자 시험 문서가 각각00:06:15/00:08:38에 저장되어 mutation 검사는 FAIL,
  전체 exit1이었다. 두 번째 문서 갱신에서36번 LP 체크도 완료됨을 확인했다. 변경을 보존하고
  반복 실행은 중단했다. 문서 편집 종료 후 mutation 재확인 필요. FULL은 실행하지 않았다.

## 2026-10-11 최초 착수 범위와 소스

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

## 2026-10-11 — 사용자 실기기 10·27·28·29번 기록 검토

16번은 이번 검토에서 제외한다. 원본 조작·체크·실행 기록은
[실기기 문서](../../operations/NETWORK_SESSION_REAL_DEVICE_TEST.md)에 그대로 보존한다.
이번 판정은 사용자 기록을 읽은 결과이며 새 기기/서버 로그 조회나 제품 수정은 없다.
검토 당시 branch는 `codex/e01-validation-wiring`, HEAD는 `5e94b7f`다.
10·27·29번에 기록된 APK SHA-256은
`8F044BA6C31918D5C6CDC99670B94979C7AD5086808B4BFDD2813B398204C088`이다.
28번 자체에는 hash가 없고, 해당 APK와 소스 commit·배포 서버의 일치도 이번에 확인하지 않았다.
시각의 오전/오후는 최신 기록에 명시되지 않았으므로 아래에서는 원문 시각만 사용한다.

### 확인된 개선과 현재 문제

| 항목 | 사용자 기록으로 확인한 사실 | 판정 |
| --- | --- | --- |
| 10번, 5:28~5:33, C8594 | 태블릿 잠금 후 복구 2회와 다른 앱 전환 후 복구 성공. 혼자 복구 화면을 띄웠지만 진행으로 돌아옴 | 이번 관찰에서 과거 보호 화면 고착은 재현되지 않음. 완전 해결/다른 조건 통과로 확대하지 않음 |
| 27번 정상 시작, 5:36~ | 짧게라도 `게임 준비 중` 화면이 보임 | 정상 준비에서 배경·연출을 유지한다는 UI 요구와 불일치하는 현재 문제. 표시 route/준비 분기를 조사해야 함 |
| 27번 착석 중 단절 | 준비 안내와 휴대폰 snackbar 후 게임 진행 | 복구 후 진행은 성공 보고. 정상 준비 안내와 실제 단절 안내를 구분해서 UI 문제를 재확인해야 함 |
| 27번 착석 중 참가자 이탈 | 첫 시도는 카드 배분 직전까지 시작, 배분 시 B·태블릿 이탈, A는 이탈 실패. 두 번째 시도는 자리 배치 설정 완료 화면으로 복귀 | 결과가 일관되지 않는 미해결 문제. 체크가 있어도 이탈 전체 통과로 판정하지 않음. 두 번째 시도의 정상 복귀가 첫 실패를 해소하지 않음 |
| 28번 | 즉시 새 방에서 LP 시작·카드 제출은 양호. 5:49~5:52 A·B·태블릿 로그에 태블릿 통신 이상이 있을 것으로 사용자가 보고 | 기본 새 방 사용은 성공 보고. 통신 이상은 조사 대상이며 오류 종류·원인·옛 요청 연관성은 미확인 |
| 29번, 5:53~ | A를 27초에 끊고 복구 후 29초. 3초에 끊은 시도는 B·태블릿에서 LIAR 판정/룰렛 또는 다음 턴 진행, A도 복구 후 다음 턴으로 이동 | 29초는 30초 상한 이내이며 숫자 증가만으로 결함 확정 불가. 마감 경합 판정과 시험 범위가 남아 있음 |

10번의 최신 잠금 대기는 20초로 기록돼 있어 원래 30초/과거 앱 전환 40초 조건과 동일한
시험은 아니다. 앱 전환 기록의 `26분`은 단위 확인이 필요하며 임의로 원문을 고치지 않았다.

### 우선 조사할 문제와 완료 근거

1. **착석 중 이탈의 첫 실패(27번): 우선 원인 조사.**
   시작 요청/서버 commit, A의 퇴장 요청·결과, 인원 부족 종료, B·태블릿 route 전환을
   같은 시도로 연결해야 한다. 퇴장 실패가 요청 실패인지 결과 확인 실패인지 구분한다.
   사용자 탭 시각만으로 서버가 시작 전에 이탈을 확정했다고 추정하지 않는다.
   시작이 거절되는 경우와 이미 시작된 뒤 인원 부족으로 종료되는 경우 모두 화면/참가 상태가
   정리되고 다시 참가·시작할 수 있어야 한다. 짧아서 재현이 어렵다는 이유로 해결 처리하지
   않으며, 미해결 문제로 남기고 제어된 회귀가 필요하다.
2. **LP 정상 시작 준비 안내(27번): UI 불일치 조사.**
   정상 첫 준비의 안내 route와 실제 단절 보호를 구분한다. `showAnnouncement: false`
   설정만으로 다른 경로의 준비 안내까지 없어졌다고 판단하지 않는다. 정상 시작을 촬영해
   어떤 화면이 표시되는지 확인하고 배경·연출 대기가 유지되는 것으로 완료를 판단한다.
3. **재생성 뒤 태블릿 통신 이상(28번): 원인 미확인 조사.**
   요청한 구간은 원문 5:49~5:52, 기기는 A·B·태블릿이다. 날짜/오전·오후/시간대와
   실제 오류가 확정된 뒤 현재 접속 heartbeat·ready·구독·callable을 비교한다.
   옛 방 instance/connection의 요청인지 현재 새 방 요청인지 구분하며, 이전에 확보한
   권한 거부 로그를 이번 시도의 원인으로 재사용하지 않는다. 원문은 시험 종료 5:50과
   로그 확인 5:52가 함께 있어 종료 후 관찰인지도 구분해야 한다.

### 오류로 확정하지 않은 경계와 미실행 사항

- **29번의 3초 직전 단절:** 모든 기기가 이후 같은 단계로 합류한 기록이다. 서버가 단절을
  반영하기 전에 정상 마감돼 자동 행동한 것일 수 있다. 마지막 heartbeat, deadline,
  단절/pause 반영, 자동 행동 commit의 순서로 판정한다. pause 확정 후 진행했다면 결함,
  정상 만료가 먼저라면 현재 계약의 정상 동작 가능성이 있다. 지금은 `오류 확정` 대신
  `마감 경합 판정 미완료`로 남긴다. 3초 이상에서는 잘 감지했다는 사용자 관찰을 모든
  조건의 감지 보장으로 확대하지 않는다. 무조건 되감거나 새 시간을 주는 정책은 제안하지 않는다.
- **29번의 27→29초:** 마지막 정상 heartbeat부터 보존하는 계약과 양립한다. 서버 근거 없이
  매번 30초 초기화나 타이머 오류로 확정하지 않는다. 최신 기록에는 30초 초과·음수·0초
  고착이 보고되지 않았지만 과거 0초 고착의 원인까지 해결됐다고 판단하지 않는다.
- **27번의 정확한 시작 응답 유실·동일 ID 재사용:** 미실행이다. 오류 주입과 재시도/
  앱 재실행 복구의 근거가 필요하다.
- **28번의 실제 옛 요청·cleanup 도착:** 미확인이다. 새 방에서 카드 제출이 가능했던 것과
  실제 옛 cleanup 도착 후에도 보호됐다는 결과는 구분한다. 명시적인 5분 후 유지 기록도 없다.
- **29번 단계/기기별 범위:** A 단절 기록만 있으며 일반 턴과 마지막 카드 도전의 대응이
  명확히 구분되지 않는다. 태블릿 단절과 마지막 카드 도전 초반/마감 직전 결과는 아직
  확인할 수 없고, 최신 3초 시험을 원래 약 1~2초 시험의 통과로 표시하지 않는다.
- 16번은 이번 판정 대상에서 제외했다. Final Call 전용 시험·FULL은 기존 보류다.
  현재 문제의 서버 배포 일치와 APK/source 일치는 별도 확인이며 전체 완료 판정하지 않는다.

## 2026-10-11 — 세 기기·서버 로그 조사 결과

사용자가 세 기기를 순서대로 연결했고 테스트가 오전임을 확인했다. 기존 조회용 계정의
역할 확인을 유지해 관련 함수의 05:35~06:00 KST만 조회했다. 새 계정 로그인·IAM 변경·
RTDB 조회·배포·제품 수정은 없다. 세 설치 APK의 SHA-256은 위 최신 시험 기록과 같다.
정제한 metadata와 조사 스크립트는 ignored `build/device-test/network-10-27-29-20261011/`에
보관했다. 원문 payload·개인정보·계정 식별자는 저장하지 않았다.

| 작업 | 결과 |
| --- | --- |
| read-only ADB 정제 수집 | 태블릿 816/A 1922/B 571개 metadata, 각각 PASS/exit 0; 시험 구간 버퍼 보존 |
| 서버 연결 확인 | payload 없는 metadata 1건, PASS/exit 0 |
| 관련 HTTP 실패/ERROR 조회 | 각각 최대 100건, 반환 11/9건, PASS/exit 0 |
| 마감 경계 05:53~05:57 조회 | 최초 100건 제한 도달 후 HTTP metadata로 좁혀 91건, PASS/exit 0 |
| ignored `exclusion_probe.mjs` | 결함 재현 4개 assertion PASS/exit 0; 해결 검증 아님 |

첫 리전 필터는 asia-southeast1만 포함해 0건이었다. 기존 metadata에서 복구 함수가
asia-northeast3에 있음을 확인하고 두 확인된 리전으로 수정했다. 첫 0건을 오류 부재로
해석하지 않았다. 조회 시간은 UTC 2026-10-10 20:35~21:00이다.

### 공통 서버 결함 확정 — 27번 퇴장·28번 후반 복구

서버 ERROR 9건 모두 `TypeError: Cannot convert undefined or null to object`,
첫 stack 위치 `lib/liars-poker/exclude-player.js:17:25`다. 현재 소스의
`functions/src/liars-poker/exclude-player.ts:26`인 `delete game.private[uid]`와 일치한다.

LP 최초 시작과 다음 라운드는 손패 공개 전 `private: {}`를 사용한다. RTDB는 빈 객체를
저장하지 않아 다음 read-back에서는 private가 없어질 수 있다. 제외 reducer는 필드가
항상 있다고 가정해 예외를 낸다. RTDB 빈 객체 제거를 모사한 로컬 fixture에서 직접 제외,
제외 preview, recovery cause 장식 경로의 같은 예외를 재현했다.

- **27번:** 05:39:23 `leaveRealtimeRoom` HTTP 500/위 TypeError. 이후 A는 05:39:38
  ready가 permission-denied/staleConnection으로 거절되고 공개 구독도 실패했다.
  이 후속 접속 거절의 정확한 원인은 아직 미확인이나 퇴장 요청의 서버 예외는 확정이다.
- **28번:** 05:48:46 ready 4건, join 05:48:46/50 및 05:54:25 3건,
  05:49:49 대기 만료 1건이 같은 예외로 HTTP 500이다. B의 05:48대 공개 단계도
  dealing이며 태블릿/B의 internal 오류와 일치한다.
- ready·join·expire는 실제 참가자 제외를 요청하지 않아도 `decorateRecoveryCauses`에서
  “제외 후 계속할 수 있는지”를 복제 상태로 계산해 동일 reducer를 실행한다. 이 preview
  예외 때문에 정상 복구 관련 요청도 실패한다. 실제로 제외가 commit됐다고 해석하지 않는다.
- 두 원격 브랜치의 exclude-player/game-adapters에는 차이가 없어 새 D1 코드가 이 예외를
  직접 도입했다고 볼 근거는 없다. 병합/전송 시점과 발생 빈도의 관계는 별도다.
- 기존 회귀의 `private: {}` 메모리 fixture만으로는 RTDB read-back의 필드 부재까지
  검증되지 않는다. 수정 시 실제 빈 map 제거를 거친 퇴장/preview/ready·join·expire
  회귀가 필요하다. 제품 수정·새 정식 테스트는 이번 조사에서 수행하지 않았다.

### 여전히 남은 원인과 경계

1. **28번 초반 접속 장애는 별도다.** 태블릿 05:47 heartbeat 3회 시간초과, stale-player
   보고 시간초과, 05:47:45/55의 같은 접속 경로 쓰기 권한 거부 2건이 있다. 이후 seq 2/3
   복구는 완료됐다. 최초 transport 지연과 거절 경로가 옛 접속인지 현재 접속인지 아직
   확정하지 않았다. 후반 TypeError로 앞선 장애 전체를 설명하거나 옛 cleanup 탓으로
   단정하지 않는다.
2. **29번은 정상 만료 선행을 뒷받침한다.** A 단절 05:55:56.902, 서버 force-timeout
   05:56:00.338 시작/HTTP 200(2.001초), B penalty 수신 05:56:02.775,
   connection-change trigger 05:56:09.200/HTTP 200이다. A는 복귀 후 penalty에 합류했다.
   현재 근거는 pause 이후 불법 진행보다 서버 단절 감지 전에 마감이 처리된 경로와
   양립한다. HTTP metadata에는 대상 UID·pause 실제 변경·마지막 heartbeat/deadline이
   없어 정확한 해당 A 상태 순서를 확정한 것은 아니다. 다른 경계 조합의 검증도 남는다.
3. **10번:** 05:31:52~53 local/failed 준비 timeout은 있으나 사용자 보고대로 이후 복구했다.
   영구 고착 재현과 일시 실패 후 복구를 구분한다.
4. **정상 준비 UI·정확한 시작 응답 유실·실제 옛 cleanup**은 여전히 미해결/미확인이다.
   소스의 정확한 `게임 준비 중` 문구는 로비 책 준비 badge에도 있어 실제 관찰 화면을
   확인해야 한다. 그 badge가 사용자가 보고한 전체 화면이라고 확정하지 않는다.

FULL·Final Call 전용 시험 보류는 유지한다. 세 기기 추가 연결 없이 확보 로그로 후속
분석할 수 있다. 구현 완료/배포 완료/전체 시험 통과로 판정하지 않는다.

## 2026-10-11 — 06:15~06:20 방 생성 거절·세 기기 재연결 고착

사용자 요청으로 해당 시간의 서버 로그와 세 기기 버퍼를 읽었다. A는 모바일 데이터,
태블릿/B는 교내 Wi-Fi이며 사용자가 모두 인터넷 연결 상태임을 확인했다. 교내 Wi-Fi는
간헐적 불안정/지연이 있다. 처음 A로 연결됐다고 전달받은 SM-A325N은 사용자가 B로
정정했고 정제 기록도 바로잡았다. 실제 A는 SM-A356E, 태블릿은 SM-P610이다.
세 APK hash는 위 시험 APK와 같다. 개인정보·원문 payload는 저장하지 않았다.

### 방 생성 거절은 기존 활성 방 검사에서 발생 — 확인

- 태블릿 06:17:50.175/06:17:54.270의 생성 callable 단계가 `failed-precondition`이다.
  대응 서버 요청 두 건은 HTTP 400이고, timing은 `onboarding`, `previous_mapping`,
  `previous_room`만 완료했다. `creation_slot`/새 allocation에 진입하지 않았다.
- 현재 소스 `create-room.ts:42`의 기존 방 검사와 일치한다. 해당 controller 매핑의
  roomInstanceId가 기존 방과 일치하고 상태가 closed/terminal이 아니며 다른 생성
  operation인 경우 거절한다. 실제 방의 세부 상태 값은 RTDB를 읽지 않아 미확인이다.
- 같은 시간의 태블릿 방 복구 `resumeRealtimeControllerRoom`은 06:15:48/06:17:40에
  HTTP 500, 퇴장 `leaveRealtimeRoom`은 12건 HTTP 500이다. ERROR 14건 모두 앞서
  확정한 `exclude-player.js:17:25`의 nullish TypeError다. 복구는
  `decorateRecoveryCauses`→preview→제외 reducer에서 실패한다. transaction이
  commit되지 않아 새 controller 연결 확정도 완료할 수 없다.
- 이번 HTTP metadata 조회에는 `closeRoom` 실행이 없다. 이 범위에서 방 종료 성공을
  확인할 수 없으며, 휴대폰 퇴장은 controller의 명시적인 방 종료와 구분한다.
  화면에 방이 없어 보이더라도 서버의 기존 방 생존 검사는 계속 새 방 생성을 막는다.
  모든 퇴장 요청이 특정 기기에서 온 것인지 metadata만으로 배정하지 않는다.

### 로비의 계속되는 재연결 안내 — 별도 유력 원인

| 기기 | 최근 Firebase 연결됨 | 이후 끊김 | 간격 |
| --- | --- | --- | --- |
| 태블릿 | 06:17:40.388 | 06:18:35.941 | 55.553초 |
| A / SM-A356E | 06:17:37.498 | 06:18:35.278 | 57.780초 |
| B / SM-A325N | 06:17:19.884 | 06:18:15.713 | 55.829초 |

A의 이전 프로세스에서도 06:15:44.223→06:16:43.835(59.612초) 패턴이 있다.
확보된 후속 로그에는 연결 성공이 없다. A/B OS snapshot은 기본 네트워크와
INTERNET/VALIDATED agent가 존재했다. 이는 인터넷 접속 근거이며 Firebase 접속
성공을 보장하지는 않는다.

[Firebase Android 공식 문서](https://firebase.google.com/docs/database/android/offline-capabilities#detecting_connection_state)는
실제 listener·대기 쓰기·onDisconnect가 없는 유휴 상태에서 60초 후 연결을 닫는다고
설명한다. [SDK Repo 구현](https://github.com/firebase/firebase-android-sdk/blob/master/firebase-database/src/main/java/com/google/firebase/database/core/Repo.java)은
`.info` listener를 일반 서버 listener와 별개로 관리한다. 따라서 `.info/connected`만
관찰하는 것은 연결을 계속 사용 중이라는 보장이 아니다.

현재 `RealtimeConnectionMonitor`는 `.info/connected=false`를 전달하고,
`ConnectionNoticeHost`는 유예 후 계속 reconnecting을 표시한다. 로비 띠의 시간/단계는
표시용이며 실제 재접속을 실행하지 않는다. 방 복구가 실패하거나 참가 방이 없는 로비에서
일반 DB listener가 없으면 유휴 연결 중단도 통신 장애로 표시될 수 있다. 약 60초 패턴,
세 기기 인터넷 연결, A의 별도 모바일 데이터가 이 가설을 강하게 뒷받침한다.
단, native `connection_idle` 원인 로그는 확보하지 못해 이번 단절 원인을 확정한 것은 아니다.
교내 Wi-Fi 지연은 최초 timeout과 별도 가능성으로 남긴다. 06:15 interruption-expire
HTTP 403 한 건은 이번 TypeError 14건과 구분하며 권한 거절의 세부 원인은 미확인이다.

### 디벨럽1 병합과 후속 조치

`origin/develop`→`origin/디벨럽1` 및 통합 전 9a26728→b84ca12를 비교했다.
기존 활성 방 거절 조건, LP exclude/game-adapters, controller resume의 장식 경로,
연결 monitor/notice 로직에 해당 결함을 새로 넣은 차이는 없다. D1의 closed allocation
재생성 개선은 종료 증명이 있어야 적용되며 이번 요청은 그 앞에서 거절됐다.
병합이 직접 원인이라는 근거는 없다. 전체 병합 무결함이나 운영 모든 함수의 source
commit 일치를 보증하는 판단은 아니다.

다음 수정은 LP private 부재를 안전하게 처리하고 RTDB read-back 형태의 실제 제외·preview·
controller resume 회귀를 추가하는 것이다. 별도로 방 복구 실패를 로비의 방 없음과 혼동하지
않는 안내/재시도와, 로비 유휴 연결을 실제 통신 장애로 오인하지 않는 판정의 검증이 필요하다.
native SDK 로그 또는 격리된 로비 60초 재현으로 유휴 중단 원인을 확정한 뒤 처리한다.
임의 방 삭제·매핑 초기화로 우회하지 않았다.

수집 명령은 ignored `build/device-test/network-0615-20261011/`의
`capture_device.py tablet|phone-A|phone-B`, `network_state.py`,
`read_server.py probe|requests|errors|roomflow|timing`이다. Python `-X utf8`로 실행했고
실제 B 수집은 최초 phone-A label 뒤 사용자의 정정으로 재분류했다.
ADB 수집 91/103/39개, OS snapshot 2개, 서버 probe 1/HTTP 실패 17/ERROR 14/
방 흐름 HTTP 16/timing 2건, 모두 PASS/exit 0이며 probe 이외 조회 최대 100건이다.
조회 시간 UTC 2026-10-10 21:15~21:20, 제품 수정·RTDB 조회·배포·추가 테스트는 없다.
시작/종료 branch `codex/e01-validation-wiring`, HEAD `5e94b7f` 유지. 기존 사용자 시험 문서
수정과 앞선 planning 3개 변경을 보존하고 조사 내용만 추가했다. FULL/Final Call 보류 유지.

## 2026-10-11 — 후속 개발 계획

사용자 요청에 따른 계획이며 아직 구현·새 검증·배포 승인은 아니다. 목표는 LP 분배 중
퇴장/복구의 서버 예외 제거, 기존 방 복구 실패를 정리 가능한 상태로 안내, 인터넷이 되는
로비에서 유휴 RTDB 연결 때문에 재연결 안내가 계속되는 문제의 원인 확정과 처리다.
기존 operation ID, room/member/connection 식별자, pause/ready/timer 계약을 유지한다.

### 1. LP private 부재 회귀부터 만들고 서버 결함 수정

- `exclude-player.ts`의 private 제거를 필드 부재에도 안전하게 처리한다. 해당 시점
  손패는 pendingHands에 있으므로 개인 데이터 정리와 남은 인원/종료 판정을 함께 검증한다.
  빈 객체가 저장됐다고 가정하는 메모리 fixture 대신 RTDB에서 빈 map이 제거된 형태를
  사용한다. null 방어는 방어 범위로 구분하고 손상 데이터를 정상 게임으로 임의 보정하지 않는다.
- `liars-poker-turn-order`, `network-session-boundaries`, `game-recovery-state`,
  `room-session-contract`의 현재 검사 구조를 활용한다. 직접 퇴장/제외, preview,
  recovery cause 장식 및 controller resume/join/ready/expire의 실제 호출 연결을 확인한다.
- 분배 시작·다음 라운드, private 존재/부재, 제외 후 2명 이상/1명 이하, 같은 퇴장 재전송,
  preview 원본 무변경을 검증한다. controller 접속 교체는 commit 후에만 확정한다.
- 완료 기준: 기존 TypeError fixture가 실패를 재현한 뒤 수정으로 통과하고, 손패 정리·
  승패/인원 규칙·미확정 작업 멱등성·pause/timer 회귀가 유지된다.

### 2. 기존 방 복구 실패에서 사용자 조작 경로 복구

- `RoomService.restoreControllerRoom` 및 provider/태블릿 로비의 상태 전달을 추적한다.
  internal/timeout은 기존 identity/pending resume을 보존하고 방 종료/부재로 처리하지 않는다.
  복구 확인 중 새 방 초대가 가능한 시점과 거절 후 표시를 점검한다.
- 기존 방 복구 재시도와 기존 방의 명시 종료 경로를 사용자가 구분할 수 있게 안내한다.
  종료 결과 미확정은 같은 close operation으로 확인하고, 서버 종료 확인 뒤 새 생성으로 간다.
  새 생성 거절을 이유로 기존 방/매핑을 임의 삭제하거나 새 ID를 반복 발급하지 않는다.
- `controller_room_recovery_test`, `room_action_fast_path_test`에 internal 보존,
  pending resume 채택/재생, 종료 응답 유실, 지연 응답과 새 방 보호를 추가한다.
- 완료 기준: 서버 복구 오류가 로비의 방 없음처럼 보이지 않고, 명시 재시도/종료 후
  기존 방 정리와 새 방 생성이 서로 다른 작업으로 확정된다. 중요한 제품/state 계약 변경이
  필요한 경우 구현안과 영향 근거를 먼저 제시한다.

### 3. 로비 60초 유휴 연결 원인 확정 후 안내 판정 수정

- 로컬 Android 재현에서 방 없는 로비/방 복구 실패 로비/실제 참가 중을 분리하고
  90초 이상 관찰한다. SDK native 로그에서 connection_idle과 실제 transport 오류를
  구분한다. 로그에는 계정·토큰·방/참가자 payload를 남기지 않는다.
- 실제 인터넷 끄기/복구, Wi-Fi 지연, 모바일 데이터에서도 비교한다. timer만 진행하는
  로비 연결 띠를 실제 재접속 횟수나 복구 성공으로 해석하지 않는다.
- 원인이 확인되면 로비의 작업/세션 필요성과 실제 실패 근거를 포함해 안내를 판정한다.
  `.info=false`만으로 정상 유휴 로비에 무기한 장애 안내를 만들지 않는다. 복구/작업 실패는
  계속 드러내고 게임 입력의 pause/ready/현재 접속 가드는 유지한다.
- monitor의 최신값 재생, 중복 구독 해제, 연결 띠의 유예/회복/오류 유지 회귀를 확인한다.
  허용되지 않은 DB 경로 구독이나 운영 keepalive 쓰기를 해결책으로 추가하지 않는다.
- 완료 기준: 정상 유휴 로비 90초에서 고착 안내가 없고, 실제 단절·현재 방 복구 실패는
  표시되며 연결과 서버 준비가 확인된 뒤에만 게임 입력이 풀린다.

### 4. 검증·반영·실기기 확인

개발 진행 요청 시 Mosigame Implement and Validate skill을 적용한다. 관련 개별 회귀 뒤
Windows `.\tool\invoke_mosigame.ps1 test session`을 실행하고 auth 영향이 있으면 auth도
추가한다. command/status/exit code와 실행 전후 working tree를 기록한다.
FULL 및 Final Call 전용 시험은 기존 사용자 보류를 유지한다. FULL 재개 후
`.\tool\invoke_mosigame.ps1 validate --full`까지 통과하기 전 전체 완료로 표시하지 않는다.

공유 reducer의 import/등록 경로를 추적해 변경 코드가 포함되는 callable/trigger/schedule
배포 목록을 확정한다. leave/resume만 배포하고 다른 ready/join/expire 경로를 남겨두지 않는다.
운영 배포 승인은 실제 변경·검증 결과·함수 목록을 만든 뒤 별도로 받는다.
새 APK는 hash/source를 기록하고 서버 반영과 함께 실제 기기에서 다음을 확인한다.

- LP 분배 중 휴대폰 퇴장, 태블릿 잠금/재실행 후 같은 방 복구 및 중복 처리 없음.
- 기존 방 복구 실패 후 재시도, 명시 종료, 종료 응답 유실 후 새 초대/방 생성.
- T/B Wi-Fi 및 A 모바일 데이터에서 정상 로비 90초 대기, 실제 단절/복귀.
- 기존 10/27/28/29번의 관련 경로 재시험. 16번과 Final Call 전용 시험은 현재 제외다.

정상 LP 시작의 `게임 준비 중` 재등장, 최초 heartbeat 지연/접속 쓰기 거절, expire 403은
별도 미확인 항목으로 유지한다. 이번 핵심 수정으로 자동 해결됐다고 판정하지 않고,
재현 화면/원인별 로그로 후속 조사한다. 계획 수립에서는 제품 수정·테스트·추가 운영 조회 없음.

## 2026-10-11 — LP 분배·로비 복구 수정 후보 검증

사용자의 개발 진행 요청으로 계획의 로컬 후보를 구현했다. RTDB가 빈 private를 제거한
실제 start/restart 상태에서 제외·preview·퇴장·resume/join·ready/failed·expire·접속 trigger를
검증한다. 수정 전 7개 회귀가 같은 TypeError로 실패했고 optional private 삭제로 통과했다.
추가 ready/trigger를 포함한 최종 신규 서버 회귀는 9개다. pendingHands와 남은 인원 판정,
preview 원본 보존, 퇴장 재전송, ready barrier를 함께 확인했다.

초기 controller 복구 확인 중 새 생성을 막고, 실패하면 기존 방 재시도와 명시 종료를
제공한다. 서버 종료 성공 전 저장 신원을 지우지 않는다. 실제 RoomService internal 재시도는
기존 접속과 미확정 resume ID를 보존하며 같은 요청의 확인/재생 후 새 접속을 채택한다.
방을 채택하지 않은 홈은 연결 띠를 구독하지 않고, 연결 소스 변경 시 이전 타이머와 늦은
이벤트를 정리한다. 실제 방의 연결·pause·ready 가드는 유지했다. 정상 유휴 로비 90초는
widget 회귀로만 확인했다. native connection_idle 확인은 USB 단일 기기 조건이 성립하지
않아 추가 확보하지 못했으며, SDK 단절 원인 확정이나 실제 네트워크 복구 확인은 아니다.

### 검증 결과와 실패 정정

- `npm run build` (functions): PASS/exit 0.
- `node --test test/liars-poker-rtdb-recovery.test.mjs test/liars-poker-turn-order.test.mjs`
  (functions): 최종 23개 PASS/exit 0.
- `flutter test --no-pub test/controller_room_lobby_recovery_test.dart test/controller_room_recovery_test.dart`:
  8개 PASS/exit 0. fixture의 필수 exception message 누락을 수정했고, 실제 Zone에서 생성된
  저장소 future를 FakeAsync가 기다리던 widget 시험은 runAsync로 실제 I/O 대기를 분리했다.
- `flutter test --no-pub test/tablet_room_reset_test.dart test/room_action_fast_path_test.dart`:
  24개 PASS/exit 0.
- `flutter analyze --no-pub` 변경 Dart 9개 경로: 최종 PASS/exit 0, No issues found.
  앞선 새 fixture의 if 중괄호 info 2건을 정정했다.
- `npm run lint` (functions): 최종 PASS/exit 0. 앞선 신규 주석 길이 오류를 정정했다.
- `.\tool\invoke_mosigame.ps1 test session`: 최종 Flutter 180개/Functions 116개,
  manifest/preflight/working-tree-mutation 포함 5단계 PASS/exit 0.
  첫 실행은 테스트 180/114개 PASS였으나 실행 도중 이 작업의 UI 조건 수정 때문에
  mutation FAIL/exit 1이었다. 소스를 고정한 최종 재실행에서 mutation까지 통과했다.

FULL/Final Call 전용 시험은 기존 사용자 보류로 미실행이다. 세션 manifest의 기존 공용
게임 검사는 유지했다. 사용자 실기기 시험 기록 파일은 수정하지 않았다. branch
`codex/e01-validation-wiring`, HEAD `5e94b7f6803ad1c66016e9581dc4c2d3c7d6245e`,
staged 없음 유지. 제품 6개, 테스트 4개(신규 2개), suite manifest 1개와 계약·planning 문서를
수정했고 기존 사용자 문서 및 앞선 planning 변경을 보존했다. commit/push/병합/새 APK/
배포/운영 DB 또는 추가 서버 로그 조회는 없다. 검증 후 기록 문서만 갱신했다.

### 배포 검토용 함수 목록 — 미배포

exclude-player → game-adapters → 공용 execute/장식 또는 leaveSessionRequest의 import와
index export를 추적한 변경 코드 포함 함수 14개다. Final Call 등의 leave wrapper도 실제로
공용 room game adapter를 사용하므로 포함한다. 함수 이름·persistent shape 변경은 없다.

1. `game_common_recovery_report`
2. `game_common_interruption_expire`
3. `game_common_interruption_wait_more`
4. `game_common_interruption_exclude_player`
5. `game_common_interruption_report_stale_player`
6. `game_common_interruption_report_stale_controller`
7. `game_common_interruption_on_connection_changed` (RTDB trigger)
8. `joinRealtimeRoom`
9. `resumeRealtimeControllerRoom`
10. `leaveRealtimeRoom`
11. `game_liars_poker_leave_game`
12. `game_final_call_leave_game`
13. `game_mafia_leave_game`
14. `game_holdem_leave_game`

createRealtimeRoom의 활성 방 guard는 변경하지 않았다. 운영 배포 승인은 별도이며,
FULL 재개·서버 반영과 새 APK 후 10/27/28/29 관련 실기기 경로를 확인해야 한다.
게임 준비 중 UI, 최초 heartbeat/접속 거절, expire 403은 별도 미해결로 유지한다.

## 2026-10-11 — LP 정상 시작 준비 표시 제거 후속

사용자의 추가 수정 요청으로 로비 TabletBookCarousel의 LP 준비 badge 표시를 제거했다.
게임 보드 waiting 단계는 이미 announcement 없이 게임 배경을 유지하며 공용 recovery
layer도 정상 준비를 덮지 않는다. 남아 있던 정확한 `게임 준비 중` 문구는 로비 책 위의
badge 경로였다. 시작 입력 잠금·선택한 책 위치 계산·실제 단절/실패 안내를 변경하지 않았다.
다른 게임의 badge는 유지하고 서버/세션/API/저장 형식은 변경하지 않았다.

기존 book_carousel 회귀를 확장해 LP 준비 중 표시 미노출과 cover geometry 보존을 확인했다.
첫 실행은 투명 badge의 Text까지 찾는 assertion 때문에 FAIL/exit 1이었다. 기존 fade 구조를
보존하고 화면 노출 기준(hitTestable)으로 검사한 재실행은 11개 PASS/exit 0이다.
명령 `flutter test --no-pub test/book_carousel_test.dart`; 변경 두 경로의
`flutter analyze --no-pub lib/platform/home/tablet/widgets/tablet_book_carousel.dart test/book_carousel_test.dart`
도 PASS/exit 0. 이후 테스트에는 설명 주석과 finder 기준만 정정했다. UI 전용 변경이므로
session/build/lint는 재실행하지 않았다. FULL/Final Call 전용 시험의 기존 보류를 유지한다.

시작 working tree는 clean, branch codex/e01-validation-wiring,
HEAD f5f126ac22ffc4c9fdb670950dc99cda1de84e63. 제품/회귀 각 1개와 계약·실기기 체크리스트·
planning 문서만 수정했으며 stage/commit/배포/새 APK/운영 조회 없음.
27/34번을 새 APK에서 확인해야 하며 서버 수정의 기존 14개 배포 목록에는 추가 대상이 없다.
이전 기록의 준비 UI 미해결 표시는 당시 판단으로 보존한다. 현재 로비 문구는 수정 후보이며
실기기 전체 시작 흐름은 확인 대기, 최초 heartbeat/접속 거절/expire 403은 계속 미확인이다.

## 2026-10-11 — 설정 완료 후 배경 대기·동일 계정 추방·홀덤 단일 기기 보호 개발 계획

사용자 요청의 세 항목을 후속 범위로 설계한다. 계획 시점 HEAD3247b20/working tree clean.
이 절에서는 제품 수정·테스트·배포를 실행하지 않는다. 이전 로비 책 badge 제거와 이번
설정 완료 뒤 준비 화면 제거는 서로 다른 구간이다. 보고된 정확한 문장은 현재 소스 검색에서
찾지 못했으므로 실제 사용 빌드·공용 shell·setup 완료 대기의 표시 경로를 먼저 확인한다.

### 1. 모든 게임의 설정 확정 이후 정상 준비는 게임 배경에서 대기

- 공용 PlayerLayoutEditor onPrepare/onComplete, tablet_game_launcher의 route 교체,
  phone waiting→game 진입, 각 게임의 초기 connecting/loading presentation을 추적한다.
  마피아 역할 설정 완료 경로도 포함하고 로비 다운로드/선택 표시와 구분한다.
- 설정 확정 연출이 끝난 뒤 서버 시작 결과를 기다리거나 첫 공개/개인 데이터를 기다리는
  정상 경로에는 게임 배경을 유지한다. 별도 준비 문구·전체 화면 loading/scrim을 제거한다.
  서버 결과가 미확정이면 배경에서 결과 확인을 계속하며 새 시작 요청 ID를 만들지 않는다.
- 실제 단절·ready 실패·시작 거절은 기존 보호/오류 안내를 유지한다. 화면 표시를 제거해도
  canSend/ready barrier는 유지하고, 거절 시 명단 수정·설정 복귀/재시도가 가능해야 한다.
- 각 게임의 초기 데이터 지연, 시작 응답 지연/유실, 실제 단절/실패 회귀를 구분한다.
  테스트는 배경 유지·정상 준비 문구 미노출·입력 차단·동일 시작 재생을 확인한다.
  Final Call 전용 실행은 기존 보류를 유지하고 변경된 공용 경로와 기존 공용 회귀를 검증한다.

### 2. 같은 계정의 휴대폰 추방은 태블릿 controller 방을 유지

- RoomProvider의 players subscription에서 controller를 내 참가자로 채택하지 않는다.
  기존 _ownsControllerSession을 기준으로 player removal 확인을 제외하고, 확인 함수의
  시작/await 결과 적용 직전에도 역할·방·session epoch를 확인해 늦은 응답을 차단한다.
- 휴대폰의 실제 강퇴 정리와 서버 close/delete 판정은 유지한다. 같은 UID의 player 삭제가
  controller의 roomCode·구독·heartbeat·저장 신원을 정리하지 않게 한다.
- 이미 로컬 방을 잃은 상태에서는 저장된 controller 세션의 존재를 새 생성 전에 확인해
  기존 방 복구를 우선한다. 복구 실패는 재시도/명시 종료로 처리하고 서버 종료 확인 전에는
  신규 할당이나 매핑 삭제를 하지 않는다. 필요 시 권한/서버 종료 판정은 추가 승인 경계를 검토한다.
- controller/player 같은 UID, 다른 UID, 마지막 참가자 추방, 진행 중 removal 확인의 역할 전환,
  실제 방 종료·삭제, 로컬 roomCode 부재+저장 세션 존재를 회귀로 확인한다.
  controller 유지·휴대폰 퇴장·재참가·명시 종료 뒤 새 생성이 각각 정상이어야 한다.
- 3247b20과 d9a61f8의 해당 client/추방/생성 경로는 같다. 서버 추방은 player만 지우고,
  local clearRoom은 server close를 보내지 않아 controllerRooms와 활성 방이 남는다.
  이후 새 operation 생성은 서버의 기존 활성 방 guard에 거절되는 공통 결함이다.

### 3. 홀덤 내 턴에 한 휴대폰만 보호 화면에 가린 원인 조사 후 수정

- 테스트 날짜/시각·APK commit/hash·기기·연결 방식·같은 계정 여부·실제 문구를 확보한다.
  문제 휴대폰부터 로그를 확보하고 필요한 태블릿/다른 휴대폰을 차례로 요청한다.
  서버 조회가 필요하면 관련 함수·시간·최대 건수를 합의한 뒤 read-only 절차를 따른다.
- 하나의 시간축에 transport, controller presence/heartbeat 판정, 현재 membership/connection,
  public/private context, ready 수락·barrier, pause 전이, turn deadline/timeout을 맞춘다.
  private 카드 payload·계정 식별자는 기록하지 않고 고정 사유와 최소 상태만 사용한다.
- 단일 기기 실제 단절, controller 오판, 늦은 private/ready 불일치, 옛 접속 이벤트,
  서버 중단 감지 전 timeout을 분리한다. 게임 전체가 진행됐다는 이유만으로 서버 pause 결함으로
  확정하지 않으며 실제 원인 fixture를 먼저 재현한다.
- 확정 원인에 한해 수정한다. 잘못된 controller 판정은 현재 접속과 최신 근거로 재확인하고,
  실제 단절은 기존 실패 보고/heartbeat 중단 계약을 따라 서버 중단으로 전달한다.
  표시를 숨기거나 ready 없이 입력을 열거나 타이머를 임의 초기화하지 않는다.
- 내 턴 초반/마감 직전 단절, controller 정상+phone 단절, reconnect 뒤 context/ready 지연,
  실제 pause 이후 timeout 거절과 잔여 시간 복원, pause 이전 정상 만료를 회귀로 구분한다.
  원인 확인 전 서버 deadline/pause 계약 변경은 구현하지 않는다.

### 작업 순서와 검증·반영

첫째 동일 계정 추방 회귀/수정, 둘째 전체 게임 설정 완료 이후 배경 대기 회귀/수정,
셋째 확보한 홀덤 로그의 원인 fixture와 수정 순서로 진행한다. 홀덤 증거 수집은 앞선
두 구현과 병행할 수 있다. 게임 시작 중 서버 상태 전이/ID 계약은 변경하지 않는다.
구현 때 Mosigame Implement and Validate skill을 적용하고 관련 회귀·분석 뒤 Windows
guarded test session을 실행한다. auth/API 변경이 생기면 영향과 추가 검증을 별도 검토한다.
FULL/Final Call 전용 시험/16번은 기존 보류 유지; FULL 재개 없이 전체 완료로 표시하지 않는다.
클라이언트만 수정되면 새 APK가 필요하며, 홀덤 서버 수정이 확인되면 실제 공유 호출 경로의
함수 목록을 확정해 별도 배포 승인을 받는다. 현재 서버 변경 필요 여부는 미확정이다.
실기기 문서에 전체 게임 설정 완료 후 배경 대기, 동일 계정 추방/기존 방 복구, 홀덤 단일
휴대폰 보호의 독립 항목을 추가한다. 기존 사용자 시험 기록은 보존한다.

## 2026-10-11 — 홀덤 제외 후 배경 대기·동일 계정 방 유지 구현 후보

사용자가 홀덤을 이번 개발에서 제외했다. 홀덤 관련 제품/테스트/로그 수집은 추가하지 않고
기존 session manifest의 공용 게임 회귀는 유지했다. 이전 계획의 홀덤 조사 단계는 보류한다.

동일 계정 추방은 controller 역할을 players membership 감시에서 제외하고, player removal
확인의 시작 및 응답 반영 시 역할/UID/dispose/session epoch를 검증하도록 수정했다.
휴대폰만 강퇴되며 태블릿 roomCode·구독·controller 신원이 유지된다. 로컬 방이 없어도 저장된
controller 방이 있으면 createRoom이 복구를 우선하고 신규 할당을 하지 않는다.
서버 추방·활성 방 생성 guard·persistent shape와 public API는 변경하지 않았다.

정상 설정 완료 대기는 공용 editor의 기존 게임 배경으로 유지되는 것을 pixel 회귀로
확인했다. LP/마피아·공용 phone connecting은 이미 정상 준비 안내를 숨긴다. Final Call과
게임 템플릿의 connecting에는 빈 GameFlowCopy.preparingGame을 표시하는 설정이 남아 있어
showAnnouncement 자체를 false로 정리했다. 보고된 정확한 문장 `게임 시작 전 게임을 준비
중입니다`는 현재 소스에 없으므로 실제 설치 APK의 전체 흐름은 확인 대기다. 단절·실패 안내와
ready/입력 보호는 그대로 유지한다. 홀덤 화면/네트워크 원인은 이번에 변경하거나 판정하지 않았다.

- `flutter test --no-pub test/controller_room_lobby_recovery_test.dart test/controller_room_lifecycle_test.dart test/table_background_transition_test.dart packages/game_kit/test/recovery/widgets/game_recovery_layer_test.dart`:
  중간 후보 29개 PASS/exit0.
- `flutter test --no-pub test/controller_room_lobby_recovery_test.dart test/table_background_transition_test.dart test/tablet_room_reset_test.dart`:
  최종 신규 늦은 추방 확인 회귀 포함 26개 PASS/exit0. 동일 UID controller 유지, player 강퇴 유지,
  저장 방 복구 우선, 늦은 player 결과 무시를 추가했고 배경 대기 무스피너/무문구도 확인했다.
- `flutter analyze --no-pub lib/platform/home/room/providers/room_provider.dart test/controller_room_lobby_recovery_test.dart test/table_background_transition_test.dart packages/game_final_call/lib/tablet/tablet_board.dart packages/game_template/lib/tablet/tablet_board.dart`:
  5개 경로 PASS/exit0.
- `.\tool\invoke_mosigame.ps1 test session`: 최종 Flutter191/Functions116, manifest/preflight/
  working-tree-mutation 포함 5단계 PASS/exit0. table_background_transition을 session manifest에 추가했다.
  별도 auth/FULL/Final Call 전용 suite는 실행하지 않았다. 서버 소스 변경이 없어 별도 lint를 반복하지 않았다.

실기기 체크리스트 36/37번 추가, 계약 문서 갱신. 기존 planning 계획 변경을 보존했다.
시작/종료 develop/HEAD3247b201f5f5f0ed73ec38c6273557e4a8f03e4c, staged 없음,
제품3개/회귀2개/manifest1개와 문서만 수정했으며 마지막 검증 뒤 문서만 갱신했다.
FULL·Final Call 전용 시험·16번 보류 유지. 이번 클라이언트 후보의 추가 Functions 배포 대상 없음.
새 APK 빌드·설치·실기기 재시험/commit/push/merge/운영 조회는 실행하지 않았다.

## 2026-10-11 — 초기화·초대 지연, 생성 요청 보존, 로비 감지, 16:54 LP 조사

읽기 전용 코드·이력 검토이며 제품 소스는 추가 수정하지 않았다. 사용자에게서 LP 장애 날짜
2026-10-11 16:54 KST와 갤럭시 로그 수집 가능 여부를 확인했다. 설치 APK와 로컬 release
artifact의 일치는 아래 후속 수집으로 확인했다. 빌드 commit·장애 화면의 정확한 문구와
각 시작의 방/게임 대응은 아직 미확인이다.

- 초기화: closeRoom은 방 전체 사전 읽기와 primed 방 루트 transaction을 순차 실행한다.
  참가자를 한 명씩 퇴장시키거나 physical cleanup을 기다리는 구조는 아니다. 참가자·게임
  데이터 증가와 같은 루트에 대한 heartbeat/presence 쓰기의 transaction 경합은 지연 후보다.
  최신 버전에서 인원별 시간을 측정하지 않았으므로 확정 병목으로 표현하지 않는다.
  최초 close의 operation-status 생략은 이미 구현되어 있어 추가 최적화로 중복 제안하지 않는다.
- 초대: 생성 서버는 onboarding, 이전 매핑, 슬롯/예약/방 할당, 예약 확정, 매핑 검증/확정,
  최종 방 확인, 슬롯 확정을 순차 수행한다. primed transaction마다 초기 값 확인도 필요하다.
  앱은 durable intent/신원 저장과 presence/onDisconnect 설정을 마친 뒤 성공한다.
  최초 생성의 불필요한 resume 제거는 이미 구현되었다. room_action_timing의 단계별 시간과
  앱 전체 완료·표시 애니메이션을 분리해 측정한 후 중복 읽기/경합을 줄일 범위를 정한다.
- 생성 기록: reconcileTerminal은 roomCreateRequests와 roomCreateSlots를 지우지 않고
  같은 roomInstanceId/allocationGeneration의 기록만 terminal로 바꾼다. controllerRooms는
  같은 target일 때 지운다. terminal 기록의 별도 TTL 삭제는 없으며 늦은 재전송 방지를 위한
  잔존 기록과 실제 활성 방을 구분해야 한다. 방 할당 전 reserved 슬롯이 남으면 rooms 기반
  cleanup만으로는 회수되지 않을 수 있다. 실제 운영 요청의 나이·상태는 조회하지 않았다.
  realtime-room-lifecycle의 요청 삭제 backstop 주석은 현재 terminal 보존 구현과 다르다.
- 로비 연결 감지: controller의 20초 stale heartbeat 보고는 playing에만 켜진다.
  로비 카드는 lastSeen 대신 player.isConnected만 표시한다. waiting/seating은 onDisconnect
  감지 → syncRealtimeRoomConnection의 방 루트 transaction → players 요약 → 앱 구독에
  의존하므로 transport 감지가 지연되면 표시도 늦어진다. 로비 freshness 표시와 게임 pause
  계약을 구분해서 보완해야 한다.
- 하단 5-5: a0ee1eb(2026-10-10 01:58:51 KST)에서 공용 게임 LED 띠를 추가했다.
  ConnectionNoticeHost의 1.5초 유예/3초 끊김 표시 뒤 [0,1,3,7,15]초에 표시 단계가 오른다.
  실제 Firebase 재시도 횟수나 5회 실패 한도가 아니다. 연결 복구 전에는 5-5에 머문다.

### 승인된 16:50~17:05 KST 서버 조회

사용자가 이번 시간/관련 함수/함수별 최대100건 조회를 승인했다. 기존 사람 확인 조회용
계정과 고정 project0000-ec01e를 사용했다. SDK launcher의 sandbox 접근 거부 후 승인된
실행 경로로 bundled Python -S gcloud.py logging read를 호출했다. probe는 metadata1건,
requests/errors는 각각 함수별 limit100·order asc로 실행했고 모두 exit0이다.
정제 결과만 ignored build/device-test/lp-1654-20261011에 저장했다. 원문 오류·사용자 식별자·
게임 payload·credential은 저장하지 않았다. RTDB 조회·쓰기·배포는 하지 않았다.

- game_liars_poker_start_game: 16:50:07, 16:52:49, 16:53:23의 HTTP200 3건,
  서버 HTTP latency 약605~631ms. 각 시작 직후 game_common_recovery_report4건씩 총12건,
  HTTP200·약367~923ms. HTTP200은 ready accepted와 staleContext/dataMissing을 구분하지 않는다.
- game_liars_poker_complete_dealing, resumeRealtimeControllerRoom,
  resumeRealtimePlayerConnection: 해당 범위 요청 기록0건. 미발견이며 정상/미호출 확정은 아니다.
- interruption_on_connection_changed5건, controller_presence_changed18건은 HTTP200.
  syncRealtimeRoomConnection은 limit100에 도달해 16:50:01~16:53:14만 포함한다.
  이 제한된 표본은 평균184ms·최대395ms이며 16:54 이후 전체를 대표하지 않는다.
- 위8개 함수에서 severity>=ERROR의 비HTTP 실행 오류는0건. 예외 미발견으로만 판정한다.

시작 함수에서 1분을 소비한 근거는 발견하지 못했다. 현재 LP는 dealing으로 시작하고
태블릿 배분 연출 뒤 complete_dealing이 손패를 공개하므로 그 이전의 화면/에셋 준비,
ready 수락과 모든 필수 접속의 barrier, 배분 연출 완료 callback을 우선 확인한다.
기기5대 대비 보고4건의 묶음은 의심 근거지만 요청 수는 고유 기기 수가 아니며 이번 방과
대응도 미확인이다. 누락 기기·서버 barrier 고착·배포 버전 불일치로 확정하지 않는다.
갤럭시 연결 후 scoped 정제 로그와 설치 metadata를 추가 수집했다.

### 갤럭시 추가 수집과 APK 비교

연결한 SM-S931N의 versionName1.0.0/versionCode2, DEBUGGABLE=false,
lastUpdateTime2026-10-11 15:04:43을 확인했다. 설치 APK의 SHA-256은 로컬
build/app/outputs/flutter-apk/app-release.apk(수정 시각15:03:03)와 일치한다.
APK의 대응 commit 및 다른4대 설치 버전은 미확인이다.

capture_device.py galaxy/capture_native.py는 각각 exit0. 전체 Android buffer에 다른 날짜
기록이 있더라도 대상16:50~17:05의 앱 구조화 이벤트0건·식별 가능한 앱 프로세스 로그0줄로
당시 장애 증거는 확보하지 못했다. 준비 보고 진단은 kDebugMode에서만 출력되므로 이번
release 앱에서는 ready_report_returned를 얻지 못한다. 오류/종료 기록의 미발견을 정상
동작 증거로 취급하지 않는다. 앱 실행·재설치·데이터 변경·로그 삭제는 하지 않았다.
추가 재현에서는 동일 source의 진단 가능한 APK 또는 승인된 최소 release 진단과
controller/player별 ready 상태·배분 완료 callback을 수집해야 한다.

## 2026-10-11 — 36·37번 실패 재조사와 개발 계획

사용자는 Functions 배포 후 debug APK에서 36번 LP 시작 준비 화면과 37번 동일 계정
휴대폰 추방 시 태블릿 방 소실/A 추방/B 단절이 다시 발생했다고 보고했다. 시험 문서의
10시02분/04분 AM/PM 및 16개 배포 성공 여부는 확인 요청했다. 사용자 시험 기록을
보존하며 기존 로컬 검사 PASS를 이 실기기 실패의 통과 근거로 확대하지 않는다.

### APK와 현재 코드 대조

보고 hash6FD148826B995C469C2DA391C8E4F69A4CE595BA1AC1741DFD444F5F434880E5는
로컬 app-debug.apk(21:55:33)와 일치한다. debug APK의 kernel_blob.bin을 읽어 현재
room_provider, tablet_book_carousel, LP/Final Call tablet_board, GameRecoveryLayer의
전체 소스가 내장됨을 확인했다(exit0). controller membership/removal 가드와 LP badge
제외를 확인했으므로 해당 APK의 수정 코드 누락을 원인으로 단정하지 않는다.
실제 태블릿 설치 hash는 USB 연결 후 별도로 확인한다. 제품 소스 수정·새 빌드·배포 없음.

### 36번 — 정상 최초 ready barrier도 중단 화면으로 분류되는 코드 경로

finalizeGameMutation은 새 게임을 만들 때 beginRecoveryPause를 호출한다. 실제 단절이
없어도 recovery.paused=true/pauseId/빈 causes가 생성된다. GameRecoveryLayer는
pauseId가 있으면 interrupted=true로 보고 tabletController의 GameInterruptionLayer를
그린다. 따라서 LP waiting의 showAnnouncement=false와 공용 editor 배경 시험만으로는
실제 시작의 공용 중단 화면을 제거하지 못한다. 화면의 정확한 문구/로그 대응은 확인 대기다.

기존 game_recovery_layer_test의 원인이 해소된 복구 barrier 시험도 빈 causes/pauseId를
사용해 안내 유지를 기대한다. 실제 단절 후 원인이 사라진 복구 대기의 보호는 유지해야
하므로 빈 causes만으로 모든 pause를 숨기는 수정은 금지한다.

개발 계획:

1. 실제 정상 생성(public 초기 context+paused/pauseId/빈 causes)을 전달하는 실패 회귀를
   추가한다. 설정 완료→서버 시작→게임 라우트→ready 지연을 포함해 최초 준비 화면을 검증한다.
2. 정상 최초 준비와 실제 단절/준비 실패 뒤 복구 대기를 식별하는 근거를 정한다.
   기존 context/세션 이력으로 안전하게 구분할 수 있는지 우선 검토한다. 서버 public pause
   목적 필드가 필요하면 하위 호환과 모든 소비자 영향 및 별도 계약 변경 승인을 받는다.
3. 정상 최초 준비에는 게임 배경을 유지하며 canSend/ready/timer barrier를 그대로 유지한다.
   실제 cause, 준비 실패, 원인 해소 후 복구 barrier는 기존 보호·재시도 안내를 보존한다.
4. LP의 실제 시작과 공용 layer 양쪽에서 정상/지연/실제 실패를 확인한다. 마피아·템플릿과
   Final Call 공유 표시 회귀를 유지하되 Final Call 전용 실기기 시험과 홀덤 네트워크 조사는 보류한다.

### 37번 — 아직 정확한 종료 경로 미확정

현재 removeRealtimeRoomPlayer는 players[playerUid]만 삭제하고 membershipRevision을
올린다. controllerUid/controller session/방 status/방 루트를 지우지 않는다. 수정된
RoomProvider는 controller를 본인 player 삭제 감시에서 제외한다. 따라서 실기기 실패를
이 가드 경로만으로 설명할 근거는 부족하다.

기존 Fake는 참가자 목록 삭제만 전달하며 roomExists=true/status·presence·방 마커 구독은
실제 연쇄 이벤트를 전달하지 않는다. 이 검사 PASS는 세 기기의 실제 접속/종료 동작 보장이 아니다.
추가 코드 문제 후보로 fetchRealtimeRoomSession/roomSessionContext가 요청 역할 대신
controllerUid==uid만으로 controller를 우선 선택한다. 같은 UID player의 신원 재조회/미확정
join 복구에 영향이 있지만 이번 태블릿 방 소실의 원인으로 확정하지 않는다.

개발 계획:

1. 태블릿 설치 hash/추방 시각·앱 로그를 우선 수집하고 필요하면 A, B를 차례로 요청한다.
   clearRoom/terminate/dispose/heartbeat 중단과 remove/close/cleanup 시간축을 맞춘다.
2. 서버 방이 실제 closed/terminal로 전이했는지, controller 접속만 끊겼는지, 태블릿 로컬
   상태만 비었는지를 구분한다. 서버 조회는 날짜·함수·시간·최대 건수 승인 후 진행한다.
3. 같은 UID의 controller/player에 서로 다른 connectionId·sequence·membership을 둔 회귀를
   구성한다. 추방 직후 phone onDisconnect/늦은 heartbeat/권한 오류/옛 구독 callback을 넣어
   controller 신원·heartbeat·B 참가·방 마커가 유지되는지 검사한다. 마지막 참가자 삭제도 포함한다.
4. 확정된 종료 경로만 수정한다. controller 역할 획득·복구·초기화와 late callback에서 같은
   identity 근거를 사용하고 UID만으로 controller/player를 선택하는 분기를 함께 검토한다.
   정상 player 강퇴·명시 방 종료·현재 allocation cleanup을 약화하지 않는다.
5. 서로 다른 계정, 재참가, 저장 방 복구, 종료 후 재생성, 옛 접속 이벤트를 회귀 확인한다.

구현 착수 때 implement-and-validate skill을 적용하고 Windows guarded test session,
역할/auth 경로 변경 시 test auth, 변경 서버 build/lint를 수행한다. FULL/Final Call/16번의
기존 보류는 유지하며 전체 완료로 표시하지 않는다. 클라이언트 수정은 새 APK, 서버 수정은
실제 import closure를 산정한 배포 목록으로 인계한다. 36/37번 실패 원문을 보존하고 후속
APK hash·배포 함수·기기별 결과를 별도 기록한다.

### 2026-10-11 — 후속 구현과 검증

사용자가 개발 진행 및 public recovery.purpose 선택 필드 추가를 승인했다.
실제 작업 시작 branch는 codex/e01-validation-wiring, HEAD3247b201f5f5f0ed73ec38c6273557e4a8f03e4c였다.
이전 조사에 기록된 develop과 이름이 달라 현재 값을 다시 확인했으며 branch/HEAD/index를
변경하지 않았다. 시작 시 기존 미커밋11개 파일을 보존했다.

- 정상 새 게임만 purpose=initialReadiness로 생성한다. 단절/preparationFailed가 등록되면
  recovery로 바꾸고 원인이 해소돼도 전체 ready 전까지 유지한다. 타이머·pause·ready 및
  서버 입력 검증은 보존했다. GameInterruption은 purpose를 파싱하고 값 동등성에 포함한다.
  공용 layer는 최초 준비만 배경에서 기다리고 기존/알 수 없는 데이터와 실제 cause는 보호한다.
- roomSessionContext는 유효한 controller 토큰으로 controller를 선택하고 나머지 요청은
  active player를 조회한다. 같은 UID phone의 세션 조회/operation status에서 태블릿 신원으로
  오인하던 결함을 수정했다. 잘못된 토큰은 player로 우회하지 않고 추방 phone은 거절한다.
- 동일 UID 추방 후 늦은 phone 단절이 controller 접속·방 status·B 참가를 유지하는 서버 회귀를
  추가했다. 태블릿의 room_terminated/room_cleared debug 기록은 UID·방 코드·토큰 없이
  역할·종료 사유만 남긴다. 37번 실기기 방 소실의 직접 원인은 아직 미확정이다.

검증 명령과 결과:

- npm run build; node --test test/room-session-context.test.mjs: 수정 전 신규 회귀3 FAIL/1 PASS(exit1),
  수정 후4 PASS(exit0). 최종 B 유지 assertion 추가 후4 PASS(exit0).
- node --test test/room-session-context.test.mjs test/game-recovery-state.test.mjs:23 PASS(exit0).
- .\\tool\\invoke_mosigame.ps1 test session: PASS(exit0), Functions123개 및 Flutter 관련 선택 시험 통과,
  실행 전후 tracked/untracked mutation 없음.
- .\\tool\\invoke_mosigame.ps1 test auth: Flutter52/Functions13 PASS(exit0), mutation 없음.
- npm run lint: PASS(exit0). 변경5개 Dart 경로 flutter analyze --no-pub: 문제0/exit0.
- flutter test --no-pub test/controller_room_lobby_recovery_test.dart
  packages/game_kit/test/recovery/widgets/game_recovery_layer_test.dart:21 PASS(exit0).
  추가 purpose 동등성 시험은 --plain-name으로 단독 실행해1 PASS(exit0)를 확인했다.
- git diff --check: PASS(exit0). FULL/Final Call 전용/16번 및 홀덤 단일 기기 조사 보류 유지.

새 빌드·기기 설치·배포·production 조회·commit/push는 실행하지 않았다. 실제 시작 라우트 전체의
실기기36 및 태블릿/A/B37을 재판정해야 하며 자동 회귀가 이를 대체하지 않는다.

배포 인계: 새 purpose 생성은 각 게임 start_game4개, 실제 장애 전환은 joinRealtimeRoom,
resumeRealtimeControllerRoom, syncRealtimeRoomConnection, game_common_controller_presence_changed,
game_common_recovery_report, game_common_interruption_report_stale_player,
game_common_interruption_report_stale_controller, game_common_interruption_on_connection_changed에
반영되어야 한다. 동일 계정 조회 수정은 fetchRealtimeRoomSession/game_common_operation_status다.
이14개는 변경 동작별 검토 대상이며 전체 파일 import closure는70개로 보수적으로 산정했다
(ignored build/device-test/network-36-37-20261011/deploy-import-closure.json).
70개를 최소 배포 목록으로 취급하지 않는다. 실제 배포 전 목록/혼합 버전 영향을 검토하고
승인된 명령으로만 진행한다. 공유 홀덤 start의 필드 호환은 포함하되 독립 홀덤 오류 수정은 없다.

### 2026-10-11 — 사용자 승인 후 Functions14개 배포

사용자 `펑션 배포 해줘` 요청에 따라 project0000-ec01e에 위 변경 동작14개만 배포했다.
Node22.23.2, Firebase CLI의 `deploy --project project0000-ec01e --only`에 아래 함수별
`functions:` 목록을 전달하고 `--non-interactive`로 실행했다. predeploy eslint/tsc PASS,
14개 모두 Successful update operation 및 Deploy complete, 최종 exit0을 확인했다.

- asia-northeast3: game_liars_poker_start_game, game_final_call_start_game,
  game_mafia_start_game, game_holdem_start_game, joinRealtimeRoom,
  resumeRealtimeControllerRoom, game_common_recovery_report,
  game_common_interruption_report_stale_player, game_common_interruption_report_stale_controller,
  fetchRealtimeRoomSession, game_common_operation_status.
- asia-southeast1: syncRealtimeRoomConnection, game_common_controller_presence_changed,
  game_common_interruption_on_connection_changed.

정제 결과는 ignored build/device-test/network-36-37-20261011/deployment-result.json에 기록했다.
배포 전후 제품 소스와 branch/HEAD/index 변경 없음, 기존 미커밋 상태 보존. 문서만 배포 결과를
갱신했다. DB/rules/Auth/IAM 직접 변경·함수 삭제·기기 조작·APK build/install은 실행하지 않았다.
CLI 배포 성공은 실제 게임 통과를 의미하지 않는다. 새 APK와 36/37 재시험, 37번 태블릿
종료 경로 로그 확인은 남아 있다. FULL/Final Call 전용/16번 보류는 유지한다.
