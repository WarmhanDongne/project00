# SECURITY-01

보안 위험 점검·중대한 문제 수정

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

**보안 위험 점검·중대한 문제 수정**

- 사용자 요청: 문제가 발생할 때의 리스크가 크므로 최소한 어떤 문제가 가능한지 점검한다.
- 조사 범위 초안: 인증·인가, Functions 요청 검증, Firebase rules, 공개/개인/서버 데이터
  경계, 비밀정보 노출, 남용 가능성. 실제 코드와 설정을 확인한 범위를 명시한다.
- 추가 조사(2026-10-04): RTDB players·selectedGame·일부 방 메타데이터의 로그인만 요구하는
  읽기 권한을 참가 전/참가자/controller/외부 계정별로 점검한다. App Check는 앱 토큰 발급이
  구현됐으나 Functions 코드에서 검증 강제는 발견하지 못했다. 콘솔 enforcement는 미조회다.
  관찰 모드·기기별 발급·구버전 호환성과 적용 범위를 확인하고 강화 여부를 결정한다.
  코드 확인과 콘솔 미확인을 구분하며 production 설정 변경은 미실행이다.
- 완료 조건: 위험·영향·근거·대응을 정리하고 출시 차단 수준의 문제를 수정·검증한다.
  미점검 영역과 남은 위험을 밝힌다. 점검 완료를 모든 보안 위험 부재로 표현하지 않는다.

## 2026-10-08 newgui 999c3e9 기준 추가 조사

- 조사 기준: `origin/newgui`의 `999c3e99086b9f917ea941cd8f283b8ac40f3f85`를
  checkout에 반영하지 않고 정적으로 비교했다. 새 권한 테스트·실기기 재현·운영 설정
  조회는 수행하지 않았으며 App Check 콘솔 enforcement도 미확인 상태를 유지한다.
- [newgui RTDB rules](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/database.rules.json#L28)의
  controller presence 쓰기는 UID를 확인하지만 controller session과 closed 상태를
  확인하지 않는다. players·selectedGame 등 로그인만 요구하는 읽기 범위도 남아 있다.
  참가 전·참가자·controller·외부 계정 및 이전 앱 인스턴스별 허용 범위를 대조해야 한다.
  필요한 공개 범위를 결정하기 전에 모든 읽기를 일괄 제한하지 않는다.
- Holdem이 추가됐으므로 [행동 요청 검증](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/holdem/act.ts#L24)과
  [controller 요청 검증](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/holdem/validation.ts#L51)도
  역할별 조사 범위에 포함한다. 공개 게임 데이터, 본인 private 데이터, server 데이터의
  기존 경계와 재접속·퇴장 후 접근을 함께 확인한다. 조사 범위 추가를 안전성 확인으로
  표현하지 않는다.
- [서버의 character ID 허용 목록](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/functions/src/room/realtime-room-functions.ts#L45)과
  rules는 새 얼굴 ID와 배포된 앱의 기존 동물 ID를 함께 허용한다. 권한 검토 때 UI
  이미지 변경과 저장 ID 호환성을 구분하고 기존 앱의 유효한 ID를 임의로 제거하지 않는다.
- 권한 정책·controller 세션 경계·App Check 강화 여부는 영향과 구버전 호환성을 확인해
  결정한다. production 접근·rules 변경·배포에 대한 기존 승인 조건과 현재 출시 분류를
  이 문서 갱신으로 바꾸지 않는다.
