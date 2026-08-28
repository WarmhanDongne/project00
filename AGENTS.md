# Mosigame repository guide

작업을 시작하기 전에 반드시 [`ENGINEERING_CONTRACT.md`](ENGINEERING_CONTRACT.md)를
읽고 따른다. 이 파일은 규칙 전체를 복제하지 않고 필요한 tracked context로 안내하는
router다.

## What to read

| 작업 | 추가로 읽을 문서와 코드 |
| --- | --- |
| 모든 작업 | [`Engineering Contract`](ENGINEERING_CONTRACT.md) |
| 구조, 게임, 플랫폼, Firebase, auth/session | [`Architecture Reference`](ARCHITECTURE.md)와 관련 코드·테스트 |
| 새 게임 | [`게임 템플릿 가이드`](lib/games/_game_template/README.md), 가장 가까운 기존 게임, `functions/src/<game>/` |
| Project CLI | `bin/mosigame.dart`, `tool/mosigame_cli/`, `test/mosigame_cli/` |

외부 개인 notes나 로컬 절대 경로는 공식 context가 아니다. 문서와 구현이 충돌하거나
제품 의도가 확인되지 않으면 추측하지 말고 evidence와 함께 보고한다. 하위
`AGENTS.md`가 있다면 해당 디렉터리 작업에는 그 지침도 적용한다.

## Validation routing

작업 중 빠른 피드백:

```bash
dart run :mosigame test session
dart run :mosigame test auth
```

관련 suite만 실행하며 targeted suite가 FULL validation을 대체하지 않는다. 완료 전:

```bash
dart run :mosigame validate --full
```

실행한 command, status, exit code와 실행 전후 working-tree 상태를 보고한다.

## Approval routing

새 dependency, public API/persistent data/state-machine contract 변경, production 접근,
deploy/migration, 사용자 변경과의 충돌, 중요한 architecture·제품 결정 또는 범위 밖
수정이 필요하면 중단하고 사용자 승인을 받는다. 전체 조건과 Definition of Done은
Engineering Contract를 따른다.

