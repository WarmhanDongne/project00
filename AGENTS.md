# Mosigame repository guide

작업을 시작하기 전에 반드시 [`ENGINEERING_CONTRACT.md`](docs/engineering/ENGINEERING_CONTRACT.md)를
읽고 따른다. 이 파일은 규칙 전체를 복제하지 않고 필요한 tracked context로 안내하는
router다.

## What to read

| 작업 | 추가로 읽을 문서와 코드 |
| --- | --- |
| 모든 작업 | [`Engineering Contract`](docs/engineering/ENGINEERING_CONTRACT.md) |
| 개발환경 점검·설정 | [`Agent Setup`](docs/development/AGENT_SETUP.md), [`Development Setup`](docs/development/DEVELOPMENT_SETUP.md), [`Development Environment Plan`](docs/development/DEVELOPMENT_ENVIRONMENT_PLAN.md) |
| 구조, 게임, 플랫폼, Firebase, auth/session | [`Architecture Reference`](docs/engineering/ARCHITECTURE.md)와 관련 코드·테스트 |
| 새 게임 | [`게임 템플릿 가이드`](lib/games/_game_template/README.md), 가장 가까운 기존 게임, `functions/src/<game>/` |
| Project CLI | [`Project CLI`](docs/engineering/PROJECT_CLI.md), `bin/mosigame.dart`, `tool/mosigame_cli/`, `test/mosigame_cli/` |
| 작업 계획·진행·완료·기록 정리 | [`작업 목록과 관리 방법`](docs/planning/TASKS.md), [`완료 작업`](docs/planning/COMPLETED_TASKS.md), 해당 월의 [`작업 기록`](docs/planning/logs/) |

외부 개인 notes나 로컬 절대 경로는 공식 context가 아니다. 문서와 구현이 충돌하거나
제품 의도가 확인되지 않으면 추측하지 말고 evidence와 함께 보고한다. 하위
`AGENTS.md`가 있다면 해당 디렉터리 작업에는 그 지침도 적용한다.

Mosigame 기능 구현 또는 버그 수정의 완료 작업에는
[`Mosigame Implement and Validate`](.agents/skills/mosigame-implement-and-validate/SKILL.md)
Skill을 사용한다. 질문, 조사, 계획, 읽기 전용 검토, 문서 전용 작업 및 Git 전용
작업에는 적용하지 않는다.

## Firebase MCP read-only pilot

Firebase MCP는 [`Firebase MCP RTDB Read-only Pilot`](docs/operations/FIREBASE_MCP.md)의 제한된
수동 테스트 관찰 절차에만 사용한다.

- 실행 전에 사람이 로컬 terminal에서 MCP 전용 계정이 활성 상태이고 그 계정에
  `roles/firebasedatabase.viewer` 이외의 더 넓은 권한이 없는지 확인한다. 계정 식별자나
  CLI 인증 출력은 채팅에 포함하지 않는다.
- 노출 도구는 `firebase_get_project`와 `realtimedatabase_get_data` 두 개여야 한다.
  다르거나 `realtimedatabase_set_data`가 보이면 아무 도구도 호출하지 않는다.
- 먼저 `firebase_get_project`로 project ID `project0000-ec01e`, 이름 `mosigame`, 상태
  `ACTIVE`를 확인한다.
- production RTDB는 사용자가 database URL, 정확한 단일 경로, 필요성을 확인하고
  해당 조회를 사전 승인한 경우에만 한 번 읽는다. root나 상위 collection을 조회하지
  않는다.
- 개인정보, credential, token과 불필요한 사용자 데이터를 요청하거나 출력하지 않는다.
- 쓰기, Auth 접근, project 변경, rules 변경, deploy와 migration은 금지한다.
- MCP 결과는 Project CLI의 targeted suite나 `validate --full`을 대체하지 않는다.

## Validation routing

실행 전 [`PROJECT_CLI.md`](docs/engineering/PROJECT_CLI.md)에서 해당 플랫폼의 실행 경로를 선택한다.
아래 플랫폼 공통 raw 형식은 실행할 command와 argument를 나타낸다. 작업 중 빠른
피드백:

```text
dart run :mosigame test session
dart run :mosigame test auth
```

관련 suite만 실행하며 targeted suite가 FULL validation을 대체하지 않는다. 완료 전:

```text
dart run :mosigame validate --full
```

실행한 command, status, exit code와 실행 전후 working-tree 상태를 보고한다.
Windows guarded invocation과 macOS/Linux raw CLI의 사용 조건은
`docs/engineering/PROJECT_CLI.md`를 따른다.

## Approval routing

새 dependency, public API/persistent data/state-machine contract 변경, production 접근,
deploy/migration, 사용자 변경과의 충돌, 중요한 architecture·제품 결정 또는 범위 밖
수정이 필요하면 중단하고 사용자 승인을 받는다. 전체 조건과 Definition of Done은
Engineering Contract를 따른다.

