# LOBBY-DESIGN-01

## 2026-10-14 — 로그인 카드 비밀번호 재설정 후보

로그인 비밀번호 아래에 `비밀번호를 잊으셨나요?`를 추가하고, 별도 route 이동 없이
기존 `MosiAuthTransition` 안에서 재설정 폼과 발송 완료 안내로 교체한다. 로그인에서
입력한 이메일을 유지하며 같은 도메인 선택 UI를 사용한다. 발송 중 중복 탭을 막고,
완료 뒤 메일 재전송과 로그인 복귀를 제공한다. 한국어·영어·중국어 간체·번체 문구를
함께 추가했다.

메일은 Firebase Auth `sendPasswordResetEmail`로 발송한다. `user-not-found`를 성공과
같이 처리해 화면에서 계정 존재 여부를 노출하지 않으며, 형식·네트워크·요청 제한 오류는
현지화된 안내로 표시한다. 별도 Functions, DB/rules, 배포 변경은 없다. auth suite의
Flutter 80개와 Functions 38개, 변경 파일 정적 분석이 통과했다. 실제 Firebase 메일
수신과 링크의 브라우저 재설정 화면, 사용자 승인 FULL validation은 남아 있다.
[검증·보존 기록](../logs/2026-10.md#password-reset-20261014).

## 2026-10-14 — 태블릿 첫 화면 가로 시작 후보

태블릿 방향을 Flutter 첫 프레임 뒤에만 적용해 Android 시작 화면과 iPad 네이티브
시작 화면이 세로로 먼저 보일 수 있었다. Android는 기본/`sw600dp` resource로 기기를
나누고 `MainActivity.onCreate`의 `super` 호출 전에 태블릿만 sensor landscape를
요청한다. target API 36의 대화면 방향 제한 예외가 적용되도록 실제 앱 용도에 맞는
`android:appCategory="game"`도 선언했다. iPad 지원 방향은 좌·우 가로만 남겼고,
iPhone의 기존 지원 방향과 Flutter의 scene 활성화 후 재적용은 유지했다.

네이티브 설정 회귀 2개, Android debug APK 조립, plist/XML 문법 검사와 변경 파일
정적 분석이 통과했다. Android 태블릿과 iPad의 실제 콜드 스타트 및 사용자 승인
FULL validation은 남아 있다.
[검증·보존 기록](../logs/2026-10.md#tablet-native-start-orientation-20261014).

## 2026-10-12 — Selected-game theme propagation

The selected book now supplies the primary action colors to the empty-room
invite/retry action, the enabled player-count filter, and the phone waiting-room
`me` badge. The existing start, detail, phone background, and room-code accents
already used the same game theme. Error, warning, and neutral reset colors keep
their semantic roles. Relevant GUI tests passed; FULL validation was not run.
See [validation log](../logs/2026-10.md#lobby-theme-propagation-20261012).

## 2026-10-12 — Liar's Poker right-phone preview layout

Moved Minjun's cards above the `Liar` button while preserving the existing phone,
button pulse, and ring animations. A widget-position regression test now keeps the
card center above the button center. Preview and localization tests passed; FULL
validation was not run. See [validation log](../logs/2026-10.md#liar-preview-phone-layout-20261012).

로비 전체 디자인 개선

[작업 목록으로 돌아가기](../TASKS.md) · [관리 방법](../TASK_MANAGEMENT.md)

현재 분류·상태·다음 행동은 작업 목록을 기준으로 확인한다. 아래 날짜가 붙은 상태·결정은 당시 기록이다.

**로비 전체 디자인 개선**

- 사용자 요청을 등록했다. 화면 구성·정보 우선순위·시각 디자인의 구체적인 변경 범위는 미정이다.
- 완료 조건 초안: 개선 목표와 대상 화면을 정하고 주요 그룹·게임 진입 흐름을 유지한 채
  디자인을 적용·확인한다. 착수 시 구체화한다.

## 2026-10-08 검토 — newgui 구현 후보와 복구 통합

현재 checkout `02669c7`의 완료 작업으로 처리하지 않는다. 별도
[`newgui` 후보 `999c3e9`](https://github.com/WarmhanDongne/project00/tree/999c3e99086b9f917ea941cd8f283b8ac40f3f85)에
로비·인증·연결 안내 UI가 있으므로 병합 후보와 후속 작업 위치를 기록한다.
UI 코드 존재는 제품 범위 합의·세션 수정·검증·배포 완료의 근거가 아니다.

- 후보의 태블릿 진입은 기존 게임 목록/미리보기 modal에서
  [TabletHome](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/screens/tablet_home.dart),
  [TabletLobbySelection](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/tablet_lobby_selection.dart),
  [tablet_game_launcher](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/tablet_game_launcher.dart)로
  옮겨졌다. 선반/상세/방 패널을 유지하는 UI와 서버 선택·해제·seating·start를 함께 검증한다.
- 새 연결 UI 6종의 배선·표시 우선순위·busy/실패 안내·접근성·모달 중복·퇴장은
  [NEWGUI-RECOVERY-01](NEWGUI-RECOVERY-01.md#newgui-recovery-01)에서 관리하고,
  복구 완료·재구독·다중 단절·턴 보존의 실제 동작은
  [SESSION-RECONNECT-02](SESSION-RECONNECT-02.md#session-reconnect-02)와 연결한다.
  복구에 성공한 경우의 순수 체감 지연은 [NET-RECOVERY-01](NET-RECOVERY-01.md#net-recovery-01) 범위다.
- **추가 재현:** [TabletHome 자동 복원 gate](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/platform/home/tablet/screens/tablet_home.dart#L143)가
  상세·스토어·시작 처리 중 playing 이벤트를 보류한 뒤 다시 검사하는지 확인한다.
  후보의 접근 조건과 선택/해제 실패를 포함해 재현하며, 현재는 확정 회귀로 기록하지 않는다.
- [에셋 준비/다운로드](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/game_assets/game_asset_prepare.dart#L5)와
  [퇴장 route/연출](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/packages/game_kit/lib/widgets/game_exit_route.dart#L5)이
  비동기 진입 수명을 바꾼다. 뒤로가기·dialog·방 종료·강퇴·provider ownership과 늦은
  요청을 점검하고, 상태 정리는 route 완료 및 현재 방/판 검사를 기준으로 검증한다.
- 후보의 [게임 registry](https://github.com/WarmhanDongne/project00/blob/999c3e99086b9f917ea941cd8f283b8ac40f3f85/lib/games/game_registry.dart#L9)는
  라이어스포커·Final Call·Mafia·홀덤 4게임이다. 새 로비의 게임 진입·복귀·퇴장을
  네 게임의 phone/tablet 경로에서 확인한다. 홀덤의 서버 상태·중단 계약은 별도 검토한다.

다음 행동은 후보 병합 범위와 담당 파일을 정하고 기존 핵심 흐름·새 UI의 회귀 검증을
연결하는 것이다. 디자인 작업 등록으로 public API/persistent data/state-machine 변경이나
production 접근·배포가 승인되지 않는다.

## 2026-10-10 — 회원가입 메일 확인·로그아웃 전환 후보

- 사용자 요청: 회원가입 메일 인증 확인, 로그아웃 시 기존 요소가 나가고 로그인 요소가
  들어오는 애니메이션. 현재 `디벨럽1` checkout에서 수정했다.
- 인증 전환의 `MosiAuthTransition`이 퇴장하는 자식에만 wrapper를 추가해
  `RegisterScreen`을 재생성하는 결함을 재현했다. 이메일 링크 처리 중 auth 이벤트가
  오면 같은 링크 인증을 두 번 요청할 수 있었다. 진입·퇴장의 동일 key/구조를 유지해
  해결하고 앱 시작/실행 중 링크 수신과 지연된 가입 응답을 회귀 테스트에 추가했다.
- `AuthGate` 홈/인증 전환: 180ms 퇴장 후 로그인 요소 등장, 총 460ms.
  퇴장 중 입력·포커스·접근성 탐색 차단, 동작 줄이기 설정에서는 즉시 전환한다.
  내부 인증 단계는 동일 scaffold를 유지한다. 동작 줄이기의 0ms AnimatedSize에서
  재현된 layout 오류는 해당 연출을 생략해 해결했다.
- 프로필 로그아웃 중 중복 요청을 막고 실패 안내/재시도를 제공한다. 성공하면
  프로필 및 상점 등 상위 route를 닫아 로그인 화면을 가리지 않게 한다.
- 메일 발송 설정·잘못된/만료된 링크·서버 가입 요청 순서·토큰 갱신 1회 재시도
  로컬 검증 통과. 실제 메일 발송/수신, 배포된 링크 연결과 실기기 앱 복귀는 미확인이다.
  production 조회·메일 발송·deploy는 수행하지 않았다. FULL 명시적 승인 대기.
- 명령별 결과와 working-tree 보존 증거:
  [10월 기록](../logs/2026-10.md#auth-mail-logout-20261010).

## 2026-10-11 — 내 프로필 하단 구분선 제거

취소·저장 버튼 바로 위 2px 선을 제거했다. 해당 Container를 Padding으로 바꿔
기존 여백과 버튼 배치를 유지한다. 기존 프로필·상점 GUI 테스트 17개 PASS/exit0.
FULL은 미실행이며 명시적 승인 대기다.
[검증·보존 기록](../logs/2026-10.md#profile-divider-20261011).

## 2026-10-11 — 게임 상점 진입 버튼 임시 숨김

사용자 요청으로 로비의 게임 상점 버튼을 숨겼다. `_HomeHeader._showGameStore`를
true로 바꾸면 다시 표시된다. 상점 코드·진입 연출과 게임 상세의 책장 복귀 버튼은
유지한다. 기존 로비·상점 GUI 테스트 34개 PASS/exit0. FULL은 승인 대기다.
[검증·보존 기록](../logs/2026-10.md#hide-game-store-20261011).

## 2026-10-12 — 비밀번호 계정 우선 이메일 인증 복원 후보

- 사용자 요청에 따라 새 가입을 약관 → 이메일·비밀번호 계정 생성 → 일반 웹 인증
  메일 → 프로필로 변경했다. Firebase `createUserWithEmailAndPassword`와
  `sendEmailVerification`을 사용하며 현재 GUI·비밀번호 정책·약관은 유지한다.
- `EmailVerificationScreen`은 재전송·확인 버튼·앱 복귀 확인·가입 나중에 하기를
  제공한다. 미인증 비밀번호 로그인/앱 재시작도 이 화면으로 복원한다.
- 기존 발송된 이메일 로그인 링크와 `settingPassword` 상태는 계속 처리한다.
  기존 계정/온보딩 상태를 덮어쓰지 않는다.
- 서버 계약: `beginOnboarding`의 선택 인자 `{provider: "legacyPassword"}`는
  비밀번호 provider를 확인하고 기존 enum `legacyPassword/settingProfile`로 미완료
  가입을 준비한다. `completeOnboardingProfile`은 이 계정의 Firebase 이메일 인증을
  서버에서 다시 검사한다. 새 상태/collection/callable은 추가하지 않았다.
- **미배포 후보:** 위 두 인증 함수를 함께 배포한 뒤 새 앱을 적용해야 한다.
  기존 서버만으로 새 앱 가입이 된다고 판단하지 않는다. FULL, production 배포와
  실제 메일 수신·인증 후 앱 복귀는 아직 확인하지 않았다.
- auth suite 60 Flutter + 20 Functions, 관련 GUI 20개 PASS/exit0. 정적 분석 통과.
  [검증·보존 기록](../logs/2026-10.md#password-email-verification-20261012).

## 2026-10-12 — 태블릿 입력 도구막대에 따른 인증 화면 이동 방지

태블릿 인증 scaffold는 키보드 inset으로 전체 화면을 축소하지 않고 기존 safe area와
중앙 배치 높이를 유지한다. 입력 폼의 스크롤 영역만 키보드와 겹치는 만큼 줄여,
작은 도구막대에는 배치가 유지되고 큰 키보드에서는 가려진 입력란·하단 버튼으로
스크롤할 수 있다. 휴대폰 분기와 OS 자동완성 기능은 유지한다.
auth suite 63 Flutter + 20 Functions PASS/exit0. iPad 실기기 및 FULL 승인 대기.
[검증·보존 기록](../logs/2026-10.md#auth-keyboard-toolbar-20261012).

## 2026-10-12 — Firebase 게스트 로그인·방 권한 연결 후보

로그인 화면의 Google·Apple 위에 게스트 버튼을 추가했다. 익명 로그인 뒤 필수 약관에
동의하면 서버가 `anonymous/complete` 온보딩과 자동 닉네임을 저장하고 Firebase
displayName도 맞춘다. 단순 익명 인증만으로는 방 생성·코드 검증·참가가 모두 차단되며,
준비가 완료된 게스트만 기존 `assertOnboardingComplete`를 통과한다. 기본 무료 게임은
이용할 수 있고 유료 게임은 기존 그룹 보유 검사 대상이다. 일반 계정이 게스트 함수를
사용해 회원가입을 건너뛰거나, 재시도가 닉네임·보유 게임·동의를 덮어쓰지 못하게 했다.
한국어·영어·중국어 간체·번체 버튼 문구를 제공한다.

로컬 인증/방 검증 후 2026-10-13 운영 Firebase에서 Anonymous provider의 활성 상태를
확인하고 `completeGuestOnboarding` 단일 함수를 배포했다. FULL·실기기 전체 흐름 확인은
남아 있다.
[검증·보존 기록](../logs/2026-10.md#guest-auth-20261012).
