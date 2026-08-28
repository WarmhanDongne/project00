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
4. Analyze a failure before changing code. Make only a bounded, in-scope
   correction supported by the failure evidence, then rerun the affected check.
   Do not create a retry engine or loop indefinitely. Stop when the same failure
   repeats without a safe next step or an approval condition is reached.

## Validate the final candidate

1. After the implementation and relevant tests are stable, run
   `validate --full` once through the platform route defined in `PROJECT_CLI.md`.
   On Windows, use the guarded invocation for validation and bounded automation.
2. Compare the Git state before and after validation. Investigate unexpected
   tracked or unignored mutation and confirm that pre-existing changes remain
   intact.
3. Do not describe `FAIL`, `BLOCKED`, an unrun check, or an internal error as a
   successful completion.

## Report evidence

Report the changed files, actual commands, status and exit code, relevant test
results, FULL validation result, branch and HEAD, final staged/unstaged/untracked
state, preservation of pre-existing changes, unexpected mutations, and remaining
limitations or findings. Do not stage, commit, push, deploy, migrate, access
production Firebase, orchestrate other models or agents, or declare an independent
`ACCEPT` unless the user separately authorizes the applicable action.

Ask for approval before adding a dependency; changing a public API, persistent data
contract, or important state machine; making a significant architecture or product
decision; accessing production; deploying or migrating; conflicting with user
changes; or expanding beyond the requested scope.
