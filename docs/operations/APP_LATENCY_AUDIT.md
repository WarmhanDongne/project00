# 앱 전체 동작 지연 조사

2026-10-10 · `디벨럽1` · 기준 HEAD `7bb2b1e` + 로컬 로비 개선 후보.
사용자 요청: 앱 안의 모든 동작에서 줄일 수 있는 지연 조사.

후속: [네트워크·화면 응답 개선 개발팀 공유](../engineering/NETWORK_LATENCY_IMPROVEMENTS.md)에
이 조사 이후 구현한 범위와 검증 상태를 기록한다. 아래 표의 ‘현재’는 조사 당시 상태다.

## 결론과 조사 경계

지연은 **고정 연출 대기, 직렬 네트워크 왕복, 서버 DB 처리, 화면·리소스 준비,
오류 복구 대기**로 나뉜다. Firebase 통신 속도 하나로 설명할 수 없다.
가장 먼저 검토할 것은 자리 배치 완료→게임 시작, 방 입장/프로필 성공 연출,
Final Call 교체 명령 전 대기, 최초 퇴장 사전 조회, 게임 목록 직렬 조회다.

`lib/`, `packages/*/lib/`, `functions/src/`의 Dart/TypeScript 559개 파일을 검색했다.
여기에는 생성된 번역 파일 4개가 포함되며 직접 작성한 소스는 555개다.
`gen/`, `*.g.dart`, `*.freezed.dart`는 제외했다. 대기·시간·I/O·저장 관련 검색 결과
1,090행을 출발점으로 사용자 진입점, 공통 서비스, 네 게임의 진행 경로와 서버
export를 추적했다. **559개 파일 모두를 정독했다거나 모든 기기에서 병목을 재현했다는
뜻은 아니다.** SDK 내부·운영 배포 설정·실제 DB 크기·실기기 프레임은 미측정이다.
정적 조사로 찾은 후보 전체를 아래 50개 항목으로 정리했다. 실제 느린 구간 여부와
절감량은 명시된 고정 대기를 제외하면 계측으로 판정한다.

- `확인`: 코드의 실행 순서나 설정을 확인. 성능 병목까지 실측했다는 뜻은 아니다.
- `가설`: 구조상 가능성이 있어 측정할 항목.
- P1: 다음 개선 묶음에서 우선 검토. P2: 계측 후 적용. P3: 연출/제품 또는 구조 결정.
- 아래 경로의 `L숫자`는 조사 시점 줄 번호다. 코드 변경 후 위치는 달라질 수 있다.
- 이번 작업은 조사·문서화다. 새 앱 코드 변경, 운영 조회, 배포, 측정 요청은 하지 않았다.

## 이미 있는 측정과 개선 후보

[로비 측정 기록](ROOM_ACTION_LATENCY.md)을 기준으로, debug iPad Simulator의 초기화
1회는 7,418ms였다. 이 중 상태 조회 3,706ms, 종료 callable 3,598ms였다. 생성 두 번은
각각 3,901ms와 761ms에 **실패**했다. 성공 생성의 평균·p95나 개선 후 시간은 없다.
이 자료로 cold start, 리전, 회선 중 하나를 원인으로 확정할 수 없다.

현재 로컬 후보에는 최초 생성 직후 불필요한 resume 생략, 최초 초기화의 status 조회 생략,
종료 방 즉시 재생성 CAS 수정, 오류 표시, client/server 단계 계측이 들어 있다.
이전 승인 FULL은 PASS지만 아직 개선 후 운영 실측은 없다. 아래에서는 재구현 대상으로
세지 않고 후속 범위를 구분한다.

## A. 앱 실행·로그인·프로필

| ID / 우선 | 확인한 경로와 근거 | 개선 방향 / 검증할 점 |
| --- | --- | --- |
| A01 P1 | 확인. [main.dart](../../lib/main.dart) L41–114: `runApp` 전에 Firebase→Crashlytics→에셋 저장소→App Check→초기 링크→Google SDK를 차례로 await | 최소 시작 화면을 먼저 표시하고 의존성이 없는 초기화만 병행. Firebase/App Check 준비 전에 보호된 요청을 보내지 않는다. 첫 프레임과 로그인 가능 시간을 따로 측정 |
| A02 P2 | 확인. [game_asset_bootstrap.dart](../../lib/game_assets/game_asset_bootstrap.dart) L24: 앱 디렉터리와 현재 패치 번호를 직렬 조회 | 두 로컬 준비의 병행 가능성 검증. 다운로드는 여기서 발생하지 않음. Google SDK도 실제 로그인 이전까지 준비 보장이 되는 지연 초기화 검토 |
| A03 P2 | 확인. [auth_provider.dart](../../lib/platform/auth/providers/auth_provider.dart) L180, L239: 외부 로그인→Firebase 로그인→서버 프로필 동기화. [auth_gate.dart](../../lib/platform/auth/widgets/auth_gate.dart) L206: onboarding 구독 | 단계별 시간 분리, 같은 UID의 중복 동기화/구독 생성 방지. 인증·가입 상태 확인을 생략해서 빠르게 보이게 하지 않는다. 이메일 링크, 신규/기존 계정, 계정 전환을 각각 측정 |
| A04 P2 | 확인. [onboarding_service.dart](../../lib/platform/auth/services/onboarding_service.dart): 이메일 링크 완료·비밀번호 변경·프로필 완료는 앞 단계 결과에 의존 | 입력 검증을 로컬에서 먼저, 중복 제출 잠금과 결과 재사용. 메일 발송·메일 앱 왕복은 앱 네트워크 시간과 분리. 재발송 cooldown은 속도 최적화로 제거하지 않음 |
| A05 P1 | 확인. [tablet_profile_modal.dart](../../lib/platform/profile/widgets/tablet_profile_modal.dart) L119: 저장 성공 후 기본 모션에서 **800ms** 대기 | 저장 성공 표시를 닫기/다음 화면과 겹치거나 짧게. reduced motion에서는 이미 0이므로 중복 변경하지 않음 |
| A06 P2 | 확인. 같은 파일 L104 및 [auth_service.dart](../../lib/platform/auth/services/auth_service.dart) L94: 이미지 upload→URL→Auth 사진 변경→닉네임 변경→프로필 callable | 변경 필드만 저장하고 독립 단계 병행/단일 프로필 갱신 설계 검토. 실패 시 부분 저장·재시도 일관성 유지. 이미지 선택은 이미 최대 1024px/quality 85. 업로드 바이트·시간 먼저 측정 |
| A07 P2 | 확인. [auth_provider.dart](../../lib/platform/auth/providers/auth_provider.dart) L342: Google signOut 다음 Firebase signOut. [delete-account.ts](../../functions/src/auth/delete-account.ts): 방/문서/파일 정리 뒤 Auth 삭제 | 로그아웃 지연을 provider별 분리 측정. 화면 busy 피드백 즉시 표시. 탈퇴는 정리 성공을 보존하고 실패/진행 안내 개선; 삭제를 무조건 백그라운드로 보내거나 Auth부터 삭제하지 않음 |
| A08 P2 | 확인. [locale_settings.dart](../../lib/platform/localization/locale_settings.dart): 작은 JSON 로컬 저장, [shorebird_patch_gate.dart](../../packages/game_kit/lib/core/update/shorebird_patch_gate.dart): 업데이트 확인/적용 | 언어·음량·패치 각각 로컬 저장/플러그인 시간 분리. locale load는 이미 비동기, 패치 확인도 항상 첫 화면을 막는 구조로 단정하지 않음. 실제 업데이트가 있는 경우의 blocking UI와 게임 중 적용 정책 별도 검토 |

## B. 로비·입장·선택·게임 시작·퇴장

| ID / 우선 | 확인한 경로와 근거 | 개선 방향 / 검증할 점 |
| --- | --- | --- |
| B01 P1 | 확인. [room_service.dart](../../lib/platform/home/room/services/room_service.dart) L145, L309: create/close 로컬 개선 후보가 있음 | 기존 후보 배포 전후를 같은 조건에서 비교. 생성은 서버 응답 이후 identity/presence 준비까지, 초기화는 서버 종료와 로컬 정리까지 측정. QR/코드 연출 시간은 별도 |
| B02 P1 | 확인. [phone_room_join.dart](../../lib/platform/home/phone/screens/phone_room_join.dart) L120: validate 성공 뒤 **680ms** 연출, 그 뒤 camera stop | 성공 연출과 화면 이동을 겹치거나 단축. scanner stop도 안전하게 겹칠 수 있는지 확인. 중복 스캔 잠금·카메라 해제·실패 표시는 유지 |
| B03 P1 | 확인. [room_service.dart](../../lib/platform/home/room/services/room_service.dart) L879: roomInstanceId 읽기→내 player 읽기→pending 저장→join 호출 | 앞선 두 독립 조회의 병행으로 직렬 단계 하나 제거 후보. 결과의 roomInstance/membership/connectionSeq는 서버에서 다시 검증. 미확정 join 재전송 및 강퇴 후 자동 재가입 금지 유지 |
| B04 P2 | 확인. 같은 파일 L722: 자동 복원은 내 membership 확인 후 status/selectedGame/game status 병렬 읽기. 프로필 변경도 join 경로 사용 | 정상 신규 참가, 재접속, 방 내 프로필 변경을 각각 계측. 이미 병렬인 3개 조회는 재최적화하지 않음. 복원 membership 선행 확인은 권한/강퇴 판정에 필요 |
| B05 P1 | 확인. [game_list_service.dart](../../lib/platform/home/gamelist/service/game_list_service.dart) L22: games 목록 후 내 보유 목록, L54: 그룹 권한 callable 후 games 목록 | 독립 조회 병행, 같은 카탈로그 응답 공유. 계정/방 전환 후 오래된 결과 배제. 보유 권한 자체를 무기한 캐시하거나 타인 users 문서를 클라이언트에서 조회하지 않음 |
| B06 P1 | 확인. [game_list_provider.dart](../../lib/platform/home/gamelist/provider/game_list_provider.dart) L29, 휴대폰 home·책장·상점 호출부 | 서비스 수준 in-flight 공유와 카탈로그 캐시, 재진입 시 기존 목록 유지하며 갱신. 상점 일부 호출부의 isLoading 가드는 이미 있음. 권한 변경/로그아웃/게임 비활성화 invalidation 필요 |
| B07 P2 | 확인. [tablet_game_launcher.dart](../../lib/platform/home/tablet/tablet_game_launcher.dart) L124–152: 에셋 준비→선택 보장→seating 호출. 서버 select와 seating에도 게임 조회 | 상세 화면/선택 시점에 필요한 리소스 준비를 앞당김. 다운로드는 사용자 동작·용량 정책 유지. 선택+seating 왕복 통합은 별도 API 설계; 선택 실패인데 seating을 먼저 시작하지 않음 |
| B08 P1 | 확인. [player_layout_editor.dart](../../packages/game_kit/lib/player_layouts/widgets/player_layout_editor.dart) L181, L394: **1,600ms 연출→250ms hold→onPrepare→1,000ms 줌** | 기본 정상 경로의 연출 합은 약 **2.85초**. 확정 좌석을 캡처하고 서버 준비를 앞선 연출과 병행하면 최대 1.85초 구간을 통신과 겹칠 여지. 연출 자체 단축은 별도 선택. 실패 롤백·취소·roster 변경·준비 barrier 검증 |
| B09 P2 | 확인. [tablet_game_start.dart](../../lib/platform/home/tablet/tablet_game_start.dart) L20: pending 확인→좌석 저장 callable→게임 시작 callable | 좌석 저장과 시작을 한 서버 명령으로 합치는 설계 후보. start intent/같은 command ID/서버 좌석 검증/응답 유실 복구 보존. 두 명령을 무작정 병렬로 보내면 안 됨 |
| B10 P1 | 확인. [room_service.dart](../../lib/platform/home/room/services/room_service.dart) L985–1034: 최초 퇴장도 status callable 후 leave callable | 초기화 후보와 같이 새 leave는 즉시 전송, 이미 미확정인 요청만 status 확인하도록 검토. 공통 플랫폼·네 게임 퇴장 모두 영향. durable intent와 중복 leave/재가입 세대 보호 회귀 필요 |
| B11 P2 | 확인. [tablet_home.dart](../../lib/platform/home/tablet/screens/tablet_home.dart) L175: 복원 준비를 150ms마다 재확인 | provider의 게임/참가자 준비 이벤트로 구동해 polling 지연과 불필요 Future 제거. route 종료·방 변경 때 취소, 한 번만 진입하도록 보장 |
| B12 P2 | 확인. [room_provider.dart](../../lib/platform/home/room/providers/room_provider.dart) L739: players heartbeat 이벤트마다 notify. [room_service.dart](../../lib/platform/home/room/services/room_service.dart) L529: players 전체 구독 | presence 타임스탬프와 화면 표시 필드를 분리 비교하고 Selector/select로 작은 영역만 갱신. stale 판단은 모든 heartbeat를 계속 소비. 그룹 보유 게임은 이미 membership 변경 때만 다시 조회하므로 heartbeat마다 callable이라는 주장은 틀림 |

## C. 공통 네트워크·서버·저장

| ID / 우선 | 확인한 경로와 근거 | 개선 방향 / 검증할 점 |
| --- | --- | --- |
| C01 P1 | 확인. [create-room.ts](../../functions/src/room/create-room.ts): onboarding, 이전 매핑/방, 슬롯, reservation, allocation, commit, 재확인이 직렬로 연결 | 기존 단계 타이머로 상위 지연부터 판정. allocation/매핑 동시성 때문에 필요한 재확인을 먼저 삭제하지 않는다. 같은 요청 내 중복 snapshot 재사용과 원자적 경계 통합은 검증된 구간만 |
| C02 P2 | 확인. [holdem/start-game.ts](../../functions/src/holdem/start-game.ts) L36, [mafia/start-game.ts](../../functions/src/mafia/start-game.ts) L52 및 다른 게임 start: replay 조회→room 조회→primed transaction | replay와 준비용 snapshot을 요청 내부에서 공유하는 방안. 트랜잭션 내부 재검증/응답 replay는 유지. 원격 왕복과 캐시 hit를 계측하여 실제 절감 판정 |
| C03 P1 | 확인/가설. [game-command-transaction.ts](../../functions/src/game-interruption/game-command-transaction.ts) L27: 방 전체 transaction, game structuredClone. 하위 connection heartbeat와 동일 트리 | 참가자/명령 수별 room 바이트·callback 재실행·transaction 시간 측정. 높은 충돌이 입증되면 presence와 게임 command 원자성 경계를 재설계. public/private/ledger를 따로 써 일시 불일치시키지 않음 |
| C04 P1 | 확인/가설. [session-contract.ts](../../functions/src/room/session-contract.ts) L89: 성공 command를 sessionOperations에 계속 기록. 소스에서 활성 방 ledger pruning 없음 | 긴 방 세션에서 history 크기와 트랜잭션 비용 확인. 중복 처리 방지용 기록을 단순 TTL 삭제하면 오래된 재시도가 재실행될 수 있음. 종료 세대 tombstone/압축/별도 인덱스는 호환 계약부터 설계 |
| C05 P1 | 확인/가설. [room-cleanup.ts](../../functions/src/room/room-cleanup.ts) L45: 방 하위 모든 변경에 trigger→현재 방 전체 get→queue transaction | deadline/instance/generation에 영향 없는 변경의 enqueue·재읽기 생략 검토. heartbeat가 cleanup deadline을 갱신하는 경우는 보존. 이전 이벤트 역전·정기 스캔 안전장치 유지. trigger는 원 명령의 직접 await가 아니므로 효과는 부하/후속 처리에 있음 |
| C06 P2 | 확인/가설. [session-functions.ts](../../functions/src/room/session-functions.ts) L60, [controller-presence.ts](../../functions/src/game-interruption/controller-presence.ts) L109: connection→요약/presence→recovery 후속 trigger | 1회 heartbeat/게임 동작이 만드는 함수 실행·DB 쓰기 수 측정. 값 동일 시 write 억제, summary 갱신 조건 축소. 복구 barrier 알림 자체를 생략하지 않음 |
| C07 P2 | 확인/가설. callable 설정은 서울 `asia-northeast3`, RTDB endpoint/trigger는 싱가포르 `asia-southeast1` | 사용자→함수 + 함수→DB 전체 지연으로 비교. Firestore/Storage 운영 위치는 미확인. callable만 DB 근처로 옮겨도 사용자 RTT가 늘 수 있어 총합 검증. RTDB 이전은 데이터 migration이라 후순위 |
| C08 P2 | 가설. 소스에 minInstances 지정 없음. [index.ts](../../functions/src/index.ts)가 여러 함수 모듈 export | 실제 cold/warm, revision, instance 시작 시간을 확인한 뒤 핵심 함수만 minInstances/초기화 축소/CPU·concurrency 실험. 콘솔 override 존재는 미확인. 비용과 부하 분산 영향 포함; 전체 함수를 상시 warm하는 제안 아님 |
| C09 P2 | 확인. [game_command_service.dart](../../packages/game_kit/lib/services/game_command_service.dart) L416 및 각 게임 command: 여러 callable warmup을 병렬 호출 | 이미 warmup 있음. 방/게임/클라이언트당 실행 횟수 확인하고 중복·동시 폭주 제한. warmup 완료를 사용자 버튼의 선행 조건으로 만들지 않음. warmup해도 다음 요청의 같은 인스턴스 배정은 보장되지 않음 |
| C10 P2 | 확인. [durable_room_operation_store.dart](../../packages/game_kit/lib/recovery/services/durable_room_operation_store.dart) L68–89: JSON deep copy/전체 재직렬화/직렬 저장. confirmed 과거 scope도 유지 | 저장 크기·시간 측정, 확정 기록의 안전한 압축·정리, 한 논리 전이 내 중복 쓰기 감소. intent 저장 전에 전송하면 안 됨. unknown은 만료시키지 않고 UID/세대별 replay 의미 유지 |
| C11 P2 | 확인. [game_query_service.dart](../../packages/game_kit/lib/services/game_query_service.dart) L46: 공개 game 전체, 사용자 private 별도 구독 | snapshot 바이트·역직렬화·UI rebuild를 분리. 필요한 작은 공개 필드/파생 상태 selector, 동일 값 알림 억제 검토. 전체 room을 클라이언트가 읽는 구조는 아니며 private 분리 유지 |
| C12 P2 | 확인. [room_recovery_batch.dart](../../packages/game_kit/lib/recovery/services/room_recovery_batch.dart), [callable_retry_policy.dart](../../packages/game_kit/lib/recovery/services/callable_retry_policy.dart), [game_progress_command.dart](../../packages/game_kit/lib/recovery/services/game_progress_command.dart) | 첫 시도/재시도 횟수/상태 조회/백오프 시간을 따로 표시. 온라인 이벤트 뒤 stale retry 예약 중복 방지와 같은 명령 공유 검토. timeout 단축은 서버 처리 취소가 아니며 이중 실행을 늘릴 수 있음 |

## D. 네 게임의 실제 행동과 단계 진행

| ID / 우선 | 확인한 경로와 근거 | 개선 방향 / 검증할 점 |
| --- | --- | --- |
| D01 P1 | 확인. [Final Call board_state.dart](../../packages/game_final_call/lib/phone/src/board_state.dart) L219: 교체/버리기 **460ms** 후 completeTurn 전송 | 입력 즉시 현재 턴·카드를 캡처해 전송하고 애니메이션 병행. 상태 도착/실패/응답 유실/마감 직전 클릭의 시각 복귀 처리 필요. 서버 턴 검증 유지 |
| D02 P3 | 확인. [FinalCallPhoneTiming](../../packages/game_final_call/lib/phone/phone_board.dart) L61: 카드 받기 2.3초, controls 0.92초, call 안내 4.2초. tablet 결과 뒤 별도 Timer | 사용자 입력을 막는 announcement/controls만 단축 후보로 분리. 안내 표시 시간 전체가 네트워크 대기는 아님. phone/tablet 병행 시간을 더하지 않는다. 빠른 진행 모드와 기존 연출 비교 |
| D03 P2 | 확인. [LP hand_card_stack.dart](../../packages/game_liars_poker/lib/phone/widgets/hand_card_stack.dart) L401: **제출 Future를 먼저 시작**, 420ms 연출과 병행 | 이미 잘 겹친 경로. 별도 선행 420ms 통신 지연으로 오인하지 않음. 요청→서버 상태→다음 행동 가능 시간 측정. 실패 복귀 380ms는 실패 UX 조정 대상 |
| D04 P3 | 확인. [LP game_controller.dart](../../packages/game_liars_poker/lib/shared/providers/game_controller.dart) L525: 판정 표시 1초+2.9초; L735: 제출 실패 시 손패 확인 140ms×최대6 | 판정/벌칙/룰렛 연출과 실제 phase 전환을 함께 추적. 실패 확인은 stream 이벤트로 조기 완료 가능. 일반 제출마다 840ms를 기다리는 것은 아님. 벌칙 정보 공개 순서와 서버 마감 보존 |
| D05 P3 | 확인. [HoldemTiming](../../packages/game_holdem/lib/shared/models/presentation_timing.dart): dealing 3.35초, 결과 showdown 12초/그 외3초. [tablet_board.dart](../../packages/game_holdem/lib/tablet/tablet_board.dart) L94 | 준비/결과 연출이 실제 다음 단계 호출을 늦춤. 재개 시 이미 지난 연출을 전부 다시 재생하는지 검증. 빨리 넘기기/공유 빠른 진행 옵션 검토; 각 휴대폰 독자 skip은 상태 분열 위험 |
| D06 P3 | 확인. [MafiaPresentationTiming](../../packages/game_mafia/lib/shared/models/presentation_timing.dart): 아침2.5초, 사망8초, 노출9초, 집계4초, 처형 이름4초·공개5초, 종료3초 | 마피아는 발표·내레이션·토론 규칙 시간이 크다. 네트워크 최적화와 분리해 공통 연출표로 조정. 서버 제한시간은 별개. 역할 설정의2초 Timer는 편집 모드 종료이지 저장 전송 debounce가 아님 |
| D07 P2 | 확인. [game_session_controller.dart](../../packages/game_kit/lib/recovery/providers/game_session_controller.dart) L113: assets→endOfFrame→준비 report. 모든 게임의 완료/다음 단계 callable | 리소스 준비를 앞당기고 서버 응답과 RTDB 반영 사이 빈 구간을 계측. 첫 프레임·private snapshot·준비 ack 없이 다음 턴을 열지 않음. 연출 끝난 뒤 callable 왕복을 숨기려면 공유 deadline/진행 계약 검토 |
| D08 P2 | 확인. 네 게임 command 서비스와 [functions/index.ts](../../functions/src/index.ts) | LP 제출/LIAR/pass/벌칙, FC draw/교체/call/최종패/다음판, Holdem fold/check/call/raise/all-in, Mafia 역할확인/밤행동/투표/토론종료/timeout에 동일 단계 계측. 로컬 선택 강조는 즉시, 확정 승패·카드·잔액은 서버 기준. finish/restart/leave도 같은 회귀 표에 포함 |

## E. 리소스·화면·소리

| ID / 우선 | 확인한 경로와 근거 | 개선 방향 / 검증할 점 |
| --- | --- | --- |
| E01 P1 | 확인. [game_asset_cache.dart](../../packages/game_kit/lib/core/assets/game_asset_cache.dart) L60: 파일별 다운로드·검증·rename 직렬. **현재 Holdem은 remote v2**, 다른 세 게임은 번들 기본값 | 네트워크/디스크 제한을 두고 2–4개 파일 병행 실험. 설치 중복 방지·partial 파일·모든 hash 검증 뒤 complete marker 유지. 큰 묶음 archive/CDN은 실제 파일 수와 바이트 측정 후 별도 설계 |
| E02 P2 | 확인. 같은 파일 L99, L174: prepare마다 설치 파일 hash 검증. [game_asset_prepare.dart](../../lib/game_assets/game_asset_prepare.dart): 준비 실패→다운로드→다시 준비 | 같은 설치 버전의 동시 검증 공유, 한 진입 흐름의 중복 검증 제거 검토. 설치/교체/손상/패치에서 invalidation. 검증을 영구 생략하면 안 됨. SHA는 이미 stream 처리라 전체 파일 메모리 로드로 오인하지 않음 |
| E03 P2 | 확인. 같은 파일 L93, L154: existsSync 경로 확인. [GameImage](../../packages/game_kit/lib/core/assets/game_image.dart) L72: 표시 크기는 받지만 decode 크기 API 없음 | remote provider 해석 결과 캐시·파일 확인을 준비 단계로 이동. 실제 표시 픽셀/DPR에 맞춘 ResizeImage 또는 decode 크기 옵션 검토. API 추가 시 소비자 호환 검토. GPU/이미지 메모리 실측 필요 |
| E04 P2 | 확인. [LP asset_preloader.dart](../../packages/game_liars_poker/lib/shared/services/asset_preloader.dart) 및 FC/Mafia preloader | 이미 이미지 4개씩 병행·사운드 비동기 준비. 첫 화면 필수 이미지와 후속 라운드 이미지를 구분하여 barrier 대상 최소화. 게임/기기별 캐시 eviction·재입장 메모리 측정; 전부 무제한 precache하지 않음 |
| E05 P2 | 확인. [sound_service.dart](../../packages/game_kit/lib/sound/services/sound_service.dart): 준비된 효과음 pool 재사용, preload 소스/사본 순차, setEffectVolume 각 player 순차 | 첫 소리의 준비 누락, 동일 소리 동시 preload, 볼륨 슬라이더의 오래된 쓰기 누적 측정. 준비 작업 공유와 마지막 볼륨만 반영하는 coalescing 검토. decoder 수 제한·scope 해제를 지키며 제한 병행 |
| E06 P3 | 확인. [book_open_route.dart](../../lib/platform/home/tablet/book_open_route.dart) L21: 진입760/복귀320ms, [game_exit_route.dart](../../packages/game_kit/lib/widgets/game_exit_route.dart) L5: 복귀960ms, how-to route560/360ms | 반복 사용하는 진입/복귀부터 짧게 하고 reduced motion에 실제 route duration도 일치시키는지 확인. 연출 지속시간=항상 입력 불가 시간은 아님. 방 코드/QR 동시 연출도 합산하지 않음 |
| E07 P2 | 확인. [store_motion.dart](../../lib/platform/home/store/store_motion.dart) L33: 등장 완료 전 IgnorePointer. 도움말 자동 넘김7.2초, scene5.6초 | 요소가 보이고 위치가 안정되면 입력 허용하는 시점 검토. 도움말은 수동 넘김과 자동 재생을 구분. 상점 구매/복원은 현재 UI placeholder여서 결제 API 지연은 분석 대상 구현 자체가 없음 |
| E08 P2 | 가설. 로비/provider 전체 rebuild, LP penalty blur, round reveal ShaderMask, 여러 게임의 정적 배경+움직이는 카드 | profile frame trace에서 UI/raster 구분 후 Selector, AnimatedBuilder child, 필요한 RepaintBoundary, 그림 decode 크기 적용. shader/blur가 있다는 이유만으로 삭제하지 않는다. timer250ms/1초 UI tick도 해당 영역만 rebuild하도록 확인 |
| E09 P2 | 확인. [game_communication_log.dart](../../packages/game_kit/lib/core/diagnostics/game_communication_log.dart) L45/89: debug에만 기록. 이전 실행은 Simulator debug | 로그 켠/끈 동일 조건과 실기기 profile을 분리. 콘솔 출력·DevTools·동시 Simulator 부하를 통신 병목으로 계산하지 않음. release에서 원래 비활성인 계측을 제거해도 배포 성능은 개선되지 않음 |
| E10 P2 | 확인/가설. 시작/재개/화면 진입/업데이트/소리/에셋 준비의 여러 owner가 비동기 작업 실행 | background→foreground, 빠른 화면 왕복, 다른 게임 이동에서 이전 작업이 계속 CPU/I/O를 쓰는지 측정. dispose/generation 취소와 in-flight 공유를 경계마다 검토. SDK 요청 취소 불가 시 결과만 폐기하고 중복 제출 방지 |

## 잘못 줄이면 안 되는 대기 및 이미 적용된 최적화

- 서버 권한·membership·connectionSeq·phase/turn 검증, durable intent, idempotency는 유지한다.
- [room-transaction.ts](../../functions/src/room/room-transaction.ts)의 첫 value 대기는 빈 SDK 캐시에서 transaction이 잘못 abort되는 것을 막는다. 단순 삭제 금지.
- client timeout/heartbeat/재시도/이메일 cooldown/턴 시간은 애니메이션과 성격이 다르다.
  짧게 하면 실제 처리가 빨라지는 게 아니라 실패·오판·중복 실행이 늘 수 있다.
- 그룹 권한 서버의 사용자 읽기, onboarding 검증의 두 문서 읽기는 이미 병렬이다.
  그룹 구성 최신성 재확인은 안전성 검사다.
- LP 카드 제출, 이미지 preload, 오디오 첫 프레임 이후 초기화, 작은 room marker 구독,
  public/private 분리, metadata보다 selectedGame ID 먼저 전달은 이미 적용되어 있다.
- 인증 token 강제 갱신을 매 요청 수행하는 구조로 확인되지 않았다. 업로드 등 일부 실패
  재시도에서만 강제 갱신한다. 이를 일반 지연 원인으로 단정하지 않는다.
- 연출 시간은 겹쳐 실행될 수 있다. 특히 phone/tablet, 카드 배분/안내, QR/코드 시간을
  전부 더해 사용자 대기 시간이라고 표시하지 않는다.

## 동작별 측정 체크리스트

이 표는 후속 측정 범위이며 이번에 실행했다는 뜻이 아니다.

| 영역 | 빠뜨리지 않을 시나리오 | 구분할 완료 시점 |
| --- | --- | --- |
| 실행/인증 | cold/warm launch, 이메일/Google/Apple, 신규 가입/기존/링크 재진입, 로그아웃, 탈퇴 | 첫 프레임 / 입력 가능 / 인증 / 프로필 / home |
| 프로필/설정 | 닉네임만, 사진만, 둘 다, 변경 없음, 언어·지역·음량 | 로컬 반응 / 저장 / 성공 표시 종료 |
| 로비 | 생성/초기화/즉시 재생성, 코드/QR 입력, preview, 닉네임·캐릭터, 신규/기존 참가, kick/leave | 버튼 / callable / presence / RTDB / 실제 프레임 |
| 탐색 | home·책장·상점 왕복, 상세·도움말·책 복귀, 소유 목록 변경 | 캐시 표시 / 최신 데이터 / 애니메이션 / 클릭 가능 |
| 시작 | 게임 선택/해제, 좌석 드래그·완료·취소, roster 변경, 첫 다운로드/설치 완료/손상 | 준비 / 저장 / start / 자산 / 모든 기기 ready / 첫 턴 |
| 네 게임 | D08 각 행동, 타임아웃, 결과/다음판/재시작/종료/퇴장 | 요청 전 대기 / 서버 확정 / 상태 수신 / 표시 / 다음 입력 |
| 복구 | Wi-Fi 단절/복구, 앱 background/재시작, controller 복귀, 느린 한 참가자, 결과 유실 | 감지 / 첫 시도 / 재시도 / 상태확인 / 준비 barrier 해제 |
| 장시간 | 연속 게임·많은 명령·게임 교체, 2명/4명/각 게임 최대 인원 | ledger/room 크기 / 메모리 / rebuild / trigger 수 |

계측은 단조 시계로 `tap → 명령 전송 → 응답 → RTDB 반영 → 화면 프레임 → 다음 입력 허용`을
나눈다. 병행 구간은 벽시계 임계 경로로 계산한다. 서버 handler 진입/DB 단계/transaction
callback 횟수/handler 종료를 연결하되 방 코드·UID·token·private 카드 원문은 기록하지 않는다.
handler 이전 인증/App Check/instance 대기는 클라이언트 총시간에 포함될 수 있다.

정상/실패, 최초/반복, 참가자 수, Wi-Fi 조건, 빌드 종류를 섞지 않는다. 작은 표본은 개별값과
median만 보고, 의미 있는 p95는 충분한 반복 표본을 확보한 뒤 계산한다. Emulator는 회귀와
부하 형태 검증용이며 실제 Firebase의 RTT/cold start 성능 증거가 아니다.

사용자가 원한 **1초대**는 우선 정상·반복 로비 명령의 목표 후보로 삼는다. 모든 게임 연출과
메일/로그인 외부 창까지 1초로 끝난다는 약속은 아니다. 입력에 대한 시각 피드백은 즉시,
네트워크를 기다리는 시간과 확정 성공 표시를 구분한다. 구체적 합격선은 baseline 이후 정한다.

## 실행 순서 제안

1. 기존 로비 후보의 배포/실측을 별도 승인 범위에서 마무리하고 공통 단계 계측을 확대한다.
2. A05/B02/D01/B08의 고정 대기와 B05/B06/B10의 중복 왕복을 개선한다.
   연출 축소와 단순 병행은 구분하며, UI 모양을 유지하고 통신을 겹치는 방법부터 검토한다.
3. B12/C05/E01/E02를 참가자 수·캐시 상태별로 측정해 다음 순위를 정한다.
4. C03/C04/C07/C08/B09는 원자성·배포·비용·호환성 영향이 크므로 별도 설계한다.
5. D02/D04/D05/D06/E06은 빠른 진행/모션 정책 결정 후 공통 시간표와 서버 조건을 함께 검증한다.

후속 구현에는 해당 targeted suite와 승인된 FULL이 필요하다. 이번 조사에서 이전 FULL을
새 개선안의 통과 증거로 재사용하지 않는다. 새 운영 요청·서버 배포·리전 변경은 별도 실행 범위다.

## 공식 성능 기준과 로컬 증거

- 실기기 profile에서 UI/raster 프레임과 시작 시간을 측정한다. Simulator debug 수치는
  제품 성능 판정과 구분한다. [Flutter performance profiling](https://docs.flutter.dev/perf/ui-performance)
- 불필요한 rebuild, 과도한 이미지 decode, 비싼 레이어는 프로파일러 근거로 줄인다.
  [Flutter best practices](https://docs.flutter.dev/perf/best-practices)
- Functions 리전은 사용자와 의존 서비스 위치를 함께 고려한다.
  [Firebase Functions locations](https://firebase.google.com/docs/functions/locations)
- cold start/초기화와 최소 인스턴스는 지연·비용을 같이 평가한다.
  [Functions tips](https://firebase.google.com/docs/functions/tips)
- RTDB는 내려받는 범위, listener, 인덱스, 부하 지표를 확인한다.
  [RTDB optimization](https://firebase.google.com/docs/database/usage/optimize)

검색 원본·소스 SHA-256·CSV 목록·서버 export 목록은 ignored
`build/app-latency-audit/`에 저장한다. 이는 재검토를 돕는 로컬 증거이고 정적 분석기가
보증한 모든 네트워크 요청/대기 개수는 아니다. 이 문서가 제안과 판정의 tracked 기록이다.
