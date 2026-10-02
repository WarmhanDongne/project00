# 게임 안정성 후속 TODO

## 마피아 화면 보강 후 남는 외부 작업 (2026-10-01)

아래는 기록만 했으며 `lib/`, `functions/`, 루트 테스트/문서는 변경하지 않았습니다.

- [ ] `functions/src/game-interruption/state.ts`: 다중 이탈을 보존하고 복구/제외 후 전체 참가자 재검사.
- [ ] `lib/platform/home/room/providers/room_provider.dart`, `services/room_service.dart`:
  transport 복구 후 최신 public/private의 동일 게임·라운드 확인 및 끊긴 구독 재개.
  패키지의 역할 데이터 대기는 초기 null만 막으며 stale private의 epoch를 입증하지 않습니다.
- [ ] `lib/platform/home/phone/screens/phone_room_waiting.dart`: 플랫폼/게임의 네트워크 가드
  중복 구독·복구 요청을 한 경계로 통합. 플랫폼의 즉시 route 종료가 마피아 종료 안내를
  먼저 닫을 수 있으므로 종료 안내가 끝난 뒤의 화면 이동 계약도 맞출 것.
- [ ] `functions/src/mafia/`와 controller pause 계약: 발표 시작 시각·일시 중단 누적 시간으로
  강제 종료 후에도 기기 간 정확한 연출 위치를 복원. 이번 패키지 시계는 살아 있는 화면의
  중단/백그라운드/transport 단절만 정지·재개하며 서버 시간을 새로 결정하지 않습니다.
- [ ] 서버 조사 결과의 확정 시점/행동 차단 정합성: 클라이언트는 받은 결과만 표시하며
  차단·변환·능력 성공 여부를 추측해 새 정보를 공개하지 않습니다.

마피아 수동 확인: 역할 확인 전/후, 밤의 각 세부 구간, 조사 결과, 아침 사망/취재,
투표 전송, 개표, 처형, 결과에서 1/10/60초 단절·백그라운드·복귀를 확인할 것.
4/12명, 긴 닉네임, 작은 휴대폰/태블릿 비율, 관전·다시하기도 실기기 검증 필요.

기준: 2026-10-01 / `jinsung/refactor-code-review`, 작업 시작 HEAD `1bb3e005`.
이번 작업은 `packages/`만 수정합니다. 아래 외부 작업은 **기록만 했으며 구현·배포하지 않았습니다.**
공식 계획의 `docs/planning/TASKS.md` → `SESSION-RECONNECT-02`와 관련된 후속 메모입니다.
팀원과 범위를 합의한 뒤 공식 계획에 병합하세요. 해당 문서 자체는 수정하지 않았습니다.

## 패키지 밖 수정 필요 — 별도 승인·협업 필요

- [ ] **분배 중·빈 손패·관전 상태의 앱 재실행 복구**
  - 파일: `lib/platform/home/room/services/room_common.dart`, `room_service.dart`.
  - 개인 데이터 존재 여부 대신 서버 참가 자격, room/game 상태로 복구 판정.
  - pendingHands 사용 중 private가 비어도 저장 세션을 지우지 않기.
  - 검증: 두 카드 게임의 분배 중 강제 종료, 빈 손패, 탈락 관전자 재실행.

- [ ] **동시에 여러 명이 끊긴 경우의 중단 관리**
  - 파일: `functions/src/game-interruption/state.ts`, `functions.ts` 및 관련 resolution 파일.
  - 첫 중단 중 발생한 추가 이탈을 보존하고 복귀·제외마다 전체 참가자를 재검사.
  - 단순 인원뿐 아니라 Final Call 2대2 등 게임별 계속 가능 조건도 재검사.
  - 검증: A 단절 → B 단절 → A 복귀/제외, controller 단절 중첩.
  - 서버 상태 계약 변경과 Functions 배포는 별도 승인 대상.

- [ ] **연결 표시 복구와 실제 게임 복구 완료를 연결**
  - 파일: `lib/platform/home/room/providers/room_provider.dart`,
    `lib/platform/home/room/services/room_service.dart`, `lib/platform/home/tablet/`의 복원 진입부.
  - transport → 인증·참가 자격 확인 → presence → 공개/개인 구독 복원 →
    최신 게임·손패 준비 → 입력 허용 순서로 복구 완료를 판정.
  - 권한 오류로 취소된 구독 재개, 태블릿 최초 오프라인 복구 실패 후 재시도 포함.
  - 패키지에서도 후속 배선이 필요하지만 외부 복구 계약 없이 임의 재가입하지 않기.

- [ ] **방 삭제·강퇴의 서버 확인 경로**
  - 파일: 위 room provider/service, 필요하면 `functions/src/room/`의 상태 확인 callable.
  - permission-denied만으로 종료하지 말고 실제 방 종료·참가 자격 상실과 인증 오류 구분.
  - 이번 패키지 수정은 오래된 조회 결과 무시와 권한 오류 시 상태 보존까지만 수행.
  - RTDB get의 빈 값만으로 실제 삭제를 확정하는 기존 경로와 장기 권한 오류 후
    퇴장 UX는 서버 확인 계약과 함께 보완할 것.

- [ ] **이미 전송된 옛 진행 요청을 새 판에서 차단**
  - 파일: `functions/src/final-call/complete-dealing.ts`, 결과 공개/라운드 전환 함수,
    `functions/src/liars-poker/complete-dealing.ts`, `ready-turn.ts`, `functions/src/mafia/night.ts` 등.
  - 현재 클라이언트는 새 판/단계가 되면 후속 재전송을 중단하지만 이미 전송한
    callable 자체는 취소할 수 없음. 기대 game instance/phase/round를 서버에서도 검사.
  - 이전 앱 호환성, commandId 재사용·중복 처리 범위까지 설계 후 적용.

- [ ] **게임 중 입력이 없는 경우의 서버 진행 백스톱 검토**
  - 파일: `functions/src/mafia/`, `functions/src/final-call/` 및 예약 작업 관련 파일.
  - 태블릿 일시 정지·종료 중 타임아웃 처리 주체와 방 보존 정책을 함께 결정.
  - 기존 일시 대기·남은 시간 보존 규칙을 클라이언트 최적화 명목으로 바꾸지 않기.

- [ ] **패키지 회귀 테스트를 공식 검증 경로에서 실행**
  - 확인 파일: `tool/mosigame_cli/`의 test/validate 선택 로직, CI workflow.
  - `packages/game_kit/test/`가 FULL/CI에 포함되는지 확인하고 누락 시 추가.
  - 기존 테스트를 삭제/약화하지 않기. 이번 작업에서는 외부 검증 코드를 수정하지 않음.
  - 이번 실행: `dart run :mosigame test session`은
    `test/controller_presence_test.dart` 누락으로 INVALID(exit 2).
    세션 suite가 요구하는 기존 테스트 파일 복구/정합성 점검은 패키지 밖 작업.

## 패키지 안 후속 최적화 — 이번에는 보류

- [ ] 이미지 디코딩 크기·캐시: `game_kit/lib/core/assets/game_image.dart`에서
  표시 크기·DPR·확대 연출을 반영한 ResizeImage/cacheWidth 정책을 정하고 사전 로딩과
  실제 렌더링의 캐시 키를 일치시키기. FC의 모든 카드 선로딩도 함께 측정.
- [ ] 숨겨진 화면: `game_kit/lib/game_flow/phone_game_shell.dart`에서 장식 Ticker만
  정지. 완료 콜백으로 서버 진행을 알리는 연출은 일괄 TickerMode(false) 금지.
- [ ] 공통 에셋: 동일 해시의 아이콘·효과음 통합은 생성 파일/등록 경로 영향 확인 후 진행.
- [ ] Flow Config 전체 단계의 Delay·ON/OFF 연결 검사. 이번에는 공용 카드 분배의
  beforeDelay/afterDelay 연결을 수정했으며 모든 단계가 자동 실행 엔진인 것은 아님.
- [ ] 원격 통신·메뉴·선택 상태 변화 시 전체 Board 리빌드 비용을 profile 모드로 측정한 뒤
  selector/위젯 분리 적용. 측정 없이 전체 상태 구조를 바꾸지 않기.

## 수동 검증

- [ ] LP/FC: 첫 라운드는 탭 시작, 다음 라운드는 자동 분배, 실패 시 연출 반복 없이 완료 요청 재시도.
- [ ] FC: 1라운드 결과 후 2라운드에서 다시하기, 분배 중 다시하기, 최종 공개 중 연결 단절.
- [ ] Mafia: 밤 행동 미제출로 첫 시간 초과 발생 후 support/wrapUp을 거쳐 아침 도달.
- [ ] 세 게임: 짧은/긴 단절, 앱 재실행, 동시 이탈, 중단 해제 뒤 남은 시간 보존.
- [ ] 실제 Android/iOS 휴대폰·태블릿에서 반복 재시작 및 게임 변경 후 메모리·프레임 측정.

서버/플랫폼 후속 작업을 하지 않았으므로 위 장애 상황 전체가 해결됐다고 판단하지 마세요.

## 앞선 공용 안정성 작업 기록 — 마피아 화면 보강 전

- 공용 `GameProgressCommand`: 같은 판·라운드·단계의 완료 알림만 재시도하고
  새 판/단계/화면 종료 시 옛 재시도를 무효화. 서버 게임 규칙과 callable 이름은 유지.
- Mafia: 밤 세부 단계와 마감 시각을 중복 진행 키에 포함.
- Final Call: 분배/최종 공개 완료 재시도, 다시하기 시 완료 표시·타이머 초기화,
  분배 위젯 키에 startedAt 포함, 휴대폰 초기 연출 상태도 새 판 기준으로 초기화.
- Liar's Poker: 분배 서버 확인 뒤 다음 연출 진입, 첫 턴 시작 실패 후 재시도.
- 공용 구독: 늦은 삭제 확인 무시, 같은 판의 낡은 revision 무시, 권한 오류만으로
  종료하지 않기. 새 판의 DTO 값이 같아도 화면에 초기화 알림 전달.
- 공용 분배: beforeDelay/afterDelay 적용, 중복 탭 방지. 첫 판 탭/후속 판 자동 시작 유지.
- 에셋: FC 기기별 배경/레이아웃 사전 로딩 분리, 세 게임에서 로딩 도중 화면 종료 확인.
- 테스트: 신규 15개. 기존 네트워크 테스트 3개는 비동기 복구의 다음 렌더링 프레임을
  기다린 후 입력 차단 해제를 직접 검증하도록 보강(앱 대기시간·기대값 변경 없음).

최종 후보 자동 검증:

| 명령 | 결과 | exit |
| --- | --- | --- |
| `dart analyze packages` | PASS, No issues found | 0 |
| `flutter test --no-pub packages/game_kit/test test/game_board_structure_test.dart test/liars_poker_card_value_test.dart test/tablet_room_reset_test.dart` | PASS, 44 tests | 0 |
| `git diff --check` | PASS | 0 |
| `dart run :mosigame test session` | INVALID, 기존 `test/controller_presence_test.dart` 누락 | 2 |
| `flutter analyze --no-pub packages` | 분석기 한글 경로 LSP FormatException; 위 Dart 분석으로 별도 확인 | 255 |
| `dart run :mosigame validate --full` | 사용자 승인 전, 미실행 | — |

작업 시작 시 staged/unstaged/untracked 변경 없음. 작업 종료 후보는 수정 15개·신규 5개
모두 `packages/` 내부이며 패키지 밖 tracked/untracked 변경 없음. 브랜치/HEAD 유지,
stage/commit/push/배포 없음. 실기기 및 운영 Firebase 검증은 실행하지 않음.

`Mosigame Implement and Validate` 절차에 따라 FULL은 별도 승인 뒤 실행합니다.
위 targeted 검사 통과를 FULL 또는 출시 검증 완료로 해석하지 않습니다.

## 마피아 화면 보강 후보 및 검증 기록 (2026-10-01)

- 공용 연출 시계: 네트워크·백그라운드·게임 중단이 겹쳐도 모든 원인이 해소된 뒤
  남은 타이머/주요 발표 애니메이션을 재개. 서버 deadline은 변경하지 않음.
- 아침·개표·처형의 휴대폰/태블릿 발표 순서와 유지 시간을 공통 설정으로 정리.
  마지막 발표는 다음 서버 상태까지 유지. 자신의 사망 발표 뒤 관전 전환.
- 역할 데이터 준비 대기, 밤 행동 대기 사유, 투표 전송/시간 만료, 조사 기록 재확인,
  요청 실패 안내 및 역할 확인 재시도 추가. 개인 조사 결과는 휴대폰에서만 표시.
- 역할 배치 요청 예외 후 버튼 복구, 요청 중 구성 변경/취소와 시작 중복 방지.
- 연결 대기가 길면 재연결/나가기 표시. 비정상 종료 안내 3초 후 이동 예약.
  플랫폼의 기존 화면 이동이 이를 앞서 실행하는 문제는 외부 TODO로 남김.
- 게임 결과를 결정하거나 서버 phase를 추측하여 변경하는 로직은 추가하지 않음.

검증 명령은 위 저장소의 Flutter SDK로 실행했고, 패키지 설치 없이 검사했습니다.

| 명령 | 결과 | exit |
| --- | --- | --- |
| `dart analyze packages` | PASS, No issues found | 0 |
| `flutter test --no-pub --timeout 45s packages/game_kit/test test/game_board_structure_test.dart test/liars_poker_card_value_test.dart test/tablet_room_reset_test.dart` | PASS, 50 tests (연출/요청 안내 신규 6개 포함) | 0 |
| `git diff --check` | PASS | 0 |
| `git status --porcelain=v1 --untracked-files=all -- . ':!packages'` | 출력 없음: 패키지 밖 변경 없음 | 0 |
| `dart run :mosigame validate --full` | 별도 사용자 승인 전, 미실행 | — |

현재 보강 시작 때 기존 수정 15개·신규 파일 5개가 있었으며 이를 보존해 작업했습니다.
브랜치 `jinsung/refactor-code-review`, HEAD `1bb3e00508030711bb08f4376940a352a9f1ed3e` 유지.
stage/commit/push/배포 없음. 마피아 전용 `flutter_test` 의존성 추가는 승인 대기 중으로
아직 변경하지 않았으며 마피아 전용 신규 화면 테스트와 실기기 검증은 미실행입니다.
주요 발표 연출의 중단을 다뤘으며 달·새 같은 모든 장식 애니메이션 정지를 뜻하지 않습니다.
이 기록은 FULL/실기기/모든 장애 경우 검증 완료를 뜻하지 않습니다.
