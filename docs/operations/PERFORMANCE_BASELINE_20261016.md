# Android release 성능 측정 기준 — 2026-10-16

관련 작업: [NET-RECOVERY-01](../planning/tasks/NET-RECOVERY-01.md),
[로비 측정 절차](ROOM_ACTION_LATENCY.md).

## 기준의 의미

사용자 요청으로 현재 develop의 추가 성능 개선 전 기준 APK를 만든다.
이 기록은 크몽/Google Play에 실제 제출한 바이너리와의 동일성을 확인한 기록은 아니다.
이 기준에서 개선 전 시간을 실측하고, 이후 동일한 빌드 조건·기기·네트워크로 비교한다.
과거 지연 개선이 이미 포함된 develop이므로 “모든 최적화 적용 전”으로 부르지 않는다.

## 소스와 환경

| 항목 | 값 |
| --- | --- |
| 기준 ID | `android-release-develop-b921f53-20261016` |
| 소스 브랜치 | `develop` |
| 소스 커밋 | `b921f53bfb73c4b5f37c883d4285e1bb9ffcf393` |
| 빌드 전 작업 트리 | clean, staged/unstaged/untracked 없음 |
| 소스 snapshot | tracked 파일 1,499개 SHA-256 보관 |
| Application ID | `com.warmhandongne.msg` |
| 요청 앱 버전 / 빌드 번호 | `1.0.0` / `4` |
| 모드 / 형식 | Android `release` / APK |
| Flutter / Dart | `3.47.5 stable` / `3.13.4` |
| Flutter framework | `6a19cca56475dbfba1478ee68d7bd0c2ef891da1` |
| Flutter engine | `af7e796e161ae0bb1ff0758c71a7105418bd9ded` |
| Java | Microsoft OpenJDK `21.0.11+10-LTS` |
| Gradle / Android Gradle Plugin / Kotlin | `9.1.0` / `9.0.1` / `2.3.20` |
| Node / npm | `v22.23.2` / `10.9.8` |
| 빌드 OS | Windows 11 Home, build 26200 |
| pubspec.lock SHA-256 | `17b20e2a4bfa49232c5cce8c4ec1fc6247b32c8796c0db34a6c32cb678a7f1d4` |
| functions/package-lock.json SHA-256 | `110b8072fbb366f510aa8018b60316c609f567be9b13cdba26c5ce85a42020e5` |

## 빌드 조건

기존 의존성/SDK를 사용하며 dependency 추가, pub get, 소스 수정, 스토어 제출,
Firebase/Rules 배포, Shorebird release/patch는 수행하지 않는다.
`android/local.properties`의 생성용 값만 release / 1.0.0 / 4로 맞춘다.

현재 환경에는 `android/key.properties`가 없다. 저장소의 기존 fallback에 따라
release 모드 APK를 debug 키로 서명한다. Google Play 설치본과의 덮어설치 가능성,
Google 로그인·Play Integrity/App Check의 실기기 동작은 별도 확인 대상이다.
서명 충돌을 해결하려고 기존 앱/사용자 데이터를 자동 삭제하지 않는다.

이 프로젝트의 Crashlytics Gradle plugin은 R8 뒤 mapping upload를 연결하므로,
로컬 측정 빌드에서는 해당 업로드만 명시적으로 제외한다. Flutter SDK가 연결된
기존 Android release assembly를 다음 명령으로 실행한다.

```powershell
.\android\gradlew.bat -p android -q -Ptarget-platform=android-arm,android-arm64,android-x64 -Ptarget=lib/main.dart -Pbase-application-name=android.app.Application -Pdart-obfuscation=false -Ptrack-widget-creation=false -Ptree-shake-icons=true :app:assembleRelease -x :app:uploadCrashlyticsMappingFileRelease
```

- ABI: armeabi-v7a, arm64-v8a, x86_64를 포함하는 단일 APK.
- Dart obfuscation: false. Widget creation tracking: false. Icon tree shaking: true.
- 기본 release 최적화와 R8은 유지한다. 새 시간 계측은 추가하지 않는다.
- 기존 상세 통신 진단은 debug 전용이므로 이 APK에 단계별 진단 UI가 있다고 가정하지 않는다.

## 산출물 확인

| 항목 | 확인값 |
| --- | --- |
| APK | [mosigame-1.0.0-build4-release-b921f53.apk](../../artifacts/performance-baselines/2026-10-16-develop-b921f53/mosigame-1.0.0-build4-release-b921f53.apk) |
| 기계 판독 기록 | [baseline.json](../../artifacts/performance-baselines/2026-10-16-develop-b921f53/baseline.json) |
| evidence 묶음 | [baseline-evidence.zip](../../artifacts/performance-baselines/2026-10-16-develop-b921f53/baseline-evidence.zip) |
| 빌드 시작 / 완료 | `2026-10-16 17:18:09` / `17:26:49` KST |
| 빌드 소요 | `520,226ms` (약 8분 40초) |
| 실제 앱 버전 / 빌드 번호 | `1.0.0` / `4` (APK에서 확인) |
| 크기 | `139,434,291 bytes` (약 139.4 MB) |
| APK SHA-256 | `1db19a2366017308ba917df0c72d8c4e825ba19059bdcb12250ec953d84cc71c` |
| min / target / compile SDK | `24` / `36` / `36` |
| 확인 도구 | Android build-tools `36.1.0`의 aapt2 / apksigner |
| debuggable | false (release 최적화, debug 인증서 서명과는 별개) |
| ABI | `arm64-v8a`, `armeabi-v7a`, `x86_64` |
| APK 서명 | v2, signers 1, apksigner verify PASS/exit 0 |
| 서명 인증서 SHA-256 | `c0b6b3a2eb965e6d8eb9b8dd047d2a1e9505e895fd2c580f3bd171f49895256c` |
| 보관 복사 검증 | 원본 APK와 별도 보관 APK의 SHA-256 일치 |

기존 KGP 사용 plugin의 향후 Flutter 호환 경고와 Firestore Java unchecked 경고가
출력됐지만 빌드는 exit 0으로 완료했다. 이 기준에서 dependency를 바꾸지 않았다.

## 검증

| 명령 | 결과 | exit |
| --- | --- | --- |
| `.\tool\invoke_mosigame.ps1 doctor --json` | PASS, 9 checks | 0 |
| `.\tool\invoke_mosigame.ps1 validate --full --json` | PASS, 12 checks. 포맷·분석·앱/5개 패키지·Functions lint/test·mutation 포함 | 0 |
| 위 Android release assembly | PASS | 0 |
| `aapt2 dump badging <APK>` | 버전·SDK·ABI 확인, debuggable 아님 | 0 |
| `apksigner verify --verbose --print-certs <APK>` | PASS, v2 서명 유효 | 0 |

FULL은 빌드 기준 커밋의 clean source에서 실행했다. guard의 Console forwarding이
PowerShell redirection을 우회해 raw JSON 파일이 비어 있으므로, 완료 tool output의
12 PASS/exit 0을 정규화한 `full-validation-summary.json`을 근거로 보관한다.
기준의 소스 내용은 추가 문서 기록과 구분한다.

## 보관 위치

- 영구 기준 APK와 manifest/evidence: `artifacts/performance-baselines/2026-10-16-develop-b921f53/`.
  APK는 기존 `*.apk` 규칙으로 Git ignored이며 `flutter clean` 대상인 build 폴더 밖에 둔다.
- 원본 evidence: `build/performance-baselines/2026-10-16-develop-b921f53/`.
  `baseline.json`, SDK/lock 기록, tracked source snapshot, 검증 요약,
  빌드 script/result/stdout/stderr와 이전 로컬 release APK를 보관한다.
- `build/` evidence는 `flutter clean`으로 삭제될 수 있어, credential/local.properties/이전 APK를
  제외한 재현 script·SDK/lock·source snapshot·검증 요약·빌드 로그·산출물 metadata를
  `baseline-evidence.zip`으로 별도 보관한다.
- 이 기록과 APK의 원격 백업, Git commit/tag/push는 수행하지 않았다.

최종 작업 트리의 변경은 이 기준 문서·기존 작업 상세/월별 기록·artifact manifest/evidence다.
시작 snapshot과 비교해 제품 소스·설정·의존성·게임 에셋은 동일하다.

## 실측 때 추가할 기록

아직 기기 설치·실행과 속도 실측을 수행하지 않았다. 운영 서버 revision/config도
조회하지 않았으므로 이 APK만으로 서버 기준까지 고정됐다고 표현하지 않는다.

| 항목 | 실측 때 기입 |
| --- | --- |
| 측정 시작·종료 | KST 날짜/시각 |
| 기기 | 휴대폰·태블릿 모델, OS, 역할 |
| 네트워크 | Wi-Fi/모바일, 같은 망 여부, 측정 중 변경 여부 |
| 참가자 / 게임 | 인원, 게임, 라운드/턴 |
| 상태 | 첫 실행/반복, 신규/재접속, 에셋 설치/캐시, 백그라운드 복귀 여부 |
| 실행 파일 | 이 기준 ID와 설치 APK SHA-256 확인 |
| 서버 | 해당 시간대 배포 변경 여부. 실제 revision은 확인했을 때만 기입 |
| 행동 | 그룹 생성, 추방, 초기화, 게임 시작, 카드 제출, 다음 입력 가능 |
| 시간 | 입력→전송, 요청→응답, 상태 수신, 다음 입력 가능을 계측 가능한 범위에서 분리 |
| 결과 | 성공/실패, 재시도 횟수, 영상/정제 로그 파일, 첫 값·반복 중앙값·최대값 |

기록에는 UID, 방 코드, token, credential과 비공개 손패/개인정보를 넣지 않는다.
