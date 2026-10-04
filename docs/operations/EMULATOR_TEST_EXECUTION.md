# AI Emulator 테스트 재구축 참고

작성·정리일: 2026-10-04
기준: [개발 전 테스트 62개](PRE_DEVELOPMENT_AUTH_NETWORK_SESSION_TEST.md)
현재 상태: **사용자 승인에 따라 실행 코드와 서비스의 테스트 분기를 제거했다. 보관한 AI 실행 결과는 62개 모두 NOT_RUN이며, 이후 수동 테스트 기록은 별도로 관리한다.**

이 문서는 제거한 환경의 설계와 실제 근거를 보관한다. 아래 과거 경로·flag·명령은 현재 실행 안내가 아니다. 실기기 테스트 문서는 유지하며 AI Emulator 실행은 환경을 다시 구현하고 확인해야 한다.

## 현재 남긴 자료와 제거 범위

| 구분 | 처리 |
| --- | --- |
| 기존 서비스 파일 8개 | 테스트 전용 추가분을 역적용해 기존 코드로 복원 |
| 신규 실행·설정·테스트 파일 13개 | 제거 |
| 기존 실행 분류 JSON | [문서 폴더 분류표](EMULATOR_SCENARIO_COVERAGE.json)로 이동 |
| 수동 테스트 62개 | 시나리오와 결과 판정 기준 유지 |
| 제거한 소스 | [단일 보관 patch](archive/emulator-test-lab.patch)에 저장 |
| 최소 실행 근거 | [로그인 화면](archive/emulator-test-evidence/phone-login-20261004.png), [RTDB probe 결과](archive/emulator-test-evidence/rtdb-probe-49886644.json) |
| 테스트 생성물 | 소유 APK 2개, 격리 emulator 데이터 3개 디렉터리, backend cache와 삭제 helper의 생성 JS·map 제거 |

복원한 파일은 Android Gradle, 앱 시작·App widget, 인증 provider·이메일 링크 설정, Functions의 참가자 presence·controller presence·방 lifecycle이다. 기본·debug manifest, 운영 Firebase 설정과 rules, dependency 파일, 기존 AVD·SDK는 유지했다.

보관 patch는 기존 파일 8개와 신규 파일 14개(이전 JSON 포함), 총 22개 파일의 변경이다. 저장 기준 HEAD는 `72b38f9d837fe9b34c334fe8fdfc79d603fa83a4`, SHA-256은 다음과 같다.

```text
7d0cd68e622f3559228452190d02ba00febff137e57f699978f1bd4465f83f44
```

patch는 빌드·테스트에 연결하지 않은 자료다. 재구축 시 현재 코드·SDK·계약과 비교하고 필요한 부분을 다시 설계한다. 과거 승인을 미래 구현·운영 접근·배포 승인으로 해석하거나 자동 적용하지 않는다.

## 62개 실행 분류의 의미

| 과거 방법 분류 | 개수 | 재구축 시 필요한 것 |
| --- | ---: | --- |
| Android UI 중심 | 45 | 기기·앱·로컬 서버·역할별 화면과 assertion |
| fixture 또는 정밀 장애 주입 | 14 | 요청·처리·응답 시점 구분과 서버 관측 |
| iOS 전용 | 1 | iOS 기기·인증 환경 |
| 별도 검증 경로 | 2 | 해당 플랫폼·release·검증 절차 |

분류는 실행 준비 완료나 통과 판정이 아니다. JSON의 모든 `result`는 `NOT_RUN`, 현재 blocker는 `AI_TEST_LAB_REMOVED`다. 당시 blocker는 `historicalBlocker`에 보관했다. ADB 캡처·탭이나 fixture trigger smoke를 제품 시나리오 PASS로 옮기지 않는다.

## 제거한 환경의 연결 설계

당시 Windows, Node 22.23.2, Firebase CLI 14.27.0, Android Emulator 36.6.11.0 환경이었다. `Medium_Tablet`·`Pixel_7a` AVD가 있었으며 조사 시작 시 연결 기기는 없었다. 재구축 시 버전을 다시 확인한다.

프로젝트는 정확히 `demo-mosigame-lab`, RTDB namespace는 `demo-mosigame-lab-default-rtdb`로 제한했다. 앱·Admin SDK·rules 참조가 같은 namespace를 사용해야 했다.

| 서비스 | Android endpoint | 호스트 endpoint |
| --- | --- | --- |
| Auth | `10.0.2.2:9099` | `127.0.0.1:9099` |
| RTDB | `10.0.2.2:9000` | `127.0.0.1:9000` |
| Firestore | `10.0.2.2:8080` | `127.0.0.1:8080` |
| Functions | `10.0.2.2:5001` | `127.0.0.1:5001` |
| Storage | `10.0.2.2:9199` | `127.0.0.1:9199` |

callable 소비 region은 `asia-northeast3`였다. Hub/Logging/Eventarc/Tasks는 loopback의 4400/4500/9299/9499 port를 사용했다.

당시 debug flag `MOSIGAME_EMULATOR_LAB`로 별도 manifest를 선택했다. 로컬 HTTP 허용, Dart보다 먼저 운영 Firebase를 초기화할 수 있는 `FirebaseInitProvider` 제거, Crashlytics·Analytics 수집 비활성화를 적용했다. 소비자 시작 전에 다섯 SDK를 모두 로컬로 연결하고 격리·초기화 실패는 시작 실패로 처리해 운영 fallback을 차단했다.

Google SDK·Google/Apple 외부 인증, App Check 발급, CrashReporting, Shorebird patch gate·patch number 조회를 테스트 모드에서 건너뛰었다. 외부 인증 버튼은 이메일 계정 안내를 반환했고 이메일 링크는 로컬 continue URL을 사용했다. 실제 이메일 전달·native 인증·모든 외부 URL 격리는 확인하지 않았다. 이 flag와 분기는 현재 제거되어 있다.

## RTDB 지역 우회와 최초 실패의 근거

당시 설치된 CLI는 RTDB v2 trigger가 `us-central1`이 아니면 실행되지 않는다고 경고했다. 사용자 승인 후 참가자 연결·controller 연결·게임 상태 동기화·방 삭제 요청 정리 네 trigger에 지역 선택기를 추가했다.

선택기는 emulator 표식, 정확한 demo 프로젝트, 유효한 loopback RTDB endpoint가 모두 맞을 때만 `us-central1`을 선택했다. 부분 설정·프로젝트 충돌은 실패로 중단했고 일반 discovery는 `asia-southeast1`을 유지했다. 실제 export metadata 69개에서 네 region만 달라지는지 확인했다. **현재 선택기는 제거됐고 네 선언은 기존 `asia-southeast1`이다.**

첫 실제 probe는 게임 상태 mirror timeout으로 FAIL(exit 1)했고 소유 데이터 정리는 성공했다. Functions 자식의 `DATABASE_URL`이 다른 namespace를 사용한 문제를 수정하고 cold start 관측 시간을 늘린 뒤 재실행했다. discovery startup 제한도 60초로 설정했다. 지역 우회만으로 작동이 증명되지는 않으며 실제 이벤트·delta 관측이 필요했다.

## 도구 재구축 때 참고할 조건

- ADB 제어는 emulator serial과 `qemu=1`을 확인하고 실물 기기를 거절했다. 완전한 PNG·픽셀을 확인하고 캡처 파일을 덮어쓰지 않았다. 지원은 devices/capture/tap/back/home까지였다. 설치·실행·로그인 일부는 확인한 serial에 별도 ADB로 수행했다.
- 새 data/datadir, read-only·no-snapshot 부팅을 사용했다. 기존 AVD wipe·snapshot 덮어쓰기는 하지 않았다.
- Windows supervisor는 정확한 자식만 Job Object로 소유하고 pipe·startup 60초·nonce 기반 종료를 관리했다. 사용 중인 port·전역 프로세스를 강제 종료하지 않았다. 종료 요청과 소유 프로세스가 비었음을 확인한 결과를 구분했다.
- readiness는 다섯 서비스 host/port와 callable의 실제 인증 거절을 확인했다. 열린 port만으로 seed·trigger·게임을 판정하지 않았다.
- backend는 기존 rules·별도 CLI cache를 사용하고 credential 관련 상속 환경을 제외했다. 운영 데이터 복사·로그인·deploy가 필요하지 않았다.
- seed는 합성 T/A/B/C/D/X 6계정, 완료된 온보딩·프로필, 3게임 카탈로그를 만들었다. A는 Final Call·Mafia를 보유하고 LP는 무료였다. T만 보유한 변형·미완료 가입·이미지 URL은 준비되지 않았다.
- probe는 UUID 경로·조건부 `null_etag` 생성·소유 경로 정리와 전후 delta assertion을 사용했다. 단계 관측 120초, 전체 600초, cleanup 예약 30초였다. seed·probe는 앱 가입·구매·참가·정상 게임 시작을 대체하지 않았다.

## 실제 확인했던 결과

이 표는 **제거 전 환경의 과거 결과**이며 현재 제거 후보 검증과 구분한다.

| 확인 | 과거 결과·범위 |
| --- | --- |
| lab debug APK 빌드 | PASS(exit 0), 1,273.4초. 이후 brace 형식 수정은 재빌드하지 않음 |
| 설치·이메일 로그인 | 합성 A로 홈 진입; native Google은 로컬 안내만 확인 |
| backend startup·seed | 5서비스 readiness, 6계정·3게임 seed PASS(exit 0) |
| 첫 RTDB probe | mirror timeout FAIL(exit 1), 소유 정리 성공 |
| 최종 RTDB probe | PASS(exit 0), 19,033ms, 제품 실행 0개 |
| Functions lint/build·관련 검사 | PASS(exit 0), 선택기 포함 89개 |
| 도구 검사 | PASS(exit 0), backend 12·ADB 4·probe 14개 |
| Flutter 설정 검사·변경 파일 analyze | PASS(exit 0), 설정 검사 3개 |
| auth/session Project CLI | 필수 파일 누락 INVALID, 실제 exit 1 |
| 당시 구현 후보 FULL | 미실행. 다른 문서 후보의 기존 RoomProvider format 실패와 구분 |

APK SHA-256은 `7B1D3672D62E87191C8553DDDE983A0CE9535E3F2A5D5ADD4417BE8C351C943B`였다. APK는 삭제했고 로그인 화면만 보관했다.

최종 probe ID는 `49886644-786f-408f-a801-038f035be4e3`다. 보관 JSON에서 참가자 pause/resume revision 1→2, controller 3→4와 남은 시간 보존, playing/finished mirror, retention 900,000ms, trigger의 예약 삭제, 소유 방·예약 cleanup을 확인할 수 있다. 제품 방 생성·게임 흐름의 통과 근거는 아니다.

## 다중 기기 한계와 미확인 범위

RAM은 약 16GB(관측 15.8GiB)였다. 두 emulator 시도에서 사용 가능 메모리가 3.375GiB에서 0.678GiB로 줄었고 두 번째 qemu는 약 3.26GiB를 사용했다. 두 번째 boot·앱 확인 전에 종료했다. 당시 설정의 메모리 압박 근거이며 16GB의 모든 다중 emulator 구성이 불가능하다는 증명은 아니다. 3대·5대·13대 실행은 검증하지 않았다.

한 phone을 일시적으로 tablet 크기로 바꿨으나 invite 입력만으로 방 생성 완료를 증명하지 못했다. 1080×2400·420dpi로 복원했고 ROOM-01을 PASS 처리하지 않았다.

정밀 장애 주입은 요청 전·서버 처리 후·응답 전달 시점을 구분해야 한다. Wi-Fi/data 토글·timeout만으로 응답 유실·중복 방지·처리 횟수를 주장하지 않는다. 역할별 화면·단계·시간·명령 반영 횟수와 서버 관측이 필요하다. scheduler, native 인증, iOS, release 경로와 추가 fixture도 미확인이다.

## 향후 재구축 순서

1. 현재 코드·계약·rules·SDK/CLI 버전을 읽고 62개 ID의 방법·blocker를 다시 분류한다.
2. 격리와 서비스 코드 변경 최소화를 설계한다. dependency·공개 API·상태 계약·운영 접근 등 승인 경계가 생기면 구체적 변경안을 먼저 제시한다.
3. 소유 프로세스·data 경로, demo/loopback 제한, 실패 시 중단·cleanup을 증명한다.
4. 로컬 5서비스·실제 네 trigger·1대 앱 로그인과 방 생성까지 확인한다.
5. 여유 메모리를 측정하며 T/A/B 3대, 필요 시 T/A/B/C/D 5대의 정상 흐름을 확인한다.
6. 정밀 장애 주입·scheduler·rules·플랫폼별 검증을 준비하고 ID별 실제 결과·근거·미지원 사유를 기록한다.

제품 결함은 수동 문서 규칙에 따라 FAIL·판정 대기·NOT_RUN으로 남긴다. 환경 준비 과정에서 임의로 고치거나 미실행을 통과로 바꾸지 않는다. 현재 제거 작업 검증은 [10월 기록](../planning/logs/2026-10.md#test-regression-01)에 남긴다.
