# LP 15:00 실기기 후속 수정 후보

2026-10-10 KST. SESSION-RECONNECT-02 / TEST-REGRESSION-01 후속.
사용자의 15:00~15:06 테스트에서 첫 룰렛 단계가 예상보다 높고, A/B 모두 다시하기 후
위너 팝업이 남았다. 태블릿은 가로, 휴대폰은 세로였으며 회전 시험이 아니었다.
FULL 보류와 사용자 직접 APK 빌드·설치 / Functions 배포 방침을 유지한다.

후속 15:45 테스트에서 사용자가 일반 룰렛 단계·위너 재시작 해결을 보고했다.
새 LIAR 생존 후 FOLD 단계 유지 문제와 첫 진입의 일시 안내는
[15:45 후속 조사](LIARS_POKER_1545_FOLD_FOLLOWUP.md)를 따른다.

## 이번 실기기 evidence

A 15:10:53, 태블릿 15:13:20, B 15:21:41 KST에 현재 연결 기기에서 새로 수집했다.
15:00~15:06 범위의 개인정보 없는 game_comm 기록만 각각 98/119/89줄 저장했다.
이전 디바이스 로그를 이번 테스트 evidence로 사용하지 않았다.
세 기기의 설치 APK SHA256은 로컬 14:54 빌드와 모두 같았다:
`FC9829CB22FD46CCE931ABCFA5AA5571C57D1FCA39775D41FA8A97FD00D8BB8A`.
APK debug kernel에도 직전 `_resultDialogRoute` 수정이 포함돼 있고 이전 context 필드는 없다.

태블릿의 추첨·확정 세 번과 재시작 요청은 성공했다. A/B는 새 dealing/playing 상태를 받았다.
A는 finished 수신 15:04:53.081 이후 15:04:56.206에 auth/subscriptions를 다시 시작했고,
B도 finished 15:04:52.837 이후 15:04:56.039~.041에 같은 초기화를 반복했다.
마지막 벌칙 결과 3초 표시 후 위너 팝업을 여는 시점과 일치한다.
운영 RTDB·서버 로그는 추가 조회하지 않았다. 로컬 코드와 새 디바이스 기록으로 범위를 좁혔다.
원판 단계/벌칙 대상의 원시 payload는 로그에 없으므로 개별 추첨별 횟수는 이 기록만으로 단정하지 않는다.

## 원인과 변경

- `AppNetworkGuard.build`가 게임 라우트 위에 팝업이 올라오면 `_isCurrentRoute == false`로
  기존 `_NetworkGuardScope/Stack`을 제거하고 child를 바로 반환했다. 게임 subtree 위치가 바뀌며
  board와 구독이 다시 만들어지고, 기존 root Navigator의 위너 route가 남는다.
  실제 `GameExitMaterialPageRoute + AppNetworkGuard + LiarsPokerPhoneGame` 회귀에서 재현했다.
  가드 wrapper와 child 위치는 유지하고 가려진 화면의 안내·입력 차단만 비활성화하도록 수정했다.
- LP board 자체가 폐기되는 경우에도 자신이 소유한 위너 route를 다음 프레임에 제거한다.
  Navigator 정리 중 재진입을 피하고, 다른 팝업이나 새 board의 route를 제거하지 않는다.
- 서버의 일반 LIAR 실패는 생존자가 두 명이라는 이유만으로 penaltyCount를 미리 올렸다.
  사용자는 **잔여카드 보유자가 혼자인 마지막 카드 도전에서 LIAR 실패한 경우에만 추가 상승**한다고
  확인했다. 직접 LIAR는 lastCardChallenge에서만 미리 올리고, 일반 턴의 자동 LIAR는 올리지 않는다.
  마지막 카드 도전 타임아웃은 기존대로 FOLD이며, 생존 후 횟수는 한 번만 증가한다.
  public shape, callable 이름, rules, 권한, 네트워크 제한 시간은 변경하지 않았다.

직전 3개 회귀는 가드 없는 board를 사용해 첫 builder 경합만 검증했다. 실제 가드를 포함한
화면 구조 전환을 검증하지 못했으며, 이번에 해당 회귀를 추가했다.

## 검증

| command | status / exit | 확인 범위 |
| --- | --- | --- |
| `flutter test --no-pub test/liars_poker_winner_restart_test.dart --reporter expanded` | 수정 전 FAIL / 1 → 최종 PASS / 0 | 화면 재생성 시 이전 위너 잔존과 가드 아래 재시작 실패 재현; 최종 6/6 |
| `flutter test --no-pub test/recovery/widgets/app_network_guard_test.dart --reporter expanded` (`packages/game_kit`) | PASS / 0 | 기존 가드 8/8 |
| `node --test functions/test/liars-poker-forced-timeout.test.mjs functions/test/roulette-restart-integration.test.mjs` (기존 compiled lib) | FAIL / 1 | 일반 직접/자동 LIAR 실패에서 첫 단계가 0 대신 1인 두 회귀 |
| `npm run build` (`functions`) | PASS / 0 | 서버 TypeScript 컴파일 |
| `node --test` LP 기존 `liars-poker-*.test.mjs`와 `roulette-restart-integration.test.mjs` | PASS / 0 | 43/43; 실제 LIAR→prepare→resolve 16/15/12칸, 추가 상승과 중복 증가 방지 |
| `npx eslint src/liars-poker/call-liar.ts src/liars-poker/forced-timeout-resolution.ts src/liars-poker/common/types.ts` (`functions`) | PASS / 0 | 변경 서버 파일 |
| `.\tool\invoke_mosigame.ps1 test session --json` | PASS / 0 | 5/5 steps, Flutter 156, 선택 Functions PASS, snapshot A/B 변화 없음 |
| `flutter analyze --no-pub` 변경 가드/phone board/part/회귀 4파일 | PASS / 0 | no issues, 8.2초 |
| `dart format` 변경 Dart 3파일 / 최종 `git diff --check` | PASS / 0 | 형식·공백 |
| FULL | DEFERRED_BY_USER / 미실행 | 사용자 보류 유지 |
| 새 APK / Functions 배포 / 수정 후 실기기 | 사용자 담당 / 미실행 | 아래 인계 절차 필요 |

명령 결과와 새 디바이스 기록은 ignored `build/device-test/lp-followup-20261010-1500/`에 있다.
guard는 Console stream으로 출력하므로 PowerShell `>`의 session.json은 빈 파일이었다.
session PASS와 exit 0은 실행 terminal 결과로 확인했으며 빈 파일을 JSON evidence로 사용하지 않는다.

## 사용자 인계

이번 서버 변경의 소비자를 확인한 배포 대상은 기존 서울 callable 두 개다.
`resolveForcedTimeout`은 `force-timeout.ts`에서만 사용하며 prepare/resolve/start 변경은 없다.
프로젝트 루트 VS Code 터미널에서 사용자가 실행한다.

```powershell
firebase deploy --project project0000-ec01e --only "functions:game_liars_poker_call_liar,functions:game_liars_poker_force_timeout"
flutter build apk --debug --no-pub
```

새 `build/app/outputs/flutter-apk/app-debug.apk`를 A/B/태블릿에 설치한다.
양쪽 모두 카드가 남은 일반 LIAR 실패의 첫 룰렛 16칸(탈락 4), 생존 뒤 둘째 15칸(탈락 5),
셋째 12칸(탈락 11)을 확인한다. 잔여카드 보유자가 혼자일 때 LIAR 실패는 이번 단계 추가 상승이다.
승리 후 태블릿 다시하기를 반복해 A/B의 위너 팝업이 사라지고 새 분배만 보이는지 확인한 뒤
네트워크·세션 시험을 재개한다. 이번 후보의 실기기 PASS나 전체 태스크 완료를 선언하지 않는다.

## 작업 트리

branch `codex/e01-validation-wiring`, 착수 HEAD `37c1afae5da46b9572058ee7ba132bc740401c1c`.
착수 staged/modified/untracked 모두 0. 사용자 커밋과 작업을 보존했다.
제품 5파일(서버 3, UI 2)·회귀 3파일과 관련 문서만 수정한다.
dependency/lockfile 변경, stage/commit/push, production 접근·배포·APK 빌드는 하지 않았다.
