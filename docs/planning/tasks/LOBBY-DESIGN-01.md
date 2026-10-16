# LOBBY-DESIGN-01

## 2026-10-16 — 휴대폰 내 프로필 중첩 배지

휴대폰의 일반 참가자 세로 목록과 게임 선택 뒤 가로 플레이어 목록에서 `나` 표시를
닉네임 옆이나 얼굴 아래 중앙에 두지 않고, 내 캐릭터 얼굴 오른쪽 아래에 작은 배지로
겹쳤다. 프로필과 배지가 하나의 시각 단위로 보이면서 닉네임 공간은 그대로 사용할 수
있다. 가로 목록의 배지 색은 선택 게임 테마를 계속 따른다.

배지 중심이 얼굴 중심보다 오른쪽·아래에 있고 두 사각형이 실제로 겹치며, 배지가 얼굴보다
작다는 위치 회귀를 추가했다. 관련 대기실·로비 GUI 37개와 정적 분석이 통과했다.
[검증·보존 기록](../logs/2026-10.md#phone-me-badge-20261016).

## 2026-10-16 — 휴대폰 화면 배경의 방향성 전환

휴대폰 route 전환은 이전 화면을 제자리에 유지하고 새 화면을 오른쪽 위에서 왼쪽 아래로
덮는 그라데이션 마스크를 사용한다. 전체 화면 페이드·미세 확대를 제거해 가장자리에서
기본 canvas가 비치는 프레임을 만들지 않는다. 대기실은 선택 전 보라색, 게임별 소개색,
자리 배치의 테이블색을 하나의 살아 있는 배경 레이어에서 전환한다. 상태마다 불투명
`Scaffold`를 교체하지 않으므로 게임 선택·해제와 `waiting → seating → playing` 경계에서도
흰색이나 검정색 바탕이 끼지 않는다.

그룹 나가기도 기존 대기실을 투명하게 축소·페이드하지 않고 같은 방향성 색 레이어가
덮은 뒤 안내 요소가 나타난다. QR↔코드처럼 배경이 변하지 않는 한 화면 내부 요소 전환과
게임의 의도된 매트 펼침은 유지했다. 동작 줄이기 설정에서는 즉시 최종색을 표시한다.

빠른 연속 게임 선택은 진행 중인 경계를 끝낸 뒤 마지막 선택색만 이어서 덮어 중간
전체색 점프를 막는다. 입장·대기실·로비·인증·프로필 GUI 69개, 정적 분석과 Project CLI session의 Flutter
219개·Functions 155개·working-tree mutation 검사가 통과했다. 실제 OLED/LCD 휴대폰의
전환 경계와 GPU 프레임은 후속 실기기 확인 대상이며 FULL은 사용자 승인 대기다.
[검증·보존 기록](../logs/2026-10.md#phone-background-wipe-20261016).

## 2026-10-16 — 태블릿 로비 전체화면·책 중심 자리배치 전환

태블릿은 앱 첫 Flutter frame과 로비부터 `immersiveSticky` viewport를 사용한다. 자리
배치 직전에 시스템 바를 숨기는 동작을 제거해 SafeArea와 로비 요소 크기가 시작 버튼 뒤에
다시 계산되지 않는다. 로비에서는 wakelock을 끄고 실제 게임에서만 켜며, 자리 배치 취소와
태블릿 게임 종료 뒤에도 시스템 바를 켜지 않고 같은 로비 viewport로 돌아온다.

자리 배치 진입은 선택한 게임의 실제 표지를 선반 위치에서 화면 중앙으로 먼저 옮긴다.
동시에 머리줄·선반 정보·방 패널이 각 방향으로 짧게 퇴장하고, 자리 배치 화면은 중앙 책
주변에서 전체 화면으로 퍼진다. 총 920ms 시간축을 대기실 복귀에서 그대로 역재생한다.
서버 선택 해제는 기존처럼 복귀 연출과 병행하고, 참가자 변경 자동 복귀도 같은 callback을
사용한다. 동작 줄이기 설정에서는 전환을 즉시 완료한다.

책 중앙 좌표·비율과 화면 확장 순서, 진입/복귀 동일 시간, 서버 응답을 기다리지 않는 복귀,
태블릿 immersive mode를 회귀 테스트로 고정했다. 관련 GUI·정적 분석과 Project CLI session
suite가 통과했다. 실제 iPad/Android 태블릿에서 시스템 gesture 표시 상태와 920ms 체감은
후속 확인 대상이며, FULL은 연속 개선의 최종 후보에서 사용자 승인 후 실행한다.
[검증·보존 기록](../logs/2026-10.md#tablet-lobby-fullscreen-book-transition-20261016).

## 2026-10-16 — 휴대폰 입장 흐름의 고정 요소 전환

- 홈→그룹 참여, 코드 확인→닉네임·캐릭터, 입장 완료→대기실과 저장 세션→대기실에
  공통 `PhoneFlowRoute`를 적용했다. iOS 기본 좌우 밀림 대신 이전 화면을 제자리에 둔 채
  새 내용이 페이드와 0.985→1 미세 확대를 거쳐 안착하며 뒤로 갈 때도 같은 형태로 빠진다.
- QR 스캔↔방 코드 입력은 route를 만들지 않는다. 상단 `그룹 참여하기`, 보라색 배경,
  방 코드 칸을 유지하고 제목·설명·스캔 안내·입력 안내·하단 버튼·전용 자판만
  `PhoneFlowContentSwap`으로 280ms 안에 교체한다. 동작 줄이기에서는 즉시 바뀐다.
- 전환 중 빠지는 카메라를 계속 보관하지 않도록 교체 완료 뒤 scanner widget을 제거한다.
  다시 QR 화면으로 돌아갈 때는 `MobileScannerController(autoStart: false)`를 다음 프레임에
  시작해 build 중 notifier 갱신과 카메라 중복 시작을 피한다.
- 방 코드 검증, 참가 요청, provider ownership과 서버 상태 계약은 바꾸지 않았다.

관련 휴대폰 GUI 26개와 정적 분석, Project CLI session Flutter 219개·Functions 155개,
working-tree mutation 검사를 PASS했다. 실제 iPhone/Android에서 카메라 권한 허용·거절,
홈 제스처 영역과 전환 체감은 후속 확인 대상이다. FULL은 연속 개선의 최종 후보에서
사용자 승인 후 실행한다.
[검증·보존 기록](../logs/2026-10.md#phone-entry-flow-transition-20261016).

## 2026-10-16 — 태블릿 시작·자리 배치 복귀 전환 안정화

태블릿에서 시작하기를 누른 뒤 서버 준비를 기다리는 동안 로비의 책 위 준비 배지와
시작 버튼 로딩 교체를 사용하지 않게 했다. 머리줄·책장·방 패널은 기존 크기와 위치를
유지하고 입력만 잠근다. 상세→선반 상태 정리도 책 열림 route가 화면을 완전히 덮은
뒤 수행해 전환 뒤의 로비가 먼저 움직이지 않는다.

방 패널의 초기화 표시는 실제 방 초기화를 실행할 때만 `초기화 중`으로 바뀐다. 게임
선택·에셋 준비·자리 배치 시작이 공용 `isLoading`을 사용하더라도 초기화 버튼의 문구와
폭은 유지된다.

자리 배치의 대기실 버튼은 회전 로딩으로 바뀌지 않는다. 미확정 게임 시작 요청이 없는지
로컬에서 확인한 뒤 route를 바로 닫고, 서버의 `seating → waiting` 선택 해제는 복귀
애니메이션과 병행한다. 실패하면 복귀한 로비에서 재시도 안내를 제공한다. 책 열림 route의
복귀 시간을 진입과 같은 760ms로 맞춰 같은 연출을 역재생한다. 참가자 구성이 바뀌어
자동 복귀하는 경로도 같은 처리 순서를 사용한다.

관련 로비·책장·자리 배치 회귀 42개와 변경 파일 정적 분석이 통과했다. Project CLI
session도 Flutter 219개, Functions 155개, working-tree mutation 검사까지 PASS했다.
연속 개선의 최종 후보가 아니므로 사용자 승인 FULL validation은 아직 실행하지 않았다.
[검증·보존 기록](../logs/2026-10.md#tablet-start-return-transition-20261016).

## 2026-10-15 — 휴대폰 그룹 나가기 즉시 전환

사용자가 승인한 시안에 맞춰 휴대폰 대기실의 그룹 나가기를 누르는 즉시 현재 요소가
빠져나가고 선택한 게임 색의 전환 화면이 나타나게 했다. 중앙 문 아이콘과 진행 점,
`그룹에서 나가는 중이에요` 안내가 서버 응답 시간을 가린다. 실제 홈 이동은 서버가
퇴장을 확정한 뒤에만 수행한다.

실패 시에는 기존 대기실 위에 오류 카드를 열고 `대기실로 돌아가기`와 `다시 시도`를
제공한다. 대기실 복귀는 화면만 되돌리며 미확정 durable 퇴장 의도를 취소하지 않는다.
따라서 헤더의 그룹 나가기 또는 오류 카드의 다시 시도로 같은 요청을 안전하게 이어간다.
퇴장 확정 전 게임 시작 상태가 와도 게임 화면을 열지 않는다. 네 언어와 동작 줄이기
설정을 함께 지원한다.

전환·실패 복귀·재시도 GUI 14개와 관련 정적 분석은 통과했다. Project CLI session은
기존 heartbeat 복구 테스트 한 건이 30초 제한을 넘어 FAIL했지만, 같은 테스트를 단독으로
재실행하면 PASS했다. Functions 155개와 working-tree mutation 검사는 PASS했다. 연속
개선의 최종 후보가 아니므로 사용자 승인 FULL validation은 아직 실행하지 않았다.
[검증·보존 기록](../logs/2026-10.md#phone-room-leave-transition-20261015).

## 2026-10-15 — 프로필 즉시 반영·백그라운드 동기화 후보

내 프로필의 저장을 누르면 입력한 닉네임과 사진을 현재 UID의 화면 초안으로 즉시 반영하고
모달을 닫는다. 태블릿·휴대폰 프로필과 이후 방 입장 닉네임은 같은 초안을 사용한다. 실제
Firebase Auth 사진/닉네임과 프로필 문서 저장은 기존 순서를 유지한 채 뒤에서 진행하며,
동기화 중 표시와 완료 안내를 제공한다. 실패해도 사용자가 본 값을 갑자기 되돌리지 않고
실패 표시와 다시 시도 동작을 제공한다. 로그아웃·회원탈퇴 때는 초안을 제거한다.

프로필 GUI 19개와 Project CLI auth suite(Flutter 80개·Functions 38개), 변경 파일 정적
분석과 diff 검사가 통과했다. 기본 PATH의 Node 24는 저장소 요구 Node 22와 달라 첫 auth
suite가 BLOCKED였고, 설치된 Node 22.23.1과 Flutter SDK 경로를 사용한 재실행은 PASS했다.
서비스 전체 체감 지연은 기존 50개 후보 조사를 현재 코드에 다시 대조하고 있으며, 제품
결정이 필요한 항목은 영향이 큰 순서로 사용자와 한 항목씩 결정한다. 사용자 승인 FULL
validation은 이 연속 개선의 최종 후보에서 실행한다.
[검증·보존 기록](../logs/2026-10.md#profile-optimistic-save-20261015).

## 2026-10-15 — 책 아래 게임 소개 확대 후보

태블릿 선반의 선택 게임 제목을 최소 32px, 영문명 14px, 설명 16px,
인원·시간 14px, 자세히 보기 버튼 17px로 키웠다. 여유가 있는 화면에서는 각각
40/16/18/15/18px까지 사용한다. 소개 영역 높이를 먼저 확보하고 작은 화면에서는
책 그림을 더 줄이며, 긴 제목·영문명과 시작 인원 알약은 가용 폭을 넘을 때만
비율 축소한다. 설명은 줄 수를 자르지 않고 자연스럽게 줄바꿈한다.

한글·영어·중국어 간체·번체, 7개 태블릿 가로/세로 크기와 글자 배율 1.3의
텍스트 잘림 검사가 통과했다. 확대 과정에서 768px 세로 화면의 긴 시작 인원
알약 overflow를 발견해 폭 맞춤을 추가한 뒤 재검사했다. 책 선택·스와이프·상세
열기 14개 회귀와 변경 파일 정적 분석도 통과했다. 사용자 승인 FULL validation은
남아 있다. [검증·보존 기록](../logs/2026-10.md#shelf-caption-type-20261015).

## 2026-10-15 — 기기가 제공한 전체 scene 사용 후보

iPadOS 26부터 legacy `UIRequiresFullScreen` 적용을 중단하고 iPad의 네 방향을 지원한다.
별도 Flutter view controller 방향 잠금과 `SceneDelegate` geometry 요청은 제거했다.
따라서 앱은 고정 가로 호환 창을 요청하지 않고 iPadOS가 제공한 전체 scene을 현재
방향으로 채운다. iPadOS 25 이하는 기존 `UIRequiresFullScreen` 요청을 유지한다.
Android launcher activity는 resize와 picture-in-picture를 끄고 API 36 대화면 호환
속성을 사용한다. 기존 `game` category와 태블릿 sensor landscape 시작도 유지한다.

iOS simulator debug 앱과 Android debug APK 빌드, 네이티브 설정 회귀 2개,
plist/XML 문법 검사가 통과했다. iPadOS 26.4 시뮬레이터가 Windowed Apps 상태에서는
콜드 스타트 뒤에도 시스템 창으로 열렸다. 앱은 할당받은 scene을 채우지만 앱이 해당
창을 자동 최대화하거나 시스템 설정을 Full Screen Apps로 바꾸는 지원 API는 없다.
연결된 iPad는 unavailable 상태여서 실기기 재설치는 못 했다. 사용자 승인 FULL
validation과 Android 대화면 확인은 남아 있다.
[검증·보존 기록](../logs/2026-10.md#platform-fullscreen-start-20261015).

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

## 2026-10-16 — 게임 상점 진입 버튼 재공개

사용자 요청에 따라 태블릿 로비 왼쪽 위의 게임 상점 버튼을 다시 표시했다. 기존 상점
route와 로비 요소 퇴장·복귀 연출을 그대로 사용하며, 상점 진열 기준이나 구매 기능은
변경하지 않았다. 재공개 시점의 상점은 개인 로비 목록으로 이미 접근 가능한 게임 중
Firestore `storeVisible == true`인 항목만 보여 줬다. 같은 날 후속
[STORE-ENTITLEMENT-01](STORE-ENTITLEMENT-01.md#store-entitlement-01)에서 상점과 library
카탈로그를 분리했다.
[검증·보존 기록](../logs/2026-10.md#show-game-store-20261016).

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
