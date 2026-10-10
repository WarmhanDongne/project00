# LP 휴대폰 위너 팝업 재시작 수정

이 문서는 첫 수정 후보의 기록이다. 2026-10-10 15:00 실기기에서 A/B 모두 잔존이 다시
보고돼 실제 네트워크 가드의 화면 재생성을 추가로 확인했다. 최신 수정·검증·Functions
두 개 반영과 새 APK 인계는 [15:00 후속 기록](LIARS_POKER_1500_FOLLOWUP_FIX.md)을 따른다.

2026-10-10 KST. SESSION-RECONNECT-02 / TEST-REGRESSION-01 후속.
사용자는 첫 게임·룰렛 결과 반영 성공 후, 다시하기에서 이전 위너 화면 아래로 카드 분배가
진행되는 오류만 수정하도록 요청했다. APK 빌드·설치와 Functions 배포는 앞으로 사용자가 담당하며,
FULL은 앞서 요청한 보류 상태를 유지한다.

## 원인과 수정 범위

휴대폰 board가 결과 DialogRoute를 push한 뒤 builder에서 얻은 BuildContext만 보관했다.
push와 첫 builder 실행 사이에 새 게임 공개 상태가 도착하면 닫을 context가 없어 닫기를 건너뛰고,
이미 예약된 이전 위너 팝업은 다음 프레임에 만들어졌다. 새 게임 화면은 그 아래에서 진행된다.
실제 LiarsPokerPhoneGame·컨트롤러·Navigator를 사용하는 위젯 회귀에서 이 순서를 재현했다.
실기기 로그를 새로 조회하지 않았으며 수정 후 실제 기기 결과는 별도 확인한다.

변경은 `packages/game_liars_poker/lib/phone/src/board_state.dart`의 팝업 수명 처리다.
route를 첫 build 전에 보관하고, 재시작 시 그 route만 removeRoute로 제거한다.
기존 generation 검사는 늦은 완료가 다음 위너 상태를 지우지 못하도록 유지한다.
root Navigator, 테마 캡처, focus closedLoop, dismiss/뒤로 가기 차단과 결과 UI는 유지한다.
네트워크·세션·게임 규칙·서버 데이터·Functions는 수정하지 않았다.

## 검증 evidence

| command | status / exit | 결과 |
| --- | --- | --- |
| 수정 전 `flutter test --no-pub test/liars_poker_winner_restart_test.dart` | FAIL / 1 | 경합 테스트에서 이전 PhoneResultDialog 1개 잔존, 정상 표시/재시작 테스트는 통과 |
| 수정 후 같은 테스트 파일 | PASS / 0 | 최종 3/3: 첫 builder 전 재시작, 표시 후 닫기와 같은 우승자 재표시, 다른 팝업 보존 |
| `flutter analyze --no-pub packages/game_liars_poker/lib/phone/phone_board.dart packages/game_liars_poker/lib/phone/src/board_state.dart test/liars_poker_winner_restart_test.dart` | PASS / 0 | no issues, 7.7초 |
| 마지막 테스트 추가 후 `flutter analyze --no-pub test/liars_poker_winner_restart_test.dart` | PASS / 0 | no issues, 5.2초 |
| `dart format --output=none --set-exit-if-changed` 위 변경 2파일 | PASS / 0 | 0 changed |
| `git diff --check` | PASS / 0 | 공백 오류 없음 |
| `validate --full` | 사용자 보류 / 미실행 | 앞선 보류를 해제하지 않음 |
| APK 빌드·설치·실기기 | 사용자 담당 / 미실행 | 새 APK로 재시작 확인 후 네트워크·세션 실기기 시험 재개 |
| Functions 배포 | 불필요 / 미실행 | 이번 후보의 서버 변경 0 |

검증 텍스트와 착수 기록은 ignored `build/device-test/lp-winner-restart/`에 있다.
새 root 테스트는 기존 root FULL 테스트 수집 대상이며 새 suite/manifest를 만들지 않았다.

## 사용자 인계

VS Code에서 프로젝트 루트 터미널을 열고 실행한다.

```powershell
flutter build apk --debug --no-pub
```

산출물은 `build/app/outputs/flutter-apk/app-debug.apk`다. 이번 대화에서 새 APK를 만들지 않았으므로
기존 산출물을 이번 수정 APK로 재사용하지 않는다. 새 빌드 후 A/B/태블릿에 설치하고 정상 승리→
태블릿 다시하기를 반복해 위너 팝업이 사라지고 새 분배 화면만 나오는지 확인한다.
이후 사용자가 계획한 네트워크·세션 실기기 테스트를 진행한다. Functions 배포 대상은 없다.

## 작업 트리

branch `codex/e01-validation-wiring`, 착수 HEAD `5d7b5d5901de7a3986eae5ac3775d0de5eeb9fe6`.
착수 staged/modified/untracked 모두 0. 최종 제품 수정 1파일, 새 회귀 1파일과 작업 문서만 변경한다.
dependency/lockfile/공용 계약 변경 없음. reset/stash/restore/stage/commit/push/production 접근 없음.
FULL·실제 기기 PASS 또는 전체 네트워크·세션 태스크 완료를 선언하지 않는다.
