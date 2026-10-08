# TEST-REGRESSION-01

핵심 회귀 테스트 복원·추가 작성과 검증 배선

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

**핵심 회귀 테스트 복원·추가 작성과 공식 검증 배선**

- 등록일·분류·상태: 2026-10-04, 사용자 지정 출시 전 필수, 요구사항 확인.
- 목적: 이후 수정이 네트워크 오류 대응·세션·인증·게임 복귀 기능을 훼손하면 검증에서
  잡을 수 있도록 핵심 테스트를 복원하고 현재 장애 조건의 테스트를 작성한다.
- 확인 기준: 다음 수치와 실행기 판정은 `fa4ad54`의 파일·코드 대조다. CLI 실제 실행
  결과와 구분하며, 후속 파일 추가로 개수가 달라질 수 있다. 이번 통합 시 루트 테스트는
  기존 4개와 untracked `emulator_lab_config_test.dart`를 포함해 5개, kit 테스트는 6개다.
- 9월 30일 `9beaadb`에서 `test/` 파일 110개가 삭제되었다. 그중 `*_test.dart`는 108개다.
  이후 일부 복원·추가가 있어 8월 31일 `ea27b79` 대비 원 검토 기준 순삭제는 파일 104개,
  `*_test.dart` 102개다. 삭제 개수를 테스트 케이스 개수로 해석하지 않는다.
- 원 검토 기준 루트에는 `*_test.dart` 4개, `packages/game_kit/test/`에는 6개가 있다.
- [targeted suite 설정](../../../tool/mosigame_cli/test_suites.dart)은 session 10개·auth 10개의
  루트 Flutter 파일을 요구하지만 **원 검토 기준에서 20개 모두 존재하지 않는다**.
  실행기는 manifest 검사 실패를 `INVALID`, exit 2로 반환하도록 되어 있다.
  이는 이번 CLI 실행 결과가 아니라 파일 존재 확인과 실행기 코드에 따른 판정이다.
- [FULL 설정](../../../tool/mosigame_cli/validate.dart)은 루트에서 인자 없는
  `flutter test --no-pub --exclude-tags invocation-guard`를 실행한다.
  [CI](../../../.github/workflows/validate.yml)도 이 FULL만 호출하며 package test 경로를
  별도로 실행하지 않는다. 새 kit 테스트를 공식 경로에 명시적으로 연결할 필요가 있다.
- 삭제된 영역에는 반복 재접속, 퇴장 의도·일관성, route 중복 종료, controller presence,
  인증·온보딩·뒤로가기 등이 포함된다. 새 구조 테스트 몇 개의 통과가 이를 대체하지 않는다.

- [ ] 삭제·이동된 테스트를 현재 패키지·API·에셋 경로에 맞춰 대조하고 필요한 핵심 테스트를
  복원·재작성한다. 과거 파일을 일괄 복구하거나 기대값을 약화해 통과시키지 않는다.
- [ ] 다중 단절, 분배 중 재실행, 복구 중 재단절, 단절 신고 실패 후 재시도, 권한 오류 후
  구독 재개, 최초 오프라인 태블릿 복구, 퇴장 후 재등장 방지, 종료 route 경합을 검증한다.
- [ ] 서로 다른 계정의 그룹 게임 목록, 명령 응답 유실·중복 요청·새 판에 도착한 옛 요청,
  핵심 로그인·온보딩 흐름을 검증한다. 기존 유지 범위와 신규 테스트 범위를 명시한다.
- [ ] session/auth manifest와 실제 테스트 파일을 일치시키고 package 테스트를 FULL/CI에
  포함한다. Flutter와 Functions의 책임 경계를 각각 검사한다.
- 완료 조건: 수정 대상 결함을 재현하는 테스트와 수정 후 통과 근거를 남기고, 관련
  targeted suite·현재 후보 `validate --full` 및 CI가 해당 테스트를 실제로 실행해 통과한다.
  자동화하지 못한 실기기 시나리오는 SESSION-RECONNECT-02에서 결과를 별도로 남긴다.
- 다음 행동: 핵심 테스트 복원 목록과 신규 장애 시나리오를 정하고 담당 영역별로 실행한다.
  이번 등록은 테스트 코드 작성·제품 수정·검증 실행 완료를 뜻하지 않는다.
- 기록: [2026-10-04 테스트 필수 작업 등록](../logs/2026-10.md#test-regression-01).

## 2026-10-08 newgui 검토 — 회귀 범위와 실행 경로

아래는 `origin/newgui`의 `999c3e9`를 `git show`·파일 목록·실행기 코드로 대조한
추가 근거다. 현재 checkout `02669c7`의 테스트 실행 결과와 구분하며, 위의 2026-10-04
기준 수치·상태·과거 검증 판정은 보존한다. 이번 기록에서 targeted suite, FULL, CI,
에뮬레이터·실기기 검증은 실행하지 않았고 production에 접근하지 않았다.

- `origin/newgui:tool/mosigame_cli/test_suites.dart`의 session 10개·auth 10개 Flutter
  경로를 해당 ref의 tracked 파일 목록과 다시 비교했고, **20개 모두 누락**됨을 확인했다.
  manifest 오류를 `INVALID`, exit 2로 반환하는 실행기 경로도 유지된다. 이는 정적 확인에
  따른 예상 판정이며 실제 CLI의 status·exit code를 기록한 것이 아니다.
- `origin/newgui:tool/mosigame_cli/validate.dart`의 FULL은 계속 루트의 인자 없는
  `flutter test --no-pub --exclude-tags invocation-guard`를 실행한다.
  `origin/newgui:.github/workflows/validate.yml`도 이 FULL을 호출하며 `game_kit`이나
  `game_holdem`의 package 테스트를 별도 실행하는 단계가 없다. 패키지에 파일이 있다는
  사실을 FULL/CI에서 실행된 근거로 취급하지 않는다.
- 이 ref에서 `packages/game_kit/test/`에는 `*_test.dart` 9개,
  `packages/game_holdem/test/`에는 6개가 있다. Holdem의 `support/fixtures.dart`는
  테스트 파일 수에 포함하지 않았다. 기존 kit 회귀 테스트·퇴장 연출 테스트와 Holdem
  화면·매퍼 테스트의 존재가 아래 장애 시나리오의 검증 완료를 뜻하지 않는다.
- 게임 검증 범위는 기존 라이어스포커·Final Call·Mafia와 새 Holdem을 합친 **4게임**이다.
  기존 3게임에서 확인한 과거 결과를 Holdem이나 새 UI에 확대 적용하지 않는다.
- 공통 UI와 Holdem에서 추가된 구현·조사 범위는
  [NEWGUI-RECOVERY-01](NEWGUI-RECOVERY-01.md#newgui-recovery-01)에 연결한다.
  [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md#session-reconnect-02)의 복구 계약과
  플랫폼·서버·패키지 담당 범위는 유지하며, 이 문서는 회귀 테스트와 검증 배선을 맡는다.

### 추가 테스트 체크리스트 — 아직 작성·실행 완료 아님

- [ ] session/auth의 누락 경로 20개를 현재 구조에 맞는 복원·재작성 목록으로 대조하고
  manifest와 실제 파일을 일치시킨다. 핵심 시나리오를 누락시키는 manifest 항목 삭제나
  기대값 완화로 통과시키지 않는다. 두 targeted suite가 해당 테스트를 실제 실행한
  command·status·exit code를 남긴다.
- [ ] FULL/CI에 `game_kit`과 Holdem package 테스트를 명시적으로 연결하고, 기존 3게임의
  필요한 package 회귀 테스트도 공식 실행 범위에 포함한다. 각 작업 디렉터리와 실행 파일
  목록을 확인해 루트 테스트 성공만으로 package 테스트가 실행됐다고 판정하지 않는다.
- [ ] 새 연결 안내 6종을 검증한다: 공통 네트워크 안내(AppNetworkGuard/CriticalNetworkGuard),
  로비 reconnect, controller reconnect, 저장 세션 복귀 안내, 참가자용 게임 중단,
  진행 기기용 게임 중단.
  `game_kit/lib/mosi_ui/mosi_connection.dart`와 각 guard/layer의 조립을 함께 검사한다.
  중복 guard의 표시 우선순위, 오프라인·온라인·복구 중 버튼 상태, 안내 문구, 실패 피드백,
  역할별 vote/continue/finish/exit와 countdown을 확인한다. 전체 화면 안내에서 뒤의 게임
  입력이 차단되고, 실제 데이터 준비 완료 전에는 입력이 풀리지 않는지 검사한다.
- [ ] Holdem phone/tablet의 요청 오류에서 ‘재시도’가 실제 실패 요청을 다시 보내는지
  검사한다. 현재 두 board의 `GameRequestRecovery.onRetry`는 `controller.clearError`에
  연결되어 있어 메시지만 지운다. 재시도 뒤 다시 실패하면 오류와 재시도 수단이 유지되고,
  성공·응답 유실·중복 클릭에서는 중복 행동이 발생하지 않는지 검증한다.
- [ ] Holdem tablet의 분배 완료·handResult 완료·턴 만료 자동 요청에 일시 실패와
  `commandInFlight` 충돌을 주입한다. 현재 `_syncAutomation`은 phase/hand 또는 deadline
  키를 저장한 뒤 한 번 전송하고 반환값을 소비하지 않아 같은 키에서 다시 예약하지 않는다.
  실패 뒤 진행이 복구되고, 판·단계 변경이나 dispose 뒤 옛 timer/요청이 새 판을 진행하지
  않는지 검사한다. 서버의 판·단계 정합성 검증은 Functions 테스트와 함께 확인한다.
- [ ] Holdem의 서버발 비정상 `finished`(최소 인원 미달 등)와 제거된 게임 표시에서
  phone/tablet이 안내 후 정해진 대기실·홈으로 한 번만 돌아가는지 검증한다. 현재 tablet은
  비정상 종료에 결과·메뉴를 표시하지 않고, phone의 `closing`은 자동 route 종료가 없다.
  상위 경로도 `finished`만으로 게임 route를 pop하지 않는다. 로컬 설정 종료의 직접 pop,
  정상 결과, 별도 방 삭제·추방은 다른 경로이므로 함께 구분한다. 이 근거를 ‘모든 종료에서
  영구 탈출 불가’로 일반화하지 않는다.
- [ ] `prepareGameAssetsForPlay`가 지연·실패하는 동안 방 코드, 선택 게임, 서버 status,
  참가 자격이 바뀌거나 화면이 dispose되는 경우를 검사한다. 늦게 완료된 준비가 이전 방·
  이미 종료된 게임 route를 열지 않고, 실패 안내 뒤 재시도할 수 있으며 중복 route가
  생기지 않는지 phone 입장과 tablet 복원·새 게임 시작에서 각각 확인한다.
- [ ] `game_kit/lib/widgets/game_exit_route.dart`의 960ms reverse transition과
  `gameRoute.completed`를 기다리는 정리를 함께 검사한다. 퇴장 중 추가 입력·timer·구독,
  중복 pop, 방향·시스템 UI 복원, 방을 waiting으로 돌리는 시점, 같은 게임 재진입 경합을
  확인한다. 기존 `game_exit_route_test.dart`의 화면 표시 확인을 넘어 실제 session 수명과
  cleanup을 검증한다. 960ms 변경이 실제 부작용을 만드는지는 아직 재현하지 않았다.
- [ ] tablet 상세 화면·스토어가 열린 동안 복원 대상이 `playing`으로 바뀌는 경우,
  화면을 닫거나 돌아온 뒤 복원을 다시 시작하는 경우, 에셋 준비 중 `finished`로 바뀌는
  경우를 검사한다. `TabletHome`의 `_isDetailOpen`·`_isOpeningStore`·현재 route 조건과
  선택 해제·복원 요청의 경합을 확인한다. 이벤트를 놓쳐 복원이 멈추거나 새 선택과 기존
  게임이 충돌하는지는 추가 재현 대상으로 남기고, 확정 결함으로 기록하지 않는다.
- [ ] 4게임 모두에서 기존 단절·재단절·재실행·복구 중 퇴장·응답 유실·다중 중단
  시나리오를 phone/tablet 흐름으로 대조한다. Android/iOS 휴대폰·물리 태블릿 검증은
  [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md#session-reconnect-02)에 기기·OS·빌드·
  게임별 결과를 남기고, 자동 테스트 결과와 구분한다.

### 완료 근거와 승인 경계

- 위 체크리스트는 테스트 계획이며 구현·수동 검증·출시 차단 해제의 근거가 아니다.
  결함별 실패 재현과 수정 후 통과 근거, 실제 targeted suite·FULL·CI 실행 경로를 남긴다.
- 공통 실행 근거는 이 작업에 한 번 기록하고 SESSION-RECONNECT-02와 NEWGUI-RECOVERY-01에서
  연결한다. 테스트 배선 완료를 제품 복구 작업 완료로, UI 하위 작업 완료를 SESSION 전체
  완료로 취급하지 않는다. 미실행·환경 차단·수동 확인 필요 범위는 각각 유지한다.
- 새 dependency, public API·persistent data·중요한 state machine 변경, production 접근과
  deploy/migration은 Engineering Contract의 별도 승인 경계를 따른다. 테스트 추가와 문서
  등록이 그 변경을 승인하거나 플랫폼·서버 담당 범위를 자동으로 확대하지 않는다.
