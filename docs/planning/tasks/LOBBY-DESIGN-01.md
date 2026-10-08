# LOBBY-DESIGN-01

로비 전체 디자인 개선

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

**로비 전체 디자인 개선**

- 사용자 요청을 등록했다. 화면 구성·정보 우선순위·시각 디자인의 구체적인 변경 범위는 미정이다.
- 완료 조건 초안: 개선 목표와 대상 화면을 정하고 주요 그룹·게임 진입 흐름을 유지한 채
  디자인을 적용·확인한다. 착수 시 구체화한다.

## 2026-10-08 검토 — newgui 구현 후보와 복구 통합

현재 checkout `02669c7`의 완료 작업으로 처리하지 않는다. 별도
[`newgui` 후보 `999c3e9`](https://github.com/WarmhanDongne/project00/tree/999c3e99086b9f917ea941cd8f283b8ac40f3f85)에
로비·인증·연결 안내 UI가 있으므로 병합 후보와 후속 작업 위치를 기록한다.
UI 코드 존재는 제품 범위 합의·세션 수정·검증·배포 완료의 근거가 아니다.

- 후보의 태블릿 진입은 기존 게임 목록/미리보기 modal에서
  [TabletHome](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/screens/tablet_home.dart),
  [TabletLobbySelection](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/tablet_lobby_selection.dart),
  [tablet_game_launcher](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/tablet_game_launcher.dart)로
  옮겨졌다. 선반/상세/방 패널을 유지하는 UI와 서버 선택·해제·seating·start를 함께 검증한다.
- 새 연결 UI 6종의 배선·표시 우선순위·busy/실패 안내·접근성·모달 중복·퇴장은
  [NEWGUI-RECOVERY-01](NEWGUI-RECOVERY-01.md#newgui-recovery-01)에서 관리하고,
  복구 완료·재구독·다중 단절·턴 보존의 실제 동작은
  [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md#session-reconnect-02)와 연결한다.
  복구에 성공한 경우의 순수 체감 지연은 [NET-RECOVERY-01](NET-RECOVERY-01.md#net-recovery-01) 범위다.
- **추가 재현:** [TabletHome 자동 복원 gate](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/screens/tablet_home.dart#L143)가
  상세·스토어·시작 처리 중 playing 이벤트를 보류한 뒤 다시 검사하는지 확인한다.
  후보의 접근 조건과 선택/해제 실패를 포함해 재현하며, 현재는 확정 회귀로 기록하지 않는다.
- [에셋 준비/다운로드](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/game_assets/game_asset_prepare.dart#L5)와
  [퇴장 route/연출](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_kit/lib/widgets/game_exit_route.dart#L5)이
  비동기 진입 수명을 바꾼다. 뒤로가기·dialog·방 종료·강퇴·provider ownership과 늦은
  요청을 점검하고, 상태 정리는 route 완료 및 현재 방/판 검사를 기준으로 검증한다.
- 후보의 [게임 registry](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/games/game_registry.dart#L9)는
  라이어스포커·Final Call·Mafia·홀덤 4게임이다. 새 로비의 게임 진입·복귀·퇴장을
  네 게임의 phone/tablet 경로에서 확인한다. 홀덤의 서버 상태·중단 계약은 별도 검토한다.

다음 행동은 후보 병합 범위와 담당 파일을 정하고 기존 핵심 흐름·새 UI의 회귀 검증을
연결하는 것이다. 디자인 작업 등록으로 public API/persistent data/state-machine 변경이나
production 접근·배포가 승인되지 않는다.
