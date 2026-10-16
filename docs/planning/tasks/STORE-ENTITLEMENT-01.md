# STORE-ENTITLEMENT-01

게임 상점과 소유권·구매 기반 구조

[작업 목록](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md) ·
[구매 기반 구조](../../engineering/PURCHASE_FOUNDATION.md)

## 목적

현재는 실제 앱 내 결제를 열지 않으면서, 상점이 유료 미보유 게임을 발견할 수 있고 이후
스토어 결제와 서버 검증을 안전하게 연결할 수 있는 경계를 마련한다.

## 2026-10-16 구현 후보

- 로비 library와 상점 store 카탈로그 provider를 분리했다.
- 상점은 `storeVisible` 전체를 읽으며, 유료 미보유·비활성 게임을 소유권 부여 없이
  표시한다.
- `GamePurchaseGateway`와 비활성 기본 구현을 추가했다. 현재 빌드는 상품 ID가 있어도
  실제 결제와 복원을 실행하지 않는다.
- 선택적 `storeProductIds.appStore/googlePlay` 파싱과 소유권 변경 후 양쪽 카탈로그
  갱신 callback을 준비했다.
- 현재 `ownedGames` 판정과 방의 그룹 보유 합집합 계약은 유지했다. 운영 Firebase 접근,
  스키마 적용, dependency 추가, 결제 콘솔 설정과 배포는 하지 않았다.

## 완료 조건과 다음 단계

이번 비과금 기반 후보는 관련 카탈로그·상점·로비 회귀와 사용자 승인 FULL을 통과해야
한다. 실제 과금 단계는 별도 제품 결정과 승인 후 다음을 완료한다.

- 비소모성 상품 ID·가격 정책과 게스트 구매 차단/계정 연결 UX 확정
- Apple·Google 거래 서버 검증, 멱등 거래 원장, entitlement와 환불·복원 계약
- 보안 규칙·Cloud Functions·스토어 콘솔 sandbox 검증
- 약관·개인정보 안내와 계정 삭제 후 복원 정책 갱신

[검증·보존 기록](../logs/2026-10.md#store-entitlement-foundation-20261016).
