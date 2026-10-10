# LP 15:45 실기기 FOLD 후속 수정 후보

2026-10-10 KST. SESSION-RECONNECT-02 / TEST-REGRESSION-01 후속.
테스트 시작은 사용자 보고 15:45이며 종료 시각은 제공되지 않았다.
사용자는 일반 룰렛 단계와 다시하기 위너 잔존이 해결됐다고 보고했다.
첫 진입의 카드 상태 갱신 안내는 1초 이내 사라지고 게임이 진행됐다는 별도 관찰이다.

## 새 현상과 코드 확인

사용자 순서: 잔여카드 보유자가 혼자인 상황에서 A가 LIAR 실패 → 첫 벌칙부터 2단계
룰렛 → 생존 → 다음 라운드 B가 카드를 소진 → A FOLD → 같은 2단계 룰렛.

`call-liar.ts`는 마지막 카드 도전의 LIAR 실패에서 penaltyCount를 0→1로 미리 올리고
`penaltyCountIncrementedBeforeRoulette=true`를 설정한다. `finish-penalty.ts`는 이 표시가
있으면 생존 후 증가를 건너뛴다. 이후 `pass-challenge.ts`는 추가 증가 없이 현재 count로
벌칙에 진입한다. 따라서 다음 FOLD도 count=1인 두 번째 룰렛이다.

수정 전 local compiled Functions를 사용하는 실제 callable probe에서
LIAR 실패→prepare→resolve(safe)→FOLD→prepare를 재현했다:

```text
firstCount=1, firstSections=15, afterSurvival=1,
nextFoldCount=1, nextFoldSections=15
```

`node --test build/device-test/lp-1545-fold/current-flow-probe.mjs`:
PASS / exit 0 / 1개. 이는 현재 현상 재현이며 수정 검증이 아니다.
probe 초기 모듈 경로 오류(exit 1)는 ignored 조사 스크립트에서 수정했다.
이전 디바이스 로그를 새 15:45 테스트 근거로 쓰지 않았으며, 이번 기기 로그·운영 로그·RTDB는
수집/조회하지 않았다. 테스트 결과는 사용자 보고, 횟수 처리 근거는 로컬 코드/probe다.

## 사용자 확인 규칙과 수정

사용자가 다음 규칙을 확인했다. 기본 간파 실패는 1→2→3단계, 잔여카드 보유자가 혼자인
LIAR 실패는 기본 단계에 한 단계 추가, FOLD는 기본 경로처럼 다음 단계를 사용한다.
따라서 첫 벌칙이 FOLD면 1단계이며, 첫 마지막 카드 LIAR 실패는 2단계 → 생존 → 다음
FOLD는 3단계다. 3단계 이후에도 룰렛 종류/확률은 최종 단계로 유지한다.

`finish-penalty.ts`의 생존 처리에서 선행 상승 표시와 관계없이 다음 벌칙을 위한 count를
한 번 올린다. 마지막 카드 LIAR 실패의 추가 상승과 생존 뒤 다음 단계 상승은 별도다.
기존 operation ledger가 중복 확정 요청의 재적용을 막는다. 선행 상승 필드/공개 데이터
형태/함수 이름을 제거하거나 바꾸지 않았다. `call-liar.ts`는 이번 후속에서 설명 주석만
바꿨다. FOLD 진입 코드와 기존 1·2·3단계 추첨 확률은 그대로다.

## 관련 검증

사용자 규칙 확인 후 실제 callable 흐름의 기존 회귀를 확장했다. 마지막 카드 LIAR 실패→
2단계 추첨→생존→중복 결과 요청→FOLD→3단계 추첨, 직접/타임아웃 FOLD의
1→2→3→3단계, 결과 요청 재전송 시 횟수 보존을 검사한다.

| 실행 | status / exit | 결과 |
| --- | --- | --- |
| 수정 전 `node --test functions/test/roulette-restart-integration.test.mjs` | FAIL / 1 | 15개 중 14 PASS, 생존 뒤 count 기대 2/실제 1 |
| `npm run build` (functions/) | PASS / 0 | TypeScript 컴파일 |
| `node --test functions/test/liars-poker-*.test.mjs functions/test/roulette-restart-integration.test.mjs` (PowerShell 파일 목록 확장) | PASS / 0 | 45/45, skip 0 |
| `node node_modules/eslint/bin/eslint.js src/liars-poker/finish-penalty.ts src/liars-poker/call-liar.ts` (functions/) | PASS / 0 | 수정 서버 파일 |
| `git diff --check` | PASS / 0 | 공백 오류 없음 |

실행 출력은 ignored `build/device-test/lp-1545-fold/{before,build,after,lint}.txt`에 있다.
FULL은 사용자 지시로 보류하며 관련 검사가 FULL을 대체하지 않는다. Flutter/APK 변경이 없어
이번 후속에서 Flutter 검사를 반복하지 않았다. 수정 후 실기기 결과는 아직 없다.

## 작업 트리와 인계

branch `codex/e01-validation-wiring`, HEAD `37c1afae5da46b9572058ee7ba132bc740401c1c`.
착수 modified 14 / untracked 1 / staged 0이며 직전 후보 변경을 모두 보존한다.
착수 hash/status와 probe는 ignored `build/device-test/lp-1545-fold/`에 저장했다.
최종 modified 15 / untracked 2 / staged 0이며 branch/HEAD는 동일하다. 기존 변경 경로의
hash 비교에서 이번 회귀·주석·작업 기록 외에는 바뀌지 않았고, 새 서버 파일과 새 보고서
외에 예상하지 못한 tracked/unignored mutation은 없다. `final-state.json`에 비교를 남겼다.
이번 후속 제품 변경은 위 서버 생존 처리 한 곳과 주석이며, 회귀/작업 기록을 갱신했다.
FULL·APK 빌드·운영 조회·배포·commit/push는 실행하지 않았다.

사용자는 VS Code에서 저장소 루트 터미널로 기존 함수 하나만 업데이트한다:

```powershell
firebase deploy --project project0000-ec01e --only "functions:game_liars_poker_resolve_penalty"
```

Firebase 설정의 functions predeploy가 lint/build를 수행한다. 이번 후속에서 다른 함수 배포는
필요 없다. 현재 설치된 APK로 새 게임을 시작해 아래를 확인한다.

1. 첫 벌칙 FOLD → 1단계, 생존 후 다음 FOLD → 2단계, 다시 생존 후 → 3단계.
2. 잔여카드 보유자가 혼자인 첫 LIAR 실패 → 2단계, 생존 후 다음 FOLD → 3단계.
3. 타임아웃 자동 FOLD도 같은 순서이며 이후 룰렛은 3단계를 유지한다.

첫 카드 갱신 안내는 사용자 관찰로만 남겼으며 이번 FOLD 수정의 범위를 확장하지 않았다.
