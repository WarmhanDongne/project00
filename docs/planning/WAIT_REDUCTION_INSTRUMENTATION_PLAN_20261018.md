# Debug 계측·수집 보완 — 설계와 검토

2026-10-18 · 기능 기준 `ea08181` · 임시 계측은 기능 개선과 별도 커밋/제거 대상.

## 1. 설계

목표는 라이어스 포커 최초/메뉴/결과 시작과 로비 초기화의 필수 사건을 보존하고,
새 선조회·늦은 보조 취소를 구분하는 것이다. 서버·게임 규칙·timeout/retry·연출·요청 순서는 유지한다.

- 기존 protocol2 계측/collector의 승인된 파일만 이식한다. branch 전체 merge는 하지 않는다.
  앱과 수집기를 함께 protocol3로 올려 기존 APK/수집기의 조합을 사전 거절한다.
- Debug + STARTUP_MEASUREMENTS 명시 opt-in에서만 extension/journal이 동작한다.
  기본 Debug/Release/Profile은 비활성. 계측 실패가 게임 성공/실패·재시도를 바꾸지 않는다.
- 기존 실제 입력 준비·사용자 공개 탭·선공 선택/제출 경계와 250ms 품질 기준을 재사용한다.
- 최초 시작: 시작 성공 뒤 cleanup 조회 start/end, 재확인, 폐기, 연출 끝/전환을 관측한다.
- room_reset: UI 수락→durable intent→서버 close/status→로컬 정리와 기기별 종료 관측.
  옛 접속 cancel 및 늦은 register/재cancel은 별도 scope/span/익명 room·connection으로 기록한다.
  표본 전체 완료 후에도 journal에 관측하되 기존 RoomActionTiming 표본은 오염시키지 않는다.
- 동작 완료와 수집 관찰 종료를 구분한다. stop 때 미완료 span은 pending으로 명시한다.
  느린 보조 작업을 완료시키려고 게임에 await를 추가하지 않는다.
- trial/role/process/seq/단조 시각, key별 익명 alias만 PC에 저장한다.
  지속 drain, overflow/gap/process 변경, 마지막 stop/drain/시계, 필수 사건을 검사한다.
  저장 해시·수집 완전성·동작 성공·시계 품질은 각각 판정한다. 새 방 관찰은 같은 수집의 후속 관찰로 분리한다.
- 빌드 표식·APK SHA256·앱/수집기 소스 지문을 manifest에 보존한다. PC 소스 지문만으로
  설치 APK를 인증했다고 쓰지 않는다. APK 실물 확인은 예비 수집 준비 조건이다.

## 2. 계획 검토 결과 — 실행 전

현재 코드 및 기존 collector와 대조해 다음을 설계에 반영했다.

1. RoomData에 roomInstanceId가 없다. DTO/API를 넓히지 않고 이미 저장된 접속 신원과
   기존 관측 지점만 사용한다. 세대 확인이 없으면 unavailable이며 방 코드로 대신하지 않는다.
2. 기존 수집기는 LP 세 시나리오 전용이다. room_reset은 별도 완전성·완료 기준을 추가한다.
   시작 시간/카드 검증을 초기화에 억지 적용하지 않는다. 이전 APK 혼합은 부분 관측으로 표시한다.
3. 캡처 밖에서 시작한 옛 등록이 캡처 중 끝날 수 있다. 이미 시작된 관측과 새 span을 구분하고
   늦은 이벤트를 새 시험의 새 접속 작업으로 오인하지 않도록 room/connection alias를 대조한다.
4. stop 뒤 미완료 보조 Future·앱 종료는 무손실로 주장하지 않는다. pending/누락을 남기고
   필수 증거 미확보를 통과시키지 않는다. 시퀀스 검사는 미계측 사건을 대신하지 않으므로
   시나리오별 필수 사건 목록도 검사한다.
5. 네트워크 단절은 이번 개선의 별도 목표가 아니다. 정상 시작/재시작/초기화/새 방이 본 시험이며,
   지연·실패·늦은 완료는 자동 주입 회귀로 검사한다. 실기기 단절 회귀는 선택 항목으로 분리한다.
6. 기존 기능 커밋과 기존 untracked 지시문을 보존한다. 새 dependency·운영·설치·배포 없음.

검토 판정: 위 범위로 구현 착수 가능. 구현 후 실제 누락/지연 사례 회귀와 기본 비활성 경로를
검증하고 사용자에게 최종 후보를 보여 준다. FULL은 적용 skill에 따라 새 명시 승인 후 실행한다.

## 3. 실행·검증 순서

1. 최소 파일 이식과 protocol3/비식별 scope·journal.
2. 새 선조회/초기화/늦은 취소/기존 구독 관측 연결.
3. collector/analyzer·manifest·필수 사건/누락/종료 처리.
4. Python 표준 라이브러리 테스트, Dart 계측 및 실제 동작 회귀, session·분석/format.
5. 설치 전 사용할 예비/본 수집 명령과 관측 한계를 문서화. 필요 빌드 지문을 정한다.
6. 별도 계측 커밋에 넣을 변경 목록과 제거 시 점검표를 남긴다. 테스트 자료는 ignored 경로에 보존.

계측 제거 시에는 해당 커밋 revert로 기능 `ea08181`의 의미가 유지되는지 대조하고 관련 검증을
진행한다. 계측 제거 후 배포할 빌드 모드로 실기기 간단 확인을 별도로 한다.


## 4. 구현 후보와 검증 기록

protocol3 계측·수집기 후보를 기능 커밋 ea08181 위에 독립 변경으로 구성했다.
기존 protocol2 파일을 이식한 12개 공용/LP 경계 외에 선조회 helper·launcher와 room service/provider만 계측했다.
실제 게임 규칙·서버 API·연출 순서·기존 대기 조건을 변경하지 않았다. 새 dependency/lock 변경은 없다.

- 최초 시작: cleanup_scope/lookup start/end, prefetch/fallback/invalidated, 연출 후 전환 대기/route 교체.
- 초기화: 수락, 기존 접속 신원 alias, 종료 의도 저장, 서버 close/status, 로컬 정리 완료와 각 기기 방 정리.
  RoomActionTiming 종료 뒤의 cancel 결과와 늦은 registration은 별도 journal/span에 남긴다.
- 모든 span은 capture epoch/action을 보존한다. 서버 경로의 await 뒤 진단도 이전 epoch로 고정한다.
  stop 때 미완료를 pending으로 남기며 게임 진행을 지연시키는 await는 추가하지 않는다.
- collector는 protocol3 + 명시 build-id/APK를 요구한다. 허용 필드·별칭·순번·overflow·process·stop/drain을 검사한다.
  파일 저장/사건 무결성/시간 품질/시나리오 통과를 분리한다. 250ms 기준은 유지한다.
- 초기화의 예비 통과에는 모든 기기의 옛 방 정리·보조 취소 최종 관측과 새 세대의 참가·최소 30초 관찰이 필요하다.
  이 후속 관찰은 초기화 소요에 합산하지 않는다. 의도 저장의 재확인 없는 confirmed replay는 정상 최초 시험으로 통과시키지 않는다.
- [실기기 지시문](../operations/WAIT_REDUCTION_REAL_DEVICE_TEST_20261018.md)에 네 경로 명령/빌드 절차와 선택 단절 회귀를 반영했다.
  원래 untracked 문서는 ignored 실행 근거 폴더에 사본으로 보존했다.

검증 근거: `build/device-test/wait-reduction/instrumentation-20261018-12b876dc/`.
Python 수집기 28건 PASS/exit0, 네 게임 launcher·scope·room fast path·계측·LP 입력 합계 57건 PASS/exit0,
후속 late-cancel 관측 회귀 포함 34건 PASS/exit0와 전체 Flutter analyze PASS/exit0를 확인했다.
초기 분석의 nullable-owner 3건과 HTTP 상태 코드 수정 중 발생한 회귀는 수정 후 해당 검사를 재실행했다.
시험/합격 조건을 낮추지 않았다. 최종 session·빌드·보존 결과는 같은 폴더의 실행 기록과 후속 기록을 따른다.

FULL은 이 새 후보에 대해 별도 명시 승인을 요청한다. 과거 기능 FULL 통과를 재사용하지 않는다.
임시 계측 커밋·push·revert는 수행하지 않았고 실기기 예비 시험/성능 향상은 미검증이다.
제거 때 이 변경만 revert하고 ea08181의 의미·관련 회귀·최종 비계측 APK 실기기 확인을 유지한다.


### 최종 후보 관련 검사 결과

Windows guarded 	ool/invoke_mosigame.ps1 test session --json: PASS/exit0, 5개 검사 PASS, 실행 전후 트리 동일. 전체 Flutter analyze 재확인 PASS/exit0. python tool/startup_measurements/build_debug.py: PASS/exit0, 빌드 중 소스 변화 없음.
새 APK와 build-manifest는 uild/device-test/instrumented-debug-20261018-234543-acb61873/에 보존했다. APK 내부 Debug kernel의 빌드 표식 포함과 SHA-256도 대조했다. 설치는 하지 않았다.
원 수집 파일 836개·소스 27개 해시 동일, 원 checkout clean/78d0fdf, dependency/lock/staging 변화 없음. 기존 실기기 문서 원문 사본 해시도 일치한다. 최종 명령·exit·후보 지문은 실행 근거 폴더 validation.json에 기록했다. 새 FULL/커밋/푸시/실기기 예비 검증은 미실행이다.


## 2026-10-19 — 선택·첫 제출 검증 후속

00:24:40 예비 수집은 시간/파일 자료가 유효했지만 이후 차례 선택으로 첫 제출 검증이 채워지는 허점을 확인했다. [후속 보완 계획](WAIT_REDUCTION_INPUT_VALIDATION_FIX_20261019.md)에 따라 protocol4 선택 상태 변경/동일 첫 제출 연결과 COLLECTING 안내를 추가한다. 기존 protocol3 판정/원본은 덮어쓰지 않으며 새 APK로 최초 시작 예비 1회부터 재확인한다.
