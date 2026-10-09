# 네트워크·세션 서버·진단 후속

2026-10-09. 이 문서는 담당자의 작업 목록이다. 사용자가 하는
[실기기 화면 테스트](NETWORK_SESSION_REAL_DEVICE_TEST.md)에 서버·로그 확인을 요구하지 않는다.
[설치·배포 준비](NETWORK_SESSION_TEST_PREPARATION.md)에서 환경을 먼저 정한다.

## 확인된 범위

현재 로컬 FULL과 실제 CI는 PASS이며, demo 백엔드에서 실제 RTDB SDK·rules·onDisconnect·
trigger·4게임 흐름 등 10개 시나리오가 통과했다. 생성 재전송의 cold transaction cache와
첫 cleanup cursor 결함은 제품/회귀 커밋으로 수정했다. 근거는
[E13 기록](../planning/NETWORK_SESSION_E13_BACKEND_CI.md)에 있다.
단위/widget·JS SDK 결과로 실제 FlutterFire·OS·배포 환경까지 완료 처리하지 않는다.
아래 표는 모두 **미실행 후속**이다. 물리 기기 화면 테스트로 해소된 부분은 결과를 연결해 줄인다.

## 화면 테스트와 별도로 남은 확인·실행 방법

| 필요한 확인 | 담당자 실행 방법 | 통과 근거 |
| --- | --- | --- |
| 원격 서버·rules가 테스트 앱과 같은 후보인지 | 대상 프로젝트 승인 후 Functions 목록/배포 리전·rules 배포 버전과 배포 결과를 확인. 새 함수 및 제거된 3개 함수의 공존 상태를 기록. 데이터 조회 없이 먼저 metadata로 확인 | 앱 빌드 SHA·Functions 배포 후보·rules가 매칭되고 구버전 호환 계획을 충족 |
| 실제 Cloud Scheduler delivery | 승인된 테스트 환경에서 세 정리 schedule의 활성 상태·주기·timezone을 확인. 합성 테스트 방의 만료/대기실 정리/cleanup queue 조건을 만들고 1분/5분 실행을 기다려 담당자가 실행 로그와 필요한 단일 경로만 관찰 | 실제 예약 호출과 기대 조건부 정리. emulator의 handler 직접 `.run` 호출 결과와 별개 |
| 배포 환경의 RTDB trigger·보안 rules | 실기기 단절 시 해당 합성 방의 현재 connection/presence 요약과 incident 변화만 관찰. 승인된 테스트 계정으로 자기 private 읽기·타인 private 거절·서버 전용 쓰기 거절 확인 | 현재 접속만 반영, 다른 방/계정에 영향 없음, 실제 배포 rules의 허용·거절 |
| FlutterFire 구독 오류/종료·파싱 실패와 공개/비공개 도착 순서 | 별도 테스트 브랜치에서 debug 테스트 adapter 또는 에뮬레이터 fixture로 permission-denied·stream onDone·잘못된 테스트 snapshot·private 지연을 각각 유도. 실제 native plugin과 UI를 실행 | connected만으로 ready 처리하지 않음, 준비 실패 중 행동 보호, 복구 후 현재 공개/private 상태로만 재개 |
| 서버가 처리했지만 응답만 유실된 명령·퇴장 | 테스트 환경의 실제 callable 처리 뒤 응답 전달을 지연/유실시키는 debug adapter를 준비. 앱 재실행·결과 확인·재가입을 함께 검증. 토큰/개인 payload를 evidence에 담지 않음 | operation 결과 재조회, 재처리 중복 없음, 저장된 퇴장 의도가 복원보다 우선, 새 membership 보존 |
| 로컬 durable 기록·파일 저장 실패 | 테스트 adapter로 참가/퇴장 기록 write 실패와 홀덤 캐시 불완전 상태를 만들고 앱의 복구·취소를 관찰. 실제 기기 데이터를 지우거나 운영 파일을 손상시키지 않음 | 성공처럼 진행하지 않음, 복구 거절/재시도·그룹 퇴장 경로가 막히지 않음 |
| 부분 생성·오래된 queue/cursor의 실제 배포 호환 | 기존 emulator 회귀는 PASS. 승인된 테스트 환경에 작은 합성 실패 fixture를 넣어 새/옛 generation 정리와 첫/저장 cursor를 확인. 큰 queue load는 격리된 emulator에서 유지 | 현재 generation 보호·조건부 보상, 실제 schedule과 due index 사용. 기존 방의 무조건 정리 없음 |
| 복구 시간·성공률·오류 분류 | 화면 테스트의 빌드/OS/게임·단절 방식별 결과에 담당자가 debug RecoveryMetrics 요약을 연결. 재생 가능한 동작에서 연결→snapshot→ready→UI 시간을 분리. p95는 충분한 반복과 사전 합의한 기준이 있을 때 산출 | 측정 집합·횟수·미실행 조합을 명시. 임의의 60초 관찰 구간을 성능 SLA로 바꾸지 않음 |
| 원래 브랜치의 CI SDK | 별도 후속 변경에서 Flutter 3.44.8 workflow와 승인 후보 SDK 3.47.5를 정렬하고 CI 실행 승인/검증 | 이번 요청대로 emulator/CI 구성은 테스트 브랜치에 유지. 현재 원래 workflow까지 보정됐다고 보고하지 않음 |

정확한 응답 유실·권한 오류·디스크 실패는 비행기 모드 조작만으로 재현했다고 확정할 수 없다.
단순 단절·재시도 화면이 통과하면 해당 화면 테스트 결과만 인정한다.
새 debug hook을 추가하는 구현은 현재 문서 작업에 포함되지 않는다. 그때 구현 skill·관련 회귀·
승인된 FULL을 적용하고, 제품 결함은 원래 브랜치에 수정/회귀를 별도 커밋으로 반영한다.

## 적은 RAM으로 다음 진단을 실행하는 경로

1. 먼저 기존 backend runner 결과를 사용한다. 재현할 새 실패가 있을 때만
   `codex/e13-emulator-ci` worktree에서 `node tool/emulator/run.mjs`를 실행한다.
   현재 runner는 10분 deadline이 있는 일회성 demo 검증이며 실행 뒤 서버가 종료된다.
2. 실제 FlutterFire 진단에는 Android 다중 emulator 대신 실기기를 사용한다.
   PC에서는 Firebase 백엔드만 지속 실행하고 debug 앱의 LAN 연결을 별도 테스트 브랜치에 준비한다.
   현재 loopback-only runner나 기존 앱으로 이 연결이 이미 된 것처럼 사용하지 않는다.
3. 대안은 승인된 별도 Firebase 테스트 프로젝트에 matching 서버/rules·앱 설정을 준비하고
   실제 기기로 진단하는 것이다. 사용자의 기기 목록에서는 서버·로그 단계를 계속 제외한다.

## 접근·기록 범위

운영 조회·deploy·migration은 대상과 필요성에 대한 별도 사용자 승인이 필요하다.
Firebase MCP를 쓴다면 [read-only pilot](FIREBASE_MCP.md)의 전용 계정/도구 확인과
정확한 단일 경로 사전 승인을 따른다. root나 전체 사용자/방 collection을 읽지 않는다.
MCP로 쓰거나 배포하지 않는다. 로그도 테스트 방과 필요한 시간·오류 종류로 한정한다.
결과에는 명령·status·exit code·후보 버전·합성 시나리오와 한계를 남긴다.
credential/token·계정 원문·손패/private payload는 기록하지 않는다.

현재 운영 접근·배포·원격 metadata/데이터/로그 조회는 수행하지 않았다.
사용자는 화면 테스트에서 발생한 **게임·기기·조작·증상**만 알려주면 된다.
