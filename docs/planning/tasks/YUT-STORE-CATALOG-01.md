# YUT-STORE-CATALOG-01

윷놀이 3종의 상점 카탈로그, 미리보기와 게임 묶음 진열 기반.

## 상품

| ID | 상품명 | 플레이 차이 | 최초 공개 상태 |
| --- | --- | --- | --- |
| `yut` | 윷놀이 | 네 방향, 한 명이 윷 4개를 던짐, 빨간 윷으로 백도 판정 | `enabled: false`, `storeVisible: true` |
| `strategy_yut` | 전략 윷놀이 | 좌우 두 진영, 네 명이 무표식 윷 하나씩 선택해 동시 공개, 도는 백도 | `enabled: false`, `storeVisible: true` |
| `strategy_yut_edition` | 전략 윷놀이 에디션 | 전략 윷놀이 규칙을 공유하고 아트만 별도 적용 | `enabled: false`, `storeVisible: true` |

전략 규칙은 사용자가 확정한 4인 2팀, 네 명의 비공개 선택 후 동시 공개,
도=백도, 팀 말 4개 완주 조건을 Firestore 후보와 상세 문구에 반영한다.

## Firestore 문서

- `games/{gameId}`는 기존 게임 카탈로그 형태를 따른다. 네 언어의 이름, 소개, 규칙,
  장르와 플레이 인원·시간·정렬·접근 유형을 포함한다.
- 새 게임 문서는 코드·서버 배포 전까지 비활성 상태다. 미리보기는 상점에 진열할 수
  있도록 `storeVisible: true`로 준비한다.
- `gameBundles/{bundleId}`는 `name`, `localizedNames`, `description`,
  `localizedDescriptions`, `gameIds`, `order`, `storeVisible`을 저장한다.
- 기본 묶음 `yut_trio`에는 세 게임 ID를 모두 넣는다. 번들 구매 기능은 비활성이다.
  추후 거래가 승인되면 포함된 각 ID를 사용자 `ownedGames`에 개별로 지급한다.
- Firestore Rules는 로그인 사용자 읽기만 허용하고 쓰기는 계속 차단한다.

## 변경/운영 경계

- `functions/scripts/yut-game-catalog.mjs`가 카탈로그 후보를 보관한다.
- `functions/scripts/seed-yut-catalog.mjs`는 기본 dry-run이며 apply는 프로젝트 확인 인자가
  필요하다. 초기 구현에서는 운영 Firestore에 쓰지 않았으며, 2026-10-19 사용자 요청으로
  `project0000-ec01e`에 적용했다. 실행 결과와 문서 ID는 2026-10 월간 기록을 따른다.
- `GameBundleService`와 상점은 `gameBundles`를 읽어 공개 번들만 표시한다.
- 가격, 스토어 상품, 거래 검증, 구매·복원은 범위 밖이며 계속 비활성이다.
- 게임 엔진과 Flutter 화면은 [YUT-GAMEPLAY-01](YUT-GAMEPLAY-01.md)에서 이어 구현한다.
- 카탈로그 문서가 운영 Firestore에 등록됐지만 세 게임 모두 `enabled: false`다. Firebase
  배포나 게임 공개 활성화는 하지 않았다.
