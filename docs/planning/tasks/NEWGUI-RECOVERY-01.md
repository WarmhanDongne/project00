# NEWGUI-RECOVERY-01

새 연결 화면·로비·에셋·퇴장 흐름에 세션 복구 연결

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 결정과
조사는 당시 근거이며, 공용 세션 구현의 완료 상태를 이 문서에 중복 관리하지 않는다.

## 등록 근거와 담당 경계

- 등록일: 2026-10-08. 사용자 요청으로 해결할 네트워크 오류와 newgui 추가 작업을 기록했다.
- 비교 기준: 조사 당시 checkout `02669c7`과 `origin/newgui`의
  `999c3e99086b9f917ea941cd8f283b8ac40f3f85`. 원격 ref의 후속 변경은 착수 시 재확인한다.
  이번 기록은 정적 코드 비교이며 newgui 병합·제품 수정·실기기·운영 검증이 아니다.
- 목적: 새 UI에서도 데이터·구독·에셋 준비 뒤 안전하게 입력을 재개하고, 복구·요청·퇴장
  실패의 이유와 다음 행동을 표시한다. 디자인 구현 사실을 복구 성공의 근거로 삼지 않는다.
- 공용 복구 계약·서버·구독 재개는 [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md),
  홀덤 고유 요청·진행·종료는 [HOLDEM-01](HOLDEM-01.md), 테스트 작성과 실행 배선은
  [TEST-REGRESSION-01](TEST-REGRESSION-01.md)가 담당한다. 이 항목은 새 UI의 소비·콜백·
  화면 수명 연결을 담당한다. 일반 로비 디자인은 [LOBBY-DESIGN-01](LOBBY-DESIGN-01.md)에 유지한다.
- 분류 결정(2026-10-08): 사용자가 NEWGUI-RECOVERY-01을 **출시 전 필수**로 지정했다.
  현재 분류·상태·다음 행동의 단일 원본은 TASKS.md에 유지한다. 담당 범위·복구 계약의
  합의와 패키지 밖 수정·API·저장 계약·production 접근·배포 승인은 별도로 확인한다.
  이 결정은 기존 SESSION-RECONNECT-02의 필수 복구 조건을 완화하거나 구현·검증 완료를 뜻하지 않는다.

## 새 연결 화면 6종의 적용 대상

[newgui 기능 변화 기록](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/docs/planning/NEWGUI_FEATURE_GAP.md)의
6종은 다음과 같다. 실제 장면·시트 구현은 공용
[MosiConnectionLayout](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_kit/lib/mosi_ui/mosi_connection.dart)에 있다.

| 화면 | 연결 위치 | 점검 내용 |
| --- | --- | --- |
| 내 인터넷 단절 | NetworkUnavailableModal / AppNetworkGuard | 자체 오프라인과 온라인 세션 복구 실패 구분, 준비 전 입력 차단, 재시도·퇴장 잠금 |
| 게임 중 태블릿 단절 | ControllerReconnectGuard | 역할별 안내, 기존 20초 후 나가기 정책, 실패 뒤 재시도와 대기실 복귀 |
| 앱 재실행 후 복귀 | SessionReturnPrompt / PhoneHome | 복원 중 로딩, 복원 실패 이유·재시도, 중복 진입 방지 |
| 대기실 태블릿 단절 | LobbyReconnectGuard / PhoneRoomWaiting | 휴대폰 자체 오프라인 우선, 퇴장 실패·재단절 시 오류 초기화 |
| 다른 참가자 단절 — 휴대폰 | GameInterruptionLayer | 투표·동의·남은 시간 표시와 요청 실패 안내 |
| 다른 참가자 단절 — 태블릿 | GameInterruptionLayer | 제외·계속·즉시 종료·만료, 최소 인원과 서버 중단 상태 정합성 |

## 정적 확인과 추가 재현 대상

- 확인: [PhoneHome 복귀 요청](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/phone/screens/phone_home.dart#L90)은
  실패 후 busy만 해제하고 새 prompt에 오류를 전달하지 않는다. 오류 설명·재시도 상태를 연결해야 한다.
- 확인: [LobbyReconnectGuard의 오류 상태](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/phone/widgets/lobby_reconnect_guard.dart#L25)는
  퇴장 실패 뒤 연결 복구 때 초기화하지 않는다. 다음 단절에 이전 오류가 재표시되는 경로를 검증한다.
- 확인한 경합 위험: [태블릿 복원 진입](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/screens/tablet_home.dart#L143)은
  상세·스토어·게임 시작 중이면 반환하고 상세 닫기·스토어 복귀에서 playing 복원을
  재검사하지 않는다. 해당 시점의 복원 이벤트와 후속 이벤트가 없는 경우를 재현해야 한다.
  실제 기기 실패로 확정한 결과는 아니다.
- 확장된 진입 경로: 기존 preview modal 역할은
  [TabletGameLauncher](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/tablet_game_launcher.dart)와
  [TabletLobbySelection](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/tablet_lobby_selection.dart)으로
  이동했다. 기존 파일을 기준으로 패치를 적용하지 않고 현재 방·선택 세대 검사와 테스트를 보존한다.
- 에셋·route 수명: 휴대폰 진입과 태블릿 복원·시작에 에셋 준비가 추가됐고, 게임 퇴장은
  960ms 전환과 route.completed 후 정리를 사용한다. 다운로드·방 변경·퇴장·dispose 사이의
  지연 응답을 검증한다. 전환 시간 자체를 결함이나 새 시간 정책으로 확정하지 않는다.
- 문서 정합성: NEWGUI_FEATURE_GAP에는 6종 적용 기록과 과거 '미적용' 설명이 함께 남아 있다.
  newgui 문서 통합 때 코드와 대조해 과거 설명을 정리한다. 현재 checkout에 없는 원격
  문서를 이번 작업에서 구현 문서로 복제하지 않는다.

## 예정 작업과 완료 조건

- [ ] 6종 화면에 공용 복구 상태·준비 완료·오류 원인을 연결하고, presence 정상만으로
  입력을 허용하거나 복구 성공을 확정하지 않는다. 자체 인터넷·controller·참가자 단절의 우선순위를 검증한다.
- [ ] 표시된 재시도가 실제 실패한 요청 또는 복구를 다시 실행하도록 연결한다. 로딩 중
  중복 요청과 퇴장을 막고, 실패는 원인에 맞게 안내한다. UI가 임의로 서버 재시도 정책을 정하지 않는다.
- [ ] 휴대폰 복귀 실패 안내와 로비 퇴장 실패 상태 초기화를 보완한다. 투표·제외·만료 요청
  실패도 숨기지 않고 다음 행동을 제공한다.
- [ ] 태블릿 상세·스토어·시작 흐름이 끝난 뒤 저장된 복원 필요 상태를 다시 확인한다.
  한 방·게임에 중복 route가 생기지 않고 오래된 복원 작업이 다른 방을 열지 않는지 검증한다.
- [ ] 에셋 다운로드 실패·재시도·재단절, 화면 제거 뒤 완료, 다운로드 중 방·판 변경을 검증한다.
  게임 데이터 준비와 에셋 준비의 완료 계약은 담당자와 확정한다.
- [ ] 960ms 퇴장 중 뒤로가기·dialog·강퇴·응답 유실·provider dispose를 검증한다.
  서버 성공 후 응답 유실을 실패로 잘못 표시하거나 퇴장한 게임을 다시 열지 않는다.
- [ ] 라이어스포커·Final Call·Mafia·Holdem의 phone/tablet 흐름과 접근성 입력 차단을
  회귀 검증한다. 해당 후보의 targeted suite·package 테스트·FULL·CI와 필요한 실제 기기
  결과를 남긴다. 자동 검증 배선과 증빙은 TEST-REGRESSION-01을 참조한다.

관련 기록: [2026-10-08 네트워크·newgui 작업 등록](../logs/2026-10.md#2026-10-08--네트워크newgui-작업-등록).

## 2026-10-08 복귀 확인 합의·에셋 설명 검토

태블릿 상세·스토어에서 기존 게임 복구가 가능해지면 사용자에게 복귀 여부를 묻고 동의 후 복귀한다.
질문 중 종료·정리된 판은 복귀시키지 않고 동의 시 현재 세션·판·필수 준비를 확인한다.
2026-10-09 사용자는 거절을 현재 게임·방 나가기로 합의했다. 태블릿 controller의 방 나가기는
기존 방 전체 종료 계약과 일반 참가자의 본인 퇴장을 구분해 연결한다. 요청 결과 미확정 시
퇴장 의도 유지·자동 복귀 차단의 P7 정책을 적용하며 질문 표시·요청 배선 상세는 추가 설계한다.

현재 코드·로컬 newgui 후보 검토상 정상 파일·동일 필수 에셋 버전이면 네트워크 복구에 재다운로드가 필요하지 않다.
후보 prepareGameAssetsForPlay도 로컬 검증 성공 시 다운로드 없이 반환한다. 진입 전 파일 검증과
실제 화면·디코딩 준비를 구분하고, 파일 유실·손상·버전 변경은 별도 예외로 조사한다.
기존 다운로드·route 검증 목록은 신규 진입 및 확인된 예외의 범위를 구분해 후속 계획에서 정리한다.
일반 복구의 다운로드 동의 질문은 철회했다. 예외 정책·실기기 검증·구현 완료를 뜻하지 않는다.
근거·미확인 경계는 [네트워크·세션 설계](../NETWORK_SESSION_DESIGN.md#56-p8--복귀-확인-합의와-에셋-검토-결과)를 참조한다.

## 2026-10-09 실행 계획 연결

[R16~R18 실행 계획안](../NETWORK_SESSION_IMPLEMENTATION_PLAN.md)의 E08은 P의 공용 안내/역할별 버튼,
E09는 T 담당안의 홈/대기실·상세/스토어·에셋 진입·종료 route 연결이다. E07은 게임별 소비자, E14는 실제 기기 확인이다.
관련 회귀 V15~V18을 해당 구현 채팅에서 작성하고 정상 결과 유지·주 안내 하나·준비 전 입력 보호를 확인한다.
위 과거 조사 표의 휴대폰 중단 투표/전체 종료·20초 나가기 노출 기대는 현재 제품 합의로 대체하고,
최초 안내부터 본인 나가기·태블릿 단독 타인 제외/일반 종료·10초 전체 안내를 검증한다. 고유 게임 투표는 유지한다.
계획 작성만으로 담당/API/저장 변경을 확정하거나 제품 구현·검증을 수행하지 않았다.


## 2026-10-11 develop 네트워크·로컬 GUI 통합 후보

사용자 요청으로 `디벨럽1`의 기존 GUI/애니메이션에 최신 develop `c8b6a74`의
네트워크 변경을 우선 반영했다. [통합·보존·검증 기록](../DEVELOP_GUI_INTEGRATION_20261011.md).
세션·인증·GUI 관련 검사는 PASS이고 최종 FULL 승인을 기다린다.
현재 미커밋 후보로, Git 이력 병합·push·배포·실기기 확인은 수행하지 않았다.
