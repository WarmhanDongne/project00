# Hold'em asset bundle

홀덤 게임의 다운로드 에셋 원본 묶음이다. Flutter `pubspec.yaml`에는 등록하지 않으며,
게임 코드의 `requiredAssetVersion`과 같은 버전을 Firebase Storage의 아래 구조로 올린다.

```text
game-assets/holdem/manifest.json
game-assets/holdem/<assetVersion>/<logicalPath>
```

`inventory.json`은 디자인 산출물 검수용 파일 목록이고, `manifest.json`은 앱의
다운로드·SHA-256 검증에 사용하는 런타임 목록이다. 두 파일은 현재 버전인 v2를
가리킨다. 현재 코드는 정식 빌드와 이후 패치 모두에서 사용할 수 있도록 최소 패치
번호를 `0`으로 둔다.

## v2 구성 (현재)

카드 앞면은 게임 코드가 직접 그리므로 v2에는 이미지가 5개만 있다. 배경과 자리 배치
에셋은 라이어스 포커의 펠트 분위기를 그대로 두고 보라색 계열만 딥그린으로 바꿨다.

- `2/images/background/tablet.webp`: 태블릿용 4:3 그린 펠트 배경
- `2/images/background/phone.webp`: 휴대폰용 9:16 그린 펠트 배경
- `2/images/layout/table.webp`: 자리 배치 애니메이션용 탑뷰 테이블
- `2/images/layout/chair.webp`: 자리 배치 애니메이션용 탑뷰 의자
- `2/images/cards/back.webp`: 휴대폰·태블릿 공용 흰색 라인 패턴 카드 뒷면

`holdem-assets-v2.zip`에는 이 README, `inventory.json`, `manifest.json`, 버전 `2`
디렉터리가 들어 있다.

## v1 (이전)

`1/`과 `holdem-assets-v1.zip`은 이미 Storage에 올라간 v1 원본이다. v1은 딥그린
다마스크 배경과 카드 앞면 이미지 104장을 포함한 110개 파일이며, 기존 설치 캐시와
롤백 확인을 위해 보존한다. Storage manifest를 v2로 바꾸면 v1 코드 앱은 새로
다운로드할 수 없고, 이미 v1을 설치한 기기만 계속 사용할 수 있다.

## 개발·시뮬레이터 캐시 설치

개발·profile·release 모두 v2 다운로드 캐시를 사용한다. 홀덤 패키지의 이미지는
Flutter 번들에 등록하지 않으며, 개발 모드도 에셋 준비를 건너뛰지 않는다.

네트워크 없이 시뮬레이터를 확인하려면 앱을 종료하고, 앱의 Application Support
디렉터리 아래 `mosigame`을 캐시 루트로 지정해 로컬 원본을 설치한다.
실제 경로는 해당 시뮬레이터의 앱 데이터 컨테이너에서 확인한다. iOS 시뮬레이터에서는
`<앱 데이터 컨테이너>/Library/Application Support/mosigame`이다.

```text
dart run tool/install_local_game_assets.dart --source assets/game-assets/holdem --cache-root "<앱 Application Support>/mosigame"
```

도구는 기존 `GameAssetCache.install`을 사용해 매니페스트·파일 크기·SHA-256을 검증하고
기존 버전 디렉터리·완료 마커를 만든다. 앱은 재실행 후 이 캐시를 같은 준비 경로로
확인한다. `--patch-number`는 기본 `0`이며 로컬 테스트에 필요한 경우에만 지정한다.
도구는 Firebase·네트워크에 접근하지 않고 앱 바이너리에 포함되지 않는다.
