# 2026-10-11 develop 네트워크·로컬 GUI 통합 후보

관련 작업: [NEWGUI-RECOVERY-01](tasks/NEWGUI-RECOVERY-01.md),
[SESSION-RECONNECT-02](tasks/SESSION-RECONNECT-02.md),
[TEST-REGRESSION-01](tasks/TEST-REGRESSION-01.md).

## 기준과 보존

- 사용자 요청: 최신 develop의 방·플레이어·게임 내부 연결/Firebase 변경을 우선하고,
  현재 GUI·애니메이션을 보존해 현재 브랜치에 반영한다.
- 작업 브랜치 `디벨럽1`, 내용 통합 시점 HEAD `7bb2b1e249c8305ad62458b001bff5057e02e5fd`.
- `git fetch origin develop`: PASS / exit 0.
  가져온 기준 `c8b6a74bd67ce8807a30a5e828d63303abf6ef67`.
- 작업 시작 시 staged 없음, 기존 tracked 수정·삭제 및 untracked 파일 있음.
  변경/미추적 파일 211개의 내용·삭제 여부와 binary diff, index diff, SHA-256을
  저장소 밖 로컬 임시 복구 사본으로 보존한 뒤 작업했다.
- HEAD를 공통 기준으로 원격 변경 33개 파일을 현재 작업 내용과 3-way 통합했다.
  10개 파일이 겹쳤고 코드의 텍스트 충돌은 없었다.
  월별 기록 목차 충돌은 양쪽 기록을 모두 보존해 해결했다.
- 겹치지 않는 기존 작업 파일 201개는 원본 해시/삭제 상태와 일치한다.
  fonts, 새 GUI 위젯, 에셋 삭제, design_exports, packages.zip도 보존했다.
- 최초 내용 통합은 **미커밋 작업 트리**에 반영했다. 이 시점에는 index/HEAD/브랜치
  이력을 변경하지 않았고 merge commit, push, Firebase 배포를 하지 않았다.
  이후 Git 이력 반영 요청은 아래 후속 항목을 따른다.

## 반영 내용

- develop: 마지막 정상 heartbeat 기준의 타이머 보존, 단절과 pause 동시 기록,
  태블릿 stale 보고 및 제한 재시도, controller 복구 identity/세대 검증.
- develop: controller 복구 중 canSend/턴 timeout 보호, 실제 pause의 ready barrier가
  끝날 때까지 안내 유지, LP dealing 응답 유실 시 동일 게임·라운드의 공개 상태 확인.
- 로컬: 로비/책 전환·참가자 등장/퇴장·카드·룰렛·LP 공개/벌칙 GUI와 폰트 유지.
  겹치는 game_screen/controller에는 신규 네트워크 보호와 기존 GUI 표시 값을 함께 유지.
- 로컬의 비충돌 로비 지연 개선·계측, 최초 요청 fast path, ready 보고 개선도 보존했다.
- 인증 suite에 이미 추가된 email_link_service_test.dart가 기대 목록에는 빠져 있던 것을
  맞춰 suite 목록 검증을 유지했다. 테스트 삭제/생략은 없다.
- develop에서 들어온 실기기 문서의 줄 끝 공백 4곳을 제거했다.

## 실행한 검증

macOS raw CLI, Functions 검사는 기존 Node 22.23.1을 PATH 앞에 지정했다.
아래 모든 검증은 PASS / exit 0이다.

| 명령 | 결과 |
| --- | --- |
| `dart run :mosigame test session` | Flutter 166개, Functions 102개; 검사 전후 작업 트리 동일 |
| `dart run :mosigame test auth` | Flutter 44개, Functions 12개; 검사 전후 작업 트리 동일 |
| 아래 GUI/통합 Flutter 명령 | 119개 PASS |
| `dart analyze lib/platform/home/room` | No issues found |
| `npm --prefix functions run lint` | PASS |
| 아래 변경 파일 format 검사 | 8개, 변경 없음 |
| `git diff --check` | 최종 PASS; 최초에는 원격 실기기 문서 공백 4곳을 보고했고 이후 정리 |

```sh
flutter test --no-pub test/book_carousel_test.dart test/tablet_room_reset_test.dart test/store_profile_gui_test.dart test/table_background_transition_test.dart test/game_board_structure_test.dart test/liars_poker_winner_restart_test.dart test/final_call_action_latency_test.dart test/room_action_fast_path_test.dart test/game_list_latency_test.dart test/game_asset_parallel_install_test.dart test/player_presence_test.dart test/mosigame_cli/test_suites_test.dart packages/game_kit/test/penalty/roulette_test.dart packages/game_kit/test/mosi_ui/mosi_motion_test.dart packages/game_kit/test/recovery/widgets/game_connection_led_test.dart packages/game_kit/test/recovery/network_session_contracts_test.dart

dart format --output=none --set-exit-if-changed lib/platform/home/room/providers/room_provider.dart lib/platform/home/room/services/room_service.dart lib/platform/home/room/services/player_presence.dart test/controller_room_lifecycle_test.dart test/controller_room_recovery_test.dart test/player_presence_test.dart test/mosigame_cli/test_suites_test.dart tool/mosigame_cli/test_suites.dart
```

## 남은 검증

- `dart run :mosigame validate --full`: 이번 통합 후보에 대한 사용자 승인 대기, 미실행.
- 실기기 동시 연결·단절·재접속 및 실제 애니메이션 육안 확인 미실행.
- 이번 결과는 로컬 통합 후보이며 최종 완료/출시/배포 판정이 아니다.

## 2026-10-11 후속 GitHub 게시 요청

사용자가 `디벨럽1`의 GitHub push를 명시 요청했다. 게시 대상은 위 통합 후보의
앱 소스·폰트·문서·테스트이며, `design_exports/`와 대용량 `packages.zip`은
로컬 내보내기 산출물로 보존하고 제외한다. `origin/develop` 재조회 결과는 같은
`c8b6a74`이고 원격 `디벨럽1`은 아직 없었다. 내용 통합 커밋과 develop 이력 병합을
기록한 뒤 새 원격 브랜치로 게시한다. 이 요청은 FULL 실행이나 Firebase 배포
승인을 뜻하지 않으며 전체 검증은 미실행 상태다.
