---
name: mosigame-implement-and-validate
description: Implement or fix Mosigame code when the request expects a completed, validated result, including continuation of an existing in-scope implementation. Do not use for questions, status checks, read-only analysis, planning, independent review, documentation-only work, Git-only operations, deployment, migration, or production Firebase access.
---

# Mosigame Implement and Validate

Complete a scoped Mosigame implementation with the repository's canonical checks
and evidence. Keep the workflow proportional: use targeted tests for feedback and
run FULL validation once the final implementation candidate is ready.

## Establish the task contract

1. Read the repository-root `AGENTS.md` and `ENGINEERING_CONTRACT.md` completely.
2. Read the task-specific context routed by `AGENTS.md`, including subordinate
   `AGENTS.md` files and relevant code and tests. Read `ARCHITECTURE.md` for
   architecture, platform, Firebase, auth, or session work, and `PROJECT_CLI.md`
   before choosing validation commands.
3. Identify the requested outcome, completion evidence, exclusions, and any stop
   or approval condition before editing.

## Preserve the working tree

1. Record the branch, HEAD, upstream, and staged, unstaged, and untracked state.
2. Identify pre-existing user changes and preserve them throughout the task. Do
   not stash, reset, restore, check out over, delete, rewrite, or stage them.
3. Keep work-items and unrelated files unchanged. If the requested implementation
   conflicts with existing changes, stop and report the evidence instead of
   resolving the conflict by assumption.

## Implement and get targeted feedback

1. Inspect the relevant implementation and existing tests, then make the smallest
   change that satisfies the request and current contracts.
2. For session work, run the `session` targeted suite. For auth work, run the
   `auth` targeted suite. Run both only when both scopes are affected.
3. For work outside session and auth, select relevant existing tests without
   inventing a Project CLI suite. Follow `PROJECT_CLI.md` for platform routing.
4. Analyze a failure before changing code. Use the bounded validation loop below.

## Run the bounded validation loop

Use at most two correction attempts across targeted checks and FULL validation.
An attempt starts when a validation failure causes a source or test change and
ends after rerunning the affected check. Read-only diagnosis does not consume an
attempt. Do not create a retry engine, queue, server, or unbounded loop.

1. Record the failed command, exit code, failing check or test, and the smallest
   useful failure signature before changing anything.
2. Classify the failure using the terminal states below. Correct it only when the
   cause is evidenced, the change stays within the original task and contracts,
   and no stop or approval condition applies.
3. Use one correction attempt, make the smallest supported change, and rerun the
   affected targeted check. If the same failure signature remains, stop as
   `FAIL` without spending another attempt on speculative changes. A different
   evidenced in-scope failure may use the remaining attempt.
4. Stop as `FAIL` when two correction attempts are exhausted and a validation
   failure remains. Preserve the failing evidence; do not weaken, delete, or skip
   tests to obtain a pass.
5. Stop immediately on a guard timeout or Project CLI internal error instead of
   automatically rerunning. Preserve the raw command status and exit code:
   startup timeout or Project CLI `BLOCKED` with exit 3 maps to workflow
   `BLOCKED`; overall timeout after progress with exit 1 maps to workflow
   `FAIL`; CLI or guard internal error with exit 4 maps to workflow `BLOCKED`
   while preserving the actual top-level status and nested guard status when
   present. For example, cleanup failure remains top-level `FAIL`, nested guard
   `INTERNAL_ERROR`, and exit 4. A caller timeout without a trustworthy CLI
   result maps to workflow `BLOCKED`.
6. Stop as `NEEDS_INPUT` when required user information or product intent is
   missing. Stop as `NEEDS_APPROVAL` before adding a dependency, accessing
   production, expanding scope, making an important design decision, or touching
   a conflicting pre-existing user change. Do not consume correction attempts
   while waiting for input or approval.

Use exactly one final workflow state, separate from any raw CLI status:

- `PASS`: relevant targeted checks and FULL validation passed, with working-tree
  safety confirmed.
- `FAIL`: an in-scope code or test failure remains after the same failure repeats
  or the correction budget is exhausted, or the Windows guard reports its
  progress-observed overall timeout with exit 1.
- `BLOCKED`: execution cannot continue reliably because of timeout, environment
  failure, Project CLI `BLOCKED`, or Project CLI internal error, except for the
  guard's exit 1 overall-timeout case classified as workflow `FAIL` above.
- `NEEDS_INPUT`: required user information or intent is missing.
- `NEEDS_APPROVAL`: a repository approval condition or scope boundary was reached.

## Validate the final candidate

1. After the implementation and relevant tests are stable, run
   `validate --full` through the platform route defined in `PROJECT_CLI.md`.
   On Windows, use the guarded invocation for validation and bounded automation.
   If FULL validation fails because of the current task and correction budget
   remains, apply the bounded loop: make one evidenced correction, rerun the
   affected targeted check, then rerun FULL validation. Otherwise stop with the
   applicable terminal state.
2. Compare the Git state before and after validation. Investigate unexpected
   tracked or unignored mutation and confirm that pre-existing changes remain
   intact.
3. Do not describe `FAIL`, `BLOCKED`, an unrun check, or an internal error as a
   successful completion.

## Report evidence

Report the final workflow state; correction attempts used; each failed command,
its actual top-level status, nested guard status when present, exit code, failure
signature, diagnosis, and resulting correction; changed files; relevant test
results; FULL validation result; branch and HEAD; final staged, unstaged, and
untracked state; preservation of pre-existing changes; unexpected mutations; and
remaining limitations or findings. Do not stage, commit, push, deploy, migrate,
access production Firebase, orchestrate other models or agents, or declare an
independent `ACCEPT` unless the user separately authorizes the applicable action.

Ask for approval before adding a dependency; changing a public API, persistent data
contract, or important state machine; making a significant architecture or product
decision; accessing production; deploying or migrating; conflicting with user
changes; or expanding beyond the requested scope.
