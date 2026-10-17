# 게임 시작 테스트 기록 복원

첨부 터미널 기록과 저장된 summary.json을 대조했다. 회차는 실패 시도를 제외한 유효 표본 순서로 복원한 번호다. 사용자가 당시 적었던 회차 번호를 확인한 것은 아니다.

6건 모두 initial_start, VALID_OBSERVED_TRIAL, pilot_passed=true이며 카드 선택·제출 성공 검증을 통과했다. 일반 COLLECTED 5건과 복구된 FAILED 1건이다. 사용자 특이사항 메모가 없어 정상 건은 로그상 결과만 기록한다.

항목: 게임 시작
회차: 1
수집 폴더: artifacts\performance-captures\debug-game-start-20261018-005036-0503abb7
특이사항: 별도 사용자 메모 없음. 저장 로그 검증 통과.

항목: 게임 시작
회차: 2
수집 폴더: artifacts\performance-captures\debug-game-start-20261018-005153-def595be
특이사항: 별도 사용자 메모 없음. 저장 로그 검증 통과.

항목: 게임 시작
회차: 3
수집 폴더: artifacts\performance-captures\debug-game-start-20261018-010031-cd88cf80
특이사항: 제출 성공 후 Ctrl+C 종료 시 수집기 오류로 FAILED. 이후 복구본 검증 통과. 원본과 복구본은 같은 테스트 1건.
복구 폴더: artifacts\performance-captures\recovered-debug-game-start-20261018-010031-4153e545

항목: 게임 시작
회차: 4
수집 폴더: artifacts\performance-captures\debug-game-start-20261018-011357-b4d246c7
특이사항: 별도 사용자 메모 없음. 저장 로그 검증 통과.

항목: 게임 시작
회차: 5
수집 폴더: artifacts\performance-captures\debug-game-start-20261018-011455-1bb8ff18
특이사항: 별도 사용자 메모 없음. 저장 로그 검증 통과.

항목: 게임 시작
회차: 6
수집 폴더: artifacts\performance-captures\debug-game-start-20261018-011603-364f9072
특이사항: 별도 사용자 메모 없음. 저장 로그 검증 통과.

## 별도 보존: 위 6건에서 제외

- 이전 메뉴 재시작 예비 수집: artifacts\performance-captures\debug-game-start-20261018-002851-bc6fb4ee. 첨부 첫 줄의 COLLECTED는 이 기록이며 게임 시작 본 수집에 합치지 않는다.
- 수집 실패: artifacts\performance-captures\debug-game-start-20261018-005259-48330e9b. COLLECTING 이후 FAILED. 유효 표본에서 제외하며 사용자 조작이나 게임 오류 원인은 이 기록 복원에서 단정하지 않는다.
- 준비 실패: artifacts\performance-captures\debug-game-start-20261018-005434-e1faa81d. COLLECTING 전 FAILED, 저장 이벤트 0건. 유효 표본에서 제외한다.

첨부에는 새로운 메뉴·결과 재시작 본 수집 기록이 없다. 명령에 --pilot이 있어도 이번 본 수집에서도 검증용으로 사용했으므로 옵션만으로 과거 예비 수집으로 분류하지 않았다.

회차는 1, 2 → 실패 2회 → 복구된 3 → 4, 5, 6의 순서다. 폴더 이름의 시각을 버튼 조작 시각으로 사용하지 않았다. 원본 자료 및 기존 보고서는 수정하지 않았다.
