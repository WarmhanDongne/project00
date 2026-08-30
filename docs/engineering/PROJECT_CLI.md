# Mosigame Project CLI

The Project CLI owns repository checks, test selection, result aggregation, and its
`0`–`4` exit-code contract. The Windows invocation guard is a thin process
supervisor around that CLI. It does not reproduce validation or doctor logic.

## Commands

The portable raw commands below express the canonical Project CLI behavior. Run
them from the repository root with the Flutter SDK's Dart available on `PATH`:

```text
dart run :mosigame doctor
dart run :mosigame test session
dart run :mosigame test auth
dart run :mosigame validate --full
```

## Platform routing

On macOS and Linux, use the portable raw commands directly from bash, zsh, or
another compatible shell. The repository does not currently contain a POSIX
invocation guard:

```bash
dart run :mosigame doctor
dart run :mosigame test session
dart run :mosigame test auth
dart run :mosigame validate --full
```

Do not install or invoke PowerShell on macOS/Linux merely to use the Windows
guard. If non-Windows automation requires an outer deadline and exact descendant
cleanup, the caller or CI environment must currently provide those guarantees. A
repository-owned POSIX guard would be a separate implementation with its own tests,
not a portable use of the Windows script.

On Windows, use the guarded form for validation, automation, restricted execution
environments, and any invocation whose caller needs a bounded result:

```powershell
.\tool\invoke_mosigame.ps1 doctor
.\tool\invoke_mosigame.ps1 test session
.\tool\invoke_mosigame.ps1 test auth
.\tool\invoke_mosigame.ps1 validate --full
```

The guard finds the repository root relative to its tracked script, so it is safe
to invoke from another working directory. It forwards arguments in their original
order through a Base64-encoded JSON environment payload rather than constructing a
shell command from user input. Only the fixed `run :mosigame` arguments cross the
Windows batch boundary; the CLI entry point decodes the original argument array.

## Why the Windows guard exists

The Flutter SDK's Windows batch launchers acquire a cache lock before starting
`dart.exe`. In a restricted execution environment, writes to that SDK cache may be
denied. Some launcher versions can treat the denied lock operation like lock
contention and retry without visible output. Because the Mosigame CLI process has
not started, its internal progress reporting and per-step timeouts cannot help.

The repository-owned guard starts its deadline before the batch launcher. It starts
a fixed PowerShell bridge suspended, assigns it to a Windows Job Object, then lets
the bridge invoke `dart.bat`. The bridge, batch shell, CLI, and their descendants
therefore remain in one exact process tree owned by the guard.

Do not patch an SDK launcher, delete its cache, change SDK/cache ACLs, or require
administrator privileges to work around this condition. Fix the execution
environment or use the explicit `BLOCKED` result.

## Deadlines and progress

- Startup deadline: 60 seconds from the moment the guarded bridge is resumed until
  the Project CLI entry point creates its exclusive startup marker in the system
  temporary directory. Guard setup and C# compilation are reported separately and
  do not consume the CLI startup budget or reported CLI-startup duration. Batch or
  PowerShell launcher noise after resume still counts. While startup remains
  unobserved, the deadline is checked before accepting a marker so a marker first
  observed at or after the deadline is rejected.
- Overall deadline: 15 minutes from guard start until the entire guarded Job Object
  becomes empty.
- Heartbeat: every 30 seconds while the child tree remains active.

Child stdout is forwarded to stdout and child stderr to stderr. Guard diagnostics,
guard-setup timing, CLI-startup timing, and heartbeat lines use stderr and are prefixed
`[mosigame guard]`. The guard does not rewrite normal CLI output or print environment
variables, credentials, tokens, or other secrets.

## FULL validation execution policy

`validate --full` runs its validation steps in order and stops after the first
non-PASS result. It still captures working-tree snapshot B so mutation evidence is
not lost. Fix the evidenced failure, rerun only its relevant check while iterating,
then run FULL once for the next final candidate.

The CLI gives FULL validation a 13-minute total budget. Before starting each
process step it separately reserves the final two-minute working-tree snapshot,
ten seconds for worst-case validation-process cleanup, and ten seconds for
worst-case snapshot Git-process cleanup. A step receives the shorter of its own
safety cap and the remaining FULL budget after those reserves. A timed-out step or
unconfirmed cleanup makes snapshot B mutation evidence untrusted even when the two
snapshots compare unchanged. The Windows guard's 15-minute overall deadline remains
the outer cleanup safety net.

The Windows invocation-guard integration suite is deliberately excluded from normal
FULL validation because it creates real process trees and exercises real deadlines.
Run it separately on Windows when `tool/invoke_mosigame.ps1`, Project CLI process
execution or cleanup, or guard deployment/environment configuration changes:

```powershell
flutter test --no-pub test\mosigame_cli\invocation_guard_test.dart
```

Use a Windows shell where the Flutter SDK cache is writable and keep an external
deadline. Ordinary product changes do not run this suite.

## Results and exit codes

Natural Project CLI exit codes are preserved:

| Exit | Result | Meaning |
| ---: | --- | --- |
| 0 | PASS | All requested checks passed. |
| 1 | FAIL | A check failed, or the guard's overall deadline expired after progress. |
| 2 | INVALID | Command arguments are invalid. |
| 3 | BLOCKED | A required environment capability is unavailable, including failure to establish exact Job Object supervision or observe the Project CLI startup marker before its deadline. |
| 4 | INTERNAL ERROR | The CLI/guard failed internally or exact process-tree cleanup could not be confirmed. |
| 130 | INTERRUPTED | The caller interrupted the guard; cleanup was confirmed. |

On deadline or interrupt, the guard terminates only its Job Object and waits a
bounded five seconds for it to empty. It never searches for or kills processes by
name. Other Dart analysis servers, Flutter daemons, terminals, Node/Java/Gradle
processes, and unrelated work remain outside that job. If cleanup cannot be
confirmed, the result is exit `4`, not success or a timeout result.

## JSON contract

With `--json`, normal child stdout is buffered until natural completion. A naturally
completed CLI emits its existing single `schemaVersion: 1` JSON document unchanged;
child and guard progress remains on stderr.

If the guard itself must decide the result, stdout contains exactly one JSON object.
It uses `schemaVersion: 1` for the current repository contract and is distinguished
from a CLI result by `resultType: "invocationGuard"`. Its stable top-level fields
are `command`, `status`, `startedAt`, `durationMs`, and `exitCode`; `guard` contains
`status`, `reason`, `progressObserved`, and `cleanupConfirmed`. A cleanup failure has
top-level `status: "FAIL"`, `guard.status: "INTERNAL_ERROR"`, and exit `4`.

No heartbeat or diagnostic text is written to JSON stdout. On a guard-level failure,
any incomplete child stdout is discarded before the single guard result is emitted.

## When raw invocation is acceptable

Raw CLI use is acceptable for short, interactive local work when the SDK cache is
writable, the caller already supplies an outer deadline and exact descendant cleanup,
or a non-Windows environment is being used. On macOS/Linux it is the current normal
repository invocation. The canonical CLI behavior is still the raw command; the
guard adds Windows invocation safety without changing it.

## Troubleshooting

- `dart-launcher-not-found`: put the supported Flutter SDK `bin` directory on PATH.
- `startup-timeout`: the Project CLI startup marker was not observed within 60
  seconds after the guarded bridge resumed. Verify that the SDK cache is writable
  by the execution identity.
  Do not change SDK code or ACLs merely to bypass the environment policy.
- `overall-timeout`: inspect child progress on stderr and determine which existing
  CLI step exceeded the outer 15-minute budget.
- `cleanup-unconfirmed` or another internal error: do not report validation as
  passed. Preserve the evidence and investigate Job Object support and host policy.
- Repository-root errors: keep the tracked script under `tool/`; do not copy it to
  an unrelated directory.

The detailed CLI implementation is in [`bin/mosigame.dart`](../../bin/mosigame.dart) and
[`tool/mosigame_cli/`](../../tool/mosigame_cli/). The common completion rules remain in
[`ENGINEERING_CONTRACT.md`](ENGINEERING_CONTRACT.md).
