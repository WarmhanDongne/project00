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

## 2026-10-13 — 디벨럽1 통합 승인·검증

사용자가 푸시된 B1 후보에서 통합 브랜치 생성·최신 디벨럽1 병합·문서/함수 수 검사 수정·
테스트 재실행을 승인했다. `fbd2f35`와 원격 확인한 `7b127da`를
`codex/b1-develop1-integration`에서 통합하고 원래 브랜치는 유지한다.
문서 충돌2개는 양쪽 기록 보존, Emulator는81 export/게스트 존재 검사로 갱신했다.
새 게스트 회귀의 요청만 B1 capability2에 맞춰 실제 온보딩 가드 검증을 보존했다.
session218/155, auth72/38, Functions494, GUI90, Emulator13 PASS/exit0다.
normal HB80회 sync0/queue0와 실제 false/close positive control 및 source 보존을 확인했다.
[통합 검증·미확인 사항](../../operations/HEARTBEAT_B1_IMPLEMENTATION.md#2026-10-13--디벨럽1-통합-후보)에
기록했다. 최종 통합 후보 FULL은 명시 승인 대기이며 push·배포·운영 접근은 이번 승인 범위에 없다.
