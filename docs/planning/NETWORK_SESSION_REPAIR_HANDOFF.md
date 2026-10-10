# 라이어스포커 룰렛·재시작 오류 수정 인계

2026-10-10 KST. 새 채팅/계정에서 이전 대화 없이 재개하기 위한 인계다.
현재 작업의 원본은 [TASKS](TASKS.md), 기술 근거는 현재 코드와
[상세 조사](NETWORK_SESSION_STARTUP_INVESTIGATION.md#roulette-restart-investigation)다.

## 사용자의 최신 요청

정상 게임 시작은 성공했고 기존 준비창·게임 데이터 문제는 없어졌다. 그러나 네트워크를
고의로 끊지 않은 LP 룰렛 결과 반영이 실패했다. 설정에서 게임 종료는 정상 동작했다.
로비에서 휴대폰 A의 인터넷 단절 시험도 기대대로 동작했다. 이후 다시 LP를 시작해 자리
설정 완료를 누르자 이미 게임이 진행 중이라는 오류가 났다.

사용자는 **새 채팅에서 원인 파악 → 해결 방법 설계 → 설계 후 실행**을 명시적으로 요청했다.
기존 근거를 재확인하고 설계 내용을 기록한 뒤 요청 범위의 구현·회귀 검증으로 이어간다.
조사나 설계 설명만 하고 끝내지 않는다. 이번 인계 채팅에서는 이 새 결함의 제품 코드를
수정하지 않았다. 다음 채팅이 작업을 소유하며 부모 채팅은 같은 소스를 병행 수정하지 않는다.

이전 버전 전체 복귀는 승인되지 않았다. 현재 코드를 보수하고 공통 통신 변경과 게임별
연결을 점검하는 방향을 설명했다. 무관한 새 기능/전체 재작성은 요청 범위가 아니다.

## 첫 행동과 Git 기준

1. root AGENTS.md와 [Engineering Contract](../engineering/ENGINEERING_CONTRACT.md)를 읽는다.
2. [Architecture](../engineering/ARCHITECTURE.md),
   [Network Session Contract](../engineering/NETWORK_SESSION_CONTRACT.md),
   [Project CLI](../engineering/PROJECT_CLI.md), 상세 조사의 마지막 두 절을 읽는다.
3. 수정에는 [Mosigame Implement and Validate](../../.agents/skills/mosigame-implement-and-validate/SKILL.md)를 적용한다.
   이미 요청된 범위는 진행하고 별도의 명시 승인 경계에서만 근거·영향을 구체화해 확인한다.
4. branch/HEAD/staged/unstaged/untracked를 다시 확인하고 기존 변경을 보존한다.

인계 직전 branch는 `codex/e01-validation-wiring`, HEAD는
`e787a10de8723d66b08c84b173a07ddbf267b113` (`feat: 10.10 작업 사항 푸시`)다.
이전 UI/시작 수정과 회귀·조사 문서 33개 경로가 이 커밋에 포함됐다.
인계 작성 전 working tree는 clean/staged 없음이었다. 로컬 upstream 추적 ref
`origin/codex/e01-validation-wiring`과 0/0이며 이번 인계에서 원격 fetch/조회는 하지 않았다.
과거 조사에 적힌 ad2ace7의 dirty tree를 현재 상태로 오인하지 않는다.
이 인계와 링크/일지 수정은 후속 로컬 변경이며 별도 commit/push는 실행하지 않았다.

같은 PC의 새 계정/채팅에서는 같은 프로젝트 디렉터리를 열면 된다. 다른 clone에는 로컬
미커밋 문서와 ignored build 자료가 없을 수 있다. 이때 e787a10에 포함된 상세 조사부터 읽는다.
credential/인증 파일을 복사하지 않는다.

## 보존할 해결 사항

- 정상 준비·카드 배분은 기존 배경/연출을 유지한다. 별도 준비 오류창/추가 퇴장 버튼을 만들지 않는다.
- 실제 실패는 기존 안내 UI, 나가기는 기존 메뉴를 쓴다. 서버 준비 barrier와 canSend 보호는 유지한다.
- 이전 수정: RoomProvider heartbeat의 만료 복구 Zone 분리, 최초/후속 준비 예산,
  LP dealing 중 public 데이터로 에셋 준비 허용, 진단 창 Overlay, 정상 준비/실제 오류 UI 분리.
- 사용자 확인은 정상 진입·준비 UI 해소·로비 A 단절 대응이다. 4게임/E14 전체 PASS가 아니다.

## 확인한 결함과 설계 쟁점

| 경계 | 확인 사항 |
| --- | --- |
| 룰렛 두 단계 ID | preparePenalty의 commandId를 resolutionId로 보관하고 resolvePenalty commandId에도 재사용한다. 공통 sessionOperations는 다른 kind/payload의 동일 ID를 permission-denied로 거부한다. 실제 callable로 재현했다. |
| 앱만 수정하면 불충분 | 서버 finish-penalty.ts가 resolutionId === commandId를 요구한다. 요청 ID와 추첨 ID의 관계를 함께 설계하고 동일 결과의 재생/한 번만 적용/재추첨 방지를 유지해야 한다. |
| 시작 비교에 heartbeat 포함 | startGameFingerprint가 players 전체를 비교해 lastSeen만 달라도 aborted가 난다. 정상 접속 갱신을 명단·좌석·게임 선택 변경과 구분하면서 중요한 변경 보호는 유지해야 한다. |
| transaction 재실행 예외 | runPrimedTransaction에는 update 예외를 저장하고 안전하게 abort한 뒤 밖에서 전달하는 처리가 없다. 설치 RTDB SDK의 rerun update가 throw하면 완료 callback/rollback/queue 정리에 도달하지 않는 경로를 고립 재현했다. 실제 SDK 경합 회귀가 필요하다. |
| 미확정 시작 요청 수명 | LiarsPokerGame.startGame은 매번 새 service를 만들고 _unresolved는 인스턴스 필드다. 자리 설정의 재시도가 기존 요청 조회/동일 ID 재생 대신 새 ID로 요청한다. timeout은 서버 취소가 아니므로 시작 의도와 ID를 올바른 수명으로 보존해야 한다. |

단순 timeout 연장, already-exists 무조건 성공 처리, 진행 중 게임 덮어쓰기로 대체하지 않는다.
공통 경계 수정 시 Final Call·Mafia·Holdem의 관련 소비자 영향도 함께 확인한다.

기기/서버 확인 사실(2026-10-09 KST):

- 21:54:31 추첨 성공. 21:54:38/21:54:57/21:55:18 반영 permission-denied.
- 21:56:32 end_game 성공, 양 기기 finished 수신. 이전 게임 종료 실패를 원인으로 보지 않는다.
- 21:58:15 새 시작 요청, 앱 8초 timeout, 후속 already-exists. 서버 첫 요청은 약 60초 뒤
  HTTP 504이며 후속 두 요청은 HTTP 409다.
- 같은 service에서 `Exception from a finished function`과 좌석/참가자 변경 예외가 기록됐다.
  예외 execution_id는 현재 요청 verification과 다르며 실제 callback 귀속/변경 필드는 미확정이다.
- App Check 경고는 enforcement disabled로 허용됐다. 직접 원인으로 단정하지 않는다.
- production DB commit 여부는 확인하지 않았다. 서버 로컬 미완료 상태와 실제 commit을 구분한다.

## 코드 진입점

- [LP command](../../packages/game_liars_poker/lib/shared/services/command_service.dart),
  [penalty coordinator](../../packages/game_liars_poker/lib/shared/providers/penalty_coordinator.dart),
  [LP 시작](../../packages/game_liars_poker/lib/game_liars_poker.dart)
- [공통 command](../../packages/game_kit/lib/services/game_command_service.dart),
  [retry](../../packages/game_kit/lib/recovery/services/callable_retry_policy.dart),
  [tablet launcher](../../lib/platform/home/tablet/tablet_game_launcher.dart)
- [룰렛 서버](../../functions/src/liars-poker/finish-penalty.ts),
  [시작 서버](../../functions/src/liars-poker/start-game.ts),
  [시작 비교](../../functions/src/common/start-game-transaction.ts)
- [transaction](../../functions/src/room/room-transaction.ts),
  [공통 command transaction](../../functions/src/game-interruption/game-command-transaction.ts),
  [ledger/presence](../../functions/src/room/session-contract.ts)

## 검증 근거와 다음 검사

이전 UI 후보는 2026-10-09 21:37 KST 승인 FULL에서 12/12 PASS/exit 0이다.
앱 337, game_kit 77, LP 5, Final Call 14, Mafia 55, Holdem 31, Functions 371;
분석/포맷/lint/mutation PASS다. 현재 발견된 통합 경로는 사각지대였으므로 이 결과를
새 수정 후보의 FULL이나 실제 기기 전체 통과로 재사용하지 않는다.

원인 조사에서는 tsc와 ignored roulette-restart-probe.cjs를 실행했다. 최종 probe 7개 판정은
결함 재현 5개/정상 비교 2개, exit 0이다. 실제 callable .run + 메모리 RTDB와 SDK rerun
본문의 VM 고립 실행이다. emulator 검증/결함 수정 완료를 뜻하지 않는다.

후속 회귀는 prepare→resolve 전체 연결, 응답 유실·중복 확정의 한 번만 적용, 재추첨 방지,
정상 heartbeat와 실제 명단/좌석 변경 구분, 실제 SDK 비동기 예외의 완료/rollback,
시작 응답 유실 뒤 UI 재시도의 ID 보존을 우선한다. 공통 코드 변경이 다른 3게임의
시작→진행→종료→재시작에 미치는 영향은 범위를 한정해 함께 점검한다.

```powershell
.\tool\invoke_mosigame.ps1 test session --json
.\tool\invoke_mosigame.ps1 validate --full --json
```

Windows canonical 경로와 Skill의 최종 후보 FULL 승인 절차를 따른다. 과거 “검증해”는
이전 후보에 이미 사용했다. 검증 중 자동 수정/테스트 약화는 하지 않는다.
최신 APK hash/설치 버전은 별도로 확인한다. 옛 인계의 APK hash를 최신으로 간주하지 않는다.

## 로그 접근과 로컬 근거

[Firebase Server Logs](../operations/FIREBASE_SERVER_LOGS.md)와 AGENTS를 따른다.
일반 로그는 기존 roles/logging.viewer로 조회 성공했다. 추가 IAM 권한은 필요하지 않았다.
configuration은 mosigame-logs-readonly, project는 project0000-ec01e다. gcloud는 PATH에
없었지만 설치돼 있었다. Windows launcher의 filter 따옴표 문제가 있으면 같은 SDK의
bundled Python `-S lib/gcloud.py`로 정상 동작했다. SDK/인증 파일은 수정하지 않았다.
기존 service는 game-liars-poker-start-game, region은 asia-northeast3, 조회 시간은
2026-10-09T12:58:10Z 이상 13:00:20Z 미만이다. 저장 근거부터 읽고 조회를 반복하지 않는다.
새 환경 로그인/계정 역할 확인 및 새 조회 범위는 정해진 절차를 따른다.

같은 workspace의 ignored 자료:

```text
build/network-session-investigation/ui-full-approved-result.json
build/network-session-investigation/roulette-restart-probe.cjs
build/network-session-investigation/roulette-restart-20261009-220548/
build/network-session-investigation/roulette-restart-tablet-20261009-220658/
build/device-test/start-game-log-metadata-probe.json
build/device-test/start-game-request-metadata.json
build/device-test/start-game-errors-sanitized.json
build/device-test/start-game-error-classification.json
build/device-test/start-game-fingerprint-error.json
```

서버 authoritative 원칙을 유지한다. 새 production 쓰기/배포/migration/DB 전체 조회는
인계 요청에 포함되지 않는다. 기존 사용자의 구버전 호환 불필요 결정이 계약 변경의 소비자/
배포 영향 검토를 생략하는 뜻은 아니다.

## 새 계정에서 붙여 넣을 요청

> docs/planning/NETWORK_SESSION_REPAIR_HANDOFF.md와 AGENTS.md를 읽고 이어가줘.
> 정상 진입은 해결됐고 LP 룰렛 반영 실패와 재시작 already-exists가 남아 있어.
> 저장된 기기/서버 로그와 재현을 먼저 확인한 뒤 원인 재확인 → 해결 설계 → 구현·회귀 검증을 진행해.
> 기존 UI 개선을 보존하고 공통 통신 변경이 4게임에 미치는 영향도 점검해.
> 이미 요청한 범위는 계속 진행하고 계약 변경·새 production 접근/배포·최종 FULL 등은 저장소 규칙에 따라 처리해.
