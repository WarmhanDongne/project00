# PACKAGE-MIGRATION-01

Flutter workspace 물리 패키지 분리

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

**Flutter workspace 물리 패키지 분리**

- 상태: `d1c40aa` 기준 플랫폼은 앱 `lib/platform/`에 있고 core·계약·공용 기반은
  `game_kit`으로 통합됐다. workspace는 공용 kit·복사용 template·번들 게임 3종의
  5개 패키지다. 패키지별 FlutterGen, import와 pubspec 의존성 전환,
  CI 경계 0건 게이트까지 구현했다. 다운로드 게임은 Application Support
  영구 캐시, Firebase Storage source, 로컬 매니페스트·SHA-256 검증, patch/asset 버전
  게이트와 수동 `downloadGame` API까지 준비했다. 앱 시작·게임 진입은 자동 다운로드를
  하지 않는다.
- 이전 단계 자동 검증: workspace pub get, 정적 분석, 경계·재시도 검사, Flutter 테스트 659개,
  Android debug 조립과 APK의 패키지 에셋 273개 포함을 확인했다.
- 과거 검증: 2026-09-09 Windows guarded FULL은 FAIL(exit 1), Flutter 668개 통과·2개
  실패다. 마피아 생성 에셋 경로의 한글 정규화 불일치와 진단 로그 테스트의 구형 경로
  기대값을 확인했다. 원격 소스 유지 요청에 따라 코드는 수정하지 않았고 Functions
  단계는 fail-fast로 실행되지 않았다. 경계 0건·재시도 검사와 정적 분석은 통과했다.
- 남은 검증: 당시 실패를 검사한 테스트 자체가 원 검토 기준에서 삭제되어, 같은 실패가
  현재도 발생하거나 이미 해결됐다고 단정할 수 없다. TEST-REGRESSION-01에서 핵심 검사를
  복원하고 현재 후보 FULL·번들 에셋/사운드·실기기 근거를 새로 확보한다. 10월 4일의
  다른 문서 작업 FULL은 형식 검사에서 FAIL한 기록도 있어 현재 PASS 근거는 아니다.
- 다음 행동: [원격 동기화 기록](../logs/2026-09.md#develop-sync-01)의 과거 결과를 참고하고,
  현재 후보를 검증한 뒤 가능한 대상 기기에서 주요 번들 게임의 asset·sound 로딩을 확인한다.
  다운로드 버튼 작업 때 Firebase Storage/Rules를 구성하고 번들 게임 복제 에셋으로
  실제 다운로드를 먼저 검증한 뒤 신작 staging patch 리허설을 수행한다.
- 근거와 환경상 우회 내용은 [2026-09 기록](../logs/2026-09.md#package-migration-01)에
  남긴다.
