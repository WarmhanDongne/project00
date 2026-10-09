# Firebase Server Logs — Read-only

이 문서는 실기기 오류 조사에 필요한 Cloud Functions 실행 로그를 기존 Firebase
조회용 계정으로 읽는 절차다. RTDB 관찰은 [Firebase MCP](FIREBASE_MCP.md)를 따른다.

## Account and access

- Project: `project0000-ec01e` (`mosigame`).
- 기존 계정의 허용 역할: `roles/firebasedatabase.viewer`, `roles/logging.viewer`.
- `roles/logging.viewer`는 일반 로그 조회 역할이다. 프로젝트 수준으로 부여하면
  `_Required`·`_Default` bucket의 일반 로그 전반을 읽을 수 있으며, 시간·함수 filter는
  수집 범위를 제한할 뿐 IAM 권한 자체를 줄이지 않는다.
- 사람이 IAM 역할과 로컬 활성 계정을 확인한다. 계정 이메일·인증 출력·token을 채팅,
  Git 또는 진단 파일에 포함하지 않는다. Owner 계정으로 이 절차를 실행하지 않는다.
- gcloud의 브라우저 로그인은 사람이 수행한다. Firebase Auth 사용자 데이터 조회와
  변경은 이 절차에 포함하지 않는다.

2026-10-09 사용자는 동일 계정 사용을 요청하고 IAM의 Logs Viewer 추가 완료를 보고했다.
로컬 조사에서는 gcloud를 PATH 및 Windows 일반 설치 위치 세 곳에서 찾지 못했다.
실제 IAM 검증, gcloud 로그인과 운영 로그 조회는 아직 실행하지 않았다.

후속 2026-10-09 사용자 직접 조회 요청에서 설치된 gcloud와
`mosigame-logs-readonly` configuration/project를 확인했다. 같은 계정의 기존 Logs Viewer로
시작 함수 오류 시간대 일반 로그 조회에 성공했다. 함수 describe는 권한 거부였지만 로그
조사에 추가 IAM 역할은 필요하지 않았다. 계정 역할은 사용자 확인을 근거로 하며 AI가
IAM policy를 직접 검증한 것으로 표현하지 않는다.
[조회 범위·명령·정제 근거](../planning/NETWORK_SESSION_STARTUP_INVESTIGATION.md#roulette-restart-investigation)를 따른다.
위의 미설치/미조회 설명은 최초 조사 시점의 기록이다.

## Human setup on Windows

1. [Google Cloud CLI 설치 안내](https://docs.cloud.google.com/sdk/docs/install-sdk)의
   Windows installer로 설치하고 PATH에 추가한다. 시스템 설치와 로그인은 사람이 한다.
2. 새 PowerShell을 열어 `gcloud version`으로 실행 가능 여부를 확인한다.
3. 기존 configuration이 없는 경우 아래 조회용 configuration을 한 번 만든다.
   같은 이름이 이미 있으면 다시 만들거나 기존 설정을 덮어쓰지 말고 사람이 확인한다.

```powershell
gcloud config configurations create mosigame-logs-readonly --no-activate
```

4. 같은 계정으로 로그인한다. 브라우저에서는 Logs Viewer를 추가한 기존 조회용 계정을
   선택한다. 아래 `--configuration`은 기존 기본 configuration 대신 조회용 설정을 쓴다.

```powershell
gcloud --configuration=mosigame-logs-readonly auth login
gcloud --configuration=mosigame-logs-readonly config set project project0000-ec01e
```

5. 사람만 로컬에서 아래 결과를 확인한다. 이메일이나 출력을 공유하지 않고 동일 계정과
   project가 맞는지 여부만 보고한다. Firebase CLI 계정도 임의로 변경하지 않는다.

```powershell
gcloud --configuration=mosigame-logs-readonly config get-value account
gcloud --configuration=mosigame-logs-readonly config get-value project
```

GUI로 시작한 Codex에 새 PATH가 반영되지 않았다면 앱을 다시 시작하거나 사람이 확인한
gcloud 실행 파일의 절대 경로를 사용한다. credential 파일을 읽어 연결을 우회하지 않는다.

Windows에서 gcloud.cmd가 필터의 인용부호를 잃으면 날짜/정규식 filter가 INVALID_ARGUMENT로
실패할 수 있다. 이번 관찰에서는 공개 launcher가 호출하는 동일 SDK의 bundled Python과
`lib/gcloud.py`를 `-S`로 직접 실행해 따옴표를 보존했다. credential을 직접 읽거나 SDK를
수정한 방식이 아니며 configuration/project/필드 제한은 동일하게 유지했다.

## Bounded investigation

사용자와 합의한 오류 조사 또는 테스트마다 다음 범위를 정한다.

- 관련 함수와 실제 Cloud Run service 이름·리전. callable 이름과 service 이름을
  같다고 추측하지 말고 Console 등에서 확인한 값으로 filter를 만든다.
- 시작·종료 시간. 사용자의 KST 시간을 UTC로 변환하고 양쪽 경계를 지정한다.
- 최대 건수. 최초 연결 확인은 1건, 오류 조사는 우선 100건 이내로 제한한다.

아래는 Cloud Functions 2세대 실행 metadata만 확인하는 PowerShell template이다.
placeholder를 확정한 조회 범위로 바꾼 뒤에만 실행한다. 실제 쿼리를 대신하는 PASS
evidence가 아니며, metadata만으로 오류 원인이나 기능 정상 여부를 확정하지 않는다.

```powershell
$serverLogFilter = @'
resource.type="cloud_run_revision"
resource.labels.service_name="APPROVED_SERVICE_NAME"
resource.labels.location="APPROVED_REGION"
timestamp>="APPROVED_START_UTC"
timestamp<"APPROVED_END_UTC"
'@
gcloud --configuration=mosigame-logs-readonly logging read $serverLogFilter --project=project0000-ec01e --limit=1 --order=asc --format="json(timestamp,severity,insertId,resource.type,resource.labels.service_name,resource.labels.location,labels.execution_id,httpRequest.status,httpRequest.latency)"
```

이 template은 `textPayload`, `jsonPayload`, 요청 URL·본문과 사용자 식별자를 출력하지
않는다. 실제 원인 조사에서 오류 메시지·stack이 필요하면 관련 함수의 기록 형태를 먼저
확인하고 민감정보가 없는 필요한 필드만 선별한다. 전체 payload를 그대로 출력하거나
파일로 redirect하지 않는다. timeout·권한 오류의 원문에도 계정 정보가 포함될 수 있으므로
보고에는 정제한 오류 분류와 exit code만 남긴다.

정제한 결과만 ignored `build/device-test/` 아래에 저장한다. 시간·service·실행 ID로
기기 로그와 비교하며 클라이언트의 `local_...` trace를 서버 execution ID로 취급하지 않는다.
조회 명령, 시간 범위, 최대 건수, 결과 수, status·exit code를 기록한다. 로그가 없는 결과는
미발견으로 보고하며 정상 동작의 증거로 바꾸지 않는다.

이 절차에는 IAM·project·rules 변경, 로그 삭제, deploy, migration과 RTDB 전체 조회가
포함되지 않는다. 로그 관찰은 Project CLI validation이나 실기기 재시험을 대체하지 않는다.

## References

- [Cloud Logging IAM](https://docs.cloud.google.com/logging/docs/access-control)
- [Google Cloud CLI authentication](https://docs.cloud.google.com/sdk/docs/authenticate)
- [gcloud configurations create](https://docs.cloud.google.com/sdk/gcloud/reference/config/configurations/create)
- [gcloud logging read](https://docs.cloud.google.com/sdk/gcloud/reference/logging/read)
