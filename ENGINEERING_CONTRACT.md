# Mosigame Engineering Contract

이 문서는 저장소의 모든 작업자가 항상 따라야 하는 최소 공통 계약이다. 특정 도구나
개인 환경에 의존하지 않는다. 세부 구조가 필요할 때는
[`ARCHITECTURE.md`](ARCHITECTURE.md)를 추가로 읽는다.

## Source of truth

우선순위는 현재 코드·테스트·설정, 이 저장소의 tracked canonical 문서 순이다.
외부 메모와 과거 계획은 참고 자료일 뿐이다. 문서와 구현이 다르면 오래된 설명인지,
현재 구현 계약인지, 제품 결정이 필요한 충돌인지 구분한다. 중요한 구조나 제품 의도를
추측해 새 규칙으로 만들지 말고 근거와 함께 보고한다.

## Architecture contract

- Mosigame은 Flutter 클라이언트와 Firebase Functions(Node.js)가 함께 동작하는
  multi-runtime 저장소다.
- 게임 규칙, 턴 검증, 승패 판정, 비공개 정보 이동과 중요한 게임 상태 전이는
  server-authoritative 원칙을 따른다. 클라이언트가 이 책임을 임의로 가져가지 않는다.
- 클라이언트는 callable command로 변경을 요청하고, 허용된 Firebase 데이터를 읽어
  화면 상태로 변환한다. 접속 상태처럼 명시적으로 허용된 플랫폼 쓰기는 보안 규칙과
  기존 서비스 계약 안에서만 유지한다.
- 공개 데이터, 사용자별 비공개 데이터, 서버 전용 데이터의 경계를 보존한다.
- public API, 배포된 callable 이름, persistent data shape 또는 state-machine
  contract를 바꾸기 전에는 하위 호환성과 모든 소비자의 영향 범위를 확인한다.
- 생성 파일을 직접 수정하지 않는다. 생성 원본과 정해진 생성 절차를 사용한다.

## Working-tree safety

- 작업 시작 전에 branch, HEAD, staged/unstaged/untracked 상태를 확인하고 기존 사용자
  변경을 끝까지 보존한다.
- 사용자 변경을 임의로 stash, reset, checkout, restore하거나 정리하지 않는다.
- validation은 상태를 판정하고 evidence를 남기는 작업이다. 검증 도중 source를 자동
  수정하지 않는다.
- Git-ignored build/cache artifact는 도구 실행의 부산물일 수 있다. tracked 또는
  unignored mutation은 실행 전후를 비교하고 원인을 확인한다.
- 테스트를 삭제하거나 약화하거나 건너뛰어 통과 상태를 만들지 않는다.

## Validation workflow

Project CLI를 실행하기 전에 현재 execution environment가 SDK launcher/cache에 필요한
권한과 외부 deadline을 제공하는지 확인한다. Windows에서 이 조건을 호출자가 직접
보장하지 못하면 [`PROJECT_CLI.md`](PROJECT_CLI.md)의 guarded invocation을 사용한다.

관련 작업 중 빠른 피드백에는 다음 targeted suite를 사용한다.

```powershell
.\tool\invoke_mosigame.ps1 test session
.\tool\invoke_mosigame.ps1 test auth
```

작업 완료 판단 전에는 저장소 루트에서 FULL validation을 실행한다.

```powershell
.\tool\invoke_mosigame.ps1 validate --full
```

Targeted suite는 빠른 피드백 수단이며 FULL validation을 대체하지 않는다. `FAIL`은
완료가 아니다. `BLOCKED`는 코드 실패와 구분하여 원인과 미실행 범위를 보고한다.
보고에는 실제 command, 결과 status, exit code를 evidence로 남긴다. Project CLI의
공통 exit code는 성공 `0`, 검증/테스트 실패 `1`, 잘못된 입력 `2`, 환경 부족
`BLOCKED` `3`, CLI 내부 오류 `4`다.

## Definition of Done

다음을 모두 만족해야 완료로 보고할 수 있다.

- 요청 범위가 구현되었다.
- 관련 테스트가 통과했다.
- `dart run :mosigame validate --full`이 통과했다.
- 기존 사용자 변경이 보존되었다.
- 예상하지 못한 tracked/unignored mutation이 없다.
- 변경 파일, 실행 명령, status와 exit code를 포함한 검증 evidence를 보고했다.

실기기, 외부 콘솔 또는 수동 UX 확인이 요구사항의 일부라면 그 결과도 필요하다.
실행하지 못한 검증을 통과했다고 표현하지 않는다.

## Stop and approval conditions

다음 상황에서는 임의로 범위를 넓히지 말고 근거, 영향, 선택지를 제시한 뒤 사용자
판단을 요청한다.

- 새로운 dependency가 필요하다.
- public API, persistent data contract 또는 중요한 state machine을 변경해야 한다.
- production Firebase/DB 접근, deploy 또는 migration이 필요하다.
- 기존 사용자 변경과 충돌한다.
- 중요한 architecture 또는 제품 결정이 필요하다.
- 현재 task 범위 밖의 수정이 필요하다.
- 같은 실패가 반복되어 안전한 다음 조치가 불분명하다.
- validation 환경이 `BLOCKED`다.
- 변경의 안전성을 판단할 근거가 부족하다.
