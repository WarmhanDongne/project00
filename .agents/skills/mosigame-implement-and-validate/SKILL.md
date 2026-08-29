---
name: mosigame-implement-and-validate
description: Implement or fix Mosigame code when the request expects a completed, validated result, including continuation of an existing in-scope implementation. Do not use for questions, status checks, read-only analysis, planning, independent review, documentation-only work, Git-only operations, deployment, migration, or production Firebase access.
---

# Mosigame Implement and Validate

Complete a scoped Mosigame implementation with proportional checks and one
canonical final validation.

## Prepare and preserve

1. Read the repository-root `AGENTS.md`, `ENGINEERING_CONTRACT.md`, and the
   task-specific context they route to. Read `PROJECT_CLI.md` before running
   Project CLI commands.
2. Record the branch, HEAD, staged, unstaged, and untracked state. Preserve
   pre-existing user changes and work-items; never reset, restore, stash, delete,
   rewrite, or stage them.
3. Inspect the relevant implementation and existing tests, then make the smallest
   change supported by current contracts.

## Choose relevant checks

- Session changes: run `dart run :mosigame test session` through the platform
  route in `PROJECT_CLI.md`.
- Auth changes: run `dart run :mosigame test auth` through that route.
- Other changes: run the directly relevant existing tests. Do not invent a new
  Project CLI suite merely for one task.
- Final implementation candidate: run guarded `validate --full` once on Windows,
  or the documented raw form on macOS/Linux.

The normal FULL pipeline excludes the slow Windows invocation-guard integration
suite. Run that suite separately on Windows when `tool/invoke_mosigame.ps1`,
Project CLI process execution or cleanup, or guard deployment/environment
configuration changes:

```powershell
flutter test --no-pub test\mosigame_cli\invocation_guard_test.dart
```

## Handle failures

Diagnose the observed failure before editing. Make only an evidenced, in-scope
correction and rerun the affected check rather than the entire FULL pipeline.
Run FULL again only when the correction produces a new final candidate.

Stop and report instead of guessing when the same failure repeats, a timeout or
CLI/guard internal error prevents a trustworthy result, user input is required,
or the change reaches an approval boundary. Never weaken, delete, or skip a
relevant test to obtain a pass. `PROJECT_CLI.md` owns CLI status, timeout, and
exit-code meanings; do not duplicate them here.

Ask for approval before adding a dependency; changing a public API, persistent
data contract, or important state machine; accessing production; deploying or
migrating; conflicting with pre-existing user changes; or expanding scope.

## Report

Report changed files, commands, results and exit codes, FULL validation, branch
and HEAD, final Git state, preservation of existing changes, unexpected mutation,
and remaining limitations. Do not stage, commit, push, deploy, migrate, access
production Firebase, or declare an independent `ACCEPT` without separate
authorization.
