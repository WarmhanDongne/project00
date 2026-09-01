# Mosigame mobile store release checklist

이 문서는 `1.0.0+2` 모바일 첫 출시의 코드 밖 작업과 안전한 배포 순서를 기록한다.
production 접근·배포·스토어 제출은 사람이 각 콘솔에서 승인해 수행한다.

## 0. 현재 출시 후보 상태

- 2026-08-31 로컬 `shorebird release android/ios --dry-run`은 `1.0.0+2`로
  둘 다 PASS했다. Android AAB는 target SDK 36, 서명, 64비트 16KB ELF
  정렬을 통과했고 iOS archive는 번들 ID, iOS 15, Privacy Manifest,
  Firebase App Check, Shorebird asset 포함을 확인했다.
- Flutter analyze와 648개 테스트, Functions build·lint·276개 테스트는
  PASS했다.
- 저장소 공식 auth/session 검증과 FULL 검증은 Node 22에서 PASS했다. FULL 검증은
  Flutter 3.44 분석 서버의 한글/NFD 작업 경로 오류를 피하기 위해 HEAD, 전체 diff,
  tracked/untracked 상태 해시가 같은 임시 영문 경로 복제본에서 실행했다.
- 2026-08-31 Firebase Hosting을 배포했다. `firebaseapp.com`과 `web.app` 양쪽에서
  AASA와 `assetlinks.json`이 HTTP 200·`application/json`이며 로컬 JSON과 의미상
  일치함을 확인했다. Android 파일에는 `com.warmhandongne.msg`와 로컬/Play App
  Signing SHA-256이 모두 들어 있다.
- 공개 `/privacy/`와 `/account-deletion/`은 양쪽 Hosting 도메인에서 HTTP 200이며
  운영자명과 지원 이메일이 포함된 것을 확인했다.
- `google-services.json`은 `com.warmhandongne.msg` 단일 Android 앱과 로컬/Play App
  Signing SHA-1의 Android OAuth client(type 1)를 포함한 최신 파일로 교체했다.
  Play 내부 테스트 설치본에서 Google 로그인 실기기 확인은 별도로 남아 있다.

## 1. 외부 식별자 확인

- Google Play Console의 **App signing key certificate SHA-256**를
  `public/.well-known/assetlinks.json`에 반영했다. upload key와 Play App Signing
  인증서를 함께 유지한다.
- Firebase/Google Cloud Console의 `com.warmhandongne.msg` Android OAuth client에
  Play App Signing SHA-1을 등록하고 최신 `android/app/google-services.json`을
  반영했다.
- Apple Developer의 Team ID가 AASA의 `6JPU444S4H`와 같고, App ID
  `com.warmhandongne.msg`에 Sign In with Apple과 Associated Domains capability가
  켜져 있는지 확인한다.
- `https://project0000-ec01e.firebaseapp.com/.well-known/apple-app-site-association`
  응답이 redirect 없이 JSON으로 열리는지 확인한다.

## 2. Firebase 보안 배포 순서

기존 앱의 그룹 게임 조회가 끊기지 않도록 아래 순서를 바꾸지 않는다.

1. Functions build·test와 Project CLI FULL validation을 통과한다.
2. 신규 함수만 먼저 배포한다.
   - `fetchRealtimeRoomGroupEntitlements`
   - `cleanupDeletedRoomCreationRequest`
3. 배포된 callable을 개발/내부 테스트 앱에서 확인한다.
4. `1.0.0+2` 앱을 내부 테스트에 배포한다.
5. 새 앱에서 무료·그룹 유료 게임 목록과 방 삭제 재시도를 확인한다.
6. 새 클라이언트 전환이 확인된 뒤 `firestore.rules`와 `storage.rules`를 배포한다.
7. 다른 UID의 `/users/{uid}` 읽기와 다른 사용자의 Storage 쓰기가 거부되는지 확인한다.

배포 기록(2026-08-31 16:52 KST):

- Node 22.23.1과 저장소 로컬 Firebase CLI 14.27.0으로 신규 함수 두 개만 선택 배포했다.
- `fetchRealtimeRoomGroupEntitlements`는 `asia-northeast3`,
  `cleanupDeletedRoomCreationRequest`는 `asia-southeast1`에서 Node.js 22 2세대
  `ACTIVE` 상태를 확인했다.
- Hosting, Firestore/Storage 규칙과 기존 Functions는 이 배포에 포함하지 않았다.

## 3. Firebase App Check 단계적 적용

1. Android 앱에는 Play Integrity, iOS 앱에는 App Attest with DeviceCheck fallback을
   Firebase Console에서 등록한다.
2. 개발 기기의 debug token은 채팅·문서·Git에 남기지 않고 콘솔에만 등록한다.
3. enforcement를 끈 상태에서 App Check 요청 지표와 실패율을 관찰한다.
4. Functions, Realtime Database, Firestore, Storage를 한 서비스씩 enforcement하고
   로그인·방 생성·참가·게임·프로필 업로드·회원탈퇴를 다시 확인한다.
5. 구버전 앱이 남아 있으면 강제 적용 전에 최소 지원 버전과 전환 계획을 결정한다.

## 4. 개인정보와 계정 삭제

- Hosting에 `/privacy/`와 `/account-deletion/`을 함께 배포한다.
- App Store Connect Privacy Policy URL과 Google Play 개인정보처리방침 URL에
  공개 HTTPS 주소를 등록한다.
- App Store 개인정보 응답과 Google Play Data safety에 이메일, 닉네임/이름,
  UID, 선택 프로필 사진, 기존 전화번호, 게임 데이터와 UID에 연결된 Crash Data를
  실제 코드와 동일하게 신고한다.
- Apple 계정으로 로그인한 실제 iPhone/iPad에서 회원탈퇴 시 Apple 재확인,
  token revoke, Firebase 계정 삭제가 순서대로 완료되는지 확인한다.
- 앱을 사용할 수 없는 계정의 삭제 이메일 요청을 수신·본인 확인·처리하는 운영
  절차를 마련한다.

## 5. Shorebird base release

- 저장소 버전과 두 스토어 빌드를 `1.0.0+2`로 일치시킨다.
- Shorebird CLI를 업데이트한 경우 doctor와 두 플랫폼 dry-run을 다시 실행한다.
- 실제 스토어 바이너리는 일반 `flutter build`가 아니라 아래 release에서 생성한다.

```text
shorebird release android --build-name=1.0.0 --build-number=2 --flutter-version=3.44.4
shorebird release ios --build-name=1.0.0 --build-number=2 --flutter-version=3.44.4 --export-method=app-store
```

Android 운영 릴리스 기록(2026-08-31 17:06 KST):

- Shorebird 릴리스 `1.0.0+2`가 Flutter `3.44.4`로 생성되었고 Android 상태는
  `active`이다.
- Play 업로드용 AAB는 `build/app/outputs/bundle/release/app-release.aab`이며 SHA-256은
  `ecda905518c3f4009f3b5073b6a0dc04c7f55912ac04670c33eb35cc1fb39e4f`이다.
- Play Console 내부 테스트 업로드와 실제 기기 검증은 아직 남아 있다.
- iOS 운영 Shorebird 릴리스는 아직 생성하지 않았다.

- Xcode Organizer를 사용하면 **Manage Version and Build Number**를 해제한다.
- App Store/Play 내부 테스트에 실제 Shorebird artifact를 올려 패치 확인·다운로드·
  재실행 적용을 검증한다.
- 실제 release 생성 후 Shorebird Console의 Artifacts 탭에서 해당 릴리스와
  Shorebird Flutter engine 심볼을 받아 Crashlytics/Play Console에 보관·업로드한다.
  현재 dry-run AAB는 `libapp.so` 심볼 미포함 경고가 있어 이 단계를 생략하지 않는다.
- Dart 코드 패치는 staging track에서 실제 기기 확인 후 stable로 승격한다.
- asset, plugin/native code, plist/entitlement/manifest 변경은 새 스토어 릴리스로 낸다.

## 6. 출시 후 Dart 수정·Shorebird patch

1. 해당 base release의 Git commit/tag에서 수정 브랜치를 만든다.
2. Dart 코드만 수정하고 targeted test와 FULL validation을 통과한다.
3. 먼저 staging track으로 패치한다.

```text
shorebird patch android --release-version=1.0.0+2 --track=staging
shorebird patch ios --release-version=1.0.0+2 --track=staging
```

4. 실제 기기에서 `shorebird preview --release-version=1.0.0+2 --track=staging`으로
   확인한다. 이 앱은 첫 실행에 패치를 받고 “업데이트를 마쳤어요”를
   보여 준 뒤, 앱을 완전히 종료하고 다시 실행할 때 적용한다.
5. 패치 번호를 확인한 후 stable로 승격한다.

```text
shorebird patches list --release-version=1.0.0+2
shorebird patches promote --release-version=1.0.0+2 --patch-number=<확인한 번호>
```

- Dart 로직·UI·문구 수정은 patch 후보다.
- 이미지·폰트 같은 asset, Firebase/Flutter plugin, Android/iOS native 코드,
  Manifest/Info.plist/entitlement, 권한, SDK 버전 변경은 patch로 보내지 말고
  빌드 번호를 올려 스토어 신규 릴리스로 낸다.
- `--allow-native-diffs`나 `--allow-asset-diffs`로 경고를 우회하지 않는다.
- stable 적용 후 Crashlytics와 주요 흐름을 관찰하고, 문제 시 Shorebird
  Console에서 해당 patch를 rollback한다.

## 7. 스토어 콘솔과 실제 기기

- App Store: 최신 연령 등급 질문, 앱 개인정보, 수출 규정, 지원 URL, 심사 진입
  방법, iPhone/iPad 스크린샷과 실제 Distribution 서명을 확인한다.
- Google Play: target API, Data safety, account deletion URL, 콘텐츠 등급, 광고 여부,
  대상 연령, App access, Play App Signing, pre-launch report를 확인한다.
- iPhone, iPad, 저사양 Android, 16KB Android 기기/에뮬레이터에서 로그인 종류별,
  이메일 링크, QR, 네트워크 단절/복귀, background/resume, 세 게임 전체 흐름,
  프로필 업로드와 회원탈퇴를 실제 store artifact로 확인한다.
- Crashlytics와 Android vitals에 새 치명 오류가 없는지 확인한 뒤 단계적 출시한다.
