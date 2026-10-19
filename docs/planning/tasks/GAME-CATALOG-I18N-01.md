# GAME-CATALOG-I18N-01

Firestore 게임 카탈로그의 이름·소개·규칙·장르를 앱 locale에 맞춰 표시한다.

## 데이터 계약

새 게임 등록의 전체 필드와 공개 순서는
[새 게임 제작·연결 가이드](../../engineering/NEW_GAME_GUIDE.md)를 따른다. 새 문서는 네
locale 정보를 모두 포함하고 `enabled: false`, `storeVisible: false`로 시작한다.

- `games/{catalogId}.name`: 이전 앱 호환용 한국어 이름
- `games/{catalogId}.localizedNames.ko`: 한국어
- `games/{catalogId}.localizedNames.en`: 영어
- `games/{catalogId}.localizedNames.zh-Hans`: 중국어 간체
- `games/{catalogId}.localizedNames.zh-Hant`: 중국어 번체
- 같은 locale 키의 `localizedDescriptions`, `localizedRules`, `localizedGenres`를
  추가하며 기존 `description`, `rules`, `genres`는 구버전용 한국어 값으로 유지한다.
- 현재 locale 값이 없으면 language code, 영어, 해당 기존 한국어 필드 순으로 대체한다.

## 반영 값

| 문서 | 한국어 | 영어 | 중국어 간체 | 중국어 번체 |
| --- | --- | --- | --- | --- |
| `liars` 또는 이전 전 `liars_poker` | 라이어스 | Liars | 骗子 | 騙子 |
| `final_call` | 파이널콜 | FINAL CALL | 最后通牒 | 最後通牒 |
| `mafia` | 마피아 | MAFIA | 黑手党 | 黑手黨 |
| `holdem` | 홀덤 | TEXAS HOLD'EM | 德州扑克 | 德州撲克 |

## 구현 범위

- `GameInfo`가 네 다국어 map을 읽고 locale별 이름·소개·규칙·장르를 계산한다.
- 홈 책 표지·책등, 목록, 상세, 대기 화면과 상점 카탈로그가 계산된 값을 사용한다.
- 운영 갱신 스크립트는 dry-run이 기본이며 apply 때 네 문서를 한 batch로 갱신한다.
- 전체 재생성 스크립트는 기존 문서를 로컬 JSON으로 백업하고, 하위 컬렉션이 없을
  때만 `liars`, `final_call`, `mafia`, `holdem` 네 문서를 한 batch로 완전 교체한다.
- 상점의 알려진 게임 소개·장르 쪽지는 하드코딩 문구 대신 Firestore 다국어 값을
  사용한다. 전체 재생성을 실행하면 이전 `liars_poker` 문서는 백업 후 삭제되고
  canonical `liars`만 생성된다.
- Firestore 카탈로그에 속하지 않는 앱 공용 UI와 네 게임의 화면 문구는
  `GameLocale` bridge 및 게임별 copy getter에서 현재 locale을 선택한다. 게임 제목,
  버튼, 안내, 오류, 규칙, 결과, 접근성 문구와 디버그 통신 진단 UI가 같은 변경을
  따른다.

## 최소 문서 필드

공통 필드는 `name`, `localizedNames`, `description`, `localizedDescriptions`, `rules`,
`localizedRules`, `enabled`, `genres`, `localizedGenres`, `minPlayers`, `maxPlayers`,
`playTime`, `order`, `accessType`, `storeVisible`이다.
Hold'em만 구버전 앱 차단을 위해 `minAppVersion`을 추가한다. 네 게임에 필요 없는
`imageUrl`, `componentImageUrl`, `ruleVideoUrl`, `tabletDescription`, `createdAt`,
`updatedAt`은 재생성 문서에 넣지 않는다.
운영 상태를 보존하기 위해 마피아는 `enabled: false`, `accessType: paid`로 재생성한다.

## 검증과 운영 상태

- Flutter 이름·소개·규칙·장르 locale 선택과 책·상점·대기 화면 검사 PASS.
- Functions 스크립트 회귀, build, lint, 전체 Node 테스트 PASS.
- 변경 Dart 정적 분석 PASS.
- 2026-10-13 운영 Cloud Shell에서 dry-run 후 재생성을 완료했다. 기존
  `liars_poker`를 제거하고 `liars`, `final_call`, `mafia`, `holdem` 네 문서를
  최소 스키마로 교체했으며, 로컬 JSON 백업 생성을 확인했다.
- 사용자 결정에 따라 마피아는 `enabled: false`, `accessType: paid` 상태로 유지했다.
- 후속 후보는 소개·규칙·장르까지 4개 언어로 확장했다. 새 필드는 아직 운영
  Firestore에 적용하지 않았다.
- 관련 Flutter 모델·책·상점·대기 화면 회귀 55개 PASS. Functions 전체 443개와
  build/lint PASS.
- 후속 화면 문구 후보는 변경 경로 정적 분석과 locale bridge·카탈로그·로비·진단 관련
  Flutter 47개, 네 게임 및 game_kit UI 206개, Project CLI auth 72개·session
  Flutter 180개/Functions 116개를 통과했다. FULL은 새 최종 후보 승인 전이라
  실행하지 않았다.
