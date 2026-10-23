# 그룹 생성·추방·초기화 측정용 release·배포 기록 — 2026-10-22

[테스트 지시문](PERFORMANCE_CAPTURE_CHECKLIST_20261022.md) · [개발·FULL 검증](../planning/ROOM_ACTION_EFFICIENCY_20261022.md)

## 승인과 소스

사용자가 이번 변경 배포 후 release 앱 생성 및 기존 영상 대비 개선도 측정 지시문 작성을 요청했다.
이 승인은 이번 세 Functions 배포와 로컬 성능 측정 APK 생성에 적용한다. 스토어/Hosting/Rules 배포,
Shorebird release/patch, 운영 게임 데이터·서버 실행 로그 조회·기기 설치/조작은 수행하지 않는다.
develop 병합·commit·push도 하지 않는다.

- 브랜치: `codex/room-action-efficiency-20261022`.
- HEAD: `cc293dffc35111e0b65ea2aa87e46d7c2347a3eb` + 이번 미커밋 제품3파일.
- 배포 시작 전 제품·테스트5파일 SHA-256이 FULL2 PASS 후보와 같음을 확인했다.
- FULL2: 13단계·1,370개 PASS/exit0. 이번 배포/빌드에서 제품 코드를 추가 변경하지 않는다.
- 기존 미추적 특허 검토·오디오 인수인계 문서와 전체 작업 트리를 보존한다.

## 서버 배포

```powershell
.\functions\node_modules\.bin\firebase.cmd deploy --project project0000-ec01e --only "functions:createRealtimeRoom,functions:removeRealtimeRoomPlayer,functions:closeRoom" --non-interactive
```

대상은 서울 `asia-northeast3`의 기존 Node.js22 2세대 callable3개다. 이름·리전·DB shape·Rules·보존 기한은 바꾸지 않는다.
`--force`나 전체 Functions 배포를 사용하지 않는다. predeploy eslint/tsc를 그대로 수행한다.

**배포 결과: 세 함수 모두 Successful update / Deploy complete, exit0.**
predeploy eslint/tsc도 PASS였다. 후속 메타데이터 조회에서 세 함수의 `ACTIVE`·
`asia-northeast3`·`nodejs22`·`gcfv2`를 확인했다. 확인 시각은
`2026-10-22 18:40:04.027 KST`(정확한 배포 완료 시각 자체가 아닌 상태 확인 시각)다.
세 함수의 배포 package source hash는 모두 `afcd42519d1c438316f0c5d68742fc0b7f205811`이다.
ignored 근거: `build/room_action_release_20261022/deployment-result.json`.
초기 PowerShell 메타데이터 추출은 대상 식별에 실패했고 Node 직접 파싱으로 3개를
확인했다. 이는 배포 실패·재배포가 아니며 배포 명령은 한 번만 실행했다.
실제 게임/사용자 데이터·Auth 데이터·실행 로그는 조회하지 않았다.

## Android release APK

- 기준 ID: `android-release-room-actions-cc293dff-wip-20261022`.
- 앱: `com.warmhandongne.msg`, 현재 저장소 버전 `1.0.0+6`.
- 이전 기준은 `1.0.0+4` / `b921f53`. 다른 버전 APK이므로 버전 표시만으로 동일성을 판단하지 않는다.
- 표준 Flutter SDK를 사용하는 Android release 최적화 APK이며 Shorebird release/patch는 생성하지 않는다.
- 현재 `android/key.properties`가 없어 기존 Gradle fallback의 debug 인증서로 서명한다. 이는 `debuggable=true` 앱이라는 뜻이 아니다. 이전 로컬 측정 APK도 같은 방식이므로 인증서 해시를 대조한다. 스토어 제출용 서명 APK라고 표현하지 않는다.
- 기존 기준과 같이 armeabi-v7a/arm64-v8a/x86_64 단일 APK, R8 유지, Dart obfuscation=false, widget tracking=false, icon tree shaking=true다.
- 기본 backend는 server다. local emulator용 define·추가 계측 코드를 넣지 않는다.
- 외부 Crashlytics mapping 업로드 task만 제외하며 앱 최적화는 유지한다. 기존 의존성으로 빌드하고 pub get·SDK/ACL·tracked 설정을 변경하지 않는다. ignored `android/local.properties`의 생성용 모드/버전만 맞춘다.

```powershell
.\android\gradlew.bat -p android -q -Ptarget-platform=android-arm,android-arm64,android-x64 -Ptarget=lib/main.dart -Pbase-application-name=android.app.Application -Pdart-obfuscation=false -Ptrack-widget-creation=false -Ptree-shake-icons=true :app:assembleRelease -x :app:uploadCrashlyticsMappingFileRelease
```

**빌드 결과: PASS/exit0**, `365,432ms`(약6분5초).
빌드 시작/완료는 `2026-10-22 18:37:01.671` / `18:43:07.101 KST`다.
실제 APK에서 버전과 release 여부를 확인했다. 설치·촬영·개선 후 실측은 아직 수행하지 않았다.

| 항목 | 확인 결과 |
| --- | --- |
| APK | [mosigame-1.0.0-build6-release-room-actions.apk](../../artifacts/performance-releases/2026-10-22-room-actions/mosigame-1.0.0-build6-release-room-actions.apk) |
| 기계 판독 기록 | [release.json](../../artifacts/performance-releases/2026-10-22-room-actions/release.json) |
| 재현·검증 evidence | [release-evidence.zip](../../artifacts/performance-releases/2026-10-22-room-actions/release-evidence.zip) — local.properties·credential 제외 |
| 버전 / package | `1.0.0+6` / `com.warmhandongne.msg` |
| debuggable | false |
| ABI | `arm64-v8a`, `armeabi-v7a`, `x86_64` |
| min / target / compile SDK | `24` / `36` / `36` |
| 크기 | `142,738,926 bytes`(약142.7MB) |
| APK SHA-256 | `00cce44392295beab6b2c818facca715e48888732b3ae4fed0c8009b8feb1cbf` |
| apksigner 검증 | PASS/exit0, v2, signers1 |
| 인증서 SHA-256 | `c0b6b3a2eb965e6d8eb9b8dd047d2a1e9505e895fd2c580f3bd171f49895256c` — 이전 로컬 측정 APK와 동일 |
| 보관 복사 | 원본/보관 APK SHA-256 일치 |
| 소스 보존 | 빌드 전후 tracked 입력1,076개 SHA-256 동일. 제품·의존성·tracked 설정 추가 변경 없음 |

기존 plugin의 KGP 향후 호환 경고가 있었으나 빌드는 성공했다. 이 경고를 이유로 dependency를 변경하지 않았다.
build 로그·소스 snapshot·검증 요약은 ignored `build/room_action_release_20261022/`에,
APK·manifest·evidence는 `flutter clean` 대상 밖인 위 artifacts 경로에 보관했다.
기존 미추적2파일의 Git blob 해시도 작업 시작 때와 같다. 이후 tracked 변경은 배포·실측
지시문/작업 상태를 남기는 문서뿐이다. 기기 설치·실제 측정 결과는 `NOT RUN/NOT VERIFIED`다.

## 비교 해석

현재 소스에는 기준 APK 이후 로비 대기 단축·로고·Android 오디오 수정 등 develop 변경도 포함된다.
기존 영상과의 비교는 이전 전체 배포 조합 대비 관측 개선이며, 이번 최적화3항목만의 인과 효과는 아니다.
배포 후 기존 APK로 다시 측정하더라도 이전 서버 조합은 재현되지 않는다.
