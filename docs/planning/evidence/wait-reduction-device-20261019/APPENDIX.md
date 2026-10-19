# 실기기 평가 부록

## 자료·계산

20개 원본은 사용자가 마지막에 지정한 5/5/5/5 목록으로 고정했다. 예비·목록 외 수집은 제외한다. integrity.json의 파일 SHA-256을 다시 계산하고 manifest 이벤트 개수, 실제 분석기 재실행 결과와 저장 summary의 주요 판정을 대조했다. `measurements.json`에 원본 파일 해시·Git 상태·재계산 값, `recalculated.json`에 전체 분석 결과, `trials.csv`·`stages.csv`에 재사용 수치를 남겼다. 원본 파일을 수정하지 않았다.

- 동일 기기: (종료 mono_us − 시작 mono_us)/1,000,000. 기기 간: 분석기의 host_range 추정 경계를 사용한다. 전체 구간 [max(종료 하한)−시작 상한, max(종료 상한)−시작 하한]. 5ms 및 200ppm 여유를 포함한 추정이다.
- 표 대표값: 각 구간 상·하한의 중간값을 표본별 계산 후 중앙값·최소·최대. 단계 중앙값을 합산하지 않는다. 입력 준비 이후 카드 선택·제출은 시작 시간에서 제외한다.
- 조회 겹침=max(0,min(조회 완료,전환 대기 시작)−조회 시작). 잔여=max(0,조회 완료−전환 대기 시작). 같은 시도의 첫 lookup에 연결했으며 5건 모두 성공·fallback 0이다.
- 취소·close 겹침=max(0,min(각 종료)−max(각 시작)). 이를 전체 단축량으로 계산하지 않는다. 서버 종료 확인 뒤 신원 정리 순서와 old/new room·connection 별칭 분리를 확인한다.
- 새 방 유지: 모든 역할이 같은 새 방에서 참가자 2명을 처음 관측한 시각의 상한 중 최댓값부터, 첫 기기 stop 하한까지 ≥30초. 그 뒤 새 방 clear 또는 참가자 감소가 없는지 확인한다. 원 수집기보다 엄격하게 전체 참가 완료를 기준으로 재검산했다.

## 원본 판정과 복원 분리

결과 재시작 `165703-6e50d9dc` 원본 issues는 missing_or_duplicate_tablet_deal_started다. 태블릿 seq38이 시작 배분이고 seq105·168은 첫 제출 검증이 끝난 뒤의 다음 라운드다. seq·원문은 보존했다. 메모리 사본에서 첫 제출 결과의 host 상한 뒤 seq105·168만 post_validation_tablet_deal_started로 재분류하여 동일 분석기를 재실행했다. 새 시작 조작은 1개이고 같은 게임이다. 파생 결과는 VALID_OBSERVED_TRIAL, 전체 12.936612~12.973888초, 대기 제외 11.829544~11.955904초다.

원본 자동 판정 통과는 19/20, 결과 재시작의 본문 통계 n=4를 유지한다. 복원 1건까지 포함한 민감도 표는 n=5: 전체 중앙값 12.210초, 최소 11.268~최대14.141초, 대기 제외 중앙값 11.609초(정확 값은 파생 JSON과 CSV로 재계산 가능). 이 항목은 재수집 필수로 판단하지 않는다. 첫 시작 완료와 첫 제출 근거는 보존됐지만 수집기 전 구간 판정을 바꿔 쓰지는 않는다.

## 파일 대응

| 시나리오/회차 | 원본 수집 이름 | 판정 |
| --- | --- | --- |
| 최초 시작/1 | debug-game-start-20261019-162841-6876562d | 원본 통과 |
| 최초 시작/2 | debug-game-start-20261019-163434-1e59481a | 원본 통과 |
| 최초 시작/3 | debug-game-start-20261019-164026-e1d8ce9c | 원본 통과 |
| 최초 시작/4 | debug-game-start-20261019-164142-21f601d2 | 원본 통과 |
| 최초 시작/5 | debug-game-start-20261019-164234-757bf668 | 원본 통과 |
| 메뉴 재시작/1 | debug-game-start-20261019-164407-ac20aa14 | 원본 통과 |
| 메뉴 재시작/2 | debug-game-start-20261019-164531-d00f9ce1 | 원본 통과 |
| 메뉴 재시작/3 | debug-game-start-20261019-164604-59a8b0a3 | 원본 통과 |
| 메뉴 재시작/4 | debug-game-start-20261019-164648-b521dbf4 | 원본 통과 |
| 메뉴 재시작/5 | debug-game-start-20261019-164724-6de83b15 | 원본 통과 |
| 결과 재시작/1 | debug-game-start-20261019-165158-7cbc9452 | 원본 통과 |
| 결과 재시작/2 | debug-game-start-20261019-165256-8626d8e7 | 원본 통과 |
| 결과 재시작/3 | debug-game-start-20261019-165425-fa0f2ad4 | 원본 통과 |
| 결과 재시작/4 | debug-game-start-20261019-165703-6e50d9dc | 원본 무효·첫 구간 별도 복원 |
| 결과 재시작/5 | debug-game-start-20261019-170326-b81efb66 | 원본 통과 |
| 초기화/1 | debug-game-start-20261019-170529-133d5002 | 원본 통과 |
| 초기화/2 | debug-game-start-20261019-171152-538fa429 | 원본 통과 |
| 초기화/3 | debug-game-start-20261019-195235-d8c96236 | 원본 통과 |
| 초기화/4 | debug-game-start-20261019-195407-ebe5a60d | 원본 통과 |
| 초기화/5 | debug-game-start-20261019-203148-c93c1ef8 | 원본 통과 |

## 코드·버전·보존

기능 기준은 ea08181a1d1ca6f51588a87fc3731fba06b84da2. 앱 보고 build_id는 b4874c569062687022afa18562ba6b723fd55881f0ef28effcedc64fb820907e, APK SHA-256은 5955a961dd0303255fd79645bd5496fa933f1a9ae3c0e58fc65811a14bb1bd56. 빌드 표식 및 APK 파일 해시 연결은 확인하지만 Android 설치 이미지를 독립 추출해 동일성을 입증한 것은 아니다. collector 작업 사본 소스와 APK 빌드 소스는 아래 매니페스트로 분리 보존한다.
기능 코드는 lib/platform/home/tablet/tablet_game_launcher.dart·tablet_start_cleanup.dart, lib/platform/home/room/services/room_service.dart. 계측 변경과 기능 변경은 별도 커밋으로 기록하며 통합에는 기능 커밋만 적용한다. ea08181에는 앱 코드 외 기존 인수인계·근거·회귀 테스트·환경 경로 수정도 포함되어 있어 커밋 전체를 확인한다.
원본 경로: 기록 worktree의 artifacts/performance-captures/<수집 이름>. 로컬 백업: 원 수집 checkout의 build/device-test/wait-reduction-records-backup-20261019/backup-manifest.json. 243개 파일 1,248,044,670bytes 복사·해시 일치. 원본 유지, 같은 디스크의 로컬 사본이며 외장/클라우드 백업은 아니다. APK·모든 10/19 수집·두 영상·진단 및 계측 소스의 당시 사본을 포함한다.
원본 동영상은 사용자 지정 Downloads의 R2/S4 파일을 읽었다. video-inventory.json에 길이·표본 시점이 있으며 원본 SHA-256은 백업 manifest에 있다. 영상 프레임은 ignored 분석 폴더에만 보존하고 Git에 넣지 않는다.

## 검증 실행 기록

analyze.py: PASS/exit0(원본19 통과·1무효); 파생 복원: PASS/exit0(원문 변경 없음); preserve.py: PASS/exit0(243개 해시 확인); video.ps1: PASS/exit0(Windows 내장 API, 새 dependency 없음). 첫 분석 실행은 Git worktree 읽기 sandbox 권한으로 exit1이어서 권한 부여 뒤 동일 계산을 재실행했다. 원본 checkout tracked 상태는 clean이다. 통합 targeted/FULL/최종 실기기 확인은 별도 최신 기록을 따른다.


## 통합 준비 결과

원격 develop fetch는 exit0이다. origin/develop은 b10fc43, 로컬 develop은 그 뒤 4325d69(로컬 추가 규칙 1건)였다. 이를 보존한 develop에서 새 codex/wait-reduction-integration을 만들고 기능 ea08181만 cherry-pick해 25d3ea3a31c87caa8bb6ba388e4bb777b2b0f1a7이 됐다. 트리는 원 기능 커밋과 완전히 같으며 Debug 계측 코드·수집기가 없다. 원 수집 checkout은 clean, 기록 브랜치는 원본 untracked 수집만 남았다.

새 worktree audit은 의존성 미준비로 BLOCKED/exit3, 기존 Prepare 승인 범위에서 기존 lock 기준 환경 준비 후 doctor PASS/exit0·Git 변화 없음. guarded test session은 PASS/exit0(29 Flutter/15 Functions 파일), 직접 관련 3개 파일은 39 tests PASS/exit0이다. 실행 원문과 상태는 ignored 분석 폴더의 integration-*.json/stdout/stderr에 보존한다. FULL은 적용 skill에 따라 새 후보의 명시적 승인을 요청했으며 아직 실행하지 않았다. develop 병합·push는 수행하지 않았다.

초기화 5건의 각 새 방에서 후속 게임 시작까지 이어진 별도 initial_start 로그 연결은 확인하지 못했다. R2 영상에는 새 방 게임 진행 1사례가 있다. 전체 5건을 후속 게임까지 자동 검증했다고 표현하지 않는다. G1 생략·V1 보류를 유지하고 계측 없는 최종 앱의 정상 시작·초기화·새 방 확인은 남긴다.
