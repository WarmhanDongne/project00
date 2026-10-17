# 게임 시작·재시작 Debug 계측

이 브랜치의 임시 측정 기능이다. `STARTUP_MEASUREMENTS=true`인 Debug 빌드에서만
로컬 진단 확장을 등록한다. Release/Profile과 기본 Debug에서는 비활성이다.
게임 규칙·연출 시간·서버 payload/DB 계약은 바꾸지 않으며 서버 배포는 필요 없다.

2026-10-17 보완판은 진단 protocol/schema **2**다. 기존 Debug 앱과는 수집을 시작하지
않으므로 참여 기기를 모두 새로 빌드·설치한다. 사용자 승인에 따라 새 수집의 기기 간
추정 범위 폭 기준을 **250ms 이하**로 변경했다. 기존 수집·분석의 100ms 판정은 보존한다.

## 측정 기준

| 경로 | 시작 |
| --- | --- |
| initial_start | 자리 배치 `설정 완료` 핸들러가 조작을 수락한 직후, 비동기 처리 전 |
| menu_restart | 메뉴의 실제 재시작 버튼 콜백, 메뉴 닫기 전에 기록 |
| result_restart | 결과 화면 다시하기 콜백, 재시작 요청 전에 기록 |

한 수집에는 한 경로·한 번의 조작만 넣는다. 후속 네트워크 재시도는 같은 조작의
전송 시도로 기록한다. 기존 서버 command ID는 익명 alias로만 연결한다.
설정한 scenario와 별도로 실제 콜백 source와 실제 조작 번호를 기록한다. 오지정이면
경고와 실제 종류를 함께 남기며, 두 번째 실제 조작은 다른 번호로 보존하고 단일 정상
표본에서 제외한다. 요청 응답의 조작 번호는 요청 시작 때의 번호를 유지한다.
최초 앱 실행 후 첫 시작과 프로세스를 유지한 반복 시작은 조건을 구분한다.
초기화 여부를 서버 cold start라고 추정하지 않는다.

태블릿 완료는 새 게임의 `playing` 연출 상태·세션 입력 허용·중단 없음·현재 route
조건을 만족한 프레임이다. 폰 완료는 새 게임 첫 턴 플레이어의 손패가 실제로
선택·드래그 제출 가능하고 복구·모달·공개 연출이 막지 않는 프레임이다.
컨트롤러의 `canSubmitCards` 한 값이나 버튼 표시만으로 완료를 판정하지 않는다.
세로·가로 손패의 실제 선택·드래그 제출 경로를 회귀 테스트로 검사한다.

카드 선택 이전의 준비 상태가 완료점이다. 사용자가 실제 카드를 고르거나 제출하기까지
기다리지 않는다. 다른 사람 차례인 폰은 제출 준비 완료 대상이 아니다.
**전체 완료는 태블릿 완료와 첫 턴 폰 완료 중 늦은 쪽**이다. 첫 턴이 될 수 있는 모든
폰을 수집하지 않았다면 전체 완료가 없을 수 있으며 추정으로 채우지 않는다.

이벤트에는 명령 시작/종료, 실제 전송 시도 시작/응답, 공개·개인 상태 적용,
에셋/화면 준비, 태블릿 stage/배분·라운드 연출 완료, 폰 stage/카드팩 진입·공개·
컨트롤 진입, 입력 조건과 사용자 탭이 들어간다. 상태와 응답의 도착 순서를 강제하지 않는다.
폰 단계 `phone_stage`와 태블릿 `tablet_stage`의 숫자는 각각 해당 Stage enum index다.
`phone_gate`: 선택=1, 제출=2, 첫 턴=4, route/복구/foreground 허용=8.
`hand_gate`: 실제 손패 선택=1, 드래그 제출=2. 두 gate가 모두 만족해야 최종 완료다.

태블릿 중앙 덱은 기존 동작대로 등장 중에도 탭을 받는다. `tablet_deck_tappable_frame`
→ `tablet_deck_tap_accepted`는 원시 조작 대기이며 등장 연출과 겹칠 수 있다.
별도 `tablet_deck_entry_started/completed`, `tablet_deal_started`,
`tablet_deal_animation_completed`, 서버 완료 콜백 `tablet_deal_completed`를 남긴다.
등장 중 탭은 사용자 단독 대기로 빼지 않는다. 새 게임의 참여자 수와 수집한 폰 수가
일치하는지도 검사한다. 실제 선공의 완료 기록이 없으면 다른 폰으로 대체하지 않는다.
태블릿 탭 수락·실제 배분 시작은 발생할 때마다 기록한다. 연속 탭이나 배분 재시작을
한 번으로 숨기지 않고, 중복된 시도는 단일 정상 표본에서 제외한다.

## 수집 준비와 실행

1. 변경한 앱을 **모든 기기**에 새로 빌드·설치한다. 예:

   ```text
   flutter run --debug --dart-define=STARTUP_MEASUREMENTS=true -d <device>
   ```

   설치되어 있던 Release APK에는 계측이 없다. 테스트 중 hot reload/restart,
   breakpoint, 앱 background 전환을 하지 않는다. VM service는 로컬 USB 경로만 이용한다.
2. 그룹 참여·게임 선택·자리 배치 등 시작 버튼 전 단계까지 준비한다. 결과/메뉴 재시작은
   해당 버튼을 누르기 전 상태에서 준비한다.
3. PC에서 Python 3의 표준 라이브러리 수집기를 실행한다. 아래 serial 값은 각 기기의
   로컬 ADB 식별자이며 저장 결과에는 넣지 않는다.

   ```text
   python tool/startup_measurements/collect.py --scenario initial_start --condition first_after_launch --device tablet=<serial> --device phone_A=<serial> --device phone_B=<serial> --duration 180 --pilot
   ```

   다른 경로는 `menu_restart` 또는 `result_restart`로 바꾼다. 참가 폰은 모두 지정한다.
   앱 프로세스를 유지한 반복 조작은 `--condition repeated`로 기록한다.
   `first_after_launch`는 모든 앱을 새로 실행한 경우에만 지정한다. 이 조건은 사용자
   선언이며 설치 APK·캐시·서버 cold start의 자동 증명이 아니다.
   ADB가 PATH에 없으면 `--adb <adb.exe 경로>`를 지정한다.
4. **`COLLECTING: all devices armed`가 출력된 뒤에만** 시작/재시작 버튼을 한 번 누른다.
   앱 clock 교환과 익명 ID 설정이 그 전에 끝난다. 단말 간 alias는 수집마다 바뀐다.
   protocol과 사전 시계 품질이 맞지 않으면 arm 전에 실패한다. 연결 확인·시계 교환은
   기기별로 병행하고 로컬 HTTP 연결을 재사용한다. 실행 중에도 반복 교환을 유지한다.
5. 카드팩은 평소처럼 누른다. 첫 턴 폰에서 실제 카드 선택·제출이 되는지도 예비 테스트에서
   확인한다. `PROGRESS`의 태블릿/선공 폰 완료와 대기 계산 가능 여부를 확인한다.
   예비 시험(`--pilot`)은 완료 뒤 실제 카드 선택·제출 콜백 성공까지 남아야 통과한다.
   완료 후 Ctrl+C 또는 안내된 수집 폴더에 `stop.request` 파일을 만들어 종료한다.
   시간 제한까지 기다려도 종료되지만 완료 후 오래 두지 않는 편이 좋다.
6. 다음 조작은 수집기를 다시 실행해 새 수집으로 진행한다. 기존 수집에는 재-arm할 수 없다.

수집기는 Android Debug 앱의 logcat에서 VM 주소만 메모리로 찾고 자신의 ADB forward를
만든 뒤 진단 확장에서 구조화된 이벤트를 받는다. logcat 원문을 파일에 쓰지 않는다.
다른 Flutter 앱에는 측정 확장이 없어 수집을 거절한다. 진단 연결/앱 재시작/로그 유실이
생기면 실패 기록을 남긴다. 수집 종료 시 자신이 만든 forward만 제거한다.

## 결과 해석

고유한 `artifacts/performance-captures/debug-game-start-.../` 폴더에 다음을 저장한다.

- `REPORT.md`: 유효/미완료 판정과 전체·대기 제외 시간, 명령 시간.
- `events.sanitized.jsonl`: 기기별 단조 시각·순번·동작·익명 게임/요청 연결.
- `summary.json`: 시계 범위·논리 명령/개별 전송 시도·사용자 대기와 계산 결과.
- `manifest.json`, `integrity.json`: 수집 조건과 해시. 로컬 보관이며 외부 백업을 뜻하지 않는다.

manifest의 HEAD·소스 해시는 수집 PC의 working copy 기록이며 설치 APK의 동일성 보장은 아니다.
예비 테스트에서는 해당 소스로 모든 기기를 새로 빌드·실행했는지 확인한다.

논리 명령 시간에는 identity 확인·저장·재시도·정리까지 포함된다. 실제 전송 시도 왕복은
`transport_attempt_round_trips`로 분리한다. 이 왕복에도 SDK/Auth·네트워크·서버가 포함되며
순수 네트워크 시간이라고 부르지 않는다. 서버 중앙값을 여기서 빼지 않는다.

사용자 체감 시간은 시작부터 전체 준비 완료까지다. 카드팩의 탭 가능~실제 탭 전체를
무조건 빼지 않는다. 태블릿·선공 폰의 foreground/현재 route/세션 gate가 열리고 관련
게임 명령이 없는 구간에서, 한쪽이 탭을 기다리고 다른 쪽도 관측상 자동 작업 없이
대기하거나 준비 완료인 구간의 교집합만 제외한다. 태블릿 덱 등장과 폰 진입·공개
연출은 대기가 아니다. 두 기기의 탭 대기가 겹치면 합집합으로 한 번만 뺀다.
다른 쪽 유휴 구간 안에 온전히 들어간 것이 시계 범위로 증명되는 대기는 같은 기기의
단조 시계 차이와 200ppm 드리프트 여유를 써 불필요한 오차 확대를 피한다. 나머지는 보수적 범위로
계산한다. 분류에 필요한 gate가 없거나 제외 후 범위 폭도 250ms를 넘으면 제외값은
`null`이다. 다른 폰의 무관한 대기를 더해서 빼지 않는다.
대기 제외값은 관측 구간의 분류이지 즉시 탭한 가상 실행이나 CPU 실행 시간은 아니다.

같은 앱 안에서는 하나의 Stopwatch를 쓴다. 기기 간에는 host 단조 시계와 앱 시계를
왕복 교환해 범위로 환산한다. 200ppm 드리프트 여유와 기기당 5ms 여유를 적용한
**추정 범위**이며 인증된 물리 시계 오차 보장이 아니다. 전체 범위 폭 250ms 초과,
동기화 불일치, process 교체, 동작 중복/세대 불일치, 관련 이벤트 누락은 전체 값을
미측정 처리한다. 이미 확보한 로컬 구간과 실패 자료는 보존한다.

`session_blockers`는 localUsable 미충족=1, transport 미연결=2, transport 복구 중=4,
진행 기기 불가=8, serverConfirmed 미충족=16, paused=32, leaving=64의 합이다.
`canSend=false`만으로 연결 오류라고 분류하지 않는다. 짧은 revision 재검증도 이유와
기간을 보존한다. `command_error`는 고정된 callable 오류 코드 번호만 기록한다.
순서는 unknown/cancelled/invalid-argument/deadline-exceeded/not-found/already-exists/
permission-denied/resource-exhausted/failed-precondition/aborted/out-of-range/
unimplemented/internal/unavailable/data-loss/unauthenticated (0~15)다. 원문·details는
버린다. `submit_result=1`은 실제 제출 콜백의 성공 반환이며 서버 내부 로그를 뜻하지 않는다.

Debug 값은 Release의 프레임 속도·부드러움을 대표하지 않는다. 앱 프레임 경계이며
손가락 접촉 시각이나 디스플레이 발광 시각을 직접 측정하지 않는다.

UID·방 코드·실제 게임/command ID·손패·원문 오류·ADB serial·진단 URI/인증 코드·
capture key는 파일에 저장하지 않는다. 새 dependency나 운영 로그 조회를 필요로 하지 않는다.

## 예비 검증과 본 테스트

최초 시작/메뉴 재시작/결과 재시작을 각 1회 `--pilot`으로 예비 실행한다. alias 연결, 실제 선택·제출,
이벤트 순번/유실, 전체 시간의 시계 품질을 확인한다. 카드팩을 즉시 누르는 경우와
의도적으로 약 5초 기다리는 경우를 비교해 사용자 대기 분류를 검사한다. 태블릿과 폰의
탭을 각각 검사하되 등장·통신과 겹친 시간까지 5초로 빼도록 강제하지 않는다.
예비 검증이 실패하면 본 테스트를 반복하기 전에 계측을 고친다. 정상 반복은 경로별 우선
5회로 시작하고 기기·참가자 수·네트워크·앱 실행/방 유지 조건을 같게 기록한다.

첫 계측판의 실기기 자료 분석에서 태블릿 탭 누락·선공 폰 미수집·시계 품질 문제가
확인됐다. 이 보완판의 자동 검증·빌드 결과는 작업 기록으로 남긴다. 사용자가 임시
계측 브랜치이므로 FULL 생략을 명시해 FULL은 실행하지 않는다. **보완판의 모든 기기
설치·예비 수집 통과 전에는 본 테스트 준비 완료로 선언하지 않는다.**
