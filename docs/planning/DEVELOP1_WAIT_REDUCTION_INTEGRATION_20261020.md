# 디벨럽1 · 대기 단축 통합 검토 — 2026-10-20

## 판단

팀원 `디벨럽1`의 로컬 Firebase 선택·로비/화면 전환·윷놀이 세 경로와, 로컬
`develop`의 시작 조회 병행·초기화 보조 취소 분리를 함께 유지한 통합 후보를 만들었다.
겹친 코드의 충돌을 해결하고 관련 자동 검사를 통과했다. 첫 FULL은 아래 테스트 준비·
기대값 불일치12건을 보완한 뒤 관련79개·분석이 PASS다. 사용자 재승인0d48bfb의
FULL은 앱·전 게임·lint를 포함한12단계 PASS, 서버 목록 기대2건으로 마지막1단계
FAIL/exit1이었다. 이 두 테스트도 보완한 뒤 서버512개가 PASS/exit0이다. 수정 후
canonical FULL은 미실행이다. 최신 요청에 따라 검증 상태를 명시한 Draft PR만 생성하고
병합은 하지 않는다.

## 비교 기준

| 기준 | commit | 의미 |
| --- | --- | --- |
| 공통 조상 | `b921f53bfb73c4b5f37c883d4285e1bb9ffcf393` | 양쪽 변경을 분리해 대조한 기준 |
| 로컬 develop | `707e3005f9e3ac2433010ed9d611d904eee7160d` | 최소 대기 단축 `6e07361` 및 이전 FULL 결과 문서 |
| origin/디벨럽1 | `b87418f5862dda55fc9bc75f761bcdd769b7cd2e` | 팀원 로컬 환경·로비/상점·신규 윷놀이 |
| origin/develop | `b10fc436ad90852a8d809879cd837565af7fb0cb` | PR 대상. 게시·병합 직전 다시 확인 |

독립 worktree의 `codex/develop1-wait-reduction`에서 양쪽을 merge했다. 원 수집 checkout,
기록 브랜치와 로컬 develop의 파일을 수정하거나 reset/stash하지 않았다. 준비는 기존
lock 범위만 사용했으며 lock 내용은 동일하다. 임시 계측·수집기를 추가하지 않았다.

## 충돌·동작 보존

| 겹친 부분 | 통합 결과 | 확인 방법 |
| --- | --- | --- |
| 최초 자리 배치 → 게임 | 팀원의 책/문 전환·로비 복귀 callback과 대기 단축의 launch 소유 조회를 결합. route 종료/취소/명단 변경 시 옛 조회 무효화 | 네 기존 게임과 윷놀이 세 ID의 성공 시작·rebuild·중복 완료 및 실패/세대 변경 회귀 |
| 선택 Firebase와 신원 | 새 조회·pending-start도 `FirebaseBackend.auth` 사용. 서버는 기본 앱, local은 named demo 앱 | server와 local 모드에서 인증 앱 일치·접속/계정/게임 교체·dispose 회귀 |
| 방 초기화 | 선택 backend를 쓰면서 durable 의도 저장 후 옛 참조만 취소하고 close/status와 병행. 서버 미확정 시 신원·원 operation 보존 | 취소 미완료/실패/늦은 등록, 새 접속, 종료 실패/재시도 회귀 |
| 작업 기록 | 양쪽 일지를 모두 보존 | 충돌 블록 대조·미해결 index 없음 |

CI에서 팀원 bootstrap 경로 `lib/firebase/firebase_bootstrap.dart`가 기존 금지 경로에
걸린 것을 확인했다. 내용은 그대로 `lib/firebase_bootstrap.dart`로 이동하고 main import만
갱신했다. 검사 예외를 늘리지 않았다. 상점 화면의 if 중괄호 lint도 동작 변경 없이 보완했다.

새 `game_yut`이 workspace에 추가됐지만 기존 FULL 대상에는 빠져 있었다. 기존 실행
경로의 package manifest에 포함하고 역방향 workspace 대조 회귀를 추가했다. 새 패키지를
검사하지 않은 채 FULL 통과로 표시되는 상황을 방지한다.

## 관련 검증

Windows Project CLI는 `powershell.exe -NoProfile -NonInteractive -OutputFormat Text
-ExecutionPolicy Bypass -File tool/invoke_mosigame.ps1 ...` 경로로 실행했다.

| 명령/검사 | 결과 | exit |
| --- | --- | ---: |
| `tool/setup_mosigame.ps1 -Prepare` | READY; 기존 lock 보존 | 0 |
| `dart format --output=none --set-exit-if-changed bin lib test tool/mosigame_cli` | PASS, 197파일 변경 없음 | 0 |
| `flutter analyze --no-pub` | PASS, 문제 0 | 0 |
| 시작/초기화/로비/배경/manifest 관련 7파일 `flutter test --no-pub` | PASS, 81개 | 0 |
| `flutter test --no-pub --dart-define=MOSIGAME_BACKEND=local test/firebase_backend_test.dart test/tablet_start_launcher_test.dart` | PASS, 18개 | 0 |
| `flutter test --no-pub` (packages/game_yut) | PASS, 8개 | 0 |
| `node --test functions/test/yut-game.test.mjs` | PASS, 14개 (session 빌드 산출물) | 0 |
| `tool/invoke_mosigame.ps1 test session --json` | PASS, Flutter 219·Functions 156·mutation 없음 | 0 |
| `tool/invoke_mosigame.ps1 test auth --json` | PASS, Flutter 80·Functions 38·mutation 없음 | 0 |
| `npm --prefix functions run lint` | PASS | 0 |
| 패키지 경계 회귀/검사·요청 retry 계약 검사 | PASS, 경계 위반 0 | 0 |
| `tool/invoke_mosigame.ps1 validate --full --json` (16480f4) | FAIL, 앱 테스트 12건. 포맷·분석·상태 보존 PASS, 뒤 패키지/Functions 미실행 | 1 |
| 보완한 책장·목록·글자 맞춤·상점·FULL 순서 5파일 테스트 | PASS, 79개 | 0 |
| 보완 테스트 5파일 `flutter analyze --no-pub` | PASS, 문제 0 | 0 |
| 재승인 `tool/invoke_mosigame.ps1 validate --full --json` (0d48bfb) | 12단계 PASS, Functions 테스트2건 때문에 마지막1단계 FAIL, 549.46초, mutation 없음 | 1 |
| 카탈로그 기대 목록 보완 후 `npm --prefix functions test` | TypeScript build·서버512개 PASS, mutation 없음 | 0 |
| 카탈로그 테스트 보완 후 canonical FULL | 미실행. Draft PR에서 CI/후속 최종 검증 확인 | — |

관련 테스트 수는 실행별 수이며 서로 중복되므로 합산하지 않는다. 최초 Prepare 전 환경
점검은 의존성 미준비(exit3)였고 Prepare 뒤 READY가 됐다. 최초 경계 검사와 정적 분석은
위 bootstrap 경로/중괄호에서 각각 exit1이었다. 원인을 고친 뒤 해당 검사만 재실행해
exit0을 확인했다. 검증 명령 실행 중 tracked/unignored 파일 변화는 없었다.

## 한계·후속

- 이 검증은 두 코드의 통합 회귀 판단이다. 전체 체감 단축량이나 서버 내부 지연 원인은
  새로 측정하지 않았다. 원래 조건이 다른 시험 간 시간 차이를 절감량으로 쓰지 않는다.
- 계측 없는 최종 앱 확인은 사용자 결정대로 방 생성·추방 개선 뒤 수행한다. G1 실기기
  생략과 V1 이전 버전 혼합 보류를 유지한다. 미실행을 통과로 취급하지 않는다.
- 윷놀이 실제 4인 기기 플레이·센서/진동·native 빌드·운영 카탈로그 공개·배포는 이번
  자동 검사로 확인되지 않는다. 기존 비공개/결제 비활성 상태와 별도 출시 승인 조건을
  유지한다. 앱/서버 코드는 일반판 2~4인, 전략판 4인으로 일치하며 규칙을 바꾸지 않았다.
- 원 수집 338파일·기록 브랜치 171파일 및 기존 develop 관련 3파일의 해시와 HEAD/status가
  작업 전과 같음을 확인했다. 로그·APK·상세 계산 자료는 원래 보존 위치에 둔다.

[대기 단축 계약](../engineering/NETWORK_SESSION_CONTRACT.md) ·
[초기화 시간 해석](../operations/ROOM_ACTION_LATENCY.md) ·
[NET-RECOVERY-01](tasks/NET-RECOVERY-01.md#wait-reduction-integration-20261020) ·
[YUT-GAMEPLAY-01](tasks/YUT-GAMEPLAY-01.md)

## 첫 FULL 실패와 회귀 테스트 보완

승인 후보16480f4의 FULL은 포맷·분석 뒤 앱 테스트12건에서 중단됐다(exit1,
195.62초). 검증 중 파일 변화는 없었다. 뒤 패키지·Functions를 통과로 집계하지 않는다.

- 번들 서비스가 새로 생성되는 세 테스트 파일에 미사용 bundle I/O용 Fake를 주입했다.
  실제 Firebase 접근 없이 기존 게임 목록·dispose·화면 검증을 유지한다. 예상하지 않은
  번들 호출은 Fake에서 실패한다. 제품의 Firebase 초기화 순서는 바꾸지 않았다.
- 윷놀이를 FULL에 포함하면서 누락한 순서 회귀의 실행 수/npm 위치를 패키지 개수에
  맞췄다. 패키지 이름/순서는 별도 manifest 회귀가 고정하고 정확한 호출 인수도 유지한다.
- 팀원 UI에서 빈 책등 대신 실제 책 순환, 상점4권씩 페이지 이동, 윷놀이/번들에만 상세
  진입을 제공하는 것을 대조했다. 해당 UI로 실제 이동해 같은 모든 게임·언어·화면 크기를
  검사한다. 마피아 예고편·가짜 결제/음악 완료 금지를 유지하며 윷놀이3종의 상세 진입과
  미보유 상태 보존을 양성 회귀로 추가했다.

중간 재검사에서 Firebase 오류가 해결된 뒤 페이지2 미탐색·옛 빈 책등 기대가 드러났다.
이를 테스트 절차에 반영한 뒤 관련79개와 보완5파일 분석이 PASS/exit0이다. 테스트를
삭제/skip하거나 문구 잘림 기준·폰트 크기·언어/기기 크기를 완화하지 않았다. 첫 FULL
이후 제품·설정·package manifest의 내용은16480f4와 같고 변경은 테스트·검증 문서다.
후속 FULL과 서버 검사, PR 전용 범위는 아래 기록을 따른다.

## 재승인 FULL 결과·서버 후속 검사·Draft PR 범위

사용자 “다시 실행하고 pr 생성만 해” 지시로0d48bfb에서 guarded FULL을 한 번
재실행했다. 549.46초, exit1이며 앱·공용·다섯 게임 패키지·Functions lint·작업 트리
보존 등12단계는 PASS다. 서버512개 중510개 PASS,2개 FAIL로 Functions 단계만 실패했다.
원인은 카탈로그 재작성 단위 테스트가 신규 윷놀이3종을 제외한 옛4종 목록을 기대한 것이다.

`functions/test/rebuild-game-catalog.test.mjs`의 정확한 대상 목록을7종으로 보완하고
윷놀이3종의 `enabled:false`·`accessType:paid` 조건도 검사했다. dry-run 무변경·기존 자료
백업·최소 스키마·하위 collection 보호 검증은 유지한다. 이 테스트는 메모리 Fake DB를
사용하며 실제 재작성 CLI·운영 접속·배포는 실행하지 않았다. 제품/카탈로그 정의는 그대로다.

실패한 서버 단계만 `npm --prefix functions test`로 재실행해 TypeScript build와512개
모두 PASS/exit0, 작업 트리 보존을 확인했다. 수정 후 canonical FULL을 다시 실행하거나
그 결과를 PASS로 바꾸지 않는다. 이 범위와 로컬 FULL 실패 이력을 PR에 명시한다.

최신 직접 지시에 따라 통합 브랜치만 push하고 **develop 대상 Draft PR만 생성**한다.
원격/로컬 develop 병합·직접 push·자동 병합은 하지 않는다. 최종 FULL/CI 확인 뒤
review-ready 및 병합 여부는 후속 판단이다. 앞선 실기기·혼합 버전·신규 게임 출시
보류 조건도 유지한다. 로그·원본과 기존 브랜치는 보존한다.
