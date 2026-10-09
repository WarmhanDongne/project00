# E13 backend integration

This harness belongs only to `codex/e13-emulator-ci`. It starts Auth, RTDB,
Firestore and Functions under the fixed `demo-mosigame-e13` project on loopback.
Production `firebase.json`, Firebase options and function sources are unchanged.

With Node 22 and Java 21 available, from the repository root:

```text
npm --prefix functions ci --no-audit --no-fund
node tool/emulator/run.mjs
```

Use a Windows shell which can write the worktree and emulator cache. The same
Node runner is used on Linux CI. No Firebase login, Android device, new npm/Dart
dependency, deploy or production credential is needed. The first run may download
the Firebase emulator binaries. Java heaps are capped at 512 MiB each, scenarios
run sequentially and fixture seeding avoids dispatching 505 simultaneous events.

The runner builds the real candidate and creates an ignored `build/e13-runtime`
entry. That entry requires both `FUNCTIONS_EMULATOR=true` and the exact demo
project, sets the namespace which the CLI has installed the actual repository
rules into, and changes only the five RTDB trigger discovery regions to
`us-central1`. The test checks that the original exports still use
`asia-southeast1`, refuses non-demo/non-emulator adapter use, and compares the
running rules with `database.rules.json` before any behavioral tests.

Clients use the RTDB standalone implementation already locked through
`firebase-admin`; each client runs in a separate process with Admin mode disabled
and an Auth emulator ID token. This internal standalone entry is intentionally
confined to the test branch and existing lockfile. Its real reads, subscriptions,
writes and onDisconnect registrations must satisfy the repository rules.

The ten scenarios cover four game starts/progression/endings, operation replay,
private context stamping and read/write denial, multi-cause readiness barriers,
actual phone/controller presence triggers, expiration and one extension,
controller exclusion, lost leave results and rejoin protection, entitlements,
reservation-only recovery, cleanup indexing and a cursor beyond 505 tombstones.
Scheduler handlers are explicitly invoked against emulator data; Cloud Scheduler
delivery itself is not emulated. Fixture-only background dispatch suppression is
restored before all live trigger and scheduler assertions.

The runner has an outer ten-minute emulator deadline, checks required ports
before execution and after shutdown, and compares content hashes and Git state
before/after. On timeout it terminates only its child process tree on Windows or
its process group on Linux. CI uploads sanitized `backend-result.json` and
`run-result.json`. Raw emulator logs stay in ignored `build/e13/` locally.

This verifies backend and JS RTDB SDK boundaries. Flutter UI, FlutterFire plugin
behavior, Android/iOS lifecycle, physical disconnection, assets and recovery
performance still require the remaining app integration/device checks.

References: [Firebase demo projects and RTDB emulator](https://firebase.google.com/docs/emulator-suite/connect_rtdb),
[Functions emulator](https://firebase.google.com/docs/emulator-suite/connect_functions),
[Emulator configuration](https://firebase.google.com/docs/emulator-suite/install_and_configure).
