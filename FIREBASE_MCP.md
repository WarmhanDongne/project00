# Firebase MCP RTDB Read-only Pilot

이 문서는 사람이 Mosigame의 제한된 Firebase MCP 파일럿을 설정하고 사용하는
방법을 설명한다. AI가 따라야 하는 강제 실행 규칙은 [`AGENTS.md`](AGENTS.md)에
분리되어 있다.

## Purpose and boundary

파일럿은 실기기 수동 테스트 중 Firebase Console에서 반복하던 Realtime Database
상태 확인을 정확한 단일 경로 조회로 대체한다. 현재 유일한 cloud project에는 실제
사용자 데이터가 있으므로 production으로 취급한다.

```text
Project ID: project0000-ec01e
Project name: mosigame
Expected state: ACTIVE
Database URL:
https://project0000-ec01e-default-rtdb.asia-southeast1.firebasedatabase.app
```

MCP는 탐색적 관찰과 장애 조사 보조 수단이다. 조회 결과만으로 기능 완료나 regression
PASS를 판정하지 않으며 Project CLI, targeted suite 또는 `validate --full`을 대체하지
않는다.

## Required safety layers

다음 조건을 모두 유지한다.

1. Firebase CLI에는 MCP 전용 Google 계정을 사용한다.
2. 그 계정에는 `roles/firebasedatabase.viewer`만 부여하고 Owner, Editor, Firebase
   Admin 또는 다른 write 권한을 함께 부여하지 않는다.
3. Firebase CLI의 `--tools`에는 `firebase_get_project`와
   `realtimedatabase_get_data`만 지정한다.
4. Codex의 `enabled_tools`에도 같은 두 도구만 지정하고
   `realtimedatabase_set_data`는 `disabled_tools`에 둔다.
5. 모든 도구는 `default_tools_approval_mode = "prompt"`를 사용한다.
6. project context는 repository 절대 경로의 `--dir`과 tracked `.firebaserc`의
   `default` project로 고정한다.

`--only realtimedatabase`만으로는 core 도구와 write 도구를 제거하지 못하므로 이
파일럿의 read-only 경계로 사용하지 않는다. Firebase MCP는 Firebase CLI 인증을
그대로 사용하므로 도구 allow-list만이 아니라 계정의 IAM 권한도 반드시 제한한다.

## Local configuration

`.codex/config.toml`은 실행 파일과 repository의 호스트별 절대 경로를 포함하므로
Git에 커밋하지 않는다. 저장소의 ignore 규칙은 이 파일의 accidental commit을
차단한다. credential, token 또는 계정 이메일을 이 파일에 넣지 않는다.

파일럿 기준 Firebase CLI 버전은 `15.22.4`다. 다른 버전을 사용할 때는 먼저 로컬
terminal에서 `firebase mcp --help`를 실행하고 `--dir`과 `--tools`가 같은 의미로
지원되는지 확인한다. `--generate-tool-list`는 전체 카탈로그를 출력하므로 실제 노출
도구 검증에 사용하지 않는다.

아래 template의 세 절대 경로를 현재 호스트 값으로 바꾼다.

```toml
[mcp_servers.firebase_rtdb_readonly]
command = 'ABSOLUTE_NODE_PATH'
args = [
  'ABSOLUTE_FIREBASE_JS_PATH',
  "mcp",
  "--dir",
  'ABSOLUTE_PROJECT00_PATH',
  "--tools",
  "firebase_get_project,realtimedatabase_get_data",
]
cwd = 'ABSOLUTE_PROJECT00_PATH'
enabled = true
required = false
enabled_tools = ["firebase_get_project", "realtimedatabase_get_data"]
disabled_tools = ["realtimedatabase_set_data"]
default_tools_approval_mode = "prompt"
startup_timeout_sec = 30
tool_timeout_sec = 60
```

경로에는 TOML literal string인 작은따옴표를 유지한다. double-quoted string으로
바꾸려면 Windows의 `\`를 `\\`로 escape하거나 `/`로 바꿔야 한다.

Project-scoped `.codex/config.toml`은 trusted project에서만 적용된다. Codex에서 이
repository를 신뢰한 상태인지 확인한 다음 Codex를 재시작하고 composer에서 `/mcp`를
입력해 서버 연결 상태를 확인한다. 이어서 새 task에서 실제 노출 도구 목록이 정확히
다음 두 개인지 확인한다.

```text
firebase_get_project
realtimedatabase_get_data
```

도구가 더 많거나 적으면 production tool call을 실행하지 말고 설정과 Firebase CLI
버전을 먼저 조사한다.

### Windows

PowerShell의 로컬 terminal에서 다음 명령으로 경로를 찾는다. 결과에 계정 정보는
포함되지 않는다.

```powershell
(Get-Command node).Source
npm root -g
```

두 번째 결과 아래의 `firebase-tools\lib\bin\firebase.js`와 repository 절대 경로를
template에 넣는다. 현재 파일럿은 Node `24.15.0`과 Firebase CLI `15.22.4`에서
검증됐다. 다른 설치 경로를 그대로 복사하지 않는다.

### macOS

Terminal에서 다음 명령으로 현재 설치의 경로를 찾는다.

```bash
command -v node
npm root -g
```

두 번째 결과 아래의 `firebase-tools/lib/bin/firebase.js`와 repository 절대 경로를
template에 넣는다. GUI로 시작한 Codex가 shell의 `PATH`를 그대로 받는다고 가정하지
말고 확인된 절대 경로를 사용한다.

이 절차는 현재 Windows 호스트에서 작성됐으며 macOS에서 실제 실행되지 않았다.

```text
macOS runtime and tool exposure: USER VERIFICATION REQUIRED
```

macOS 사용자는 Firebase CLI 버전, `mcp --help`, 실제 노출 도구 두 개,
`firebase_get_project` 결과를 직접 확인해야 한다. production RTDB read는 별도 사전
승인 없이는 재현 확인에 포함하지 않는다.

## Before every production read

다음 순서로 확인한다.

1. 사람만 로컬 terminal에서 `firebase login:list`를 확인한다. 이 명령은 계정 이메일을
   표시할 수 있으므로 출력을 채팅, issue 또는 보고서에 붙이지 않는다.
2. 필요한 경우 사람이 `firebase login:use`로 MCP 전용 계정을 선택한다. Owner 계정이
   활성 상태라면 MCP를 시작하지 않는다.
3. Google Cloud IAM에서 해당 계정이 `roles/firebasedatabase.viewer`이고 더 넓은
   권한이 없는지 확인한다.
4. AI는 `firebase_get_project`만 호출해 위의 project ID, 이름과 상태를 비교한다.
5. database URL, 정확한 단일 경로, 조회 필요성, 예상값과 민감정보 가능성을 제시하고
   사용자에게 그 한 번의 production read 승인을 받는다.
6. 승인된 `realtimedatabase_get_data`를 정확히 한 번 호출하고 최소 결과만 보고한다.

승인은 다른 경로, 다른 database 또는 재시도에 재사용하지 않는다. `/` 또는 상위
collection 전체 조회, wildcard 성격의 조회와 사용자/Auth 데이터 탐색은 금지한다.

## Prohibited operations

- `realtimedatabase_set_data` 및 모든 데이터 생성, 수정, 삭제
- Auth 사용자 조회 또는 변경
- project, app, database instance 생성이나 변경
- Firebase 초기화, Security Rules 변경, deploy 또는 migration
- Owner credential 사용
- 전체 database dump
- credential, token, 계정 이메일 또는 개인정보 출력
- MCP 결과를 공식 validation evidence의 대체물로 사용

금지 도구가 노출되거나 project 또는 account 확인이 불명확하면 조회하지 않고
`BLOCKED`로 보고한다.

## Completed Windows pilot evidence

Windows 로컬 파일럿에서는 runtime에 노출된 도구가 정확히 두 개였고
`firebase_get_project`가 예상 project를 반환했다. 사용자가 승인한 production read는
다음 한 건뿐이다.

```text
Path: /codex_mcp_readonly_probe/phase9-20260829
Expected: null
Actual: null
Calls: 1
```

응답에는 개인정보가 없었고 write, deploy, Auth 접근 또는 repository mutation이
발생하지 않았다. 이 evidence는 같은 production 조회의 반복 승인이 아니다.

동일 상태 확인이 반복되면 MCP 조회를 늘리지 말고 Project CLI assertion, Firebase
Emulator 또는 integration test로 자동화한다.

## References

- [Firebase MCP server](https://firebase.google.com/docs/ai-assistance/mcp-server)
- [Firebase Realtime Database IAM roles](https://cloud.google.com/iam/docs/roles-permissions/firebasedatabase)
- [Codex MCP configuration](https://developers.openai.com/codex/mcp)
- [Mosigame Project CLI](PROJECT_CLI.md)
