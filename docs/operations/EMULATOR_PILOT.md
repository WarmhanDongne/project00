# Firebase Emulator multi-device pilot record

Status:

```text
DEFERRED — IMPLEMENTATION REVERTED / RESEARCH DOCUMENTED
```

This record describes the Android 1–3 device automation pilot investigated on
2026-08-29. The executable pilot was removed before staging or commit because
the remaining platform limitations and live-device verification did not fit the
available time. This document is not an active test procedure.

## Investigated design

The pilot combined these ideas:

- a debug-only FlutterFire connection mode for local Auth, Realtime Database,
  Firestore, Functions, and Storage endpoints;
- Flutter's SDK-provided `integration_test` development dependency;
- an allowlisted JSON runner that mapped logical roles to one to three exact
  ADB serials;
- composable lifecycle, UI, assertion, network, screenshot, and log-capture
  actions instead of one fixed room scenario;
- local artifacts with captured values omitted and common credential patterns
  redacted.

Arbitrary shell commands were intentionally excluded. Production Firebase
access, deployment, migrations, Auth mutation, and database writes were outside
the pilot.

## Evidence collected before rollback

- Scenario/config/runner Flutter tests: PASS, 12/12.
- Three-role scenario dry-run: PASS, 7 validated steps.
- Guarded `test session`: PASS; 5/5 validation steps, 76 Flutter tests, and 22
  Functions tests.
- Auth, Realtime Database, Firestore, and Functions emulators: startup and
  automatic shutdown PASS.
- Storage Emulator startup: FAIL because the repository has no approved
  `storage.rules` file. Storage scenarios were therefore treated as BLOCKED.
- Live Android execution: NOT RUN. No devices were attached during final
  verification, so neither a device integration smoke test nor a three-device
  scenario was claimed as PASS.

Temporary emulator logs were removed and no related emulator process remained.
No production Firebase read or write occurred.

## Limitation that stopped the pilot

Three production RTDB v2 triggers are correctly registered in
`asia-southeast1`, matching the real database. The local RTDB Emulator warned
that these triggers do not run there because its supported trigger region is
`us-central1`.

An Emulator-only region selector was prototyped so production discovery would
continue to use `asia-southeast1`. Its first lint run stopped on two missing
JSDoc tags. The selector and all other executable pilot changes were then
removed when the pilot was deferred; no region override remains in the code.

## Repository state after rollback

The repository intentionally retains none of the pilot's dependencies,
FlutterFire routing, Firebase Emulator configuration, Android cleartext setting,
Functions region override, integration test, scenario runner, or automated
tests. Existing application and user-owned working-tree changes are separate
from this record.

## Conditions for a future restart

Restart only after allocating time for all of the following:

1. Connect and identify up to three Android devices with stable ADB serials.
2. Approve a test-only strategy for the RTDB v2 trigger region and prove that
   deployment discovery remains on `asia-southeast1`.
3. Decide whether Storage is excluded or add separately reviewed Emulator-only
   rules.
4. Prepare deterministic local test identities and seed data without production
   credentials.
5. Run a device smoke test, a real three-device scenario, targeted suites, and
   guarded `validate --full`, including process-tree cleanup evidence.

Until those conditions are met, manual multi-device testing remains the source
of evidence for network and session behavior.
