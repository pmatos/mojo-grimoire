# Current decisions: process, CI and checks

This page continues [process.md](process.md) with CI and its checks.

## One list of checks, one gate

Every check is a hook of `.pre-commit-config.yaml`, which keeps local and CI
one list (ADR-2026-11-15-1903). `.github/workflows/ci.yml` runs each hook in
one step of one job:

- `static`: the file checks, the ADR checks, the Python tests of the scripts,
  the linters and formatters (typos, ruff, shellcheck, actionlint, zizmor);
- `lean`: `lean-build`, which builds `lean/` with `--wfail` and so runs the
  Lean tests and the axiom check (ADR-2026-11-15-1906); `spec`, which renders
  the spec; and `conformance`, which runs the model on the conformance suite
  ([conformance.md](conformance.md#the-suite)).

The gate job `pre-commit` needs both, always runs, and passes only when both
passed. It is the check that the ruleset requires. `.github/workflows/pr-title.yml`
runs `conventional-pre-commit` on the PR title as the `PR title` check. The
`ci-hooks` hook fails when a hook runs in no step or in two, or when the gate
does not need every job.

Rejected: requiring each job's check in the ruleset, so that every new job
would need a ruleset change.

## Hooks locally

`./scripts/ensure-hooks.sh` installs the `pre-commit` and `commit-msg` hooks.
Claude's `SessionStart` hook runs it, and its `PreToolUse` gate blocks edits
and shell commands until the hooks are installed. Nobody bypasses a check: no
`--no-verify`, no `SKIP=`, no overridden `core.hooksPath`.

Before a push, run the smoke test,
`pre-commit run --all-files --hook-stage pre-push`. It runs the fast hooks on
every file. `lean-build` is slow and sets `stages: [pre-commit]`, so the smoke
test skips it; it runs on a commit that touches `lean/`, and in CI.

## The Python test runner

Each Python test hook runs its tests through `scripts/run_unittests.py`, which
runs them as `python FILE` would and, in CI, writes one row of counts to the
job summary: tests run, passed, failed, errors and skipped. `lean-build` writes
the counts of `#guard`s, theorems and examples per library the same way,
through `scripts/suite_summary.py`.

## Caches

The `static` job caches `~/.cache/pre-commit`. The `lean` job caches the Lean
toolchain, keyed by `lean/lean-toolchain`. On a pull request it restores
`lean/.lake/build` as `main` last built it, and Lake rebuilds what changed. A
push to `main` builds from scratch and saves the build, keyed by its commit. A
hit trusts Lake's traces, so code that adds a read at elaboration declares it
in the lakefile in the same PR; the list of `.lean` files that
`#check_axioms` walks is the target `sourcePaths`.

## Installer downloads

CI caches elan's installer download. Its pins, `ELAN_VERSION` and
`ELAN_SHA256`, are in the `env` of both the restore step and the install
step; a bump edits both. `scripts/ci-install.sh elan` downloads it only when
the restore found no copy, and checks its SHA-256 on every run before using
it.

Rejected: `leanprover/lean-action`. A checksummed elan tarball needs no
third-party action (ADR-2026-11-15-1905).

## Actions and dependencies

Every action is pinned to a commit SHA with its version in a comment.
Dependabot updates them weekly, after a 7-day cooldown, with the commit
prefix `ci`. Workflows default to `contents: read` and check out without
persisted credentials.
