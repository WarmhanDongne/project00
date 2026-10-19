# LOCAL-EMULATOR-01
로컬 Firebase 개발환경과 서버 전환

[작업 목록](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

## 요청과 범위

2026-10-15 사용자는 로컬 에뮬레이터 개발환경 구성, Firebase 서버와 간편한 전환,
새 브랜치 `local_emulator`에서의 진행을 요청했다. 깨끗한 `develop`
`b921f53bfb73c4b5f37c883d4285e1bb9ffcf393`에서 브랜치를 생성했다.

기존 E13 데모 런타임을 재사용하고 앱 전체의 Firebase 선택을 일관되게 연결한다.
로컬 테스트 계정·카탈로그, 관리 UI, 저장/복원, 문서와 회귀 검사를 포함한다.
운영 접근·배포·의존성 추가·게임 규칙/데이터 계약 변경·실기기 다중 조작 자동화는 제외한다.

## 구현과 근거

- [사용 방법](../../development/LOCAL_FIREBASE.md)이 실행과 전환의 단일 원본이다.
- named demo app으로 서버 Firebase 인증/캐시를 분리하고 모든 기존 direct instance
  접근을 선택된 앱으로 연결한다. 서버 기본 동작과 서비스 DI는 보존한다.
- E13 어댑터의 기존 리전/프로젝트 거절 검사를 재사용한다. 운영 Functions 소스는 변경하지 않는다.
- 개발환경 audit의 이전 Firebase options 경로를 현재 game_kit 경로로 보정했다.

## 완료 조건과 검증

관련 Dart 분석, 서버/로컬 선택 회귀, auth/session suite, 로컬 통합 검사,
iOS 시뮬레이터 실행은 통과했다. 남은 사용자 승인 FULL 결과까지 남긴다. Android 실기기와
클라우드 성능·소셜 로그인·Cloud Scheduler는 별도 확인 범위다.
검증 과정과 한계는 [월별 기록](../logs/2026-10.md#local-emulator-20261015)에 기록한다.
