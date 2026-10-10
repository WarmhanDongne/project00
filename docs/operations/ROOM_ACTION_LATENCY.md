# 로비 방 생성·초기화 지연 측정

2026-10-10. 사용자 보고: iOS Simulator에서 방 생성과 초기화 각각 체감 3~4초.
희망은 1초대이며, 아직 실제 측정값이나 확정된 성능 합격선은 아니다.

## 측정하는 것

debug 앱의 기존 오른쪽 아래 통신 진단 버튼에서 기록을 확인·복사한다.
`RoomActionTiming`은 기존 작업에만 단조 시계(Stopwatch)를 붙인다. 계측용 요청,
새 서버 함수, DB 필드나 timeout/retry 변경은 없다. release에서는 기록하지 않는다.
방 코드·UID·요청/세션 ID·본문·오류 원문 대신 앱 내부 sample 번호와 고정 단계만 남긴다.
실패 시에는 허용 목록의 Firebase 오류 코드 또는 timeout 코드만 `error_code`로 추가한다.

| 기록 | 의미 |
| --- | --- |
| `방 생성 · 전체 완료` | provider 명령 시작부터 방 코드 저장·구독 시작·화면 갱신 알림까지 |
| `방 초기화 · 전체 완료` | 초기화 확인 후 provider 명령 시작부터 성공한 로컬 방 정리까지 |
| `callable:createRealtimeRoom` | 생성 함수 요청부터 응답/오류/클라이언트 timeout까지 |
| `callable:resumeRealtimeControllerRoom` | 생성 응답 후 controller 세션 복구 요청 |
| `rtdb:presence_write` | 현재 controller 접속 쓰기 완료까지, 해당 쓰기의 재시도 포함 |
| `rtdb:disconnect_cancel` | 초기화 전 onDisconnect 예약 취소 |
| `callable:game_common_operation_status` | 초기화 요청의 기존 처리 결과 조회 |
| `callable:closeRoom` | 서버 방 종료 요청 |
| `local:*` | 로컬 intent·identity 저장/조회 등. identity cache miss 시 하위 callable 포함 가능 |

각 시작/완료는 `sample`과 `step`으로 연결한다. `elapsed_ms`는 해당 단계 소요 시간,
`total_ms`는 이 sample 시작부터 누적 시간이다. 최종 `status=success/failure`를 구분한다.
같은 함수가 여러 번 있으면 각각의 시도이며 대기 간격은 전체 시간에 포함된다.
늦은 Future가 이미 종료된 sample을 성공으로 바꾸거나 다음 sample에 섞이지 않는다.

**callable 시간은 순수 인터넷 ping이 아니다.** SDK 인증 처리·전송·서버 준비 및 함수 내부
Firestore/RTDB 작업·응답 수신을 포함한다. 클라이언트 로그만으로 cold start나 서버 DB
처리 시간을 따로 확정할 수 없다. 필요한 경우에만 [서버 로그 제한 조회](FIREBASE_SERVER_LOGS.md)를
별도 범위·승인으로 진행한다.

전체 시간은 화면의 첫 프레임이나 연출 종료를 재지 않는다. 현재 방 코드 표시 연출은
약 580ms, QR 등장 연출은 760ms이며 둘은 병행한다. QR은 연출 시작 약 440ms 후 나타나기
시작한다. 앱 처리 완료 뒤 체감 시간에 포함될 수 있으므로 두 연출 시간을 합산하지 않는다.

## 같은 환경에서 확인

1. 계측 코드가 포함된 debug 앱을 실행한다. 기존 설치 APK/앱은 자동으로 바뀌지 않는다.
   시뮬레이터 모델·OS, 앱 후보, 네트워크와 동시 실행 시뮬레이터 수를 기록한다.
2. 다른 플레이어가 사용하지 않는 테스트 로비에서 진단 기록을 지우고 닫는다.
3. 방 생성 1회 → 표시 확인 → 초기화 확인 1회를 수행한다. 첫 실행과 연속 실행을 구분한다.
4. 같은 조건에서 최대 5쌍을 수동 실행한다. 실패도 기록하며 결과 미확정 상태에서 연타하지 않는다.
5. 진단창의 `기록 복사`로 결과를 전달한다. 200개 이벤트 버퍼이므로 게임 진행 없이
   측정 직후 복사한다. 측정 중 앱 재시작을 했다면 별도 표본으로 분리한다.

생성/초기화 각각 첫 값과 후속 값의 중앙값·최대값, 단계별 시간을 비교한다.
5회만으로 안정적인 p95나 실제 기기 성능을 확정하지 않는다. iOS Simulator 결과를
iPhone/iPad 실기기 결과로 표현하지 않는다. 합성 테스트 시간도 Firebase 실측으로 쓰지 않는다.

## 개선 전 순서 (첫 실측 후보)

- 생성: 로컬 intent 저장 → create callable → identity 저장 → controller resume callable
  → RTDB presence 쓰기 → 확인 저장 → 로비 갱신. 서버 생성 함수 자체도 온보딩 조회,
  생성 slot/예약/방/매핑/완료 표시 등 여러 RTDB 작업을 순차 수행한다.
- 초기화: identity 확인 → onDisconnect 취소 → operation status callable → 필요하면 close
  callable → 로컬 정리. 요청 결과가 이미 applied/stale면 close를 반복하지 않는다.

이 순서를 삭제하거나 병렬화하기 전에는 멱등성·접속 세대·퇴장 의도 보존에 미치는
영향을 따로 검토해야 한다. 계측 추가는 속도 개선 완료를 뜻하지 않는다.

## 2026-10-10 개선 전 실제 시뮬레이터 측정

사용자가 기존 Firebase에 생성·초기화를 최대 5회씩 실행하도록 승인했다.
iPad Air 11-inch (M4), iOS 26.4, debug 앱, `develop`의 `7bb2b1e` 위 로컬 계측 후보를
설치했다. Mac에서 시뮬레이터 5대가 부팅된 상태이며 네트워크 품질·실기기 성능은
별도로 측정하지 않았다. FULL은 부하 간섭을 피하려고 아래 측정 종료 후 시작했다.
기존 참가자 0명 방의 초기화와 이후 생성 시도를 정상 앱 UI로 실행했다.

| KST 시각 / 작업 | 전체 | 주요 단계 | 결과 |
| --- | ---: | --- | --- |
| 17:07:49 초기화 1 | 7,418ms | status 3,706ms + close 3,598ms + disconnect 취소 83ms | 성공 |
| 17:08:31 생성 1 | 3,901ms | create callable 3,829ms, 로컬 intent 5ms | 실패 |
| 17:09:13 생성 2 | 761ms | create callable 756ms, 로컬 intent 1ms | 실패 |

생성 실패가 반복되어 초기화 1회·생성 2회에서 추가 요청을 중단했다. 최대 횟수 승인을
성공 5회 측정 완료로 표현하지 않는다. 앱은 방 코드가 없는 로비로 돌아왔으며 서버의
잔여 생성 상태는 직접 조회하지 않았다. 실패 응답만으로 서버 무변경을 단정하지 않는다.

초기화 표본의 98.5%는 순차 callable 두 번이었다. 첫 생성 요청과 재시도 간 차이는
관찰했지만 두 번 모두 실패하므로 정상 생성 속도, warm/cold start, 평균·중앙값 또는
1초대 달성 가능성을 확정할 수 없다. 생성은 resume/presence 단계에 도달하지 않았다.
클라이언트 계측은 오류 원문·코드를 저장하지 않아 실패 원인은 아직 미확정이다.

추가 발견: `tablet_room_panel.dart`의 방 코드 없는 초대 화면은 provider의 `errorMessage`를
표시하지 않는다. 실제 실패 후에도 초대 버튼으로만 돌아왔고, 실패는 진단창에서 확인했다.
성능 개선 전에 생성 실패 원인과 사용자 오류 안내를 함께 다룰 필요가 있다.

앱 진단창과 로컬 iOS unified log의 시간 필드를 대조했다. 정제한 22개 이벤트만
ignored `build/room-latency/device-os-timing.json`에 저장했다. 앱 stdout 연결에는 계측이
전달되지 않아 이 로컬 로그 경로로 확인했다. 운영 서버 로그·RTDB 직접 조회·배포는
하지 않았다. 서버 내부 원인 조사는 별도 조회 범위와 계정 확인이 필요하다.


## 2026-10-10 `디벨럽1` 개선 후보

사용자가 위 분석의 개선을 새 브랜치에서 구현하도록 요청했다. 서버 권위, 요청 ID,
기존 persistent shape, 30초 복구 예산과 종료 방 보존 기간은 유지한다.

| 경로 | 이전 | 개선 후보 |
| --- | --- | --- |
| 정상 신규 생성 | create → resume → presence | 최초 전송이고 응답 connectionSeq=1이면 create → presence |
| 생성 결과 유실·실제 복구 | create 재생 → resume → presence | 유지. 진행된 접속 세대도 resume 사용 |
| 최초 초기화 | status → close | close 직접 전송 |
| 결과 미확정 초기화 | status → 필요 시 close | 유지. 원래 ID/domain 재사용 |
| 초기화 직후 재생성 | created 슬롯이 정리 주기까지 막을 수 있음 | 서버가 확인한 종료 allocation의 completed 슬롯만 기존 CAS에서 교체 |
| 생성 실패 화면 | 빈 로비에서 오류 미표시 | 오류 안내와 기존 초대 재시도 버튼 유지 |

신규 생성도 identity 저장과 presence 성공 후에만 완료한다. 단절 예약은 기존처럼 등록한다.
생성 응답이 유실되거나 presence가 실패하면 durable intent를 보존하고 다음 시도에서
복구 경로를 사용한다. resume 실패/빈 결과를 생성 성공으로 처리하지 않는다.
초기화는 전송 전에 awaitingResult를 저장하며, 앱 재시작·응답 유실 시 status 조회를 보존한다.

서버는 기존 controller 매핑이 가리키는 방의 UID/instance/generation과 종료 상태를 확인한다.
그 방의 creationOperationId 및 generation과 일치하는 `created` 슬롯만 새 `reserved`로
교체한다. `reserved`/다른 operation/다른 generation은 덮어쓰지 않는다. 추가 DB 요청 없이
기존 이전 방 조회와 슬롯 transaction을 사용한다. 기존 방의 물리 정리는 보존 기간 뒤
계속 처리하며, 늦은 close/cleanup은 새 슬롯·방·매핑에 영향을 주지 않는다.
로컬 실제 callable 테스트에서 수정 전 create→close→create 실패를 재현했고, 수정 후
즉시 재생성과 동시 생성 단일 승자·옛 요청/cleanup 보호를 확인했다. 운영 실패의 정확한
오류 코드는 미수집이므로 운영 원인을 확정한 것으로 표현하지 않는다.

### 서버 단계 계측과 남은 최적화

`createRealtimeRoom`, `closeRoom`, `game_common_operation_status`에
`room_action_timing` 구조 로그를 추가했다. 요청마다 action/status/durationMs와 고정
stages별 count/durationMs/failures, 실패 시 표준 errorCode만 남긴다. UID·방 코드·본문·
토큰·오류 메시지·details는 기록하지 않는다. 실패한 로그 출력이 명령 결과를 바꾸지 않는다.
반복 stage는 합산한다. 서버 총 시간은 handler 내부만 측정하며 runtime 기동·callable
프레임워크 인증 이전 지연은 포함하지 않는다. 클라이언트와 서버 시간 차이를 그대로
cold start로 해석하지 않는다.

배포 대상 후보는 위 기존 callable 3개다. 현재 배포하지 않았고 시뮬레이터도 새 후보로
교체하지 않았다. 새 리전/minInstances 설정·DB 이전·의존성 추가는 없다.
배포 승인과 운영 측정 범위를 별도로 확정한 후 같은 환경에서 성공한 생성/초기화의
첫 요청 및 반복값을 측정한다. 서버 onboarding/slot/allocation/mapping/close_transaction
시간과 실행 metadata를 비교해 DB 왕복 또는 기동 지연을 구분한다.

- callable 한 번 제거는 코드·테스트로 확인한 변경이며, 1초대 실측 달성은 미확인이다.
- 콜드 스타트가 확인되면 핵심 함수의 최소 인스턴스 유지 비용을 검토한다.
- DB 대기가 지배적이면 서울 callable–싱가포르 RTDB 배치를 검토한다. 리전 이동은
  클라이언트 호환·기존 함수 유지·Firestore 위치·실측을 포함한 별도 배포 결정이다.
- QR 760ms 연출은 유지했다. UX 조정만으로 서버 처리 완료를 앞당겼다고 표현하지 않는다.


### 후보 검증 결과

관련 Flutter 30개·서버 회귀 9개, session suite와 최종 FULL(사용자 승인 1회)이 모두
PASS/exit 0이다. FULL은 원본과 동일한 영문 경로 사본에서 root 378개·패키지 5개·
Functions 397개 및 포맷/분석/lint를 검증했고 working-tree mutation이 없었다.
[명령·상태·보존 근거](../planning/logs/2026-10.md#room-action-improvement-20261010).
이 결과는 로컬 구현 검증이며 배포 후 응답 시간이나 1초대 달성의 근거가 아니다.
