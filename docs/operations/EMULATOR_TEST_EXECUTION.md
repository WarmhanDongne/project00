# Codex가 직접 실행하는 Android Emulator 테스트 준비

작성일: 2026-10-04  
기준: [개발 전 테스트 62개](PRE_DEVELOPMENT_AUTH_NETWORK_SESSION_TEST.md)  
현재 상태: **테스트 전용 RTDB 지역 전략 승인·로컬 연결 구현 / APK·로컬 이메일 로그인·서버 startup·네 RTDB trigger smoke 확인 / 제품 테스트는 62개 모두 미실행**

## 현재 확인한 환경

- Windows, Node 22.23.2, Firebase CLI 14.27.0, Android Emulator 36.6.11.0.
- ADB와 `Medium_Tablet`·`Pixel_7a` AVD가 설치돼 있다.
- 조사 시작 당시 연결된 기기 0대. 호스트 메모리 15.8 GiB, logical processor 8개.
- 최초 ADB 조사 당시에는 Auth/RTDB/Firestore/Functions/Storage 로컬 연결 코드가
  없었다. 이후 사용자가 테스트 전용 RTDB 지역 전략을 승인했고, opt-in Android
  debug 연결과 로컬 backend 준비 코드를 추가했다. 생성된 운영 Firebase options와
  `firebase.json/.firebaserc`는 그대로다. 기존 운영 APK를 제품 테스트용으로 실행하지 않았다.
- 현재 후보의 debug APK 생성, 병합 manifest, 설치·앱 startup, 합성 A 계정의 로컬
  이메일 로그인 후 홈 진입과 다섯 로컬 서버 startup을 확인했다. 네 RTDB trigger는
  최초 실패 원인을 고친 뒤 실제 이벤트 probe를 재실행해 확인했다. 아래 smoke evidence와
  62개 제품 시나리오의 결과는 별도다.
- Android 제어 확인에는 기존 AVD 데이터와 다른
  `build/emulator_lab/control-smoke-20261004` 디렉터리를 사용했다.
  `-read-only -no-snapshot -data <새 파일> -datadir <새 디렉터리>`로 부팅했다.
  기존 AVD를 wipe하거나 저장 snapshot을 덮어쓰지 않았다.

## 제가 수행할 실행 방식

게임 UI는 제가 각 역할의 캡처를 읽고 ADB로 조작하며 결과를 판정하는 방식으로 진행한다.
현재 controller는 탭·Back·Home을 지원한다. 설치·앱 실행·로그인 smoke에는 별도로
확인한 emulator serial에 raw ADB를 사용했다. 재실행·역할별 연결 장애·화면 확대와
게임 assertion은 아직 controller 기능으로 제공하지 않는다.
버튼 좌표는 직전 화면에서 확인하고 화면이 바뀌면 다시 읽는다.
연결 장애는 Wi-Fi/data 토글 명령만으로 성공 처리하지 않고 해당 client 연결·서버
관측과 함께 입증한다. 화면 캡처 성공이나 조작 전송 성공은 제품 테스트 통과가 아니다.

현재 [ADB controller](../../tool/emulator_lab/adb_controller.mjs)는 다음만 지원한다.

```powershell
node tool/emulator_lab/adb_controller.mjs devices
node tool/emulator_lab/adb_controller.mjs capture emulator-5580 build/emulator_lab/run01/before.png
node tool/emulator_lab/adb_controller.mjs tap emulator-5580 350 1357
node tool/emulator_lab/adb_controller.mjs back emulator-5580
node tool/emulator_lab/adb_controller.mjs home emulator-5580
node --test tool/emulator_lab/adb_controller.test.mjs
```

각 tap 좌표는 예시다. 직전 캡처에서 실제 버튼 위치를 읽어 입력한다.
이 도구는 실제 휴대폰 serial, 임의 shell action, 기존 캡처 덮어쓰기와
`build/emulator_lab` 밖 저장을 거절한다. 연결 상태와 `ro.kernel.qemu=1`을 확인한다.
현재는 앱 설치·실행·네트워크 제어·게임 assertion을 지원한다고 주장하지 않는다.

첫 `exec-out screencap` 결과는 PNG 헤더가 있었지만 실제 픽셀이 불완전했다.
증거로 사용하지 않고 파일 전송 방식으로 바꿨다. 새 controller는 완전한 PNG chunk와
압축 해제된 픽셀 크기를 검사한 뒤에만 CAPTURED로 보고한다.
이미 만들어진 불완전 캡처 01/02는 제품 근거로 사용하지 않는다.

이번 제어 smoke에서 `sys.boot_completed=1`, 1080x2400 화면의 파일 전송 캡처를
확인했다. 최초 Android System UI 대기창의 Wait 위치를 관찰해 탭했고 이후 홈 화면으로
전환된 캡처를 직접 읽었다. Android 첫 부팅의 System UI 지연은 제품 오류가 아니다.
4개 Node 안전 검사 PASS(exit 0)와 분류표의 62개 ID/45·14·1·2 집계 PASS(exit 0)를
확인했다. 이는 최초 ADB 제어 smoke 기록이다. Mosigame APK·backend 실행 evidence는
아래에 별도로 기록했다.

## 실제 로컬 smoke evidence

실행 ID: `firebase-smoke-20261004-A`. 앱 설치·로그인은 한 대의 Android emulator에서
수행했다. 제품 62개 중 실행한 시나리오는 **0개**다. 정상 방 생성·참가와 게임 시작,
네트워크 장애·재접속은 아직 이 smoke의 검증 범위가 아니다.

| 실제 명령·확인 | status / exit / 근거 |
| --- | --- |
| `flutter build apk --debug --no-pub --dart-define=MOSIGAME_EMULATOR_LAB=true` | PASS, exit 0; 1273.4초 |
| 생성 APK | `build/emulator_lab/firebase-smoke-20261004-A/mosigame-lab.apk`; SHA256 `7B1D3672D62E87191C8553DDDE983A0CE9535E3F2A5D5ADD4417BE8C351C943B` |
| 병합 manifest 확인 | `FirebaseInitProvider` 제거, Crashlytics·Analytics 수집 flag 둘 다 `false` 확인 |
| raw ADB 설치·앱 실행 | 설치 exit 0; 실제 앱의 demo project 준비 로그 확인 |
| 합성 A 계정의 로컬 이메일 로그인 | 홈 진입 캡처 `build/emulator_lab/firebase-smoke-20261004-A/23-login-stable.png` 확인; 이메일 링크·신규 온보딩 시나리오 결과는 아님 |
| native Google 버튼 | 테스트 환경에서 외부 인증을 차단하는 안내만 관찰; Google 인증 성공·취소 검증은 미실행 |
| `.\tool\emulator_lab\start_local_backend.ps1` | Auth/Database/Firestore/Functions/Storage 다섯 서비스 startup 확인 |
| `node tool/emulator_lab/local_backend.mjs status` | PASS, exit 0; 고정 host/port와 인증 없는 callable의 `UNAUTHENTICATED` 응답 확인 |
| `node tool/emulator_lab/local_backend.mjs seed` | PASS, exit 0; 합성 계정 6개·게임 3개 작성 |
| 최초 실제 RTDB trigger probe | FAIL, exit 1; `room-status-mirror` 관찰 timeout. probe가 만든 방·예약 정리는 PASS. 실패를 최종 성공 기록으로 덮지 않음 |
| Functions Admin DB namespace 수정 | backend 자식 환경의 `DATABASE_URL`을 고정 `demo-mosigame-lab-default-rtdb`로 설정; 설치된 CLI의 환경 변환 단위 검사 확인 |
| `node tool/emulator_lab/rtdb_trigger_probe.mjs` 재실행 | PASS, exit 0; run ID `49886644-786f-408f-a801-038f035be4e3`, 19033ms. 참가자 pause/resume revision 1→2, controller 3→4, 시간 저장·deadline 복구, playing/finished 방 상태 동기화·900000ms 보존, 방 삭제 뒤 예약 정리 확인. 소유 방·예약 제거 확인 |
| Windows backend 종료 | `node tool/emulator_lab/local_backend.mjs stop` exit 0 뒤 supervisor `STOPPED` exit 0, `Owned process tree empty; cleanup confirmed` 확인. 고정 lab 포트의 listener 없음 확인 |
| 두 번째 `Medium_Tablet` 동시 부팅 | 메모리 부족으로 중단. `emulator-5582`는 boot 완료 전 free RAM 0.678 GiB까지 감소; 설치·앱 실행·T/A 동시 검증 미실행. 새 Tablet만 `emu kill` exit 0, 소유 PID·serial 제거와 기존 phone 보존 확인 |
| 한 대의 임시 tablet layout | phone의 `wm size 1920x1200`, `wm density 240`으로 진행 기기 홈을 표시했지만 초대 입력→방 생성 요청은 확인하지 못함. 입력·환경 문제와 제품 결함을 구분하지 못해 판정 대기. 별도 Tablet·ROOM-01 통과 근거가 아님 |
| 화면 복원·phone 정리 | lab 앱만 종료한 뒤 `wm size reset`·`wm density reset` exit 0; 원래 1080x2400·420 dpi 확인. 소유 phone `emu kill` exit 0 뒤 `adb devices` 빈 목록·소유 launcher 종료 확인 |

RTDB probe는 합성 로컬 방을 만들고 실제 RTDB 이벤트에 의한 네 trigger를 확인하는
backend smoke다. 단계별 관찰 한도 120초, 전체 한도 600초와 정리 예비 시간 30초를 둔다.
자신이 만든 방·예약만 정리하며 앱 UI, 실제 네트워크 단절, Scheduler의 정기 실행,
제품 복구 정책을 대신 검증하지 않는다. 최종 결과의 `productScenariosExecuted`도 0이다.

임시 tablet layout의 캡처 두 번은 `ADB_COMMAND_FAILED`(exit 1)로 실패했다.
이후 성공한 controller 캡처와 raw ADB 파일 전송 후 PNG 픽셀 검사를 통과한 파일만
화면 근거로 읽었다. 캡처 재시도 성공을 초대 입력 성공으로 해석하지 않는다.

원시 화면에는 테스트 계정 정보·손패·역할이 포함될 수 있다. 캡처는 Git-ignored build에
보관하고 공유 문서에는 민감 내용을 제거한 근거만 연결한다.

## 62개 항목의 실행 범위

[기계가 읽는 분류표](../../tool/emulator_lab/scenario_coverage.json)는 각 ID와 제목,
실행 방식, 제한, 기존 task를 유지한다. **실행 코드나 PASS 결과표가 아니다.**

| 방식 | 수 | 항목 |
| --- | ---: | --- |
| Android UI 중심 실행 방식 분류 | 45 | AUTH-04~07; ROOM-01~03/05~06; NET-01~09; RESTORE-01~08; EXIT-01~09; CMD-01; GAME-01~03/05~06; UI-01~04 |
| 로컬 fixture·정밀 장애 주입 | 14 | AUTH-01~02/08; ROOM-04; NET-10; CMD-02~06; GAME-04; UI-05; OBS-01~02 |
| iOS 필요 | 1 | AUTH-03 |
| 별도 rules/CLI 검증 | 2 | OBS-03~04 |

Android UI 45개는 실행 방식 분류이며 현재 즉시 실행 가능한 45개를 뜻하지 않는다.
로컬 backend와 계정·게임 fixture, 동시에 동작하는 역할별 앱, 실제 연결 장애·재실행
제어와 화면·게임 상태의 관측이 선행 조건이다. 각 ID의 일부 변형만 수행한 경우
전체 통과로 기록하지 않는다.
UI-03은 현재 debug 전용 준비로 release 조건을 확인할 수 없어 미실행으로 유지한다.
AUTH-01의 로컬 링크·테스트 이메일 로그인은 외부 메일 전달과 네이티브 링크 처리 전체
검증을 대체하지 않는다. 현재 테스트 모드는 Google·Apple 인증을 차단하며 가상 OAuth
성공 경로를 추가하지 않았다. 로컬 이메일로 홈에 진입해도 AUTH-02/03을 통과로 세지 않는다.
Apple 로그인, 실물 네트워크 전환, 제조사 백그라운드 제한, 사용자 안내 이해도는
Android emulator 테스트의 성공 범위를 확대하지 않는다.

| 항목 | 아직 필요한 준비·별도 검증 |
| --- | --- |
| AUTH-01 | 로컬 이메일 링크 요청·처리 확인; 실제 메일 앱·발송·네이티브 링크 왕복은 별도 |
| AUTH-02 | 현재 lab에서 native Google 인증을 차단하며 가상 OAuth 경로도 없음. 실제 Google 계정 선택·취소는 별도의 인증 테스트 환경 필요 |
| AUTH-03 | Android/Windows lab에서 실행 불가; 별도 iOS native 인증 환경 필요 |
| AUTH-04 | 현재 seed는 모든 계정의 온보딩이 완료됨. 신규·미완료 계정과 비밀번호/프로필 단계 준비 필요 |
| ROOM-04 | A 전용 유료 게임·무료 LP는 seed에 있지만 T 전용 소유 게임 변형은 없음 |
| NET-10, OBS-02 | 정기 Scheduler 실행 제어와 보존 경계·고아 요청 fixture 필요. RTDB 삭제 trigger smoke와 정기 정리는 별도 |
| CMD-02~06, OBS-01 | 서버 처리·응답 전달·요청/이벤트 순서를 구분하는 정밀 장애 주입 없음 |
| UI-03 | 현재 routing은 Android debug만 허용하므로 release 비노출 검증용 후보가 없음 |
| UI-05 | catalog의 이미지 URL이 빈 값임. 서로 다른 로컬 이미지와 지연 로딩 준비 필요; 키보드 부분은 독립 실행 가능 |

| 게임/목적 | 동시에 필요한 앱 기기 |
| --- | --- |
| 로그인·단일 화면 | 1대 |
| T/A 비교 | 2대 |
| LP 및 A/B 다중 단절 | 3대 T/A/B |
| FC·Mafia 4인 전체 앱 화면 | 5대 T/A/B/C/D |
| Mafia 12인 모든 참가 화면 | 13대; 현재 호스트 실행 여유 미검증 |

이번 설정의 2대 동시 부팅은 메모리 부족으로 중단했으며, 3대 LP·5대 FC/Mafia의
동시 앱 실행은 미검증이다. 더 작은 기기 설정 또는 메모리 여유가 있는 호스트에서
부팅·조작 지연과 역할별 앱 동작을 다시 측정해야 한다.
봇 또는 seed 참가자로 바꾸면 해당 참가자의 앱 검증은 미실행/부분 실행으로 남긴다.

## 구현한 테스트 전용 클라이언트 연결

[설정](../../lib/firebase/emulator_lab_config.dart)과
[SDK 연결](../../lib/firebase/emulator_lab.dart)은
`--dart-define=MOSIGAME_EMULATOR_LAB=true`를 명시한 Android debug 빌드에만 적용된다.
잘못된 flag, release 또는 다른 플랫폼에서의 활성화는 거절한다.
`main.dart`는 별도 `demo-mosigame-lab` options로 초기화하고 아래 SDK들을 연결한 뒤
AuthGate·ServerClock 등 소비자를 시작한다. 격리 검사·초기화 실패 시 startup 실패
화면으로 종료하며 운영 options로 fallback하지 않는다.

| 서비스 | Android Emulator에서 접속하는 endpoint | 연결한 소비자 |
| --- | --- | --- |
| Authentication | `10.0.2.2:9099` | `FirebaseAuth.instance` |
| Realtime Database | `10.0.2.2:9000` | 기본 인스턴스와 공용 `RealtimeDatabaseService` |
| Firestore | `10.0.2.2:8080` | `FirebaseFirestore.instance` |
| Functions | `10.0.2.2:5001` | 실제 callable 소비 region `asia-northeast3` 인스턴스 |
| Storage | `10.0.2.2:9199` | `FirebaseStorage.instance` |

테스트 모드에서는 Google SDK 초기화·Google/Apple 외부 인증·App Check 발급·
CrashReporting 초기화와 Shorebird patch gate/patch number 조회를 건너뛴다.
외부 인증 버튼은 준비된 이메일 계정을 사용하라는 안내를 반환한다. debug 오류 overlay는
유지한다. 병합 manifest에서 수집 비활성화를 확인했으며, 전체 원격 통신을 감사하거나
제품의 모든 외부 URL 경로를 검증한 것으로 확대하지 않는다.
[이메일 링크 설정](../../lib/platform/auth/services/email_link_config.dart)은 테스트 모드에서
로컬 continue URL을 사용한다. 로컬 Auth 링크의 요청·앱 처리와 실제 이메일 전달은
각각 검증해야 한다.

[Gradle](../../android/app/build.gradle.kts)는 같은 flag를 확인해 debug 전용
[emulatorLab manifest](../../android/app/src/emulatorLab/AndroidManifest.xml)를 선택한다.
이 manifest는 cleartext HTTP를 허용하고 운영 프로젝트를 Dart보다 먼저 초기화할 수
있는 `FirebaseInitProvider`를 제거하며 Crashlytics·Analytics 수집을 비활성화한다.
flag가 없는 일반 빌드는 기존 manifest와 초기화 경로를 사용한다.
현재 APK 빌드·병합 manifest·hash·기기 startup 결과는 위 smoke evidence에 기록했다.

실제 smoke에서 사용한 빌드 옵션은 다음과 같다. 다음 회차도 설치 후보의 hash와
실제 빌드 옵션을 새 실행 ID에 남긴다.

```powershell
flutter build apk --debug --no-pub --dart-define=MOSIGAME_EMULATOR_LAB=true
```

## 구현한 로컬 backend·fixture 도구

[backend 도구](../../tool/emulator_lab/local_backend.mjs)는 정확한
`demo-mosigame-lab`, `127.0.0.1`의 고정 port, `demo-mosigame-lab-default-rtdb`
namespace를 사용한다. 운영 프로젝트·다른 namespace·외부 endpoint·임의 CLI 인자를
거절한다. Firebase CLI는 현재 설치된 `functions/node_modules/firebase-tools`를 사용한다.
Functions 자식 환경의 `DATABASE_URL`도 같은 default RTDB namespace로 고정한다.
이 값은 Admin SDK가 다른 namespace에 접근했던 최초 probe 실패를 수정한 설정이다.
생성 config·CLI 전용 cache·로그는 Git-ignored `.firebase/emulator-lab` 아래에 둔다.
CLI 실행 환경에서 credential 관련 상속 변수를 제외하고 별도 CLI cache를 사용한다.
이 구성은 Firebase CLI 로그인·운영 데이터 복사·deploy가 필요하지 않다.

생성 config는 Auth/Database/Firestore/Functions/Storage를 함께 시작하고 기존
`database.rules.json`, `firestore.rules`, `storage.rules`를 원래 경로로 참조한다.
`storage.rules`는 현재 존재한다. 과거 pilot의 rules 부재는 현행 blocker가 아니다.
에뮬레이터 UI는 끄고 단일 프로젝트 모드로 실행한다.

| 서비스 | 호스트 endpoint |
| --- | --- |
| Auth / Database / Firestore | `127.0.0.1:9099` / `127.0.0.1:9000` / `127.0.0.1:8080` |
| Functions / Storage | `127.0.0.1:5001` / `127.0.0.1:9199` |
| Hub / Logging / Eventarc / Tasks | `127.0.0.1:4400` / `127.0.0.1:4500` / `127.0.0.1:9299` / `127.0.0.1:9499` |

현재 지원 명령은 다음과 같다. config 작성, readiness 확인, fixture 쓰기와 서버 시작은
서로 다른 결과이며, 실제 실행 결과는 위 smoke evidence와 대조한다.

```powershell
node tool/emulator_lab/local_backend.mjs config
.\tool\emulator_lab\start_local_backend.ps1
node tool/emulator_lab/local_backend.mjs status
node tool/emulator_lab/local_backend.mjs seed
node tool/emulator_lab/rtdb_trigger_probe.mjs
node tool/emulator_lab/local_backend.mjs stop
node --test tool/emulator_lab/local_backend.test.mjs
```

- `config`: 기존 운영 config를 바꾸지 않고 lab config를 생성·검사한다.
- Windows `start_local_backend.ps1`: Node launcher를 정지 상태로 만든 뒤 Windows
  Job Object에 포함해 Firebase CLI·Java·Functions 자식 프로세스를 함께 소유한다.
  이미 사용 중인 lab port가 있으면 기존 프로세스를 종료하지 않고 시작을 거절한다.
  종료하려면 시작한 세션의 stdin에 `stop` 한 줄을 보내거나 별도 terminal에서
  `node tool/emulator_lab/local_backend.mjs stop`을 실행한다. 별도 stop 명령은 lab의
  `owner.json`에 있는 프로젝트·nonce·소유 PID 형식을 검사하고 정확한 세션 nonce의
  `stop.request`만 작성한다. supervisor가 자기 nonce와 일치하는 요청만 받아
  소유 Job Object의 프로세스를 종료한다. `STOP_REQUESTED`는 정리 완료가 아니다. 실행 결과의
  `Owned process tree empty; cleanup confirmed`를 확인해야 정리 성공으로 기록한다.
- `status`: Hub가 반환한 다섯 서비스의 host/port와 callable 인증 거절 응답을 확인한다. seed 완료·게임 정상
  동작·RTDB trigger 실행을 판정하는 명령이 아니다.
- `seed`: readiness·목적지 검사 뒤 합성 T/A/B/C/D/X 계정과 완료된 온보딩·프로필,
  세 게임 카탈로그를 로컬 Auth/Firestore에만 작성한다. 현재 fixture는 A가
  Final Call·Mafia를 보유하고 LP는 무료다. T만 보유한 게임 변형은 별도 fixture가 필요하다.
  모든 온보딩을 완료 상태로 쓰며 게임 이미지 URL은 빈 값이다. 미완료 가입과 이미지
  로딩 검증에는 추가 fixture가 필요하다.
  계정·게임 seed는 실제 앱의 가입·구매·참가·정상 게임 시작 검증을 대체하지 않는다.

Windows에서 `node ... local_backend.mjs start` 직접 실행은 Job Object launcher 없이
시작하지 못하도록 거절한다. 임의 project·port·deploy 옵션을 받지 않는다.
현재 ADB controller의 지원 범위는 앞의 devices/capture/tap/back/home 그대로이며
backend 도구가 앱 설치·텍스트 입력·네트워크 장애 주입을 제공하는 것은 아니다.

## 승인·구현한 RTDB trigger 지역 전략

[기존 Emulator Pilot](EMULATOR_PILOT.md)의 재개 조건은
“Approve a test-only strategy for the RTDB v2 trigger region and prove that
deployment discovery remains on asia-southeast1.”이다.

현재 설치된 Firebase CLI 소스 `functions/node_modules/firebase-tools/lib/emulator/functionsEmulator.js`
는 RTDB trigger의 region이 `us-central1`이 아니면 실행되지 않는다고 경고한다.
사용자가 2026-10-04 테스트 전용 전략을 승인했다. 다음 네 trigger 선언은
공유 [선택기](../../functions/src/emulator-test-config.ts)의
`selectDatabaseTriggerRegion()`을 사용하도록 구현했다.

- `functions/src/game-interruption/functions.ts`: 참가자 연결 변경
- `functions/src/game-interruption/controller-presence.ts`: controller 연결 변경
- `functions/src/room/realtime-room-lifecycle.ts`: 게임 종료 동기화·방 삭제 요청 정리

이 변경은 네 trigger의 region 선언에만 테스트 전용 선택기를 적용한다.
`FUNCTIONS_EMULATOR=true`이고 프로젝트가 정확히 `demo-mosigame-lab`이며 필요한 로컬
RTDB endpoint가 설정된 경우에만 `us-central1`을 선택한다. 허용 endpoint는
`127.0.0.1`·`localhost`·`[::1]`의 유효한 host:port 형식이다.
emulator 표식이 있는데 조건이 일부만 맞거나 프로젝트 식별자가 충돌하면 실패로
중단한다. emulator 표식 없는 일반 discovery/배포 조건에서는 기존
`asia-southeast1`을 유지한다. callable 이름·persistent shape·게임 상태 전이는 변경하지 않는다.

설치된 CLI는 discovery에도 `GCLOUD_PROJECT`, `FUNCTIONS_EMULATOR`,
`FIREBASE_DATABASE_EMULATOR_HOST`, `FIREBASE_CONFIG`를 전달한다. 선택기는 그 실제
변수 경로를 사용하며 별도 수동 region override를 요구하지 않는다.

구현 검사 결과:

| 명령·확인 | 결과 |
| --- | --- |
| `npm run lint` (`functions/`) | PASS, exit 0 |
| `npm run build` (`functions/`) | PASS, exit 0 |
| 선택기·presence·room·interruption 관련 Node 테스트 6파일 | 89/89 PASS, exit 0 |
| 최종 `node --test test/emulator-test-config.test.mjs` (`functions/`) | 5/5 PASS, exit 0; 위 89개에 포함된 선택기 검사 재실행 |
| 일반/로컬 조건의 실제 `index.js` export metadata 비교 | 69개 export 유지, RTDB 4개 region만 변경, 나머지 endpoint 선언 동일 |
| 실제 로컬 presence·게임 status·방 삭제 이벤트의 네 trigger 실행 | 최초 상태 동기화 timeout FAIL 뒤 DATABASE_URL 수정·재실행 PASS, exit 0; 위 smoke evidence의 run ID·관측값 참조 |
| client emulator 설정 Flutter 테스트 | 3개 PASS, exit 0 |
| 변경된 Dart 파일 analyze | PASS, exit 0 |
| `node --test tool/emulator_lab/local_backend.test.mjs` | 12개 PASS, exit 0 |
| `node --test tool/emulator_lab/adb_controller.test.mjs` | 4개 PASS, exit 0 |
| `node --test tool/emulator_lab/rtdb_trigger_probe.test.mjs` | 14개 PASS, exit 0 |
| `.\tool\invoke_mosigame.ps1 test auth` / `test session` | INVALID, 실제 exit 1; 실행 목록의 필수 삭제 파일 누락. 앱 제품 실패와 별도 |
| 이번 후보의 `.\tool\invoke_mosigame.ps1 validate --full` | 미실행; 승인되지 않은 실행 범위. 과거 후보의 FULL format 실패와 구분 |

metadata 검사는 handler를 호출하거나 Firebase 데이터를 읽고 쓰지 않고 수행했다.
운영 배포·rules 완화·운영 접근은 이 테스트 준비의 범위가 아니다.
새 `integration_test` dependency 없이 ADB 방식으로 시작할 수 있다.

최초 문서의 “승인 필요·로컬 연결 구현 없음”은 위 구현 이전 상태였다. 현재는 승인을
반영해 client routing·backend launcher·fixture 준비를 구현했고 위 로컬 smoke 근거를
확보했다. 모든 제품 테스트가 완료된 상태는 아니다.
[공식 RTDB Emulator 연결 문서](https://firebase.google.com/docs/emulator-suite/connect_rtdb)는
Android emulator에서 호스트 localhost 대신 `10.0.2.2`를 사용하고 프로젝트 ID를 일치시키도록 안내한다.
[Auth Emulator 문서](https://firebase.google.com/docs/emulator-suite/connect_auth)는
실제 프로젝트에서 emulator 연결이 누락된 제품은 실제 자원에 접근할 수 있다고 설명한다.
그래서 이 준비는 모든 제품을 로컬 endpoint와 demo project로 함께 제한한다.

## 아직 필요한 실행과 보조 기능

- APK·backend·네 trigger와 소유 프로세스 정리의 로컬 smoke는 위에 기록했다.
  정상 방 생성·참가, 제품 시나리오 결과는 별도로 남긴다.
- 3대·5대 동시 앱 실행, 게임별 정상 진입과 역할별 네트워크·lifecycle 제어를 준비한다.
  현재 reusable ADB controller의 기능 범위를 넘어서는 조작은 실제 지원 여부를 먼저 확인한다.
- CMD-02~06/OBS-01 등의 요청 전·서버 처리 후·응답 전달을 구분하는 정밀 장애 주입은
  아직 제공하지 않는다. timeout만으로 처리 후 응답 유실을 주장하지 않는다.
- 역할별 화면·공개 단계·시간·명령 반영 횟수를 모은다. 예상한 제품 결함이 재현되면
  FAIL로 남기며 테스트 환경 준비 과정에서 그 제품 결함을 고치지 않는다.
- 현재 session/auth의 필수 삭제 파일 누락 INVALID와 이전 후보 FULL format 실패는 별도 evidence다.
  위 도구 검사·Functions 검사로 현재 후보의 targeted suite나 FULL을 대체하지 않는다.

## 실행 단계와 완료 근거

1. 빈 Android 기기의 부팅·화면 읽기·탭·Back/Home 확인.
2. 로컬 Firebase 5종 startup 및 RTDB trigger 실제 실행 확인.
3. 현재 앱 로컬 빌드 1대의 로그인·홈·방 생성 smoke.
4. T/A/B 3대 LP 정상 흐름, 반복 단절·시간·종료 복귀.
5. T/A/B/C/D 5대 FC/Mafia 정상 흐름과 단계별 복구.
6. 정밀 장애 주입·rules·검증 경로 항목 실행.
7. 62개 ID별 실제 결과와 지원되지 않은 변형의 사유 기록.

결과는 원본 문서의 통과/실패/판정 대기/미실행/해당 없음 규칙을 따른다.
모든 62개가 같은 방식으로 자동화되거나 Android에서 통과할 수 있다고 약속하지 않는다.
현재 제품 테스트는 62개 모두 미실행이다. 제어 smoke·구현 검사 결과를 제품 시나리오의
통과로 옮기지 않는다. 로컬 smoke와 앞으로의 제품 실행 결과는 실행 ID별로 따로 보존한다.
