# SESSION-RECONNECT-02

게임 재접속 보완·단절 신고 재시도·네트워크 가드·기기별 검증

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

**서버 상태 기반 게임 복귀와 공용 재접속 처리 보완**

- 등록일: 2026-09-30.
- 최초 결정(2026-09-30): 브랜치 병합 충돌을 피하기 위해 수정은 추후 진행하고 TODO를 등록했다.
- 현재 분류·상태(2026-10-04): 사용자가 출시 전 필수로 지정했다. 담당 범위·복구 계약 합의
  전까지 구현 착수는 보류하며, 필수 분류를 배포나 계약 변경 승인으로 해석하지 않는다.
- 협업 경계: 개발자 2명이 분담하며 사용자 담당은 `packages/`다. 플랫폼·서버 수정도
  필요하므로 팀원과 범위를 합의한다. 별도 승인 없이 패키지 밖 구현을 수정하지 않는다.
- 목적: 순간 단절과 앱 재실행 모두에서 기존 참가 자격·게임 상태를 유지하고,
  데이터·구독·화면이 준비된 뒤 안전하게 게임으로 복귀한다.
- 관련 기록: 2026-09-29~30 재접속 분석·설계 대화와 보류 요청을 아래에 요약했다.
  기존 [SESSION-RECONNECT-01 완료 기록](../COMPLETED_TASKS.md)은 당시 검증 범위로
  유지한다. [NET-RECOVERY-01](NET-RECOVERY-01.md#net-recovery-01)의 순수 체감 지연과 구분한다.

## 확인 근거와 추가 재현 대상 — 원 검토 기준

아래는 `fa4ad54` 기준의 코드·변경 이력 확인이며 운영 서버·실기기 PASS 판정은 아니다.
분배 중 복원·다중 단절은 기존 결함, 준비 완료·옛 요청 도착은 계약 공백, 빈 조회와
재진입 연출의 실제 영향은 추가 재현 대상으로 관리한다. 9월 30일 구조 변경·10월 2일
안정성 보완이 병합됐어도 외부 플랫폼·서버 범위는 자동 착수된 것으로 보지 않는다.

## 분배 중 복원 판정과 로컬 세션 삭제

[복원 판정](../../../lib/platform/home/room/services/room_common.dart)은 진행 중 게임에서
`privateGameDataExists`를 필수로 요구한다. 그러나 라이어스포커와 파이널콜은 분배 중
손패를 `game/server.pendingHands`에 두고 `game/private`를 비운다.
정상 분배 상태가 복원 불가로 판정되면 `detectRestorableSession`과 `restorePlayerRoom`이
저장 세션을 지운다.

이 불일치는 8월 비교 코드에도 있다. 9월 회귀로 단정하지 않는다. 빈 손패·탈락 관전의
영향은 각 게임의 실제 private 노드 유지 여부를 별도 확인해야 한다.

## 다중 참가자 단절과 시간 보존

[중단 상태 처리](../../../functions/src/game-interruption/state.ts)의 `beginGameInterruption`은
이미 다른 참가자의 중단이 있으면 추가 단절을 등록하지 않는다. A 단절 → B 단절 →
A 복귀 순서에서 A의 중단을 취소할 때 B의 단절 상태 전체를 다시 검사하지 않는다.
controller pause가 남아 있지 않다면 deadline을 복원할 수 있다.

이 코드는 `ea27b79` 이후 변경되지 않았다. 8월에 검증한 단일 참가자 반복 단절 및
참가자+controller 중첩 중단과, 여러 참가자 동시 단절은 서로 다른 경우다.
기존 시간 보존 통과를 취소하기보다 추가 실패 조건을 따로 관리해야 한다.

- 앞선 분석의 서버 메모리 실행에서는 A 단절 → B 단절 → A 복귀 때 B가 끊긴 채
  턴이 재개되는 조건을 재현했다. 운영 서버·실기기 재현과 구분한다.

## 연결 복구·구독 재개·실제 준비 완료

`RoomProvider._performConnectionRecovery`는 controller/player presence를 복구하고
heartbeat를 시작하면 반환한다. 공개·개인 스냅샷이 같은 판·라운드의 최신 데이터인지,
권한 오류로 끝난 구독이 다시 열렸는지를 기다리는 계약은 없다.

[AppNetworkGuard](../../../packages/game_kit/lib/core/network/app_network_guard.dart)는
`onRetry`가 정상 반환하면 입력 보호를 해제한다.
[GameSessionController](../../../packages/game_kit/lib/game_flow/game_session_controller.dart)는
구독을 최초 `startSession`에서 열지만 오류로 끝난 구독을 다시 여는 경로가 없다.
연결 표시 정상화 뒤에도 화면이 굳거나 오래된 손패로 입력할 위험을 조사해야 한다.
일반적인 RTDB 자동 재연결과 취소된 구독 재생성은 구분한다.

## 태블릿 최초 오프라인 복구

[TabletHome](../../../lib/platform/home/tablet/screens/tablet_home.dart)은 `initState`에서
`restoreControllerRoom`을 한 번 호출한다. 실패하면 provider의 roomCode가 없는 상태로
남는다. lifecycle 복귀는 `resumeControllerPresence`만 호출하고, 이는 roomCode가 없으면
반환한다. 휴대폰 홈과 달리 최초 복구 실패 뒤 연결 true 이벤트로 저장 방 복구를 다시
시작하는 경로가 없다. 앱을 다시 열어야 복구가 재시도되는지 실기기 확인이 필요하다.

## 재진입 연출과 이미 전송된 요청

- [라이어스포커 태블릿 board](../../../packages/game_liars_poker/lib/tablet/src/board_state.dart)는
  첫 스냅샷에서 카드 더미가 비어 있으면 서버 phase가 playing이어도 로컬 stage를 dealing으로
  선택한다. 이미 분배가 끝났고 아직 제출 카드가 없는 시점의 재실행을 우선 재현한다.
  기존 더미를 복원해 바로 현재 단계로 가는 다른 분기도 있으므로 모든 복귀가 실패한다고
  일반화하지 않는다.
- 10월 2일 추가된 [GameProgressCommand](../../../packages/game_kit/lib/game_flow/game_progress_command.dart)는
  새 판·단계로 바뀌면 후속 재시도를 무효화한다. 이미 전송된 callable은 취소하지 못한다.
- [Final Call 분배 완료](../../../functions/src/final-call/complete-dealing.ts)와
  [Liar's Poker 분배 완료](../../../functions/src/liars-poker/complete-dealing.ts)는 요청에
  기대 startedAt·round를 받지 않는다. 같은 controller session의 옛 요청이 새 판의 dealing
  상태에 도착하면 현재 phase 검사만으로 구분할 수 없다. 다른 단계 진행 함수도 함께 조사한다.
  재시도 기능 자체를 제거하기보다 서버의 판·단계 정합성 검증을 설계해야 한다.

## 빈 조회를 삭제로 해석하는 경로

`GameSessionController._confirmMissingPublicGame`은 1.5초 뒤 공개 상태를 조회하고,
빈 값이면 제거된 게임으로 바꾼다. 최신 정상 이벤트가 돌아온 뒤 옛 조회가 화면을 닫는
경합은 10월 2일 세대 검사로 보완됐다. 다만 빈 조회 자체를 서버의 실제 삭제로 확정하는
경로에는 서버 연결·참가 자격 확인이 함께 연결되어 있지 않다.
오프라인 캐시 조건에서 실제로 빈 결과가 반환되는지는 이번에 재현하지 않았다.

## 예정 작업 — 아직 미구현

- [ ] 플랫폼: 손패 유무가 아닌 서버의 기존 참가 자격·게임 상태로 복귀를 판정하고,
  분배 중·빈 손패·관전자 상태를 구분한다. 일시 오류만으로 저장 세션을 삭제하지 않는다.
- [ ] 서버: 다중 단절을 추적하고 복귀·제외 때 남은 중단 사유와 최소 인원을 재검사한다.
  마지막 중단 사유가 해소되기 전에는 턴을 재개하지 않고 기존 남은 시간을 보존한다.
- [ ] 공용 패키지: 재접속·상태 동기화·준비 완료를 구분하는 공용 복구 관리와 구독 재연결,
  중복 복구 방지, 제한된 재시도, 입력 차단·안내 UI를 정리한다.
- [ ] 게임 패키지: 라이어스 포커·파이널 콜의 phone/tablet board가 신규 입장과 복귀를
  구분하도록 한다. 현재 단계로 복원하고 완료된 시작·분배·벌칙 연출을 중복 실행하지 않는다.
- [ ] 플랫폼: 태블릿 오프라인 실행 후 네트워크 복구 시 저장된 controller 방 복구를 재시도한다.
- [ ] 플랫폼: stale 참가자 신고의 일시 실패 후 같은 heartbeat 관측값으로도 제한적으로
  재시도한다. 현재는 요청 전에 관측값을 기록하고 실패해도 유지해 다음 신고가 막힌다.
  온라인 상태·최신 heartbeat·퇴장·방 변경을 확인하고 서버 최신 presence 재검사와
  중복 신고 방지를 유지한다. [2026-10-04 분류 결정](../logs/2026-10.md#session-reconnect-02) 참고.
- [ ] 플랫폼·공용 패키지: 실시간 연결 필수 화면의 네트워크 가드 누락·중복, 복구 완료 전
  입력 차단과 요청 실패 안내를 점검한다. 앱 전체 모달·최소 재전송 횟수를 일괄 적용하지 않는다.
- [ ] 기기별 검증: Android/iOS 휴대폰·물리 태블릿에서 라이어스포커·Final Call·Mafia의
  단절·재실행 복귀를 확인하고 기기·OS·빌드·게임·시나리오별 결과를 남긴다.
- [ ] 서버·공용 패키지: 기존 UID·세션과 게임/분배 버전의 정합성, `commandId` 중복 방지,
  오래된 라운드 요청 거절, 공개/본인 개인/서버 전용 데이터 경계를 유지한다.

## 착수 시 합의 및 완료 조건

- 제안 방향은 기존 Firebase·서버 권위 구조 유지 + 현재 상태 복원 + 공용 재접속 관리자다.
  휴대폰 자동 복귀/다시 참여 확인 정책, 준비 완료와 턴 재개의 계약, 세션·영속 데이터·API
  변경은 병합 후 영향 분석과 별도 승인으로 확정한다. 새 프레임워크 도입은 현재 범위가 아니다.
- 분배 중 재실행, 제출 성공 직후 응답 유실, 두 명 동시 단절, 복구 중 재단절,
  태블릿 재실행, 오프라인 실행 후 연결 복구, 빈 손패·관전 복귀를 회귀 검증한다.
- 직접 퇴장·강퇴·제외·방 종료 시 부당한 재참가가 없고, 손패·턴·남은 시간 보존,
  중복 행동·구독·연출 방지와 최소 인원 정책을 검증한다.
- 관련 Flutter·Functions 테스트와 합의한 기기 조합의 검증 근거를 남긴다.
  iOS·물리 태블릿·Final Call·Mafia의 단절·재실행 복귀는 별도 확인하며 8월 라이어스포커/
  Android 태블릿 에뮬레이터·A32·A35 통과를 확대 적용하지 않는다. 실시간 연결 필수 화면의
  네트워크 가드 누락·중복과 요청별 재시도도 점검하되 앱 전체 모달·최소 재전송 횟수는
  캡처의 제안만으로 새 계약으로 확정하지 않는다.
  현재 등록은 수정·테스트·배포 완료를 뜻하지 않는다.
- 핵심 회귀 테스트와 공식 검증 실행 경로는 [TEST-REGRESSION-01](TEST-REGRESSION-01.md#test-regression-01)과
  함께 완료하며, 자동 검증을 실기기 확인의 대체 근거로 사용하지 않는다.
- 다음 행동: 병합된 코드에서 문제 존속 여부를 재확인하고 담당 파일·수정 순서를 합의한다.
  패키지 밖 수정 및 서버 배포는 각각 승인된 범위에서만 진행한다.
- 기록: [2026-10-04 필수 분류 결정](../logs/2026-10.md#session-reconnect-02).

## 2026-10-08 보완 — newgui 후보 기준의 오류·복구 검증

조사 기준은 현재 checkout `02669c7`과 UI 구현 후보
[`origin/newgui`의 `999c3e9`](https://github.com/WarmhanDongne/project00/tree/999c3e99086b9f917ea941cd8f283b8ac40f3f85)다.
아래는 코드 대조로 확인한 공백과 필요한 후속 작업이며, 병합·수정·자동 테스트·실기기
검증·배포 완료 기록이 아니다. 기존 담당 범위·보류·승인 경계를 유지한다.
새 UI의 작업 위치와 연결 화면별 점검은
[NEWGUI-RECOVERY-01](NEWGUI-RECOVERY-01.md#newgui-recovery-01)에서 함께 관리한다.

### 원 조사 1~13의 후속 체크리스트

| 원 번호 | 확인 수준과 해결·검증할 내용 |
| --- | --- |
| 1 | **관찰·원인 미확정:** NET-07의 반복 단절 뒤 전 휴대폰 방 이탈·태블릿 진행/종료 실패를 실제 삭제, 참가 자격 상실, 구독 취소, 잘못된 종료 판정으로 나눠 재현한다. 상태 유실을 순수 체감 지연으로 처리하지 않는다. |
| 2·3 | **코드 확인·완료 계약 미확정:** presence 복구와 heartbeat 재개 뒤 반환하는 [플랫폼 복구](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/room/providers/room_provider.dart#L1003)를 같은 판의 public/private 데이터·필요한 구독 정상화와 연결한다. [최초 구독](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_kit/lib/recovery/providers/game_session_controller.dart#L95) 이후 SDK 자동 재연결과 오류로 취소된 구독의 재생성을 구분하고, 준비 전에 입력 보호를 풀지 않는다. |
| 4 | **코드 확인·단절 정책 미확정:** [단일 중단 슬롯](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/game-interruption/state.ts#L105)이 다른 참가자의 단절을 기록하지 않는 흐름을 보완한다. A 단절 → B 단절 → A 복귀/제외 때 남은 유효한 중단 사유와 최소 인원을 다시 확인한다. 어느 참가자의 단절을 중단 사유로 삼을지는 별도 합의한다. |
| 5 | **코드 확인·증상 연결은 추가 재현:** 태블릿 `controllerPause` 중 타임아웃·진행 명령의 서버 차단을 점검한다. [LP](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/liars-poker/forced-timeout-resolution.ts#L39)·[FC](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/final-call/timeout-turn.ts#L34)의 `deadline === null` 검사에는 RTDB에서 삭제된 값의 `undefined`·비숫자 조건도 검증한다. NET-04·06 시간 손실의 확정 원인으로 단정하지 않는다. |
| 6 | **코드 확인:** [복원 조회](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/room/services/room_service.dart#L389)의 private 노드 존재와 참가 자격을 분리한다. 분배 중 재실행·빈 손패·탈락·관전에서 정상 참가자의 로컬 세션이 지워지지 않는지 게임별로 확인한다. |
| 7 | **코드 확인·실기기 재현 필요:** [태블릿 최초 복원](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/screens/tablet_home.dart#L81)은 한 번만 실행된다. 오프라인 시작 실패 뒤 연결 복구와 lifecycle 복귀로 저장 controller 방을 다시 확인하는 경로를 마련한다. |
| 8·9 | **코드 확인·재진입 영향은 추가 재현·요청 계약 미확정:** 완료된 분배 연출의 재실행과 새 판에 도착한 옛 분배 완료 요청을 구분한다. [LP](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/liars-poker/complete-dealing.ts)·[FC](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/final-call/complete-dealing.ts)의 서버 판·라운드·단계 검사와 재시도 식별자를 합의하고, 이미 전송된 요청은 클라이언트 재시도 취소로 취소되지 않음을 검증한다. |
| 10 | **코드 확인·오판은 미재현:** [빈 public 재조회](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_kit/lib/recovery/providers/game_session_controller.dart#L195)를 실제 삭제로 확정하기 전에 연결·멤버십·판 identity를 함께 확인한다. 기존 세대 검사를 보존한다. |
| 11 | **코드 확인:** [stale 관측값 선등록](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/room/providers/room_provider.dart#L756) 후 일시 실패한 동일 값의 제한적 재시도와 [onDisconnect 등록](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/room/services/room_service.dart#L587)의 성공/실패 관찰을 보완한다. 10초 heartbeat·20초 stale 기준과 중복 신고 방지는 유지한다. |
| 12 | **코드 확인·응답 유실 재현 필요:** [퇴장 실패 재확인](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/room/providers/room_provider.dart#L1463)의 room/active 노드 존재만으로 게임 참가 상태를 판단하지 않는다. 서버 퇴장 성공 뒤 응답 유실, active 방 노드 잔류, 퇴장 의도 해제와 heartbeat 재개를 함께 검사한다. |
| 13 | **코드 확인·표시 우선순위 미확정:** 내 단절·태블릿 단절·다른 참가자 단절·명령 실패를 나누고 중복 가드·숨은 실패·재시도 busy/성공/실패를 점검한다. [휴대폰 복귀 실패](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/phone/screens/phone_home.dart#L90)는 새 디자인에서도 오류를 Prompt에 전달하지 않는다. 동일 `commandId`·판 identity, 시도별 timeout·전체 예산을 유지하며 요청별 재시도 정책을 검증한다. |

- [ ] 인증: [AuthGate 정상 수신 callback](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/auth/widgets/auth_gate.dart#L211)이
  `_onboardingLoaded`만 설정하고 `_onboardingFailed`를 해제하지 않는 공백을 보완한다.
  조회 timeout/일시 오류 뒤 정상 데이터 수신, 이전 UID의 늦은 callback, 수동 재시도를
  구분하고 인증 담당 범위를 확인한다.

### newgui에서 함께 검증할 통합 경계

- [ ] [새 launcher](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/tablet_game_launcher.dart#L115)와
  [선택 직렬화](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/tablet_lobby_selection.dart#L28)의
  방·선택 generation 검사를 보존한다. 복구 중 선택/해제/시작·방 종료가 겹칠 때
  오래된 요청이 새 방이나 판을 건드리지 않는지 확인한다.
- [ ] 새 연결 UI 6종의 상세 점검은 [NEWGUI-RECOVERY-01](NEWGUI-RECOVERY-01.md#newgui-recovery-01)과
  연결한다. 디자인 완료와 실제 복구 완료·퇴장 성공을 같은 판정으로 취급하지 않는다.
- [ ] [에셋 준비 helper](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/game_assets/game_asset_prepare.dart#L5)는
  캐시 확인 실패 시 다운로드를 시도한다. 에셋 없는 상태·다운로드 중 단절·실패·늦은
  완료를 복구 단계 및 route/방/판 identity 검사와 함께 다룬다. 자동 복원 때 다운로드하는
  정책은 기존 cache-only 설명과 대조하고 의도를 확정한다.
- [ ] [퇴장 route](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_kit/lib/widgets/game_exit_route.dart#L5)의
  960ms 연출 및 `route.completed` 뒤 정리를 검증한다. 일반 퇴장·강퇴·방 종료·dialog·back
  stack·provider dispose와 늦은 요청이 겹쳐 중복 pop/재진입/유령 참가자가 생기지 않아야 한다.
- [ ] **추가 재현할 UI 경합:** [TabletHome 복원 진입](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/screens/tablet_home.dart#L143)은
  상세·스토어·시작 처리 중 반환하고, 같은 방의 provider callback은 finished만 다시
  확인한다. playing 이벤트가 이때 도착한 뒤 상세/스토어를 닫으면 복원 재검사가 필요한지
  실제 접근 조건과 함께 재현한다. 현재 기록은 확정 재현이나 newgui 회귀 판정이 아니다.
- [ ] 검증 범위를 라이어스포커·Final Call·Mafia·**홀덤 4게임**의 휴대폰/태블릿으로 잡는다.
  후보의 [게임 registry](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/games/game_registry.dart#L9)에
  홀덤이 추가됐으므로 공용 복구 수정 후 이를 제외하지 않는다. 기존 3게임 통과를 홀덤의
  중단·타임아웃·퇴장 계약 검증으로 확대하지 않는다.

복구 완료·턴 재개·다중 단절·요청 fencing·홀덤의 상태 계약과 public API/persistent data
변경은 담당 범위 및 호환성 검토 후 별도 합의한다. production 조회·배포·migration은
이 체크리스트 등록으로 승인되지 않는다.

## 2026-10-08 중단·재개·시간 보존 정책 합의

사용자는 태블릿 또는 생존 참가자 누구든 서버가 단절을 확정하면 추가 유예 없이 전체 게임을
중단하고, 태블릿과 생존 참가자의 필수 데이터·화면·에셋 준비 확인 후 재개하며,
서버 중단 시점의 남은 시간을 보존하는 권장안을 수락했다.

상세 동작과 미결정 경계는 [네트워크·세션 설계](../NETWORK_SESSION_DESIGN.md#51-p1p3-상세-동작-명세),
합의 근거는 [월별 기록](../logs/2026-10.md#2026-10-08--중단재개시간-보존-정책-합의)에 남긴다.
이것은 상위 제품 정책의 합의다. 준비 확인 API·저장 구조·구버전 호환, 대기·제외·종료 정책과
담당 범위는 추가 설계하며, 구현 착수·검증 완료·production 접근·배포 승인으로 확대하지 않는다.

### 참가자별 대기와 만료 후 결정 방향

2026-10-08 사용자는 서버 단절 확정부터 필수 준비까지 참가자별 총 60초 대기,
추가 단절·재시도로 기존 마감 초기화 금지를 수락했다. 시간 만료 후에는 태블릿 진행자가
단독으로 더 기다리기·해당 참가자 제외 후 계속·게임 종료를 선택하도록 지정했다.
같은 참가자의 이번 중단에서 더 기다리기는 30초 한 번만 허용하도록 결정했다.
연장 시간도 만료되면 더 기다리기를 다시 제공하지 않고 제외 후 계속·게임 종료를 선택한다.
연장 기준 시각과 인원 부족 버튼 조건 등의 상세는 설계 문서에서 권장안과 구분한다.
기존 자동 만료 처리·스케줄·구버전 호환과의 차이는
[설계 문서](../NETWORK_SESSION_DESIGN.md#52-p5--참가자-대기와-만료-후-진행자-선택)에 남겼다.

태블릿 자체 단절은 기존 서버 방 보존 한도 안에서 게임·보존 턴 시간을 유지하고,
휴대폰에 복구 기다리기·본인 게임과 그룹 나가기를 제공하는 것으로 합의했다.
단절을 이유로 별도의 짧은 자동 종료 제한시간을 추가하지 않으며 기존 방 정리와 게임별 최소 인원 규칙은 유지한다.
복귀한 태블릿은 현재 세션·판·필수 준비 및 남은 참가자 중단 상태를 다시 확인한다.

사용자는 기본·추가 대기 만료 전 조기 제외도 허용하고 조기 제외 버튼은 태블릿에만 배치하도록 지정했다.
휴대폰의 중단 참가자 제외 투표와 인원 부족 시 전체 게임 즉시 종료 권한은 제거하기로 합의했다.
본인 게임과 그룹 나가기는 유지하고, 다른 참가자 제외와 전체 게임 수동 종료는 태블릿 진행자가 결정한다.
마피아 등 게임 고유 규칙의 투표는 변경 대상이 아니다.
진행자의 일반 게임 종료는 기존 설정 메뉴의 현재 게임 수동 종료 기능이다.
설명 후 사용자는 정상 진행·중단 중에도 대기 만료를 기다리지 않고 해당 종료 권한을 유지하도록 합의했다.

2026-10-08 앱 재실행 후 휴대폰은 재참여 확인·태블릿은 자동 복구하는 것으로 합의했다.
앱을 종료하지 않은 순간 단절은 기존 화면에서 자동 복구하는 전제를 유지한다.
복귀 후에도 현재 세션·참가 자격·판·필수 준비를 확인하며 기존 중단 마감을 초기화하지 않는다.
휴대폰 복귀 거절은 본인 게임·그룹 퇴장을 요청하는 것으로 후속 합의했다.
이후 진행은 기존 게임 규칙·전체 재개 조건을 따른다. 현재 로컬 복귀 기록만 삭제하는 코드와의 차이는
설계 문서에 기록한다.

2026-10-08 퇴장 결과 미확정 시 퇴장 의도를 유지하는 P7 권장안을 수락했다.
게임 자동 복귀와 입력을 막고 퇴장 확인 중을 표시한다. 연결 회복 후 서버 결과를 확인하고
미처리라면 재시도를 제공하며, 조회 실패만으로 퇴장 완료나 참가 복구를 확정하지 않는다.
전송 후 결과 미확정 중 취소를 제공하지 않는 것으로 후속 합의했다.
사용자는 연결 회복 후 퇴장하는 의미를 질문했다. 네트워크 오류 자체로 퇴장 의도를 만들지 않으며,
명시적으로 나가기를 선택한 경우에 적용한다. 확실한 미전송 상태의 취소·재시도 상세·의도 보존의 기술 계약은 추가 설계한다.

후속 사용자 지정: 네트워크 오류만 발생하면 퇴장하지 않고 복구·재개하며,
오류 중 본인이 게임·그룹 나가기를 선택한 경우 연결 회복 후 퇴장을 처리한다.
미전송 상태 취소 제안은 미합의로 유지한다. 이후 정책 질문은 한 번에 세 가지씩 제시한다.

태블릿 상세·스토어 화면에서 기존 게임 복구가 가능해지면 복귀 여부를 묻고 동의 후 복귀하도록 합의했다.
정상 파일·동일 버전의 단절 복구에는 재다운로드가 필요하지 않다는 설명은 코드 검토상 타당하다.
다운로드 파일 검증과 번들·화면 준비 보장은 구분하며, 별도 파일 유실·손상·버전 변경 예외는 미재현이다.
통신 실패 자동/수동 재시도 정책은 이번 답변으로 합의하지 않았다.

2026-10-09 태블릿 복귀 질문 거절은 현재 게임·방 나가기를 요청하는 것으로 합의했다.
controller의 기존 방 전체 종료 계약과 일반 참가자의 본인 퇴장을 구분해 후속 기술 설계에 연결한다.
요청 결과 미확정 시 의도 유지·자동 복귀 차단 정책을 적용한다.

2026-10-09 추가 30초는 서버가 더 기다리기를 수락한 순간부터 계산하는 것으로 합의했다.
만료 후 선택 전 참가자가 필수 준비를 완료하면 해당 선택 안내를 닫고, 모든 필수 기기 준비 시
서버 자동 재개·다른 중단 사유가 남으면 계속 중단하는 것으로 합의했다.
자동 재시도 사용 방향은 동의했으나 간격·한도·세부 오류 처리는 논의 중이다.
현재 복구의 1·2·4·8초 후 8초 반복과 게임 command의 250·500·1000ms 간격을 구분해 설계한다.

후속 사용자 합의: 세션 복구는 즉시 첫 시도 후 실패마다 1·2·4·8초, 이후 8초 간격으로 재시도한다.
응답 대기·재시도 지연을 포함해 한 차례 최대 30초, 이후 수동 재시도 안내·입력 보호를 유지한다.
오프라인에는 앱 요청을 멈추고 실제 서버 연결 회복 시 즉시 새 제한된 복구 시도를 시작한다.
이전 묶음과 병렬 실행·늦은 결과 반영을 막고 참가자의 60초·추가 30초 마감은 초기화하지 않는다.
자동 한도 도달만으로 퇴장·게임 종료를 하지 않는다.

후속 합의: 복구 서버 요청별 최대 8초, 수동 재시도 버튼으로 즉시 새 최대 30초 복구 시작.
미확정 명령은 기존 작업의 결과 확인·재시도를 유지하고 중복 클릭을 합치며 참가자 대기 마감은 바꾸지 않는다.
앱 재실행 후에도 미확정 퇴장 의도를 보존하고 결과 확인을 이어가며 게임 자동 복귀를 막는다.
현재 프로세스 내 RoomLeaveIntent와의 차이·저장 구조·요청 식별자·호환성은 후속 기술 설계한다.

후속 합의: 멱등 게임 행동의 일시 통신 실패는 기존 0.25·0.5·1초·최초 포함 최대 4회·요청별 8초·전체 12초 재전송 유지.
권한·게임 규칙 거절은 자동 반복 대신 현재 인증·자격·턴 확인 후 이유와 다음 행동을 안내한다.
제외 후 게임을 계속할 수 없으면 버튼 비활성화·이유 표시·서버 동일 검사, 연장 기회가 남으면 기다리기/종료,
소진됐으면 종료를 제공한다. 전체 합의는 [설계 요약](../NETWORK_SESSION_DESIGN.md#511-현재-항목의-전체-합의-요약--2026-10-09)에 모았다.

남은 전체 결정은 [설계 목록](../NETWORK_SESSION_DESIGN.md#512-추가-결정검토가-필요한-전체-항목--2026-10-09-조사-기준)에 모았다.
제품 결과와 AI가 먼저 구체화할 기술 계약·담당/채팅/검증 계획을 구분한다. 이 목록은 새 상태나 착수 승인이 아니다.

2026-10-09 후속 사용자 합의: R01~R10 중 R03은 대안, 나머지는 권장안을 선택했다.
미전송 상태에서도 퇴장 의도를 유지하고 취소를 제공하지 않는다. 준비 실패 중단·자동 진행 수동 재시도·
foreground 새 복구·게임별 인원·종료 후 이동·안내 우선순위·에셋 조건부 동의·방 생성 부분 복구·측정 후 목표 합의를 반영했다.
선택과 근거는 [설계 5.13](../NETWORK_SESSION_DESIGN.md#513-r01r10-권장안과-대안--선택-결과-반영)에 보존한다.
이전 미전송 취소 미합의 기록은 당시 결정 상태이며 현재는 취소 미제공으로 확정됐다.
남은 것은 R11~R15 기술 계약·R16~R18 실행/검증 계획과 측정 후 성능 목표 수치다.

2026-10-09 후속 범위 지정: 사용자는 구버전 앱을 고려하지 않아도 된다고 지정했다.
위 과거 기록의 구버전 앱 호환 검토는 현재 설계 범위에서 제외한다. R15는 현재 callable·scheduler·rules 영향,
새 계약의 앱·서버 반영 순서와 기존 저장 데이터 전환 필요성을 검토한다. 이 지정으로 배포나 데이터 전환을 실행하지 않는다.

2026-10-09 사용자 요청으로 [R11~R15 기술 설계안](../NETWORK_SESSION_TECHNICAL_DESIGN.md)을 작성했다.
준비 보고와 접속/판 식별·다중 중단/단일 시간 보존·제외 preview·명령/퇴장 수명·방 생성/정리 경합을 구체화했다.
공용 숫자만으로 FC의 팀 구성과 Holdem 현재 핸드의 올인 생존을 판단하지 않는 기준도 포함한다.
신규 API·persistent data·state-machine의 주요 선택 A~C는 검토 전 제안이며 구현/검증 완료가 아니다.
기술안 검토 뒤 R16~R18 담당·채팅 단위·검증 계획을 확정한다. 기존 사용자 packages 경계와 현재 작업 상태를 유지한다.

2026-10-09 후속 검토 반영: 기존 기술안의 방향은 유지하고 구현 설명을 보충했다.
타인 행동 시 변경 없는 private에도 새 상태의 메타데이터를 붙이는 규칙, 연결 유지 중 준비 실패의 서버 중단 절차,
안내 reducer와 홈/대기실 이동·결과 정리 순서, 최초 오프라인의 pending restore·온보딩 watcher 회복을 명시했다.
terminal 기록이 정리 조회 한도를 차지하지 않도록 due index/부분 실패 보정안을 추가하고,
복구 측정의 시작/완료 지점·다른 기기/사용자 대기 분리·debug 기록 범위를 지정했다.
관련 검증 시나리오도 같은 [기술안](../NETWORK_SESSION_TECHNICAL_DESIGN.md)에 추가했다.
신규 저장/API 계약은 여전히 검토용 제안이다. 제품 코드·테스트·작업 상태·구버전 제외·담당 경계는 변경하지 않았다.

2026-10-09 사용자 요청으로 [R16~R18 실행 계획안](../NETWORK_SESSION_IMPLEMENTATION_PLAN.md)을 작성했다.
P 사용자 packages 담당과 T 플랫폼/서버/검증 담당안, 허용 경로·선행 계약·게임별 서버/패키지 채팅·
각 기능의 회귀/완료/인수인계와 최종 통합/실기기를 연결했다. 이번 SESSION 범위는 E02~E09·V01~V18 중심이다.
기술안 A~C·실행 후보·T 담당의 확정은 E00에 남아 있다. 기존 보류를 해제하거나 패키지 밖 구현을 시작하지 않았다.
현재 코드/검증 배선/제품 테스트/production은 미변경·미실행이며 신규 채팅을 생성하거나 팀원에게 전송하지 않았다.

2026-10-09 후속 사용자 합의: 코드 기준은 가장 최근 newgui, 기술안 A~C는 모두 권장 방식으로 채택했다.
현재 접속/준비 식별·전송 전 durable 퇴장 저장·terminal/generation/due 정리 계약을 채택하며 구버전 제외는 유지한다.
개발 시작 전에 계획 문서 push와 develop merge를 요청했다. T 담당 범위와 착수 최신 SHA/후속 변경 확인은 남아 있다.
기존 보류의 이유를 담당/착수 대기로 갱신하되 제품 구현은 시작하지 않는다.

## 2026-10-09 E00 착수 기준 확인

후속 요청으로 develop에서 첫 단위 E00을 시작했다. 최신 newgui `fcee643`가 반영된 develop `58634d1`의
계약·실제 소비자·후속 변경·targeted 실행 공백을 [착수 기록](../NETWORK_SESSION_E00_BASELINE.md)에 남겼다.
사용자는 담당 구분과 분리 이유의 설명을 요청했다. P 사용자 packages/T 팀원 플랫폼·서버·검증 분담은 아직 확정하지 않았다.
관련 구현은 E01 이후이며 제품 코드·검증 배선·production을 변경하지 않았다. 현재 상태는 작업 목록을 따른다.

후속 답변에서 사용자가 전체 작업을 수행한다고 확인했다. 기존 2인 협업을 전제한 담당 분담은 제거했다.
P/T는 실행 계획의 패키지/플랫폼·서버·검증 영역 표기이며 별도 사람이 아니다.
최신 코드 기준·소비자·검증 공백·단일 담당을 E00 인수인계로 정리했고 다음 단위는 E01 검증 배선이다.
채팅별 범위·완료 조건·의존 순서는 유지하며 기능 구현과 전체 검증 완료를 뜻하지 않는다.

## 2026-10-09 E01 검증 기반 구현 후보

develop `151eff8`에서 첫 구현 단위 E01의 누락 session/auth 회귀와 package/FULL 실행 배선을 복원했다.
[E01 기록](../NETWORK_SESSION_E01_VALIDATION.md)은 기존 동작의 검증과 새 복구 정책의 후속 구현을 구분한다.
이번 변경은 제품 세션 계약 구현이 아니며 해당 단위 완료 후 E02로 넘긴다. 공통 실행 근거는 TEST-REGRESSION-01에 연결한다.

## 2026-10-09 E02~E12 순차 구현 후보

사용자 요청으로 A~C 공용 계약부터 네 게임·플랫폼·UI·계측을 연결했다.
[현재 계약](../../engineering/NETWORK_SESSION_CONTRACT.md)과 [후보/검증/기존 변경](../NETWORK_SESSION_E02_E12_IMPLEMENTATION.md)을 따른다.
관련 검사와 승인 후 FULL을 구분한다. E13 emulator/CI·E14 기기·production은 미실행이며 일부 PASS로 태스크 전체 완료를 선언하지 않는다.

같은 날 사용자 명시 승인 후 현재 후보의 Windows guarded `validate --full --json`을 1회 실행했다.
12단계 모두 PASS/exit 0, root Flutter 334·5 package 167·Functions 368개와 전후 mutation PASS다.
E02~E12 로컬 구현 검증 결과이며 E13 emulator/CI·E14 기기/성능·출시 판정은 남겨 둔다.
실제 command/전체 step/working tree 근거는 위 후보 검증 문서에 기록했다.

## 2026-10-09 E13 백엔드 emulator/CI 후보

[E13 기록](../NETWORK_SESSION_E13_BACKEND_CI.md)에 기존 후보의 커밋·푸시와 같은 SHA의
테스트 브랜치 분리, 실제 RTDB 생성/정리 결함과 별도 회귀 커밋, 현재 FULL·CI·기기 범위를 남긴다.

후속 사용자 명시 승인으로 제품 수정 후보 a3fe7fc의 guarded FULL 1회가 PASS/exit 0,
12단계·root 334·package 167·Functions 371·전후 mutation PASS다. 실제 backend CI도
10/10 PASS/exit 0이다. canonical FULL CI의 SDK 차이 실패와 테스트 브랜치 17ca1f5 보정,
새 후보 재실행 승인 요청은 위 E13 기록에 남겼다. 앱·기기/성능·출시 전체 완료로 확대하지 않는다.

후속 승인으로 17ca1f5의 실제 CI 재실행도 성공했다. backend 10/10, canonical FULL
12단계·root 334·package 167·Functions 371·mutation 모두 PASS/exit 0이다.
성공 SHA/링크와 문서만 동기화한 최종 tree 확인은 E13 기록에 남겼다.
FlutterFire/앱 통합·기기/성능·출시 판정은 별도로 유지한다.

## 2026-10-09 실기기 조작 목록 준비

태블릿 1대·휴대폰 2대 기본, 추가 기기 모이는 날만 파이널콜·마피아 4대와 진행 가능한 제외
3대 묶음으로 [기기 조작 목록](../../operations/NETWORK_SESSION_REAL_DEVICE_TEST.md)을 작성했다.
검토 ID·서버·로그 작업 없이 행동과 화면 결과만 확인한다.
[환경·설치·배포 준비](../../operations/NETWORK_SESSION_TEST_PREPARATION.md)와
[담당자 진단 후속](../../operations/NETWORK_SESSION_SERVER_FOLLOWUP.md)은 별도다.
대상 환경·OS 조합은 미확정, 원격 접근/배포·앱 빌드/설치·실기기 실행은 미실행이다.

후속 사용자 결정으로 기존 Firebase·Android APK 실기기·변경 사항 전체 배포·구버전 호환
불필요를 확정했다. [준비/실행 기록](../../operations/NETWORK_SESSION_TEST_PREPARATION.md)을 따른다.
APK 빌드는 PASS이며 설치·기기 결과는 아직 미실행이다. 배포 결과와 기기 결과를 분리한다.

## 2026-10-09 실기기 정상 시작 실패 수정 후보

사용자 요청으로 heartbeat 수명, 최초/후속 준비 제한, 라이어스포커 dealing 에셋 대기,
진단 창 Overlay를 수정하고 session 회귀에 등록했다.
[수정/검증 기록](../NETWORK_SESSION_STARTUP_INVESTIGATION.md)을 따른다.
Guarded session 5단계, 관련 37개, 마지막 연결/수명 21개, 변경 파일 분석/포맷은
PASS/exit 0이다. controller token 무효화 뒤 player heartbeat로 바뀌지 않는 것도 확인했다.
기존 사용자 변경은 보존했고 branch/HEAD 유지, staged 없음이다.
사용자 승인 FULL·수정 APK 설치·실기기 확인은 미실행이다. 기존 실기기 정상 시작 FAIL은
새 후보에서 통과로 바꾸지 않으며, 시작 callable/퇴장 route의 미확정 근거는 남겨 둔다.

후속 사용자 승인 후 현재 후보의 Windows guarded `validate --full --json`을 1회 실행했다.
12/12 단계 PASS/exit 0, 앱 337개·5 package 174개·Functions 371개/skip 0,
실행 전후 mutation PASS다. 기존 사용자 변경 4개도 전후 SHA-256 동일이다.
수정/로컬 전체 검증 후보가 통과한 것이며 수정 APK/실기기 정상 시작과 미확정 시작 요청/
퇴장 route의 확인은 남아 있다. branch/HEAD 유지, stage/commit/push/deploy 없음.

## 2026-10-09 정상 준비 UI 분리 후보

후속 사용자 UI 요청으로 준비/원인 없는 barrier는 기존 배경·연출을 유지하고,
실제 실패/이탈만 기존 오류 안내를 사용하도록 수정했다. 별도 준비/퇴장 버튼을 제거하고
기존 상단 메뉴·퇴장 모달을 유지했다. 서버 준비 조건과 canSend 보호는 유지한다.
[변경 파일·검증 기록](../NETWORK_SESSION_STARTUP_INVESTIGATION.md)의 마지막 UI 후보 절을 따른다.
최종 guarded session 5/5 PASS/exit 0, 관련 분석/19개 파일 포맷 PASS/exit 0이다.
이전 후보 FULL 승인을 재사용하지 않으며 이번 후보 FULL의 새 승인을 요청한다.
수정 APK/실기기 결과·미확정 시작 요청/퇴장 route 및 SESSION 출시 판정은 별도다.

후속 사용자 “검증해” 승인으로 같은 UI 후보의 guarded FULL을 1회 실행했다.
2026-10-09 21:37 KST 시작, 336776ms, 12/12 PASS/exit 0이다.
앱 337·5 package 182·Functions 371/skip 0 및 mutation PASS다.
[승인 FULL 기록](../NETWORK_SESSION_STARTUP_INVESTIGATION.md)의 마지막 절을 따른다.
수정 APK/실기기 UI·연결 확인과 SESSION 출시 판정은 남아 있다.

## 2026-10-09 진입 성공 후 룰렛·재시작 조사

사용자가 정상 진입/준비 UI 해소와 로비 A 단절 대응 성공을 보고했다.
[후속 조사](../NETWORK_SESSION_STARTUP_INVESTIGATION.md#roulette-restart-investigation)에
태블릿/휴대폰 로그와 실제 callable 오프라인 재현을 기록했다. 룰렛 추첨/확정 ID 충돌과
시작 시간초과 뒤 새 서비스가 미확정 요청을 이어받지 못하는 결함을 확인했다.
수동 종료 성공은 양 기기 로그로 확인했다. 최초 시작 지연/commit 경로는 서버 로그 요청 중이다.
이번 요청은 원인 조사이며 제품 수정·production 조회/배포·새 FULL은 실행하지 않았다.

후속 사용자의 기존 일반 로그 권한 확인/직접 조회 요청으로 gcloud 조회용 configuration에서
시작 함수의 승인 시간대 로그를 읽었다. 60초 HTTP 504, 좌석 검증의 finished-function 비동기
예외, 후속 HTTP 409를 확인했다. 정상 heartbeat까지 비교하는 fingerprint와 SDK callback
예외의 미종료 경로를 추가 재현했다. 기존 Logs Viewer로 가능했으며 IAM 추가 변경은 없었다.
production 데이터 commit 여부/실제 변경 필드는 로그만으로 확정하지 않았다. 제품 수정은 후속이다.

## 2026-10-10 승인한 룰렛·재시작 수정 후보

사용자 계약 변경 승인 후 추첨/확정 ID 분리, 의미 있는 시작 fingerprint, transaction
예외 abort 완료, 미확정 시작의 직렬 영속화·원래 응답 재생과 설정 완료 소비자를 수정했다.
[수정 후보·실제 명령·한계](../NETWORK_SESSION_ROULETTE_RESTART_REPAIR.md)에 근거를 남겼다.
guarded session 5/5(Flutter 127/Functions 89), Functions 전체 385 및 분석/포맷/lint
PASS/exit 0이다. 이전 정상 로딩/메뉴 계약은 유지했다. 최종 후보 FULL의 별도 승인과
수정 APK·실기기 검증은 남아 있으며 production/배포·SESSION 출시 판정으로 확대하지 않는다.

후속 사용자 “승인할게” 응답으로 같은 제품 후보 guarded FULL을 한 번 실행했다.
2026-10-10 07:05 KST, 239473ms, 12/12 PASS/exit 0, 앱 346/package 188/Functions 385다.
분석·포맷·lint·mutation PASS, timeout 없음. 위 수정 후보 문서에 결과를 보존했다.
FULL 종료 후 작업 기록만 갱신했으며 수정 APK·실기기·배포/출시 판정은 남아 있다.
## 2026-10-10 LP 새 실기기 후속 오류 분석·설계

사용자는 새 APK 설치/Functions 미배포와 약 12:30~12:40 KST 테스트를 확인했다.
이전 디바이스 로그를 이번 증거로 재사용하지 않고 A/태블릿/B를 새로 추출했다.
세 설치 APK hash가 같고 로컬 빌드와 일치한다. 조회 계정 역할을 사람이 확인한 뒤
승인 시간/관련 함수만 metadata·정제 오류로 조회했다(반환 81/고유 74건, RTDB 미조회).
[후속 분석·해결 설계](../NETWORK_SESSION_LP_DEVICE_FOLLOWUP_DESIGN.md)에 시간축,
실제 명령/status/exit code, 확정 사실·가설·필요 회귀를 기록했다.

룰렛 확정 두 번의 invalid-argument/서버 HTTP 400은 이전 서버의 동일 ID 검사와 일치한다.
A는 복구 완료 안내 뒤에도 ready/LIAR 권한 거절과 접속 heartbeat 실패가 지속됐다.
B/태블릿도 동시 ready 지연을 겪었지만 후속 보고는 성공했다. 접속 교체 조건의 정확한
귀속과 타이머 수치/첫 원판 규칙은 현재 기록만으로 모두 확정하지 않았다.
실제 LP controller의 public 수신 중 resolve 누락/최종 ready 실패 뒤 무기한 대기를
ignored probe로 관찰했다(2/2 PASS/exit 0). 이는 결함 재현이고 해결 검증은 아니다.
제품 소스·정식 suite·새 FULL·배포·migration·commit/push는 수행하지 않았다.
직전 후보 FULL PASS는 보존하며 위 추가 결함의 수정·필요 서버 반영·실기기 재시험은 후속이다.

## 2026-10-10 후속 구현 후보

사용자 진행 요청으로 [LP 후속 수정](../NETWORK_SESSION_LP_DEVICE_FOLLOWUP_IMPLEMENTATION.md)을 구현했다. 중간 session 5/5·서버 90 PASS/exit 0과 실제 controller/방 서비스/위젯 회귀·분석 PASS다. 최종 재확인 후 새 승인 FULL·APK·서버 반영·실기기 순서로 진행하며 이전 FULL을 재사용하지 않는다.

후속 사용자가 FULL 검증을 보류하고 직접 실기기 테스트를 우선하겠다고 지시했다. 관련 검사 통과 후보의 새 APK를 준비하며 FULL은 미실행으로 유지한다. 서버 반영·실기기 결과는 별도로 기록한다.

사용자 기존 Functions 63개 업데이트 승인으로 배포와 사후 metadata 확인이 PASS/exit 0이다. 전체 79개 이름 유지·승인 대상 63개 ACTIVE, 리전/런타임 동일·함수 추가/삭제 없음(2026-10-10 14:13:59 KST). 새 APK와 [시험 체크리스트](../NETWORK_SESSION_LP_DEVICE_FOLLOWUP_IMPLEMENTATION.md#승인된-서버-반영실기기-인계)를 인계하며 FULL은 보류, 실제 기기 설치·재시험은 사용자 대기다. commit/push 없음.
