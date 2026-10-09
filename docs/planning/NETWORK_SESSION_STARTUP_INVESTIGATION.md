# 실기기 정상 시작 실패 조사

2026-10-09 KST. SESSION-RECONNECT-02 / TEST-REGRESSION-01 후속 원인 조사다.
현재 상태의 원본은 [TASKS.md](TASKS.md), 기존 준비/검증 근거는
[실기기 인계](NETWORK_SESSION_REAL_DEVICE_HANDOFF.md)다.

## 사용자 보고와 현재 판정

- 태블릿 1대와 휴대폰 A/B가 같은 Wi-Fi에 연결되어 있다.
- 그룹 참가·자리 배치는 정상이나 설정 완료 뒤 게임 중단 → 태블릿 연결 안내 →
  게임 데이터 준비 안내가 반복돼 실제 게임을 시작하지 못했다.
- 나가기 뒤 B는 로비, A는 QR 화면으로 이동했다. 세 번째 시도에서는 자리 배치 중
  태블릿에 통신 실패가 표시됐다.
- APK의 게임 통신 진단 버튼이 보이지 않는다고 보고했다.
- **정상 시작은 사용자 보고 기준 FAIL**이다. 수집 기록의 게임명은 라이어스포커다.
  태블릿과 휴대폰 A/B의 debug 기록을 확인했으며, B의 설치 APK는 준비한 APK와
  SHA-256까지 일치한다. 태블릿/A의 정확한 APK 해시는 확인하지 않았다.
  일부 기록에 ready/barrier/input과 서버 playing 전이가 있어도 실제 화면·입력 성공을
  뜻하지 않는다. 다른 실기기 항목은 NOT_RUN이며 기존 FULL/backend CI PASS와 구분한다.

## 확인한 코드 결함

### 복구 후 heartbeat가 완료된 복구 제한에 묶임

[RoomProvider](../../lib/platform/home/room/providers/room_provider.dart)의
`_recoverCurrentConnection`은 `RoomRecoveryBatch.run` 안에서 `_performConnectionRecovery`를
실행한다. 그 안에서 controller/player의 `Timer.periodic` heartbeat를 생성한다.
이 타이머는 생성 때의 Dart Zone을 유지한다.

[RoomRecoveryBatch](../../packages/game_kit/lib/recovery/services/room_recovery_batch.dart)의
`current`는 완료된 owner를 반환하지 않지만 `inherited`는 계속 반환한다.
[RoomService](../../lib/platform/home/room/services/room_service.dart)의 `_writeWithRetry`는
`inherited.request`를 사용하므로 복구 시작에서 30초가 지나면 실제 RTDB 쓰기 전에
`TimeoutException`이 발생한다. heartbeat 자체의 새 요청에도 오래된 제한이 적용되는 결함이다.

정상 인터넷이어도 마지막 접속 갱신이 오래되면 휴대폰의 controller presence 판정은
20초 유예 뒤 연결 복구 화면을 표시하고, 진행 기기의 stale-player 보고도 게임 중단을
요청할 수 있다. **실기기에서도 같은 시점의 반복 실패를 확인했다.** 태블릿은
18:32:57.560 복구 시작 뒤 18:33:28.585부터 실패했고, B는 19:04:54.483 복구 시작 뒤
19:05:25.637부터 실패했다. 모두 약 31초 뒤이며 이후 10초 주기로 반복된다.
한 기기 안의 상대 시간 비교이므로 기기 간 시계 오차와 무관하다.

### 새 게임 준비/보고가 대기실의 오래된 제한을 재사용

`RoomProvider._recoverCurrentConnection`과 controller 방 복원은
`GameRecoverySession.preparationBatch`에 owner를 보관한다.
[GameSessionController](../../packages/game_kit/lib/recovery/providers/game_session_controller.dart)의
`_watchPreparation`은 최초 사용 가능 상태 전에 그 owner를 선택한다. 첫 게임에서는
`previous` context가 없으므로 새 게임 분기의 owner 갱신도 실행되지 않는다.

대기실/자리 배치에서 이미 30초가 지났다면 첫 게임 준비 제한이 0ms가 된다.
이미지 준비 전에 timer가 실행되면 preparation failure가 유지되어, 이후 공개/private와
화면 준비가 모두 완료되어도 `localUsable`은 false다.
[GameInterruptionCommandService.report](../../packages/game_kit/lib/recovery/services/game_interruption_command_service.dart)
또한 같은 `preparationBatch`를 재사용하므로 만료된 owner에서는 ready/failed 보고도 전송하지 않는다.
같은 owner를 계속 보관하면 이후 중단의 ready 보고에도 영향을 줄 수 있다.

두 결함은 **작업 하나에 한정해야 할 복구 deadline이 반복 접속 갱신과 다음 게임 준비까지
남는 문제**다. 새 API/데이터 계약이나 timeout 상향이 필요하다는 근거는 없다.

만료된 준비 owner 결함은 로컬 재현으로 확인했지만, 수집된 초기 진입에는 ready가
성공한 기록도 있다. 이번의 모든 준비 화면을 이 결함으로 단정하지 않는다.

### 라이어스포커의 시작 준비가 아직 공개되지 않은 손패를 기다림

[휴대폰 board_state](../../packages/game_liars_poker/lib/phone/src/board_state.dart)의
`_warmUpAssets`는 `waitForInitialData`가 끝나야 `prepareScreen`을 호출한다.
[LiarsPokerController](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)의
`isEntryDataReady`는 휴대폰에서 phase가 `dealing`이면 항상 false다.

그러나 새 공통 [game-mutation](../../functions/src/game-interruption/game-mutation.ts)은
게임 시작 시 준비 barrier를 만들고, 진행 기기와 참가자의 ready를 받아야 해제한다.
손패는 [complete-dealing](../../functions/src/liars-poker/complete-dealing.ts)의 완료 명령에서
공개된다. 그 명령은 pause 중에는 거절된다. 즉, 준비 보고는 손패를 기다리고 손패를
공개하는 진행은 준비 보고를 기다리는 순서가 된다.

완전한 영구 대기는 `_warmUpAssets`의 12초 timeout 후 이미지 준비를 계속하는 우회로가
풀어준다. A는 첫 수집의 18:34:58.030 → assets 18:35:11.750(13.720초),
18:55:55.405 → assets 18:56:08.886(13.481초)였고, B도 각 시작에서 약 13초 뒤
assets/screen, 약 14~15초 뒤 ready/barrier/input을 기록했다.
정상 시작 직후 중단/준비 안내가 길어지는 직접적인 코드 근거다. 12초를 늘릴 문제가
아니며, 게임 화면용 손패 대기와 준비 barrier에 필요한 공개 상태·에셋 준비를 구분해야 한다.

### 진단 창의 Tooltip에 Overlay 조상이 없음

[app.dart](../../lib/app.dart)는 `MaterialApp.builder`에서 `DevErrorOverlay`를
Navigator 바깥에 둔다. [DevErrorOverlay](../../packages/game_kit/lib/core/diagnostics/dev_error_overlay.dart)의
열린 창에는 복사·지우기·닫기 `IconButton`의 tooltip이 세 개 있는데, 이 위치에는
Navigator가 제공하는 Overlay 조상이 없다.

B의 기존 메모리 오류를 VM service의 `getObject`로 읽어 알려진 오류 종류만 분류했다.
`No Overlay widget found` 42건과 `Tooltip`, `IconButton`, `DevErrorOverlay` 이름을 확인했다.
원문/사용자 값/VM 인증 URI는 출력·저장하지 않았다. 최종 조회는 앱 안에서 expression을
실행하지 않으며 앱 재시작·hot reload·isolate resume도 하지 않았다. 생성한 임시 adb
port forwarding은 각 조회 후 제거했다.

같은 `MaterialApp.builder` 배치로 창을 여는 로컬 widget probe도 Overlay 오류 3건을
재현했다. 창을 열면 기존 심전도 버튼은 숨겨지고, 오류로 닫기 아이콘도 그려지지 않는다.
실제 앱은 오류 위젯을 `SizedBox.shrink`로 바꾸므로 원인 대신 빈 부분으로 보일 수 있다.
이는 진단 창이 사용 불가능해지는 확인된 결함이다. 사용자의 모든 버튼 미표시 순간에
창이 열려 있었는지는 기록하지 않았으므로 그 전체 경위를 단정하지 않는다.

기존 `test/dev_error_overlay_refresh_test.dart`는 닫힌 오버레이의 build 중 로그만 검사하며
진단 창을 여는 동작은 검사하지 않는다. 기존 복구 owner 테스트 역시 `current == null`만
검사하고 완료 owner의 `inherited`를 사용하는 실제 서비스/타이머는 검사하지 않는다.
이번 회귀가 과거 PASS 검증에서 빠질 수 있었던 구체적인 빈틈이다.

## 실기기 기록과 별도 미확정 현상

| 근거 | 확인 내용 | 판정 한계 |
| --- | --- | --- |
| 태블릿 기록 386줄 | controller heartbeat TimeoutException 87건, dev_error 70건 | 시작 요청 성공/ready 성공도 있으므로 전체 서버 장애로 볼 수 없음 |
| 첫 A 수집 522줄 | 준비 보고 전 13~14초, dev_error 305건, 재접속 중 준비 보고 권한 거절 | 원본은 B를 같은 파일명으로 수집하면서 덮어씀. 처음 읽은 tool output/선택 시점이 근거 |
| B 기록 346줄 | player heartbeat TimeoutException 28건, dev_error 86건, 각 진입의 12초 대기 우회 | 사용자가 B를 `-Device phone-A`로 수집했다고 확인. snapshot과 phone-B 이름으로 복사 보존 |
| B 설치 APK 읽기 | 준비 APK SHA-256과 동일, version 1.0.0+2/debug | 태블릿/A 설치 해시의 증거는 아님 |

태블릿의 18:32:58 및 19:02:00, A의 18:37:44 및 18:42:20 준비 보고는
새 접속 identity 확인 이전/교체 중에 `permission-denied`를 받았다. 태블릿과 A에는
후속 ready가 성공한 기록도 있다. 서버는 현재 connection ID/seq/connected 및
controller 세션을 검증하므로, 오래된 접속으로 너무 이르게 보낸 보고가 거절되는
경쟁 상태가 유력하다. 구조화 로그에는 서버 `details.reason`이 없어 정확한 거절 조건은
확정하지 않는다. 이를 Firebase IAM/rules 배포 오류로 확대할 근거도 없다.

태블릿의 18:43:40 시작 요청은 8초 뒤 클라이언트 timeout, 이후 재시도는
`already-exists`, 원래 요청은 약 60초 뒤 `deadline-exceeded`다. 뒤의 앱 실행에서
18:46:15/26 및 18:51:29 시작 요청은 반복 `permission-denied`다. 이전 요청이 서버에서
어디까지 반영됐는지와 이 권한 거절 조건은 로컬 기록만으로 확정하지 않는다.

A는 퇴장 시점과 겹치는 공개 구독 오류/빈 private를 받았고 B는 finished 상태를 받았다.
현재 코드에서 명시적으로 ‘게임과 그룹 나가기’를 누른 기기는 그룹 퇴장 경로를,
남아 있는 기기는 종료된 게임 라우트만 닫는 경로를 사용한다. A가 직접 퇴장을 눌렀다면
화면 차이는 설명 가능하다. 버튼을 누른 기기/이유와 최종 route는 로그에 없으므로
QR/로비 차이 자체를 별도 결함이나 정상 판정으로 확정하지 않는다.

태블릿의 마지막 게임에는 ready 이후 한동안 공개 업데이트가 기록되지 않는 반면,
휴대폰에는 barrier와 playing 기록이 있다. 태블릿 로그만 보고 다른 기기의 준비가
계속 실패했다고 해석하지 않는다. 구독/라우트 종료 여부는 현재 기록에 없는 정보다.

## 재현 명령과 결과

조사 단계에서는 제품 파일/기존 테스트를 변경하지 않았다. 아래 진단 harness만 ignored
`build/network-session-investigation/`에 작성했다.

1. `C:\flutter\bin\cache\dart-sdk\bin\dart.exe --disable-dart-dev build/network-session-investigation/budget_probe.dart`
   — **REPRODUCED / exit 0**. 실제 `RoomRecoveryBatch`에 합성 elapsed=31초를 주입했다.
   복구 안에서 생성한 timer에 `current=null`, `inherited=원래 owner`가 남고,
   heartbeat write 0회, 준비 보고 send 0회, retained 준비 제한 0ms를 확인했다.
   Firebase/네트워크 호출은 없다.
2. `C:\flutter\bin\flutter.bat test --no-pub --reporter expanded --timeout 30s --plain-name "DIAGNOSTIC expired lobby recovery budget poisons first game readiness" build/network-session-investigation/readiness_probe_test.dart`
   — **REPRODUCED / 진단 test 1 PASS / exit 0**. 기존 readiness test의 fake query/commands를
   재사용하고 실제 `GameSessionController`에 만료 owner를 주입했다.
   데이터 수신 후 1ms를 진행하고 이미지/프레임 준비를 완료해도 입력 보호가 유지되고
   failed report가 1회 발생하며 ready report가 없음을 확인했다.
   이는 결함 재현 성공이며 제품 수정 PASS가 아니다.
3. 최초 readiness harness는 zero-delay timer가 실행되도록 가상 시각을 진행하지 않아
   기대를 만족하지 못해 **FAIL / exit 1**이었다. 실기기에서 비동기 이미지 준비 전
   시간이 흐르는 조건을 반영해 1ms 진행을 추가했다. 제품 코드 변경은 없다.
4. 기존 APK ZIP 읽기 검사 **PASS / exit 0**. Flutter가 공백을 `%20`으로 인코딩하는
   asset key 기준으로 라이어스포커 이미지 34개 모두 존재한다. debug kernel과
   `game-communication-diagnostics-button` marker도 존재한다. PNG만 확인한 초기
   좁은 검사와 공백 미인코딩 검사는 전체 이미지 판정에 사용하지 않았다.
5. `C:\flutter\bin\flutter.bat test --no-pub --reporter expanded --timeout 30s build/network-session-investigation/diagnostics_sheet_probe_test.dart`
   — **REPRODUCED / 진단 test 1 PASS / exit 0**. 창을 여는 순간 Overlay 오류 3건,
   사라진 opener와 그려지지 않은 닫기 아이콘을 확인했다. 제품 수정 PASS가 아니다.
6. 연결된 B의 `adb -d shell pm path com.warmhandongne.msg`, 그 경로의
   `adb -d shell sha256sum <base.apk>`와 로컬 `Get-FileHash ... -Algorithm SHA256`
   — **READ / 일치 / exit 0**. SHA-256은
   `f62881911d555aa211c9fa5ea9f89af9792b14496d6893c32bd352266e9d81b1`이다.
   첫 sandbox SDK/adb 실행 2건은 launcher/권한 오류 **미실행 / exit 1**이었고,
   승인된 SDK launcher 환경에서 읽기에 성공했다. 앱 데이터 변경은 없다.
7. `C:\flutter\bin\cache\dart-sdk\bin\dart.exe --disable-dart-dev build/network-session-investigation/diagnose_widget_errors.dart`
   — **READ / exit 0**. B의 기존 오류를 `getObject`로 읽고 알려진 오류 종류/위젯 이름만
   반환했다. 최초 expression 조회는 RPCError, 초기 object 탐색 2회는 FieldRef에
   staticValue가 없어 NoSuchMethodError로 **진단 도구 실패 / exit 1**이었다.
   full Field를 추가 조회하는 것으로 도구를 보정했다. 최종 read와 이름 확인 모두 exit 0.

APK 파일 존재만으로 디코딩 성공을 입증하지 않는다. B 설치 후보 일치는 별도의 해시
검사로 확인했으며, 이미지 디코딩 실패를 정상 시작 실패의 원인으로 확정하지 않았다.

## 로그 수집과 남은 확인

현재 APK 코드에는 오른쪽 아래 심전도 진단 버튼/기록 복사가 있으나 사용자는 버튼이
없다고 보고했다. B 설치 후보 일치와 실제 진단 창 Overlay 결함은 확인했다.

같은 PC의 ignored `build/network-session-investigation/collect_device_log.ps1`은 실제 기기
한 대만 USB로 연결한 뒤 앱 version/debug flag와 `game_comm` / `room_connection` /
`dev_error` 구조화 로그만 수집한다. 기본은 기존 logcat buffer 조회이며, `-Live`만
새 증상을 관찰하는 동안 수집한다. 앱 삭제/데이터 초기화/재빌드가 필요하지 않다.
별도의 담당자 진단이며 [사용자 조작 목록](../operations/NETWORK_SESSION_REAL_DEVICE_TEST.md)에
서버/로그 항목을 추가하지 않는다.

태블릿/A/B의 수집으로 게임명, heartbeat 실패, 초기 준비 지연과 진단 창 오류를 확인했다.
A/B의 서로 다른 퇴장 화면과 자리 배치 통신 실패를 위 결함만으로 확정하지 않는다.
운영 DB/실행 로그 조회·재배포·FULL·APK 재빌드는 하지 않았다.

다음 제품 수정에서는 heartbeat timer가 완료된 작업 Zone의 owner를 사용하지 않도록 하고,
대기실/새 게임/실제 복구 episode의 준비 제한 경계를 분리한다. 라이어스포커의 준비
barrier와 손패 대기를 분리하고 진단 창에는 Tooltip에 필요한 Overlay를 제공한다.
오래된 비동기 요청의 deadline 유지, 한 episode의 timeout 비연장, pause/입력 보호는
유지해야 한다.
실제 `RoomService` 호출을 포함한 30초 이후 heartbeat와 지연된 게임 진입 회귀가 필요하다.
제품 수정/회귀는 원래 브랜치에 별도 커밋, emulator/CI 설정은 기존 테스트 브랜치에 둔다.
수정 시 구현 skill·관련 suite와 후보별 승인 FULL 절차를 적용한다.

조사 시작 branch `codex/e01-validation-wiring`, HEAD `ad2ace7`.
기존 사용자 변경은 `docs/operations/NETWORK_SESSION_REAL_DEVICE_TEST.md`의 메모이며 보존했다.

최종 문서 점검: 조사 문서 local 링크 14개/누락 0/줄 끝 공백 0, scoped
`git diff --check -- docs/planning/TASKS.md docs/planning/logs/2026-10.md`
**PASS / exit 0**. branch/HEAD는 유지됐다. 시작 때의 변경 4개 외에 조사 중
`AGENTS.md`, `docs/operations/FIREBASE_MCP.md`, 새 `docs/operations/FIREBASE_SERVER_LOGS.md`
변경이 나타났으며 이 조사에서 만든 변경이 아니다. 새 지침을 읽고 그대로 보존했다.
이 조사 소유의 tracked/unignored 변경은 TASKS/월 기록/조사 문서뿐이며 제품 소스,
기존 테스트, dependency, lockfile, CI 설정에는 변경이 없다.

## 2026-10-09 사용자 요청 후 수정 후보

사용자의 `코드 수정해` 요청으로 같은 브랜치/HEAD에서 다음 클라이언트 후보를 작성했다.
서버 데이터 모양·callable·dependency·게임 규칙은 변경하지 않았다.

- `RoomProvider`: 복구 await가 끝난 바깥 Zone에서 heartbeat와 완료 알림을 시작한다.
  UID/방/수명/연결 세대/퇴장 확인 뒤에만 시작하며 늦은 operation의 원래 deadline은 유지한다.
- `GameSessionController`: 첫 게임은 대기실의 오래된 준비 owner를 버리고, 이미 준비된
  게임의 새 pause는 새 owner를 사용한다. 같은 pause의 barrier/dataSeq 변경과 진행 중인
  준비 대기는 같은 제한을 유지한다. 데이터/새 pause만으로 sticky failure를 풀지 않는다.
- 라이어스포커: dealing 공개 상태로 에셋 준비를 시작한다. 실제 손패 화면 진입 gate와
  진행 중 게임의 공개/본인 private 대응 확인은 유지한다.
- debug 진단 창: `MaterialApp.builder` 아래 별도 Overlay를 제공해 Tooltip/복사/지우기/닫기를
  정상 렌더링한다. 기록 갱신과 다시 열기를 함께 확인한다.

회귀는 실제 `RoomService` identity/write 경로의 태블릿·휴대폰 heartbeat를 wall-clock
32초 뒤에도 확인하고, 만료 대기실 owner·active 복구 owner 공유·후속 pause·barrier 변경·
준비 소진/늦은 데이터·최초 구독 실패·LP dealing/기존 게임 손패를 확인한다.
기존 session suite에 관련 회귀를 등록했으며 별도 suite는 추가하지 않았다.

초기 guarded session은 Flutter 96 PASS/2 FAIL, Functions 73 PASS, mutation PASS로
전체 **FAIL/exit 1**이었다. 32초 heartbeat와 진단 창은 통과했다. 같은 pause의 준비 owner를
유지하도록 수정했고 LP fixture를 실제 `hand/{cardId}/rank` 모양으로 보정했다.
직접 관련 재검사에서는 LP 테스트의 미완료 준비 timer가 남아 **FAIL/exit 1**이었다.
실제 화면 준비/프레임까지 검증하는 것으로 harness를 완성한 뒤 4개 관련 파일
37개 테스트 **PASS/exit 0**이다. 모두 3분 외부 deadline/cleanup 확인을 사용했다.
10개 변경 Dart 파일 format은 **PASS/exit 0**이며 최초 sandbox 실행은 포맷 이후
SDK telemetry 권한 오류 **exit 1**로 끝났다. 허용된 SDK 환경에서 재확인했다.
변경 파일 분석은 test reference의 `@override` 누락 1건 **exit 1**을 확인해 보정했다.

후속 guarded session은 선택 Flutter/Functions 73개 및 mutation까지 5단계
**PASS/exit 0**이었다. 바깥 PowerShell의 stderr/CLIXML 수집에는 parsing 오류가 있었으나
guard가 실행한 CLI JSON은 모든 step의 PASS/exit 0·timeout 없음과 mutation PASS를 반환했다.
검증 배선/guard 소스는 바꾸지 않았다. 포맷 1회는 mapped-file 쓰기 경고가 있어
해당 줄을 직접 정리하고 마지막 읽기 전용 format으로 10개 파일 변경 필요 0/exit 0을 확인했다.

마지막 검토에서 복구 시작 때의 controller token을 캡처하고, 무효화된 복구 완료가
player heartbeat를 시작하지 못하게 했다. 후속 회귀의 최초 harness는 중복 dispose 오류와
같은 파일의 가상/실제 시계 수명 혼용으로 1개 test timeout을 냈다(**FAIL/exit 1**, 외부
3분 timeout 아님, cleanup 확인). 두 heartbeat 회귀를 실제 시계로 통일하고 정리를 한 번만
수행한 후 다음 3개 파일 21개 테스트 **PASS/exit 0**을 확인했다.

| 검사 | 실제 command/범위 | 결과 |
| --- | --- | --- |
| session | `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\invoke_mosigame.ps1 test session --json` | PASS, 5/5 step, exit 0 |
| 준비/LP/목록 | `flutter test --no-pub --reporter expanded` + `game_readiness_contract_test.dart`, `startup_readiness_test.dart`, `test_suites_test.dart`, `package_test_manifest_test.dart` | 37 PASS, exit 0 |
| 최종 연결 | `flutter test --no-pub --reporter expanded` + `room_recovery_heartbeat_test.dart`, `controller_room_lifecycle_test.dart`, `room_leave_state_test.dart` | 21 PASS, exit 0 |
| 최종 분석 | `flutter analyze --no-pub` + 아래 10개 변경 Dart 파일 | 문제 0, exit 0 |
| 최종 포맷 | `dart format --output=none --set-exit-if-changed` + 같은 10개 파일 | 변경 필요 0, exit 0 |

직접 Flutter 검사는 ignored `build/network-session-investigation/run_flutter_check.dart`가
tracked `SystemProcessRunner`로 SDK launcher 전부터 3분 deadline과 정확한 child cleanup을
제공했다. FULL을 대신하지 않는다. 관련 37개 성공은 tool output에 남았고 이후 log artifact는
덮어쓰므로 최종 연결/분석 파일과 혼동하지 않는다.

변경 Dart 파일은 제품 4개(`RoomProvider`, `GameSessionController`, LP controller,
`DevErrorOverlay`), 회귀 4개(heartbeat, 진단, game_kit readiness, LP startup),
session manifest와 manifest 회귀 2개다. 문서는 공용 수명 계약의 구현 설명·이 기록·TASKS·
SESSION/TEST 상세·월 기록을 갱신했다. 기존 사용자 변경 4개(AGENTS, Firebase MCP,
실기기 메모, 새 server log 절차)를 그대로 보존했다.

branch `codex/e01-validation-wiring`, HEAD `ad2ace7c3f0d67e73c3ba0fc57d49395d7f4ad1d` 유지,
시작/최종 staged 없음. 후보는 unstaged/untracked이며 예상하지 못한 제품·lockfile·dependency·
CI 변경은 없다. 최종 `git diff --check`는 **PASS/exit 0**, 변경 문서 6개의 local 링크는
149개/누락 0이다. 작업 목록/상세/월 기록을 수정 후보·승인 FULL 대기로 갱신했다.
태스크 완료를 선언하지 않았다.

후속 사용자 승인으로 아래 FULL을 실행했다. 수정 APK 빌드·설치·
실기기 재확인은 미실행이다. 시작 callable의 timeout/권한 거절과 A/B 퇴장 route 차이를
모두 해결했다고 확대하지 않는다. 운영 접근/배포/커밋/푸시는 하지 않았다.

### 후속 사용자 승인 FULL 결과

사용자의 `승ㅇ` 답변을 승인으로 확인하고 현재 후보에 Windows guarded
`.\tool\invoke_mosigame.ps1 validate --full --json`을 **1회** 실행했다.
2026-10-09 20:24 KST 시작, CLI duration 583234ms, **PASS/exit 0**, 12/12 단계다.
모든 process step exit 0, timeout 없음, 마지막 working-tree-mutation PASS다.

| 단계 | 결과 |
| --- | --- |
| preflight | PASS |
| dart-format | PASS, 149개 파일 변경 필요 0 |
| flutter-analyze | PASS, 문제 없음 |
| flutter-test | PASS, 앱 337개 |
| flutter-test-game-kit | PASS, 70개 |
| flutter-test-game-liars-poker | PASS, 4개 |
| flutter-test-game-final-call | PASS, 14개 |
| flutter-test-game-mafia | PASS, 55개 |
| flutter-test-game-holdem | PASS, 31개 |
| functions-lint | PASS |
| functions-test | PASS, 371개/skip 0 |
| working-tree-mutation | PASS, 실행 전후 동일 |

5 package 합계 174개다. 기기/production 확인과 실제 CI 재실행을 뜻하지 않는다.
검증 JSON은 ignored `build/network-session-investigation/fix-full-approved-result.json`에
보존했다. FULL 중 source/doc를 수정하지 않았으며 끝난 뒤 승인/결과 기록만 갱신했다.
기존 사용자 변경 4개는 FULL 전후 SHA-256이 같았다. branch/HEAD/staged 상태는 유지했다.
실기기 정상 시작 결과는 기존 FAIL에서 바꾸지 않는다. 다음 행동은 수정 APK/기기 재확인과
미확정 시작 요청/퇴장 route의 추가 증거 수집이다. SESSION 전체 출시 판정은 남아 있다.

## 2026-10-09 — 정상 준비와 실제 오류 UI 분리 후보

사용자 후속 요청과 첨부 화면에 따라 정상 진입·카드 분배·데이터 준비는 기존 배경과
연출을 유지하고, 별도 안내창/퇴장 버튼을 띄우지 않도록 수정했다. 실제 네트워크 오류와
게임 준비 실패는 기존 UI로 알리고 나가기는 기존 메뉴·퇴장 모달을 사용한다.
이 UI 정책은 사용자 요청으로 승인됐으며 서버 준비 barrier·데이터 shape·명령 권한은 변경하지 않았다.
앞 절의 승인 FULL은 이전 시작 실패 수정 후보에 대한 결과이며 이번 UI 후보의 FULL을 대체하지 않는다.

### 변경 파일과 동작

- 공용 [GameRecoveryLayer](../../packages/game_kit/lib/recovery/widgets/game_recovery_layer.dart)는
  causes/기존 playerUid가 없는 준비 pause를 표시하지 않고 실제 오류만 기존 GameRequestNotice로 표시한다.
  GameConnectingOverlay를 게임 진입 경로에서 제거하고 별도 퇴장 버튼을 생성하지 않는다.
  본인 준비 실패와 서버 중단이 겹쳐도 오류 안내/재시도는 한 곳에서 처리한다.
- [GameInterruptionLayer](../../packages/game_kit/lib/recovery/widgets/game_interruption_layer.dart)는
  실제 사고만 표시한다. 휴대폰은 기존 오류 안내를 사용하고 태블릿의 제외·한 번 연장·종료 확인은 유지한다.
  태블릿 실제 중단의 배경을 불투명 navy로 교체하지 않고 기존 scrim을 사용한다.
- [GameSessionController](../../packages/game_kit/lib/recovery/providers/game_session_controller.dart)는
  준비 실패를 기존 errorMessage에 전달한다. 늦은 데이터가 실패 문구만 지우지 않으며,
  명시 재시도에서 문구를 닫는다. 기존 실패 보호·30초 제한·준비 보고 계약은 유지한다.
- [PhoneGameShell](../../packages/game_kit/lib/game_flow/phone_game_shell.dart)은
  대기 안내를 생성하지 않는다. 게임 content만 canSend로 차단하고 기존 상단 메뉴는 유지한다.
  초기 준비 실패에도 기존 메뉴를 표시한다. 기존 public constructor 필드는 호환을 위해 유지한다.
- LP [board](../../packages/game_liars_poker/lib/phone/src/board_state.dart)와
  [게임 화면](../../packages/game_liars_poker/lib/phone/screens/game_screen.dart)은 초기 실패에도
  기존 메뉴를 사용할 수 있게 연결했다. [세로](../../packages/game_liars_poker/lib/phone/screens/game_screen/portrait_view.dart)/
  [가로](../../packages/game_liars_poker/lib/phone/screens/game_screen/landscape_view.dart)의 별도 중복 오류 표시는 제거했다.
  [controller](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart)의 카드 선택·제출/LIAR/FOLD는
  서버/로컬 준비가 완료된 경우에만 허용하며 ready ack 변화도 기존 화면 State를 유지한 채 반영한다.
- [Final Call](../../packages/game_final_call/lib/phone/src/board_state.dart),
  [Mafia](../../packages/game_mafia/lib/phone/src/board_state.dart),
  [Holdem](../../packages/game_holdem/lib/phone/phone_board.dart)은 셸의 별도 퇴장 콜백 배선을 제거하고 기존 메뉴를 사용한다.
- [공용 UI 회귀](../../packages/game_kit/test/recovery/widgets/game_recovery_layer_test.dart),
  [결정/퇴장 회귀](../../packages/game_kit/test/recovery/widgets/interruption_decision_contract_test.dart),
  [재시도 안내 회귀](../../packages/game_kit/test/recovery/retry_budget_and_notice_test.dart),
  [준비 회귀](../../packages/game_kit/test/recovery/providers/game_readiness_contract_test.dart),
  [LP 시작 회귀](../../packages/game_liars_poker/test/shared/providers/startup_readiness_test.dart)를 보완했다.
  [session suite](../../tool/mosigame_cli/test_suites.dart)와 [정확한 manifest 회귀](../../test/mosigame_cli/test_suites_test.dart)에
  공용 UI/결정 회귀 두 파일을 등록했다. 새로운 suite/dependency/public API/persistent data는 추가하지 않았다.
- 현재 UI 계약은 [Network Session Contract](../engineering/NETWORK_SESSION_CONTRACT.md)에 반영했다.

### 관련 검사와 현재 판정

Windows 경로와 exit 의미는 [Project CLI](../engineering/PROJECT_CLI.md)를 따른다.

| 실제 command | 결과 |
| --- | --- |
| SDK Dart → bounded run_flutter_check.dart → flutter test --no-pub --reporter expanded: 공용 UI/결정/재시도/준비·LP 시작·board/manifest 7개 파일 | 초기 55 PASS/exit 0, timeout 없음 |
| `.\tool\invoke_mosigame.ps1 test session --json`: 첫 UI 후보 | FAIL/exit 1: Flutter 카드 선택 보호 1건, Functions 73 PASS, mutation PASS |
| SDK Dart → bounded run_flutter_check.dart → flutter test --no-pub --reporter expanded packages/game_liars_poker/test/shared/providers/startup_readiness_test.dart | 누락된 canSend 조건 반영 뒤 관련 3 PASS/exit 0, timeout 없음 |
| `.\tool\invoke_mosigame.ps1 test session --json`: 최종 UI 후보 | PASS/exit 0, 5/5 단계, 17개 Flutter 파일·Functions 8개 파일/73 tests, mutation PASS, 83938ms |
| SDK Dart → bounded run_flutter_check.dart → flutter analyze --no-pub: 변경 implementation·관련 test/manifest 경로 11개 | PASS/exit 0, No issues found, 12.1s |
| SDK Dart format --output=none --set-exit-if-changed: 위 source/test/manifest 19개 파일 | PASS/exit 0, 변경 필요 0 |
| git -c core.excludesFile= diff --check | PASS/exit 0 |

실제 선택 테스트가 준비/서버 pause/오프라인 보호 누락을 잡았다. 해당 조건을 반영한 뒤
실패 회귀부터 다시 확인하고 마지막 안내 중복/재시도를 포함한 최종 session을 실행했다.
검사 source를 실행 중 수정하지 않았으며 마지막 작업 기록은 검사 종료 후 갱신했다.
ignored 근거: build/network-session-investigation/ui-session-initial-result.json,
ui-session-final-result.json, ui-final-analysis.log. 기록의 파일 이름은 실행 명령에 포함한 경로다.

시작/최종 branch는 codex/e01-validation-wiring, HEAD는 ad2ace7c3f0d67e73c3ba0fc57d49395d7f4ad1d이며
staged 없음이다. 이전 시작 실패 수정·기존 사용자 변경을 보존했다.
AGENTS/Firebase MCP/실기기 목록/server log 절차 문서 4개는 이전 기록과 SHA-256이 같고,
canonical session의 실행 전후 tracked/unignored mutation은 PASS다.
검사 뒤 이 기록·task 상태만 갱신했다. commit/push/deploy/production 접근은 실행하지 않았다.

이번 후보의 validate --full은 미실행이며
[Mosigame Implement and Validate](../../.agents/skills/mosigame-implement-and-validate/SKILL.md)의
“ask the user for explicit approval to run `validate --full`” 규칙에 따라 새 명시 승인을 요청한다.
수정 APK 빌드/설치와 실제 태블릿·휴대폰 화면/연결 재확인은 미실행이다.
로컬 관련 PASS를 실제 시작 성공이나 SESSION 전체 출시 판정으로 확대하지 않는다.

### UI 후보 승인 FULL 결과

후속 사용자 “검증해”를 이번 UI 후보의 FULL 승인으로 확인했다.
실행 command: `.\tool\invoke_mosigame.ps1 validate --full --json`.
2026-10-09 21:37 KST 시작, duration 336776ms, **PASS/exit 0**, 12/12 단계다.

- 포맷 149개 파일 변경 필요 0, 전체 분석 No issues found.
- 앱 테스트 337개, game_kit 77개, LP 5개, Final Call 14개, Mafia 55개, Holdem 31개 PASS.
- 5 package 합계 182개, Functions lint 및 테스트 371개/skip 0 PASS.
- 모든 process step exit 0, timeout 없음, working-tree-mutation PASS.
- ignored JSON: build/network-session-investigation/ui-full-approved-result.json.
- branch codex/e01-validation-wiring/HEAD ad2ace7c3f0d67e73c3ba0fc57d49395d7f4ad1d,
  staged 없음 유지. 기존 변경 보존, 실행 중 source/doc 변경 없음.
  검사 종료 후 승인 결과와 task 기록만 갱신했다.
- 수정 APK 빌드/설치·실제 기기 UI/연결 확인·실제 CI 재실행은 미실행이다.
  이 로컬 FULL 결과를 실기기 정상 시작 성공이나 SESSION 전체 출시 판정으로 확대하지 않는다.

<a id="roulette-restart-investigation"></a>
## 2026-10-09 — 진입 성공 후 룰렛·재시작 오류 조사

### 사용자 보고와 기기 근거

사용자는 정상 게임 진입 성공, 기존 준비창/데이터 오류 해소, 로비에서 휴대폰 A의 의도적
인터넷 단절 대응 정상 동작을 보고했다. 이후 LP 룰렛 결과 반영 실패 → 설정에서 게임 종료
→ 로비 단절 시험 → 재시작 설정 완료 시 이미 진행 중 오류를 조사했다.
이 보고는 해당 시나리오에 한정하며 4게임·E14 전체 PASS로 확대하지 않는다.

연결된 휴대폰의 정제 진단 245줄과 사용자가 확인한 태블릿의 정제 진단 417줄을 USB로
읽었다. 기존 파일을 덮어쓰지 않았다. ignored 근거는 아래 두 디렉터리다.

- `build/network-session-investigation/roulette-restart-20261009-220548/`
- `build/network-session-investigation/roulette-restart-tablet-20261009-220658/`

시각은 2026-10-09 KST, 태블릿 진단 기준이다.

| 시각 | 관찰 |
| --- | --- |
| 21:53:18 | 최초 게임 시작 성공 응답, 이후 dealing→playing 수신 |
| 21:54:31 | 룰렛 추첨 성공, safe 결과 수신 |
| 21:54:38 / 21:54:57 / 21:55:18 | 결과 반영이 세 번 모두 permission-denied |
| 21:56:32 | end_game 성공, gameEnded/revision 14, public finished 수신; 휴대폰에서도 finished 수신 |
| 21:58:15 → 21:58:23 | 다음 게임의 첫 시작 요청, 8002ms 뒤 앱 시간초과 |
| 21:58:36 | 다음 시작 요청이 194ms 뒤 already-exists |
| 21:59:15 | 앞선 원격 요청의 deadline-exceeded가 뒤늦게 기록됨 |
| 22:00:07 | 추가 시작 요청도 200ms 뒤 already-exists |

### 1. 룰렛 두 단계의 작업 ID 충돌 — 코드 및 오프라인 재현 확인

[LP command service](../../packages/game_liars_poker/lib/shared/services/command_service.dart)는
preparePenalty의 commandId를 resolutionId로 보관하고 resolvePenalty의 commandId에도
같은 값을 넣는다. [서버 resolve](../../functions/src/liars-poker/finish-penalty.ts)는
현재 resolutionId와 commandId가 같아야 한다고 검사한다.

그러나 [공통 명령 경계](../../functions/src/game-interruption/game-command-transaction.ts)는
두 명령 모두 방의 sessionOperations에 기록하며,
[roomOperationResult](../../functions/src/room/session-contract.ts)는 같은 ID의 kind/payload가
다르면 `permission-denied: 다른 요청에 사용한 작업 ID입니다.`로 거부한다.
정상 추첨 성공 자체가 다음 확정을 거부시키는 충돌이다. 단절을 일으킬 필요가 없다.
태블릿의 세 번 연속 추첨 성공/확정 권한 거부와 일치한다. 기기 로그는 서버 상세 문구를
보존하지 않으므로 배포 서버의 throw 위치를 직접 추적한 것으로 표현하지 않는다.

클라이언트 commandId만 별도로 만들면 현재 서버에서 invalid-argument가 발생한다.
수정 시 추첨 식별자와 요청 식별자를 구분하고, 동일 결과의 재확정 멱등성 및 기존 요청의
처리를 함께 검토해야 한다. 이번 원인 조사에서는 제품 코드/계약을 변경하지 않았다.

### 2. 시작 응답 시간초과 뒤 원래 요청을 이어받지 못함 — 코드 결함 확인

[게임 진입](../../packages/game_liars_poker/lib/game_liars_poker.dart)의 startGame은 호출마다
새 LiarsPokerService/CommandService를 생성한다.
[공통 명령 서비스](../../packages/game_kit/lib/services/game_command_service.dart)의
미확정 요청 보관은 인스턴스 필드 `_unresolved`이고 새 서비스가 이를 공유하지 않는다.
전역 session의 retryCommand에 기존 호출이 남을 수 있지만 자리 설정의 다음 시도는 그
콜백을 사용하지 않고 startGame을 새로 호출한다. 새 GameCommandBatch와 새 commandId가
만들어져 operation_status 확인/동일 요청 재생을 건너뛴다.

[재시도 정책](../../packages/game_kit/lib/recovery/services/callable_retry_policy.dart)의
Future.timeout은 기본 8초이며 원격 작업 취소를 의미하지 않는다. LP startGame은 자동
재전송을 켜지 않았다. [자리 설정](../../lib/platform/home/tablet/tablet_game_launcher.dart)은
예외를 일반 시작 실패로 처리하고, [배치 위젯](../../packages/game_kit/lib/player_layouts/widgets/player_layout_editor.dart)은
다음 설정 완료를 다시 허용한다. 서버에서 처리됐거나 처리 중인 요청을 새 시작으로
취급하게 되는 틈이다. 서버의 동일 요청 재생은 이미 지원된다.

오프라인에서는 수동 종료→다시 선택→자리 설정→새 게임이 정상 성공했고, 새 게임 시작
반영 후 응답을 받지 못한 상황을 구성하면 새 ID는 already-exists, 기존 ID는 성공 재생이다.
재현의 방 status는 별도 미러 trigger가 실행되기 전 seating으로 두었다. 실제 서버의
status/commit 여부를 조회한 것은 아니다. already-exists 문구는 start transaction의
committed=false에 공통으로 붙으므로, 그 문구만으로 정확한 commit 경로를 단정하지 않는다.

이전 게임의 종료 실패를 원인으로 지목할 근거는 없으며 종료 성공은 양 기기 로그로 확인했다.
최초 8초 지연의 원인, 첫 시작의 실제 commit 시점, 배포 서버의 상태·버전은 미확정이다.
서버 내부 경합/콜드스타트/응답 전달 지연 중 하나라고 임의로 단정하지 않는다.
사용자에게 start_game의 21:58:10~22:00:20 KST 오류 문구·처리시간 로그를 요청했다.
production 접근은 실행하지 않았고 gcloud는 현재 PATH에서 찾지 못했다.

### 실행·검증과 후속 범위

| command | 결과 |
| --- | --- |
| `adb -d logcat -d -v time flutter:I *:S` → game_comm/room_connection/dev_error만 보관 | PASS/exit 0, 휴대폰 245줄·태블릿 417줄 |
| `node functions/node_modules/typescript/bin/tsc --project functions/tsconfig.json` | PASS/exit 0, 현재 서버 소스를 ignored lib에 컴파일 |
| `node build/network-session-investigation/roulette-restart-probe.cjs` | PASS/exit 0, 실제 callable .run + 메모리 RTDB로 아래 5개 판정 |

1. 정상 추첨→동일 ID 확정: permission-denied 재현.
2. 클라이언트 ID만 분리: invalid-argument 재현.
3. 수동 종료→선택→자리 설정→새 게임: 성공.
4. 처리된 시작을 새 ID로 다시 요청: already-exists 재현.
5. 원래 시작 요청 재생: 기존 성공 응답, gameInstanceId 유지.

재현은 Firebase 앱을 초기화하지 않고 getDatabase를 메모리 참조로 대체한다. 실제 원격
트랜잭션·이벤트 순서·지연 재현 또는 수정 검증이 아니다. 제품 코드, 정식 test suite,
dependency, 서버 배포는 변경하지 않았다. 이번 조사에는 targeted/FULL을 새로 실행하지 않았다.
기존 FULL은 기존 테스트가 다룬 범위의 PASS로 보존한다. 실제 prepare→resolve 호출 연결과
시작 응답 유실→UI 재시도의 ID 보존 통합 회귀가 없음을 확인했고 후속 보완 대상으로 남겼다.

시작 branch codex/e01-validation-wiring/HEAD ad2ace7c3f0d67e73c3ba0fc57d49395d7f4ad1d,
staged 없음이다. 기존 제품/사용자 변경을 유지하며 이 조사 기록·작업 문서만 갱신했다.
작업 중 사용자 실기기 문서 변경에서 발견한 trailing whitespace는 범위 밖이므로 그대로 보존한다.

### 후속 승인 로그 조회 — 시작 시간초과의 서버 원인 보강

사용자는 일반 로그 열람 권한이 이미 승인됐음을 알리고 직접 CLI 조사를 요청했다.
이후 [서버 로그 절차](../operations/FIREBASE_SERVER_LOGS.md)를 다시 확인하고 별도
mosigame-logs-readonly configuration/project0000-ec01e를 사용했다. PATH에는 없었지만
설치된 gcloud를 발견했다. 위의 미조회/미설치 설명은 그 시점의 기록이다.
계정 이름·인증 자료는 출력하지 않았으며 IAM 변경/추가 권한은 필요하지 않았다.

함수 describe는 permission-denied/exit 1이었다. 이어 기존 Logs Viewer로 일반 로그는
조회 성공했다. 첫 메타데이터 1건에서 실제 service_name `game-liars-poker-start-game`,
location `asia-northeast3`를 확인했고 이후 이 두 값으로 정확히 제한했다.
시간 범위는 2026-10-09T12:58:10Z 이상, 13:00:20Z 미만(21:58:10~22:00:20 KST)이다.

Windows gcloud.cmd 호출에서 필터 전달 2회가 exit 1로 실패했다. 2차는 날짜 문자열의
따옴표 유실로 INVALID_ARGUMENT 구문 오류였다. SDK 실행 파일을 수정하지 않고 gcloud.cmd가
원래 호출하는 bundled Python `-S lib/gcloud.py`를 직접 실행해 필터를 보존했다.
성공 조회의 공통 command는 `gcloud --configuration=mosigame-logs-readonly logging read`
이며 project/위 filter/limit/order/필드 제한을 명시했다. 상세 실행 구분은 다음과 같다.

| 조회 | 제한·결과 | status/exit |
| --- | --- | --- |
| 시작 함수 이름만 좁힌 메타데이터 검색 | limit 1, 1건, service 이름 확인 | PASS/0 |
| 정확한 service/시간의 실행 메타데이터 | limit 99, 13건 | PASS/0 |
| 같은 범위의 요청 access log 제외 오류 필드 | limit 50, 10건, 메모리에서 정제 후 저장 | PASS/0 |
| 기존 insertId 두 건의 오류 분류 확인 | limit 2, 2건 | PASS/0 |
| 기존 좌석 오류 한 건의 안전한 접두부 확인 | limit 1, 1건 | PASS/0 |

성공한 5회가 반환한 27건은 중복을 포함하며 고유 기록은 13건이다. 요청 URL/본문,
private 게임 데이터/계정/토큰은 저장하지 않았다. ignored `build/device-test/`의
start-game-log-metadata-probe.json, start-game-request-metadata.json,
start-game-errors-sanitized.json, start-game-error-classification.json,
start-game-fingerprint-error.json에 정제한 근거를 보존했다.

확인한 서버 사실:

- 21:58:16.268 시작 요청: HTTP 504, latency 59.995304064s. 앱의 8초 제한만 발생한 것이
  아니라 서버 응답 자체도 약 60초 안에 완료되지 않았다.
- 21:58:16.680 같은 service에서 `Exception from a finished function: Error:`와
  `게임을 준비하는 동안 참가자 또는 좌석이 바뀌었습니다. 다시 시도해주세요.`가 기록됐다.
  이 비동기 예외의 execution_id는 현재 요청의 verification 로그와 다르다. 정확히 어느
  과거 실행의 callback인지·어떤 필드가 달라졌는지는 로그만으로 확정할 수 없다.
- 후속 두 시작 요청은 각각 HTTP 409, 서버 latency 0.009720513s와 0.007975078s다.
- App Check 경고에는 enforcement disabled로 허용했다는 기록이 있다. 해당 경고를
  이번 요청 거절/시간초과의 직접 원인으로 판정하지 않는다.

추가 코드 결함:

`startGameFingerprint`가 players 객체 전체를 비교한다. 정상 heartbeat의 lastSeen,
isConnected/접속 정보도 포함된다. `applyRoomPresence`는 정상 연결 갱신 때 플레이어의
lastSeen을 바꾸므로, 실제 좌석·명단이 같아도 시작 중 변경으로 잘못 거부될 수 있다.
기존 게임 상태 검사보다 먼저 호출되는 assertStartGameSnapshot은 transaction callback
안에서 HttpsError를 직접 던진다. runPrimedTransaction에 callback 오류를 저장해 abort
후 밖에서 전파하는 처리가 없다.

설치된 Firebase RTDB SDK의 repoRerunTransactionQueue도 update 예외를 잡아 transaction을
정상 종료하지 않는다. 재실행 도중 예외가 발생하면 완료 callback/rollback/queue 정리까지
도달하지 못할 수 있다. 서버의 finished-function 비동기 예외 + 60초 504 + 후속 409와
일치하는 유력한 실패 경로다. 이때 서버의 로컬 진행 중 캐시 때문에 already-exists가 날
가능성도 있으므로, 앞선 시작이 production DB에 실제 commit됐다고 단정하지 않는다.

오프라인 probe에 두 검사를 추가해 같은 command를 다시 실행했고 **PASS/exit 0, 7개 판정**이다.
정상 lastSeen만 1000→2000으로 바꿔 aborted를 재현했다. 설치된 SDK rerun 함수 본문을 VM에서
실행하고 상태 접근만 대체해, 이 예외가 완료 callback 없이 빠져나가 transaction이 RUN 상태와
기존 currentWriteId를 유지하는 것도 확인했다. 실제 emulator/원격 동시성 재현과는 구분한다.

수정 우선순위는 룰렛 두 단계 ID 계약 정리, 시작 비교에서 정상 heartbeat 제외,
트랜잭션 재실행 예외의 안전한 abort/응답 처리, 시작 미확정 요청의 ID/서비스 수명 보존이다.
정상 roster/seat 변경 보호는 계속 필요하다. 제품 수정·새 정식 suite/FULL·배포는 미실행이다.
