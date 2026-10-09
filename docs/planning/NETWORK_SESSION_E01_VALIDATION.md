# E01 검증 배선·회귀 복원 기록

[작업 목록](TASKS.md) · [TEST-REGRESSION-01](tasks/TEST-REGRESSION-01.md) · [실행 계획](NETWORK_SESSION_IMPLEMENTATION_PLAN.md)

## 2026-10-09 구현 후보

E00 문서 commit `38b37ed`는 [PR #142](https://github.com/WarmhanDongne/project00/pull/142)로
develop에 병합됐다. 병합 commit `151eff8`의 clean tree에서
`codex/e01-validation-wiring`을 만들었다. 최신 newgui `fcee643` 기준 제품 코드를 유지한다.
사용자가 전체 영역을 수행하며 P/T는 사람별 분담이 아니다.

이번 후보는 V00의 실행 경로 복원이다. session/auth manifest는 그대로 유지하고,
삭제 commit `9beaadb^`에서 아래 20개 파일과 CLI 회귀 11개 파일을 선택적으로 가져와
현재 코드와 대조했다. 삭제된 108개 테스트 전체를 복원한 것이 아니다.
제품 코드·서버 계약·패키지 테스트 내용은 변경하지 않았다.

## session/auth 20경로 대응

경로는 루트 `test/` 기준이다. 각 파일은 실제 기존 동작을 검사하며 빈 테스트가 아니다.

| Suite | 파일 | 보존한 핵심 시나리오 / 현재 코드 대응 |
| --- | --- | --- |
| session | [controller_presence_test.dart](../../test/controller_presence_test.dart) | heartbeat 유예 경계, 즉시 단절, 미확인·미래 시각 |
| session | [controller_reconnect_guard_test.dart](../../test/controller_reconnect_guard_test.dart) | 복구 전 입력 차단·복구 후 해제, 변경된 안내 문구 대응 |
| session | [controller_room_lifecycle_test.dart](../../test/controller_room_lifecycle_test.dart) | 늦은 조회 결과 폐기, 삭제·closed 확정, 종료 경합 |
| session | [game_reconnect_screen_test.dart](../../test/game_reconnect_screen_test.dart) | 기기별 안내·대기 후 버튼·위치 유지, 기존 20초 UI 기준 |
| session | [restorable_player_session_test.dart](../../test/restorable_player_session_test.dart) | waiting/seating 복원 자격, 종료·제거·비활성 거절 |
| session | [room_join_feedback_test.dart](../../test/room_join_feedback_test.dart) | 방 없음·만원·상태별 피드백, 미확인 서버 정보 비노출 |
| session | [room_leave_intent_test.dart](../../test/room_leave_intent_test.dart) | 퇴장 중/확정 후 복원 차단, 방별 기록·정규화, 기존 실패 정책 |
| session | [room_leave_state_test.dart](../../test/room_leave_state_test.dart) | 중복 퇴장·실패·구독 오류·재단절·늦은 복구 완료 |
| session | [room_restore_to_waiting_test.dart](../../test/room_restore_to_waiting_test.dart) | 종료 후 waiting, 결과 화면/동기화 전 정리 방지 |
| session | [session_return_prompt_test.dart](../../test/session_return_prompt_test.dart) | 복귀/거절 콜백·중복 클릭 방지, 로딩 버튼을 기존 key로 검사 |
| auth | [auth/auth_gate_email_link_test.dart](../../test/auth/auth_gate_email_link_test.dart) | 실행 중 링크가 상위 route 정리 후 인증 로딩 표시, 카드 전환 대기 |
| auth | [auth/auth_gate_rotation_test.dart](../../test/auth/auth_gate_rotation_test.dart) | 로그인 후 반복 회전에서도 온보딩 단일 구독 유지 |
| auth | [auth/auth_gate_stuck_loading_test.dart](../../test/auth/auth_gate_stuck_loading_test.dart) | 가입 상태 timeout·재시도·세션 정리, 카드 전환 대기 |
| auth | [auth/email_link_error_message_test.dart](../../test/auth/email_link_error_message_test.dart) | 사용 완료·만료 링크의 재전송 안내, Firebase 원문 대체 |
| auth | [auth/google_login_button_test.dart](../../test/auth/google_login_button_test.dart) | Google 로고 에셋 표시 |
| auth | [auth/onboarding_parity_test.dart](../../test/auth/onboarding_parity_test.dart) | 가입 단계·경로 값의 서버 일치, Apple 경로 해석 |
| auth | [auth/register_loading_test.dart](../../test/auth/register_loading_test.dart) | 로더 중복 방지·즉시 재전송·비밀번호 조건·프로필 입력 차단, MosiButton/현재 필드 대응 |
| auth | [auth/tablet_auth_parity_test.dart](../../test/auth/tablet_auth_parity_test.dart) | 기기 크기·글자 배율·폼 폭·비밀번호 정책, 현재 필드/사진 버튼 대응 |
| auth | [platform_auth_shell_test.dart](../../test/platform_auth_shell_test.dart) | 카드와 그림자 여백의 중앙 배치, 실제 스크롤 이동 |
| auth | [social_login_button_test.dart](../../test/social_login_button_test.dart) | enabled 탭·disabled 차단, 현재 52px 높이와 8px 모서리 일치 |

복원 테스트의 PASS는 새 복구 정책 구현 완료를 뜻하지 않는다. 특히
`room_leave_intent_test`·`room_leave_state_test`의 **실패 시 기존 상태 복원**은 현재 baseline이며,
채택한 **영속 퇴장 의도 유지**는 E06에서 구현과 회귀를 함께 변경한다.
`GameReconnectScreen`의 기존 20초 UI 대기는 새 서버 60초 참가자 마감/추가 30초 계약을 검증하지 않는다.
복구 준비 barrier·다중 중단·시간 보존·retry 예산·route/terminal·실기기 시나리오는 해당 후속 E와 E13/E14에 남는다.

## FULL/CI 배선

[명시적 package manifest](../../tool/mosigame_cli/package_test_manifest.dart)에 game_kit과 4게임을 등록했다.
루트 Flutter test 다음에 각 `packages/<name>`에서 `flutter test --no-pub`를 실행하고,
그 뒤 기존 Functions lint/test를 실행한다. 템플릿은 테스트 0개라 성공 단계로 등록하지 않는다.
각 단계의 작업 디렉터리·결과 ID·공통 deadline/정리 규칙은 [Project CLI](../engineering/PROJECT_CLI.md)에 명세했다.
CI는 같은 FULL을 호출한다. 별도 shell 테스트 목록을 만들지 않았다.

CLI 회귀는 인자·실행 순서·5개 package 작업 디렉터리, 각 package 실패 전파/후속 중단,
package timeout/불신 mutation 근거를 검사한다. 기존 deadline·정확한 process 정리·snapshot·exit-code
회귀를 보존했다. 실제 workspace 등록·테스트 존재와 session/auth 경로 존재도 root 회귀로 검사한다.
새 게임은 실제 테스트 작성과 manifest 등록을 함께 해야 한다.

## 실행 근거와 남은 확인

공통 command/status/exit code·초기 실패와 보정·전후 tree는
[2026-10 기록](logs/2026-10.md#2026-10-09--e01-회귀-복원검증-배선)에 한 번 기록한다.
targeted/직접 package 실행은 최종 FULL을 대체하지 않는다.
2026-10-09 사용자 명시 승인 뒤 `.\tool\invoke_mosigame.ps1 validate --full --json`을 실행했다.
PASS, CLI/호출 exit 0, 241908ms. 12단계 모두 PASS이며 root 334개, package 5개 합계 139개,
Functions 337개 테스트가 실제 실행됐다. CLI의 mutation 검사와 별도 branch/HEAD/status/SHA256 비교에서
실행 전후 43파일이 동일했다. 결과 기록 갱신 외 제품/테스트/실행기 코드는 추가 변경하지 않았다.
현재 E01 후보의 CI 실행·Git 반영과 후속 제품 회귀는 별도 확인한다.
