# CORE-REVIEW-01

핵심 구현 점검·그룹 목록 권한 회귀

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

**핵심 구현 점검·중대한 비효율 수정**

- 요청 배경: 전체 코드가 어떻게 구현됐는지 살피고 비효율을 최적화한다. 출시 전에는
  데이터 정합성·게임 진행·핵심 사용 흐름에 영향을 주는 범위를 우선한다.
- 다음 행동: 로그인, 그룹·방, 게임 시작·진행·종료, 재연결 흐름의 책임과 처리 경로를
  확인한다. 비용은 COST-01, 보안은 SECURITY-01에서 상세 결과를 관리한다.
- 완료 조건: 점검 범위와 근거를 남기고 출시를 막는 데이터 유실·진행 불가·중대한
  비효율을 수정·검증한다. 일반 구조 정리는 CODE-AUDIT-01과 CODE-OPTIMIZE-01로 연결한다.

- 상태(2026-10-04): 요구사항 확인. 일반 참가자 그룹 목록의 권한 불일치 근거를 흡수했고,
  나머지 핵심 흐름은 조사 범위를 확정해야 한다. 별도 작업 ID·출시 분류를 추가하지 않는다.
- 다음 행동: 일반 참가자의 해당 방 멤버십을 확인하는 조회 계약과 기존 앱 호환성·영향을
  설계하고 승인 범위를 확정한다. callable/API 변경은 별도 승인 대상이다.
- 완료 조건 보완: 태블릿 T와 서로 다른 계정 휴대폰 A/B에서 T만 소유한 유료 게임,
  A만 소유한 유료 게임, 무료 게임의 그룹 목록 동일성·참가/퇴장 갱신을 확인하고,
  외부 계정 접근을 차단한다. heartbeat 반복 호출과 별도 controller 방 보유 계정도
  검증한다. TEST-REGRESSION-01의 역할별 테스트 및 현재 후보 FULL 근거를 남긴다.
- 기록: [2026-10-04 검토 통합](../logs/2026-10.md#공통-문서-확인).

## 일반 참가자의 그룹 대기실 게임 목록 — 회귀 근거

8월에는 클라이언트가 그룹 UID들의 `users/{uid}.ownedGames`를 읽어 합쳤다.
9월 1일 `b2bba19`에서 Firestore 사용자 문서를 본인만 읽도록 제한하면서 조회를
`fetchRealtimeRoomGroupEntitlements` callable로 옮겼다.

현재 호출 경로는 다음과 같다.

1. [RoomProvider](../../../lib/platform/home/room/providers/room_provider.dart)의
   `listenRoom`이 태블릿·휴대폰 모두 `_refreshGroupGames`를 호출한다.
2. [GameService](../../../lib/platform/home/gamelist/service/game_list_service.dart)의
   `fetchGroupGames`가 같은 callable을 인자 없이 호출한다.
3. [서버 함수](../../../functions/src/room/realtime-room-lifecycle.ts)는 요청 UID를
   controller UID로 간주하고 `controllerRooms/{요청 UID}`를 조회한다.
4. 일반 참가자에게 이 매핑이 없으면 `failed-precondition`으로 실패한다. 다른 방의
   controller 매핑이 있으면 현재 참가한 방 대신 그 방을 기준으로 조회할 가능성도 있다.
5. 클라이언트는 목록을 비우고 failure 상태를 표시한다. 실패 후 UID 캐시를 지우므로
   다음 players 이벤트에서 같은 실패를 반복할 수 있다. heartbeat에 따른 반복 호출도 점검 대상이다.

태블릿과 같은 UID를 쓰면 controller 매핑 조건을 통과할 수 있어 사용자 보고와 맞는다.
같은 계정 로그인을 해결책으로 강제할 문제는 아니다. 일반 참가자의 해당 방 멤버십을
서버에서 확인하고 최소한의 게임 ID만 돌려주는 조회 계약을 보완할 필요가 있다.

단, 휴대폰 **홈**의 개인 목록은 `fetchGames`로 본인 소유·무료 게임만 조회한다.
태블릿 소유 게임이 다른 계정의 개인 홈 목록에 없는 것과, 같은 그룹 대기실의 목록 조회
실패는 구분해야 한다. 이번 원인 확인은 후자에 해당한다.

## 2026-10-08 newgui 999c3e9 기준 추가 조사

- 조사 기준: `origin/newgui`의 `999c3e99086b9f917ea941cd8f283b8ac40f3f85`를
  `git show`와 `git diff`로 확인했다. 해당 코드는 현재 checkout에 반영하지 않았다.
  아래 내용은 정적 코드 확인이며 새 테스트·실기기 재현·운영 조회 결과가 아니다.
- 일반 참가자 그룹 목록: UI 개편 뒤에도 서버는 요청 UID의 controller 방 매핑으로
  그룹을 찾는다. [newgui 조회 함수](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/room/realtime-room-lifecycle.ts#L182)가
  기존과 같으므로, 해당 방 멤버십에 따른 조회 계약·외부 계정 차단·다른 controller 방
  보유 계정의 재현 범위를 유지한다. UI 변경을 권한 회귀 해결로 판정하지 않는다.
- Holdem 인원 정합성: 공용 중단은 [공개 플레이어의 `alive` 상태](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/game-interruption/state.ts#L108)로
  계속 가능 여부를 계산하지만, [Holdem 제외 처리](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/holdem/game.ts#L241)는
  `stack > 0`인 생존자 수로 인원 부족 종료를 판정한다. 올인으로 stack이 0인 참가자가
  살아 있는 경우 안내와 최종 종료 판정이 달라질 가능성을 확인했다. 실제 영향은
  미재현이며, 올인·폴드·탈락·퇴장의 게임 정책을 임의로 확정하지 않는다.
- 범위 연결: 다중 단절과 중단 중 진행 요청은 [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md),
  회귀 검증은 [TEST-REGRESSION-01](TEST-REGRESSION-01.md)에서 Holdem까지 포함해 관리한다.
  방·controller 매핑·예약의 부분 실패 정합성은 [ROOM-CREATE-REQUEST-01](ROOM-CREATE-REQUEST-01.md),
  정리 후보 제한·처리량과 비용은 [COST-01](COST-01.md)과 연결한다.
- 승인 경계: 방 멤버십 조회 API와 구버전 호환성, 중요한 게임 상태 판정 변경은 기존
  승인 조건을 유지한다. 이 추가 조사만으로 구현 착수·완료·출시 분류 변경을 판단하지 않는다.
