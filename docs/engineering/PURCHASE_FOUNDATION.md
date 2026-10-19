# 구매·소유권 기반 구조

현재 앱은 유료 결제를 제공하지 않는다. 이 문서는 실제 과금이 실수로 열리지 않도록
현재 비과금 경계와 이후 결제를 연결할 위치를 정의한다.

## 현재 동작

- 로비의 `library` 목록은 Firestore `games` 중 `enabled == true`이며 무료이거나 현재
  계정이 보유한 게임만 보여 준다.
- 상점의 `store` 목록은 소유 여부와 관계없이 `storeVisible == true`인 게임을 보여 준다.
  비활성 게임은 공개 준비 중, 활성 유료 미보유 게임은 구매 준비 중으로 표시한다.
- 현재 소유권 원본은 `users/{uid}.ownedGames` 배열이다. 필드가 없으면 빈 목록이다.
- 방에서는 서버가 컨트롤러와 현재 활성 플레이어의 보유 게임을 합쳐 접근을 판정한다.
- `GamePurchaseGateway`의 기본 구현은 `DisabledGamePurchaseGateway`다. 상품 ID가 있어도
  결제·복원·소유권 변경을 수행하지 않는다.
- 결제 SDK dependency, App Store Connect/Play Console 상품, 영수증 검증 callable,
  거래 원장, 환불 알림은 아직 없다.

## 카탈로그 계약

`games/{catalogId}`는 기존 필드에 선택적인 `storeProductIds` map을 받을 수 있다.

```text
storeProductIds:
  appStore: "mosigame.game.example"
  googlePlay: "mosigame_game_example"
```

이 값은 상품 연결 정보일 뿐 가격이나 소유권이 아니다. 가격·통화는 실제 결제 도입 때
각 스토어에서 조회한다. 필드가 없거나 비어 있어도 현재 무료 게임과 상점은 그대로
동작한다.

## 실제 결제를 붙일 때의 경계

1. `GamePurchaseGateway`의 플랫폼 구현을 추가한다. UI는 영수증이나 구매 토큰을 해석하지
   않는다.
2. 클라이언트 거래를 Cloud Function에 보내고 Apple/Google 서버 검증 뒤에만 소유권을
   부여한다.
3. 서버 전용 거래 원장과 사용자별 entitlement를 추가하고, 거래 식별자는 멱등 키로
   사용한다. `ownedGames`는 이전 앱 호환용 파생 캐시로만 유지한다.
4. 환불·취소 알림으로 entitlement를 회수하고, 구매 복원도 같은 검증 경로를 사용한다.
5. 게스트는 구매 전에 기존 익명 UID에 영구 로그인 수단을 연결한다.
6. 소유권 변경 결과가 오면 상점과 library provider를 모두 다시 읽는다. 현재 화면은
   이를 위한 `onEntitlementsChanged` 경계를 제공한다.

이 단계는 새 dependency, persistent data contract, Cloud Function, Firestore rules와
운영 콘솔 설정을 포함하므로 별도 승인·테스트·배포 절차를 거친다.
