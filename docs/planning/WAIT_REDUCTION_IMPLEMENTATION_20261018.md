# 불필요한 대기 단축 — 구현·검증 기록

2026-10-18 · `codex/wait-reduction` · 기반 `develop` / `4325d691d7b94d2458e1140c601ba66894d54ca3`

[구현 인수인계](WAIT_REDUCTION_HANDOFF_20261018.md) · [근거·해시](evidence/wait-reduction-20261018/input-manifest.json) · [분석 코드와 develop 대조](evidence/wait-reduction-20261018/code-comparison.json)

## 현재 상태

문서 인수인계 → 자료 자체 점검 → 문서만 반영한 중간점 → 환경 준비 → 합의 두 항목의 구현 후보와 관련 검증까지 진행했다. **후속 사용자 승인으로 합의 두 항목의 코드 구현과 FULL 검증을 마쳤다(PASS/exit 0). 실기기·지원 이전 버전 혼합·실제 성능 효과는 미검증이다.** commit/stage/push·운영 조회·배포는 하지 않았다. 추가 후보 세 항목은 인수인계에만 남겼다.

문서 전용 중간점은 ignored `build/device-test/wait-reduction/document-only-checkpoint.json`에 당시 HEAD·변경 목록·문서 해시로 보존했다. 중간점을 만들려고 커밋하지 않았다. 원 수집 checkout의 원본 836개와 관련 소스 27개의 SHA-256을 다시 대조했다. 원 브랜치에는 작업 외부에서 기존 untracked 수집 자료를 기록한 `78d0fdf` 커밋이 생겨 HEAD/Git 상태는 달라졌다. 원 `13119f2`의 후속 커밋이며 수집 자료 추가만 있고 구현 소스와 원본 바이트 변경이 없음을 확인했다. 새 커밋을 되돌리거나 이 작업의 커밋으로 취급하지 않았다. 실제 개수·현재 HEAD·변경 경로는 같은 폴더의 `preservation.json`을 기준으로 한다.

## 구현 1 — 최초 자리 배치에서 정리 대상 조회 병행

- 자리 저장 및 서버 시작 성공 **뒤**에 정리 대상 조회를 시작하고, 남은 착석·줌과 겹친다. 전환 때 같은 Future를 사용하므로 이미 끝난 조회를 다시 하지 않는다. 늦으면 기존처럼 완료를 기다린다.
- `_TabletGameLauncher`가 조회와 시작/전환 중복 방지 상태를 소유한다. route builder 재실행으로 상태가 초기화되지 않는다. route 종료·취소 시 무효화한다.
- UID·방 코드·방 인스턴스·진행자 세션·connection ID/sequence를 로컬 신원과 대조한다. 새 신원/계정으로 바뀌면 이전 결과로 전환하거나 최신 방을 대신 재조회하지 않는다.
- 현재 관측 가능한 게임 문맥이 새 세대로 바뀌면 옛 조회/전환을 폐기한다. 시작 전의 **이전 게임 캐시**는 새 시작의 권위 있는 문맥으로 취급하지 않는다. 완전한 공개 게임 미러를 새로 만들지는 않았다. 실제 정리는 기존 서버의 방·게임 세대·종료 상태 검사로 계속 보호한다.
- 조회 실패 때 같은 유효 시도에서 전환 직전 조회를 한 번만 다시 한다. 그것도 실패하면 기존 nullable target 의미를 유지한다. 로컬 신원이 없으면 미리 조회를 하지 않고 전환 시 기존 확인을 수행한다.
- 게임 화면의 퇴장 연출 종료 뒤 정리하는 순서와 태블릿 가로 방향, 자리/줌/배분/손패 공개 연출을 유지한다. 메뉴·결과 재시작과 복구 경로를 최적화 대상으로 넓히지 않았다.

변경: `lib/platform/home/tablet/tablet_game_launcher.dart`, `tablet_game_start.dart`, 내부 helper `tablet_start_cleanup.dart`. TemplateGame·서버 callable·DB·Rules·영속 스키마는 변경하지 않았다.

## 구현 2 — 초기화의 옛 접속 예약 취소 분리

- 옛 신원·정확한 connection 참조·종료 payload를 먼저 고정한다. 기존 durable close 의도 저장과 `awaitingResult` 저장을 끝낸 뒤 **옛 예약 취소 ∥ 기존 close/status 처리**를 시작한다.
- 취소 오류는 시작부터 처리하며, 취소가 실패하거나 끝나지 않아도 서버 종료 응답을 기다릴 수 있다. 저장 실패 시 취소와 새 서버 종료 모두 시작하지 않는다. 이미 confirmed인 종료에서도 옛 예약 정리는 시도한다.
- 서버 응답 유실 시 신원·원 operation ID를 유지하고 기존 applied/stale/notApplied 재확인 절차를 따른다. 서버 미확정 상태에서 성공 처리하거나 복구 신원을 삭제하지 않는다.
- 저장 중 신원이 교체되면 새 세션에 leaving/invalidate를 적용하지 않는다. 서버 확인 뒤의 신원·진행자 세션 삭제도 기존 roomInstance/session 조건을 유지한다.
- presence 등록은 신원과 해당 방 세대의 durable close 의도를 검사한다. 종료 전에 시작한 등록이 취소 뒤 늦게 완료되면 **그 옛 경로만** 다시 취소한다. 새 접속의 등록을 취소하지 않는다. 세대가 없는 전역 mutable 참조를 늦게 조회하지 않는다.
- 늦은 보조 완료가 끝난 RoomActionTiming 표본에 성공을 추가하지 않는 기존 보호를 유지한다. 종료 재시도를 미완료 취소 Future에 묶지 않는다.

변경: `lib/platform/home/room/services/room_service.dart`. 게임 나가기·참가자 퇴장에 범위를 확대하지 않았다. 서버 규칙·프로토콜·게임 규칙은 그대로다.

## 실행한 검증

모든 구현/환경 명령은 새 worktree에서 실행했다. 아래 경로는 worktree 기준이다. 각 로그와 실행별 코드/최종 소스 해시는 ignored `build/device-test/wait-reduction/`에 보존한다.

| 검사·실행 명령 | 결과 / exit | 근거 |
| --- | --- | --- |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\setup_mosigame.ps1 -Prepare` | READY / 0, doctor 9 PASS | 승인 범위의 lock 의존성 준비. lock·버전 변경 없음. Windows setup의 config 존재 확인 경로 1곳 수정 |
| `flutter test --no-pub test/tablet_start_launcher_test.dart test/tablet_start_cleanup_test.dart test/lobby_gui_test.dart --reporter expanded` | 37 PASS / 0 | `start-and-lobby-final.log`. 공용 네 게임 launcher·rebuild/중복·시작 실패·수명·기존 로비 UI |
| `flutter test --no-pub test/tablet_start_launcher_test.dart --reporter expanded` | 10 PASS / 0 | `launcher-generation-final.log`. 조회 중 세대 불일치 폐기 보완 후 같은 10건 재검증 |
| `flutter test --no-pub test/tablet_start_launcher_test.dart --plain-name "new game before lookup" --reporter expanded` | 1 PASS / 0 | `generation-during-lookup.log`. 추가한 조회 완료 전 게임 교체 경합 |
| `flutter test --no-pub test/room_action_fast_path_test.dart test/room_action_timing_test.dart test/tablet_room_reset_test.dart test/room_restore_to_waiting_test.dart test/game_command_response_loss_test.dart --reporter expanded` | 59 PASS / 0 | `close-and-recovery-final.log`. 취소 지연·오류·미완료·늦은 등록·실제 새 접속 등록·새 session 보호·디스크 실패·원 ID 재시도·네 게임 응답 유실 |
| `powershell.exe -NoProfile -ExecutionPolicy Bypass -File .\tool\invoke_mosigame.ps1 test session` | PASS / 0, 5개 검사 PASS | `session-suite.log`. Flutter/Functions/작업 트리 보존. PowerShell의 stderr XML 변환 경고가 섞였으나 CLI 최종 PASS·프로세스 exit 0을 확인함 |
| `dart format --output=none --set-exit-if-changed` + 변경 Dart 파일 7개 | PASS / 0, 변경 0개 | 4개 앱 파일·3개 관련 테스트 |
| `flutter analyze --no-pub` + 위 7개 파일 | PASS / 0 | `analysis-final.log`, No issues found |
| `git diff --check` 및 원본/lock/staging 대조 | PASS / 0 | `preservation.json`, `validation.json` |
| `tool/invoke_mosigame.ps1 validate --full --json` | **PASS / 0** | 후속 명시 승인으로 실행. `full-20261018-approved/result.json`, 실행 전후 작업 트리 동일 |

초기 검사에서 새 테스트의 역할 추론 설정 2건과 위젯 가상 시간/실제 Future 경계 문제가 나타났다. 역할 검증을 정확한 controller 저장소로 바꾸고 테스트 비동기 작업을 `runAsync`로 격리해 수정했다. 가상 시간과 실제 시간 사이에 멈춘 해당 테스트 프로세스 트리만 식별해 종료했으며, 테스트를 삭제/skip하거나 검증 기준을 낮추지 않았다. 초기 실패/진단 로그도 같은 폴더에 보존한다. 제품의 미리 읽기 검토 중 발견한 새 게임 문맥 충돌은 무효화로 처리하고 회귀를 추가했다.

## 남은 채택 조건

1. 후속 사용자 승인으로 **FULL PASS/exit 0**를 확인했다. setup은 Windows 존재 경로 확인만 수정했고 guard 구현/프로세스 관리 설정은 바꾸지 않았다. 아래 실기기·전후 성능 검증은 별도다.
2. 실기기에서 최초 시작·메뉴/결과 재시작 불변·복구·게임 퇴장, 의도된 연출·가로 방향, 실제 선택/제출, 초기화 실패·재시도와 지원 이전 버전 혼합을 확인한다. 자동 테스트의 네 게임 launcher 대역과 실제 게임 서비스 응답 유실 검사는 과거 모든 APK를 시험했다는 뜻이 아니다.
3. **성능 효과는 미측정이다.** develop에는 과거 Debug 수집기/이벤트 묶음이 없다. 후속으로 최소 계측 경계를 맞춘 후 같은 빌드·기기·망 조건에서 비교한다. 최초 시작은 시작 성공·조회 시작/완료·연출 끝·화면 첫 프레임·입력 준비를, 초기화는 의도 저장·옛 취소·서버 close·태블릿/폰 완료를 분리한다. 실제 요청 연결 없이 시간을 더하거나 빼지 않는다. 기기 간 범위 폭 250ms 기준을 유지한다.
4. 조회 추가 대기는 같은 시험에서 `max(0, 조회 완료 - 연출 끝)`으로 확인한다. 취소 분리의 실제 기여가 작으면 성능 변경 채택 근거로 삼지 않는다. 예상 단축 초를 제시하지 않는다.

추가 후보 logger import 축소·게임 시작 중복 읽기 재사용·방 생성 독립 읽기 병행은 **별도 채택 승인 후** 진행한다. 준비 인스턴스/주기적 예열 보류 결정과 폰 안내·카드팩 의도는 유지한다.


## 사용자 후속 결정 — 2026-10-18

최종 FULL 실행 질문에 사용자가 “지금은 실행하지 않음”을 선택했다. FULL을 실행하지 않았고 추가 테스트도 시작하지 않았다. 기존 구현 후보와 관련 PASS 결과는 보존한다. FULL·실기기·혼합 버전·실제 성능 효과는 미검증이므로 최종 완료/성능 채택으로 표시하지 않는다.


## 후속 승인·FULL 결과 — 2026-10-18

사용자가 “풀 진행 후 구현 계획 실행”을 요청해 이전 미실행 선택을 갱신했다. 당시 두 합의 항목은 이미 구현돼 있었으므로 동일 후보의 해시를 확인하고 Windows guarded FULL을 1회 실행했다. FULL은 PASS/exit 0이고 검증 중 Git 상태와 후보 파일 해시 변화가 없었다. 포맷/전체 분석/앱/공용·네 게임 패키지/Functions lint·test 및 작업 트리 보존을 확인했다. 검증 뒤에는 현재 동작 설명과 기록 문서만 갱신했으며 제품 코드를 다시 변경하지 않았다.

명령: `powershell.exe -NoProfile -NonInteractive -OutputFormat Text -ExecutionPolicy Bypass -File tool/invoke_mosigame.ps1 validate --full --json`. 전체 결과는 ignored `build/device-test/wait-reduction/full-20261018-approved/result.json`, 원문 stdout/stderr와 실행 전후 상태는 같은 폴더에 보존했다. 원 수집 자료 836개와 관련 소스 27개 해시도 재확인했다.

코드 구현과 자동 검증은 끝났고 실기기·지원 이전 버전 혼합·동일 조건 전후 측정은 남아 있다. 합의한 두 항목의 구현 범위를 유지하며 추가 후보 세 개는 별도 채택 대상이다. commit/push/merge·운영 조회·배포는 하지 않았다.
