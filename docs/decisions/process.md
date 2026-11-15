# Current decisions: process

This page says what holds today for how mojo-grimoire is built and changed. It
is the record: when this page and an ADR it cites disagree, the page wins, and
the ADR is fixed or deleted (ADR-2026-11-15-1902).
[process-ci.md](process-ci.md) continues it with CI and its checks.

## Who decides what

Every agent follows one approval boundary, orchestrators included
(ADR-2026-11-15-1904).

- An unanswered direction question waits in a `human-ready` issue. A timeout or
  the human's absence never supplies an answer. Independent work continues.
- Ambition means finishing the agreed ticket scope. Additional work is filed
  separately. The human rules before a ticket widens.
- An agent asks before introducing new tooling or checking machinery,
  including hooks and verifiers, and before changing the roadmap.

Routine implementation choices, such as naming and test details, may proceed
within the ticket's scope. They are recorded. `AGENTS.md` holds these standing
rules. The human asked on 2026-11-15 for funk's practice to be adopted here.

Rejected: deciding a direction question and recording the choice afterward. In
funk, agents did so while the human was away.

## Direction: the roadmap

The roadmap is the human's document "Mojo Formal Semantics in Lean — Roadmap".
Its phases run from Phase 0, groundwork, to Phase 6, compile-time semantics,
with gates G0 to G5. v1 is gate G5. Changing the roadmap is a direction call
for the human. Phase 0 drops the roadmap's step of contacting the Isabelle
model's author, by the human's ruling of 2026-11-15.

## How a change reaches main

Every change reaches `main` as a squash-merged pull request
(ADR-2026-11-15-1900). A repository ruleset, versioned in
`.github/rulesets/main.json`, enforces this. It requires a pull request and
linear history, blocks force pushes and deletion, and has no bypass actors.
It requires the `pre-commit` and `PR title` checks, and a pull request must be
up to date with `main` before it merges.

1. Branch from an up-to-date `main`. Never commit on `main`.
2. Write commit messages as Conventional Commits; the `commit-msg` hook checks.
3. Open a PR whose title is a Conventional Commit header: squash merging makes
   it the commit message on `main`. Body: what changed and why, `Closes #N`.
4. If the PR is behind `main`, merge `main` into it and wait for its checks on
   the new head. `docs/adrs/INDEX.md` is generated: resolve every other
   conflict first, then run `python3 scripts/adr_index.py --write`.
5. Merge by squash once CI is green. Never merge red.

The format is `type(scope)!: summary`, with the types `feat`, `fix`, `perf`,
`refactor`, `docs`, `test`, `build`, `ci`, `chore`, `style` and `revert`.

Rejected: commitlint, which jsse uses. It is a second implementation, in
Node, that could disagree with the local hook.

## File-size budget

Every text file is at most 20,000 bytes, so any agent can read any file whole
in one pass (ADR-2026-11-15-1901). The `file-size-budget` hook enforces it on
commit and in CI. A file that would exceed it is split by responsibility into
focused sibling files. Only generated or vendored files are excluded, through
the hook's `exclude` pattern; `docs/adrs/INDEX.md` is one.

Rejected: jsse's ratchet that lets an oversized file stay while it does not
grow. This repository starts with no oversized file.

## ADRs

ADRs are named by their UTC timestamp, carry a tier and an area, and are
listed in a generated index (ADR-2026-11-15-1902). The areas are
`semantics`, `lean-model`, `conformance`, `spec` and `process`, each with a
page here. An ADR is written only for a direction decision that binds more
than one module, is edited in place when the decision changes, and is deleted
with a row in `docs/adrs/removed/AREA.json`. `docs/adrs/README.md` has the rules and the
template.

Rejected: immutable ADRs with `superseded by` chains, which in funk grew
chains no one read.
