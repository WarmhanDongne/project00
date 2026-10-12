# HEARTBEAT-B1-01
Heartbeat를 Ping 수준으로 경량화하는 B1-C 구현

[작업 목록](../TASKS.md) · [작업 관리 방법](../TASK_MANAGEMENT.md)

2026-10-13 사용자가 B1 사전 조사 보고서의 B1-C와 W1~W7 구현·회귀·demo Emulator 검증을 승인했다.
운영 Firebase 접근·배포·migration·Git commit/push는 제외하고 기존 미배포 작업을 보존한다.
로비 heartbeat 중단은 보류하며 이번 후보에서도 10초 heartbeat/조건부 20초 stale을 유지한다.

W1 현재 tuple 판정과 두 P1 정리 보호, W2 current leaf 관찰·Rules, W3 시각-only 쓰기/서버 seed,
W4 connected-only 단절 trigger/타이머, W5 lifecycle signal/advisory queue/cursor repair,
W6 capability/구 APK 차단/fingerprint, W7 기존·신규 회귀와 E13 harness 통합을 수행했다.
게임 reducer/규칙·ready 의미·재시도 예산·이력 GC·정리 유예를 바꾸지 않는다.
기술 계약은 [네트워크·세션 계약](../../engineering/NETWORK_SESSION_CONTRACT.md),
구현·측정·미확인 항목은 [결과 보고서](../../operations/HEARTBEAT_B1_IMPLEMENTATION.md)를 따른다.

완료 조건은 현재 identity와 last-normal 타이머 보호, P1 경합, normal HB sync/queue 0과 실제
false/status positive control, actual Rules/SDK/root CAS, session/auth 및 사용자 승인 FULL이다.
실기기/native 단절 시간과 실제 과금·배포는 별도 후속이며 로컬 결과로 통과를 확대하지 않는다.
같은 비용 작업 COST-01, 미배포 정리 ROOM-CREATE-REQUEST-01, 세션 복구 SESSION-RECONNECT-02와 연관된다.
