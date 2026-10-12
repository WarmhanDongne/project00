# LIARS-CATALOG-01
Firestore 카탈로그 문서 ID를 games/liars_poker에서 games/liars로 이전한다.

[작업 목록](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

2026-10-12 사용자가 표시 이름 변경 후 문서 ID 이전과 앱·서버 호환 처리를 승인했다.

## 범위
- Firebase 문서 ID만 새 이름 liars를 canonical로 사용한다.
- game protocol ID, RTDB selectedGame/gameType, 기존 ownedGames, asset path,
  패키지명·callable명은 liars_poker를 유지한다. 이름이 아닌 참조 계약이다.
- 새 앱은 GameInfo 수신 시 liars를 liars_poker 런타임으로 매핑한다.
- 기존 구매 데이터는 liars와 liars_poker를 동일 소유 키로 판정한다.
- 양 문서가 존재하면 liars 우선, 목록 중복 제거. liars.enabled=false여도
  legacy로 fallback하여 접근 정책을 우회하지 않는다.
- 서버 selectRealtimeRoomGame, beginRealtimeRoomSeating은 canonical 문서 조회,
  문서 부재일 때만 legacy 조회. 권한/통신 오류는 그대로 실패한다.
- 규칙/설명 관리 스크립트도 기존 실제 문서를 찾아 legacy 재생성을 방지한다.

## 반영 순서와 조건
1. 관련검사 후 사용자 승인 FULL 1회.
2. 현재 소스에 별도 사용자 작업이 많으므로 FULL 후보 및 배포 diff를 확인한다.
   배포 대상: selectRealtimeRoomGame, beginRealtimeRoomSeating 두 개.
   함수 전체 배포나 규칙 변경은 하지 않는다.
3. 사용 중인 모든 앱에 새 카탈로그 reader 반영. 외부 배포 여부를 확인해야 한다.
   구버전 앱은 games/liars 문서로부터 바로 runtime ID를 만들므로 지원되지 않는다.
4. Firebase 인증 후 아래 dry-run으로 source/target/subcollection 충돌을 확인한다.
   node functions/scripts/migrate-liars-catalog.mjs
5. 새 앱/두 서버 함수 반영 확인 후:
   node functions/scripts/migrate-liars-catalog.mjs --apply --clients-updated
   games/liars_poker 데이터 전체를 games/liars로 transaction.create하고 원본 delete.
   target이 있으면 덮어쓰지 않는다. subcollection이 있으면 중단한다.
6. 새 문서의 모든 필드·name/인원/활성 상태를 비교하고 이전 문서 부재를 확인한다.
   실제 앱 목록→선택→자리 배치→게임 시작과 기존 방 재접속을 확인한다.

## 롤백
node functions/scripts/migrate-liars-catalog.mjs --rollback (dry-run)
node functions/scripts/migrate-liars-catalog.mjs --rollback --apply
새 문서 전체를 옛 문서로 동일하게 원자 이전한다. 기존 위치에 문서가 있으면 중단한다.
새 앱/서버는 missing canonical fallback을 지원하므로 롤백 중 별도 게임 데이터 변환이 없다.

## 운영 반영 상태

2026-10-13 Cloud Shell의 카탈로그 재생성으로 `games/liars_poker`가 제거되고
`games/liars`가 생성됐다. 그러나 순서상 먼저 배포되어야 했던 운영
`selectRealtimeRoomGame`과 `beginRealtimeRoomSeating`은 이전 리비전이어서 런타임 ID
`liars_poker`를 문서 ID로 직접 조회했다. 그 결과 로비에는 라이어스와 참가자 2명이
정상 표시돼도 게임 선택 단계에서 삭제된 문서를 찾지 못해 시작할 수 없었다. 인원 제한
문제는 아니며 라이어스의 2~6명 계약은 앱·카탈로그·시작 함수에서 일치한다.

같은 날 두 함수만 canonical reader가 포함된 리비전으로 배포했다. 두 함수 모두
`asia-northeast3`, `ACTIVE`, hash `297bd7c812f172347680d8b70ad36b19326346a7`을 확인했다.
Functions build/lint, 카탈로그·방 회귀 29개, Project CLI session의 Flutter 181개와
Functions 116개 및 working-tree mutation 검사가 PASS했다. 기존 방에서도 게임 시작을
다시 누르면 새 선택 요청부터 재시도할 수 있다.

아직 하지 않은 것은 앱 설치·스토어 배포, 실제 2기기 라이어스 시작 확인과 현재 전체
working tree 기준 FULL이다. 구버전 앱은 `games/liars` 문서 ID를 런타임 ID로 변환하지
못하므로 지원 대상 기기에 새 앱을 반영해야 한다.

## 2026-10-12 검증 기록

직접 Flutter 목록/소유/legacy fallback/중복/비활성 회귀11개 PASS/exit0.
Functions migration/reader/catalog 회귀10개 PASS/exit0, npm run build PASS/exit0.
린트 첫 실행은 새 helper의 JSDoc/max-len 3건으로 FAIL/exit1; 주석 보완 후 PASS/exit0.
`dart run :mosigame test session --json`: PASS/exit0, 54.104초, 5단계 및 mutation PASS.
원본 경로 Flutter 분석은 기존 한글 경로 LSP JSON 오류(exit255); 동일 소스 영문 사본으로 재검사.
FULL은 새 명시 승인 전 미실행이며 운영 변경 완료가 아니다. 증거 build/liars-catalog-migration/.

영문 경로 동일 소스의 변경 파일 정적 분석 PASS/exit0. 첫 승인 FULL은 의존성 링크 때문에
사전 Git snapshot에서 BLOCKED/exit3(3.808초), 실제 복사본 교체 후 session 5단계와 mutation
PASS/exit0(56.154초). 재승인 FULL은 preflight PASS 뒤 셸의 `FLUTTER_ROOT`가 쓰기 제한된
SDK 래퍼를 우선 선택해 dart-format FAIL, mutation PASS, 최종 FAIL/exit1(3.348초)였고 후속
제품 검사는 시작되지 않았다. 환경을 분리하자 기존 `test/lobby_music_test.dart` 줄바꿈 한 곳도
포맷 실패로 확인되어 의미 변경 없이 정리했다. 이후 원본·최신 영문 사본의 전체 Dart 포맷은
PASS/exit0. 검증 사본 생성 뒤 추가된 GUI 변경까지 다시 동기화했으며 FULL 재실행은 새 승인 대기다.
