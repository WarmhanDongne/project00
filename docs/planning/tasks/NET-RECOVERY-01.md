# NET-RECOVERY-01

네트워크 복구 체감 지연

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

- 담당 Issue: 착수 승인 시 생성.
- 분류 결정 근거: 2026-10-08 사용자 요청으로 출시 전 필수 지정.

## 현재 동작

- RTDB의 `.info/connected`가 복구되면 저장된 휴대폰 또는 controller 세션으로 같은 방의
  presence와 구독을 복원한다.
- 앱의 주요 복구 단계는 각각 8초 제한을 사용한다.
- 복구 중에는 안내 화면을 표시한다. 일시적인 문제라면 그대로 기다릴 수 있고, 기다릴
  수 없으면 `게임과 그룹 나가기`를 선택할 수 있다.
- 참가자 단절 판정은 별도 계약이다. 기존 10초 heartbeat와 `onDisconnect`를 유지하며,
  태블릿이 마지막 `lastSeen` 후 20초를 초과한 후보를 서버에 한 번 검증 요청한다.

이 항목은 **세션과 방 상태를 보존하며 복구에는 성공했지만 시간이 길게 느껴지는 경우**만
다룬다. 두 번째 단절 뒤 방·게임을 잃는 현상은 체감 개선이 아니라 출시 차단
`SESSION-RECONNECT-01`이다.

- 현재 분류(2026-10-08): 사용자 요청으로 출시 전 필수로 옮겼다. 아래 과거 관찰 근거는
  보존하며, 측정 목표·점검 범위는 착수 시 확정한다.

## 기존 출시 후 관찰 분류의 근거

- 첫 단절은 30초 안에 앱 재시작 없이 같은 게임으로 복귀했다.
- 체감 시간에는 앱 코드뿐 아니라 OS 네트워크 전환과 Firebase SDK 재연결 시간이 포함된다.
- 상태를 보존한 단일 복구에서 출시를 막을 수준의 반복적인 지연 측정값은 아직 없다.
- 복구 안내와 명시적인 나가기 경로가 있어 앱이 무응답 상태로만 보이지는 않는다.

과거 반복 단절의 세션·방 유실에는 이 보류 근거를 적용하지 않았다. 수정 APK의
2026-08-31 라이어스포커 최종 테스트(Medium Tablet 에뮬레이터 + A32·A35)는 반복
단절을 포함해 통과했다. 당시 순수한 체감 지연만 출시 후 관찰하기로 했으며 상태 유실이 재발하면
다시 출시 차단 여부를 평가하기로 했다.

## 기존 우선순위 재평가 조건

기존 관찰 단계에서는 다음 중 하나가 확인되면 P1 또는 출시 차단 항목으로 재평가하기로 했다.

- 짧은 일시 단절 뒤에도 앱 재시작이 필요하다.
- SESSION-RECONNECT-01 수정 후에도 방, 게임 또는 남은 턴 상태가 유실된다.
- 일반적인 네트워크 전환에서 재연결이 반복적으로 30초 이상 걸린다.
- 같은 증상의 사용자 문의 또는 실제 세션 사례가 반복된다.
- Play Console, Crashlytics 또는 지원 기록에서 freeze·ANR·복구 실패가 확인된다.

30초와 반복 사례 기준은 최초 관찰 기준이며, 실제 배포 지표를 확보하면 조정한다.

## 조사할 때 수집할 근거

- 단절 시작, `.info/connected` 복구, 세션 복원 완료 시각
- 휴대폰/태블릿 역할, OS, 네트워크 전환 종류
- 앱 재시작 필요 여부와 방·게임 상태 보존 여부
- 개인정보를 제외한 `[dev_error]`, `[game_comm]`, `room_connection` 구조화 로그

production RTDB 관찰이 필요하면
[`Firebase MCP RTDB Read-only Pilot`](../../operations/FIREBASE_MCP.md)의 사전 승인과
단일 경로 조회 절차를 따른다.

## 완료 기준

- 짧은 단절 뒤 앱 재시작 없이 같은 방과 게임으로 자동 복귀한다.
- 게임 상태와 중단 시 보존한 남은 턴 시간이 유지된다.
- 측정한 복구 시간이 착수 시 합의한 목표 안에 들어온다.
- Android와 iOS 실제 기기에서 단절·복구 회귀 테스트를 완료한다.
- 관련 Flutter·Functions 자동 테스트와 Project CLI FULL validation이 통과한다.

## 관련 코드와 문서

- [`RoomProvider.retryConnectionRecovery`](../../../lib/platform/home/room/providers/room_provider.dart)
- [`RealtimeConnectionMonitor`](../../../packages/game_kit/lib/core/network/realtime_connection_monitor.dart)
- [`ControllerReconnectGuard`](../../../lib/platform/home/phone/widgets/controller_reconnect_guard.dart)
- [`사용자 로그인·네트워크·세션 안내`](../../operations/USER_AUTH_NETWORK_SESSION_GUIDE.md)
- [`인증·네트워크·세션 기술 참고`](../../operations/AUTH_NETWORK_SESSION_TECHNICAL_REFERENCE.md)

## 2026-10-08 보완 — newgui 복구 지연의 측정 경계

검토 후보는 [`newgui`의 `999c3e9`](https://github.com/WarmhanDongne/project00/tree/999c3e99086b9f917ea941cd8f283b8ac40f3f85)이며,
이 등록은 병합·구현·검증 완료를 뜻하지 않는다. 현재 작업의 순수 체감 지연 범위와
착수 시 목표·점검 범위를 합의하는 조건은 유지한다.

- [ ] 측정점을 단절 시작 → OS/SDK 연결 복구 → presence/참가 상태 복구 → 필요한 구독과
  같은 판의 게임 데이터 수신 → 에셋 준비 → 입력 보호 해제/서버 중단 해제로 나눈다.
  [플랫폼 복구 반환](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/room/providers/room_provider.dart#L1003)을
  게임 준비 완료로 간주하지 않는다. 완료 계약은 [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md#session-reconnect-02)에서 합의한다.
- [ ] 새 연결 UI 6종의 안내/재시도/나가기 노출 시간은
  [NEWGUI-RECOVERY-01](NEWGUI-RECOVERY-01.md#newgui-recovery-01)과 함께 기록한다.
  [태블릿 단절 안내의 20초 나가기 노출](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/phone/widgets/controller_reconnect_guard.dart#L16)과
  stale 판정 유예·실제 네트워크 복구 시간을 구분한다. UI 문구나 버튼 표시만으로
  세션 복구 성공을 판정하지 않는다.
- [ ] [에셋 다운로드](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/game_assets/game_asset_prepare.dart#L5)와
  [960ms 퇴장 연출](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_kit/lib/widgets/game_exit_route.dart#L5)의
  대기 시간을 SDK 재연결 지연과 분리한다. 캐시 유무·게임·기기·OS·빌드를 측정에 남긴다.
- [ ] 라이어스포커·Final Call·Mafia·홀덤 4게임의 휴대폰/태블릿 조합에서 상태 보존이
  확인된 성공 복구만 지연 측정 대상으로 삼는다. 반복 단절 뒤 방/손패/턴 유실,
  취소된 구독의 미복원, 다중 단절 누락, pause 중 timeout 진행, 퇴장 응답 유실,
  숨은 오류·AuthGate 실패 잔류와 상세/스토어 복원 경합은 지연 개선으로 축소하지 않고
  [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md#session-reconnect-02) 및 새 UI 작업으로 보낸다.

위 측정 항목은 목표 수치나 재시도 횟수를 새로 확정하지 않는다. 운영 데이터 접근은 기존
Firebase MCP 사전 승인·단일 경로 제한을 유지한다.
