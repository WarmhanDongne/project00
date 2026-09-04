# Mosigame documentation

이 디렉터리는 사람이 읽는 tracked canonical 문서를 역할별로 관리한다. 에이전트의
저장소 진입점과 작업별 문서 라우팅은 루트 [`AGENTS.md`](../AGENTS.md)가 담당하고,
실행 가능한 Skill과 metadata는 `.agents/`에 둔다.

## Engineering

- [`Engineering Contract`](engineering/ENGINEERING_CONTRACT.md)
- [`Architecture Reference`](engineering/ARCHITECTURE.md)
- [`Project CLI`](engineering/PROJECT_CLI.md)

## Development

- [`Agent Setup`](development/AGENT_SETUP.md)
- [`Development Setup`](development/DEVELOPMENT_SETUP.md)
- [`Development Environment Plan`](development/DEVELOPMENT_ENVIRONMENT_PLAN.md)

## Operations

- [`Firebase MCP RTDB Read-only Pilot`](operations/FIREBASE_MCP.md)
- [`Emulator Pilot`](operations/EMULATOR_PILOT.md)
- [`Auth/Network/Session Technical Reference`](operations/AUTH_NETWORK_SESSION_TECHNICAL_REFERENCE.md)
- [`Real-device Auth/Network/Session Checklist`](operations/REAL_DEVICE_AUTH_NETWORK_SESSION_CHECKLIST.md)
- [`User Auth/Network/Session Guide`](operations/USER_AUTH_NETWORK_SESSION_GUIDE.md)

## Planning

- [`작업 목록`](planning/TASKS.md): 출시 전 필수·권장·출시 후 작업, 현재 상태와 완료 조건
- [`완료 작업`](planning/COMPLETED_TASKS.md): 최종 변경, 완료일, 검증 근거와 한계
- [`월별 작업 기록`](planning/logs/): 월별 파일 안에서 태스크별 과정과 날짜별 목차 관리
  — [2026년 8월](planning/logs/2026-08.md)

진행 과정은 기록에, 현재 구현 설명은 Engineering/Operations의 해당 기술 문서에 둔다.
문서 작성·이동과 상태 관리 방법은 작업 목록의 관리 방법을 따른다.
