# CI runs every pre-commit hook, one job per suite, behind one gate job named pre-commit

Status: accepted
Tier: direction; area: process

## Decision

- Every check is a hook of `.pre-commit-config.yaml`, which keeps local and CI
  one list. CI runs each suite of hooks as its own job of
  `.github/workflows/ci.yml`: `static` and `lean` today.
- One step per hook, in one form:
  `uvx pre-commit@4.6.2 run ID --all-files --verbose --show-diff-on-failure`.
  Each step runs even when one before it failed. No job sets `SKIP`.
- A gate job, `pre-commit`, needs every suite job, always runs, and passes
  only when each of them succeeded. It is the check that the ruleset
  requires (ADR-2026-11-15-1900).
- The `ci-hooks` hook fails when the config, the workflows' steps and the
  gate disagree. A new hook needs a step in one job, and a new job a place in
  the gate's `needs`.
- In CI, each test suite writes its counts to the job summary and the log.
- Before a push, an agent runs the smoke test,
  `pre-commit run --all-files --hook-stage pre-push`. Slow hooks, such as
  `lean-build`, set `stages: [pre-commit]`, so it skips them; CI runs them.

The human asked on 2026-11-15 for this repository to follow funk's setup.

## Why

A suite per job shows each suite as its own check with its own counts, and
runs them in parallel. One gate keeps the ruleset fixed as suites are added.

## Rejected alternatives

- **Require each suite's check in the ruleset.** Every new job would need a
  ruleset change.
- **Checks written directly in workflows.** Local runs and CI would drift.
