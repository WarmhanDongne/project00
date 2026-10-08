# 홀덤 MVP 제품·구현 계획

이 문서는 Mosigame의 첫 다운로드형 신작인 텍사스 홀덤의 제품 범위, 서버 권위
계약, 기기별 화면 책임, 에셋 전달과 단계별 검증 기준을 정리한다. 구현 과정의 현재
상태는 [TASKS.md](TASKS.md#holdem-01), 실행 기록은
[2026-10 작업 기록](logs/2026-10.md#holdem-01)에서 관리한다.

## 1. 현재 판정

- 게임 ID와 패키지명은 각각 `holdem`, `game_holdem`을 사용한다.
- 게임 종류는 텍사스 홀덤이며 실제 금전·환전·현금성 보상을 다루지 않는 가상 칩
  단일 테이블 토너먼트다.
- 태블릿은 공용 테이블과 진행 상황, 휴대폰은 개인 홀 카드와 행동 입력을 담당한다.
- 기존 자리 배치 좌표와 좌석 선택 흐름은 바꾸지 않는다.
- 다운로드 에셋은 `assets/game-assets/holdem/`에 있다. 현재 코드는 v2(5개)를
  요구하며, 이미 배포된 v1(110개)은 기존 설치와 롤백 확인용으로 보존한다.
- 화면은 [홀덤 화면 디자인](https://claude.ai/artifact/SaH6BTuokFGAcVLrDWx8Gr)을
  기준으로 한다. 시안의 보라색 톤은 같은 분위기의 딥그린으로 옮겼고 카드 앞면은
  코드로 그린다.
- 서버 상태 머신과 callable, Flutter 패키지와 양 기기 화면, 다운로드·캐시 연결,
  카탈로그 등록 스크립트와 런타임 매니페스트까지 구현했다. Firebase Storage 업로드,
  Firestore 카탈로그 쓰기, Functions·Rules·Shorebird production 배포는 수행하지 않았다.

이 문서의 수치 기본값은 구현을 시작하기 위한 제안이다. 아래 제품 결정 표에서
확정 표시가 없는 값은 서버 상태 계약을 고정하기 전에 사용자 확인이 필요하다.

## 2. MVP 목표와 제외 범위

### 목표

- 한 방의 참가자가 좌석 배치 후 텍사스 홀덤 토너먼트를 끝까지 진행한다.
- 셔플, 카드 배분, 베팅 검증, 팟 계산, 족보 비교와 승패 판정은 서버가 수행한다.
- 휴대폰에는 본인의 카드만, 태블릿에는 공개 가능한 정보만 표시한다.
- 명령 재시도와 네트워크 재연결 뒤에도 같은 행동이 중복 반영되지 않는다.
- 제작한 딥그린 테이블·의자·배경과 휴대폰/태블릿 카드 에셋을 런타임 다운로드로
  제공한다.

### MVP에서 제외

- 실제 금전, 환전, 구매한 칩, 현금성 보상
- 캐시 게임, 리바이, 애드온, 다중 테이블, 관전자 베팅
- 채팅, 이모트, 핸드 히스토리 공유, 통계와 랭킹
- 방 중간 신규 참가와 탈락자의 재참가
- Omaha, Short Deck 등 다른 포커 규칙
- AI 플레이어와 서버가 대신하는 장기 오프라인 플레이

## 3. 제품 결정 표

| 항목 | MVP 제안 | 상태 |
| --- | --- | --- |
| 게임 방식 | No-Limit Texas Hold'em, 단일 테이블 토너먼트 | 방향 확정 |
| 재화 | 방 안에서만 유효한 가상 칩, 게임 종료 시 소멸 | 방향 확정 |
| 지원 인원 | 2–8명 | 2026-10-06 확정 |
| 시작 칩 | 1,000칩 | 2026-10-06 확정 |
| 최초 블라인드 | small 10 / big 20 | 2026-10-06 확정 |
| 블라인드 상승 | 5핸드마다 2배, 최대 160/320 | 2026-10-06 확정 |
| 행동 제한 | 20초 | 2026-10-06 확정 |
| 시간 초과 | 체크 가능 시 체크, 아니면 폴드 | 2026-10-06 확정 |
| 재참가 | 칩 0이면 탈락, 리바이 없음 | 2026-10-06 확정 |
| 종료 | 한 명만 칩을 보유하면 우승 | 방향 확정 |
| 휴대폰 방향 | 세로 고정 | 2026-10-06 확정 |
| 연결 중단 | 공용 interruption 계약을 사용하고 복구/제외 전까지 진행 보호 | 구조 확정 |

2인 플레이를 지원하면 딜러가 small blind이며 먼저 프리플롭 행동을 하고, 플롭
이후에는 big blind가 먼저 행동하는 heads-up 규칙을 별도로 검증한다.

## 4. 게임 규칙 계약

### 핸드 진행

1. 서버가 참가자와 칩을 확인하고 딜러 버튼, small blind, big blind를 결정한다.
2. 서버가 안전한 난수로 52장 덱을 섞고 각 참가자에게 홀 카드 2장을 배분한다.
3. 프리플롭 베팅을 진행한다.
4. burn 1장 후 flop 3장을 공개하고 베팅한다.
5. burn 1장 후 turn 1장을 공개하고 베팅한다.
6. burn 1장 후 river 1장을 공개하고 베팅한다.
7. 둘 이상 남으면 showdown에서 가장 강한 5장 조합을 계산한다.
8. 메인 팟과 side pot을 자격이 있는 승자에게 나눠 주고 다음 핸드로 이동한다.

한 명을 제외한 모두가 폴드하면 남은 사람이 즉시 모든 팟을 받고 카드는 공개하지
않는다. 동률 팟의 나머지 칩은 딜러 버튼 다음의 살아 있는 좌석부터 시계 방향으로
한 칩씩 배분한다.

### 지원 행동

- `fold`
- `check`
- `call`
- `bet`
- `raise`
- `allIn`

서버는 현재 턴, 참가 상태, 필요한 call 금액, 최소 raise, 보유 칩과 라운드 버전을
검증한다. short all-in은 이전 full raise보다 작을 수 있지만 이미 행동을 마친
플레이어의 raise 권한을 다시 열지 않는다. 정확한 no-limit 재오픈 규칙과 side pot
계산은 순수 함수 테스트로 먼저 고정한다.

### 족보

높은 순서대로 royal flush를 별도 등급으로 두지 않고 straight flush의 최고 형태로
처리한다.

1. Straight Flush
2. Four of a Kind
3. Full House
4. Flush
5. Straight
6. Three of a Kind
7. Two Pair
8. One Pair
9. High Card

Ace는 A-K-Q-J-10과 A-2-3-4-5 스트레이트 양쪽에 사용할 수 있다. 7장 중 최선의
5장을 선택하며 모든 동률 비교 키를 서버의 단일 evaluator가 만든다.

## 5. 서버 권위 상태

상태 단계는 다음 순서를 기준으로 한다.

```text
starting
  -> handSetup
  -> preflop
  -> flop
  -> turn
  -> river
  -> showdown
  -> handResult
  -> handSetup | finished
```

모두 폴드한 경우 현재 베팅 단계에서 바로 `handResult`로 이동할 수 있다. 단계명,
필드명과 callable payload는 구현 1단계에서 테스트와 함께 확정하며, 배포 뒤에는
persistent data/state-machine contract로 취급한다.

### `game/public`

- `gameType`, `status`, `phase`, `handNumber`, `revision`
- 딜러·small blind·big blind 좌석과 현재 블라인드
- 공개 community cards
- 메인/side pot별 금액
- 쇼다운 결과의 참가자별 최종 5장(`result.bestCards`, 화면 강조용 선택 필드)
- 플레이어별 좌석, 남은 칩, 현재 핸드 투입액, 토너먼트 상태
  (`alive/eliminated`)와 핸드 상태(`active/folded/allIn/eliminated`)
- 현재 행동 UID, 행동 마감 서버 시각, call 금액과 최소 raise
- 마지막 공개 행동과 핸드 결과
- showdown에서 공개하기로 결정된 카드만

### `game/private/{uid}`

- 본인의 홀 카드 2장
- 서버 evaluator로 만든 현재 족보(`handRank`: category와 최선의 카드, 표시 전용)
- 서버가 계산한 현재 허용 행동
- call 금액, 최소/최대 추가 투입액
- 본인에게만 필요한 오류 복구·확인 정보

다른 참가자의 홀 카드, 남은 덱과 burn 카드는 두 경로에 두지 않는다.

### `game/server`

- 섞인 덱과 덱 위치. burn 카드는 덱 위치만 진행시키고 별도 공개·보존하지 않음
- 베팅 라운드별 기여액과 전체 누적 기여액
- 마지막 full raise, 마지막 aggressor, 행동 완료 집합
- 딜러 이동과 블라인드 레벨 계산 정보
- 처리한 `commandId`와 상태 버전
- 중단·타임아웃·결과 계산에 필요한 서버 전용 값

## 6. 명령과 멱등성

예상 callable 이름은 저장소 규칙에 맞춰 `game_holdem_<action>`을 사용한다.

| 명령 | 호출 주체 | 핵심 검증 |
| --- | --- | --- |
| `start_game` | 태블릿 controller | 선택 게임, 참가자·좌석, 인원, 시작 옵션 |
| `complete_dealing` | 태블릿 controller | 현재 phase/stateVersion, 연출 중복 완료 |
| `act` | 현재 휴대폰 사용자 | auth UID, 턴, action, amount, commandId |
| `timeout_turn` | 활성 클라이언트 | 서버 마감 경과, 현재 턴·버전 |
| `complete_result` | 태블릿 controller | 결과 연출 완료, 다음 핸드 가능 상태 |
| `leave_game` | 해당 사용자 | 기존 공용 중단·퇴장 계약 |
| `end_game` | 태블릿 controller | 종료 권한과 현재 상태 |

재시도 가능한 명령은 같은 `commandId`를 유지한다. 서버는 상태 변경과 command
기록을 같은 RTDB transaction 경계에서 처리하고, 오래된 `stateVersion` 요청을
거부한다. 중요한 단계 이동을 클라이언트가 계산하지 않는다.

## 7. 기기별 화면

### 태블릿

- 기존 자리 배치 화면과 좌표를 그대로 사용하고 준비 완료 후 홀덤 board로 전환
- 중앙 community cards 5장, 팟과 현재 블라인드 표시
- 각 기존 좌석에 닉네임, 칩, 현재 베팅액, 상태, 턴 강조 표시
- 딜러·small blind·big blind 마커 표시
- 전체 카드 배분, flop/turn/river, 팟 이동과 결과 연출
- 다른 사람의 비공개 홀 카드는 showdown 공개 전까지 렌더링하지 않음

### 휴대폰

- 세로 화면의 상단 상태·턴 타이머, 중앙 홀 카드 2장, 하단 행동 영역
- 서버가 허용한 행동만 활성화
- raise는 슬라이더와 숫자 입력 중 한 가지 방식으로 통일하고 최소/최대 표시
- 제출 중 중복 입력 차단, 재시도 시 같은 `commandId` 유지
- 게임 중단·재접속·탈락·결과 화면을 구분
- 휴대폰 카드 앞면은 하단 역방향 rank가 없는 현재 비대칭 에셋 사용

`PhoneGameShell`, `GameScreenPhase`, `GameSessionController`,
`GameTurnCountdown`, `GameTurnCountdownFace`, `ServerClock`,
`GameCommandService`, `GameQueryService`,
`GameInterruptionCommandService`를 사용한다. 제외가 필요하면 구현 파일 상단에
구체적인 이유를 남긴다.

## 8. 패키지와 코드 배치

```text
packages/game_holdem/
  lib/game_holdem.dart
  lib/game_copy.dart
  lib/game_theme.dart
  lib/phone/...
  lib/tablet/...
  lib/shared/models/...
  lib/shared/providers/...
  lib/shared/services/...
  test/...

functions/src/holdem/
  types.ts
  validation.ts
  deck.ts
  hand-evaluator.ts
  betting.ts
  pots.ts
  game.ts
  start-game.ts
  act.ts
  timeout-turn.ts
  complete-dealing.ts
  complete-result.ts
  leave-game.ts
  end-game.ts
```

`game_template`을 복사해 시작하고 게임 패키지는 `game_kit`만 내부 의존성으로
사용한다. 새 dependency와 네이티브 플러그인은 추가하지 않는다. 앱의 게임 ID별
분기는 만들지 않고 `GameRegistry`에만 등록한다.

## 9. 에셋·다운로드·릴리스

- `requiredAssetVersion`은 2이다. v2는 라이어스 포커 펠트를 그린으로 바꾼 배경
  2개, 자리 배치 테이블·의자, 공용 카드 뒷면만 포함한다. 카드 앞면은
  `HoldemCardView`가 그린다.
- 시안 글꼴 Caprasimo·Bodoni Moda는 앱 번들(`assets/fonts/`)에 있다. 번들 글꼴은
  Shorebird 패치로 추가할 수 없으므로 이 화면은 새 앱 빌드와 함께 배포한다. 한글
  본문은 game_kit의 IBM Plex Sans KR을 쓴다.
- Storage manifest를 v2로 바꾸면 v1 코드 앱은 새로 다운로드할 수 없다. 새 앱
  배포 시점에 맞춰 v2를 올린다.
- `packages/game_holdem/pubspec.yaml`에는 에셋과 FlutterGen 설정을 넣지 않는다.
- 모든 이미지는 `GameImage.remote(gameId: 'holdem', assetVersion: 1, ...)`로
  접근한다.
- `inventory.json`은 디자인 검수용이고 `manifest.json`은 다운로드·SHA-256 검증용이다.
  현재 최소 패치 번호는 0이며 staging patch가 더 높은 번호를 요구하면 업로드 전에
  조정한다.
- Storage 경로는 아래로 고정한다.

```text
game-assets/holdem/manifest.json
game-assets/holdem/1/<logicalPath>
```

- `device` 태그는 유지하되 현재 런타임 정책대로 두 기기 파일을 모두 받는다.
- 먼저 번들 게임 복제 매니페스트로 실제 Storage/기기 다운로드를 리허설한 후 홀덤을
  올린다.
- Firebase Storage 업로드, Firestore 카탈로그 변경, Rules 변경, Functions 배포,
  Shorebird patch는 각각 production 변경 전 별도 승인을 받는다.

## 10. 구현 단계와 통과 기준

### 단계 0 — 제품 계약 확정 (완료: 2026-10-06)

- 제품 결정 표의 미확정 값을 승인받는다.
- 실제 플레이 시간 목표와 지원 인원을 확정한다.
- 완료 기준: 규칙 수치와 제외 범위가 확정되고 persistent state 구현을 시작할 수 있다.

### 단계 1 — 서버 순수 규칙 (완료: 2026-10-06)

- 카드·덱·족보 evaluator, 베팅 라운드, side pot, 버튼·블라인드 이동을 순수 함수로 구현
- 카드 중복, 모든 족보와 동률, wheel straight, heads-up, short all-in, 복수 side pot,
  홀수 칩 배분을 자동 테스트
- 완료 기준: Functions build/lint와 홀덤 규칙 테스트 통과

구현 파일은 `functions/src/holdem/{config,types,deck,hand-evaluator,table,betting,pots}.ts`,
검증은 `functions/test/holdem-rules.test.mjs`이다. callable export와 Firebase
읽기·쓰기는 단계 2에서 추가한다.

### 단계 2 — 서버 상태 머신

구현·production Functions 배포 완료: 2026-10-06.

- 시작, 배분, 행동, 타임아웃, showdown, 결과, 다음 핸드, 종료 callable 구현
- public/private/server 경계, commandId 멱등성, stateVersion 경합 검증
- 퇴장·단절·최소 인원 정책을 공용 interruption 계약에 연결
- 완료 기준: 권한·재시도·동시 요청·단절 회귀 테스트 통과

### 단계 3 — Flutter 게임 패키지

구현 완료: 2026-10-06. 패키지 analyze·테스트·경계 검사를 통과했다.

- `game_template` 기반 `game_holdem` 생성과 workspace/registry 등록
- 공용 세션 controller와 snapshot mapper 구현
- 휴대폰 행동 화면과 태블릿 테이블 화면 구현
- 기존 좌석 위치를 변경하지 않고 원격 에셋 연결
- 완료 기준: 패키지 테스트, analyze, 패키지 경계 위반 0건

### 단계 4 — 카탈로그와 다운로드 연결

코드·원격 배포 완료: 2026-10-06. 카탈로그 dry-run, manifest 110개 해시 검증,
메모리 source 다운로드·재진입 캐시 테스트를 통과했다. production Storage의
110개 객체와 manifest 메타데이터를 재검증하고 Firestore 카탈로그를 등록했다.

- 개발·staging 카탈로그에 설명, 규칙, 인원, 플레이 시간, 소유권 정책 등록
- v1 런타임 manifest 생성과 SHA-256 일치 확인
- 다운로드 전/중/완료/손상/버전 불일치/오프라인 재사용 UI 검증
- 완료 기준: production 쓰기 없이 staging과 실제 기기에서 다운로드·재시작 확인

### 단계 5 — 통합·릴리스 후보

자동 검증과 Android 릴리스 빌드 완료: 2026-10-06. 실제 양 기기 확인은 남았다.

- 전체 핸드, side pot, 동률, 탈락, 재접속, 태블릿 재실행을 양 기기에서 확인
- `python3 tool/check_package_boundaries.py`와
  `dart run :mosigame validate --full` 통과
- 성능과 메모리를 실제 지원 기기에서 확인
- 완료 기준: 검증 근거와 남은 제한을 기록하고 배포 후보 승인 요청

### 단계 6 — 승인 후 배포

1. Functions와 Rules의 호환 가능한 배포 — 완료
2. 에셋 v1 및 manifest 업로드 — 완료
3. Firestore 게임 문서 활성화 — 완료
4. Android 1.0.0+2 릴리스 APK 빌드 — 완료
5. 휴대폰·태블릿 실기기 확인 — 대기

각 단계는 이전 단계 성공을 확인한 뒤 진행하며 롤백 조건과 구버전 앱의 차단 동작을
함께 확인한다.

## 11. 필수 테스트 행렬

- 덱: 52장 유일성, 셔플 뒤 중복 없음, burn 포함 소비 순서
- 족보: 모든 등급, kicker, board play, wheel, 완전 동률
- 베팅: check/call/bet/raise/all-in, 최소 raise, short all-in 재오픈 금지
- 팟: main/복수 side pot, 폴드 기여금, 동률 분할, 홀수 칩
- 턴: 잘못된 UID, 중복 commandId, 오래된 version, 시간 초과 경합
- 개인정보: 공개 snapshot과 로그에 미공개 홀 카드·덱이 없음
- 수명: 단절·복귀·제외, 태블릿 재실행, 결과 중 재접속
- UI: 휴대폰 최소 폭과 큰 글자, 태블릿 주요 비율, 입력 연타와 제출 실패
- 에셋: 110개 SHA-256, 손상 거부, v1/patch 호환성, 오프라인 캐시

## 12. 주요 위험과 대응

| 위험 | 대응 |
| --- | --- |
| 잘못된 side pot·동률 계산 | UI보다 순수 서버 규칙과 조합 테스트를 먼저 구현 |
| 홀 카드 유출 | public/private/server fixture를 별도 검사하고 로그 payload 제한 |
| 중복 베팅 | commandId와 stateVersion을 transaction에서 함께 검증 |
| 단절로 게임 정지 | 공용 interruption 계약과 시간 초과 정책을 같은 상태 머신에 연결 |
| 패치와 에셋 버전 불일치 | requiredAssetVersion/requiredPatchNumber 양방향 차단 |
| iOS 패치 코드 성능 | 공용 연출 재사용, evaluator 1회 계산, 실제 staging 기기 측정 |
| 긴 플레이 시간 | 블라인드 상승·시작 칩·인원 결정을 단계 0에서 플레이 시간과 함께 조정 |
