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

The roadmap is the human's document "Mojo Formal Semantics in Lean — Roadmap",
kept as written in [`docs/roadmap.md`](../roadmap.md); the human asked for the
copy on 2026-11-15. This page records where the project departs from it. Its
phases run from Phase 0, groundwork, to Phase 6, compile-time semantics,
with gates G0 to G5. v1 is gate G5. Changing the roadmap is a direction call
for the human. Phase 0 drops the roadmap's step of contacting the Isabelle
model's author, by the human's ruling of 2026-11-15. The roadmap puts every
disagreement with the compiler in the decision log; by the human's ruling of
2026-11-16, the log records only where the model departs from the compiler
([conformance.md](conformance.md#the-decision-log)). The roadmap also
classifies a mismatch as a spec decision; by the human's ruling of
2026-11-19, the only departure is a compiler bug. The roadmap builds Mojo
1.2.x from source at a pinned commit; by the human's ruling of 2026-11-19,
the reference is the latest nightly, pinned as a wheel checked by sha256
([semantics.md](semantics.md#the-reference), #160).

Phase 0 is done: gate G0 holds at the pin of the time, Mojo 1.2.0, as
[phase0-baseline.md](../conformance/phase0-baseline.md) records.

### Phase 1: the core calculus in Lean

The roadmap's Phase 1 ported the Isabelle model, retargeted its translator
and compared against its suite. That conflicts with the project's
independence (ADR-2026-11-15-1908), so the human approved this re-scoped
Phase 1 on 2026-11-15. In order:

1. The spec site, ported from funk (ADR-2026-11-15-2030), so that every module
   below lands with its readable section.
2. Abstract syntax, the static checker (accept, or reject with an error
   class) and ASAP elaboration in `MojoGrimoire.Core`, designed in our own
   terms, for the Micro-Mojo subset: structs, methods, the argument
   conventions, moves and copies, control flow and `Int`. Elaboration
   destroys each field of `self` inside `__deinit__` at its last use, as the
   compiler does: the human ruled on 2026-11-15 that the model gets the
   Isabelle model's two divergences (`d05`, `d13`) right from the start.
   Then lists and references: `List[T]` and indexing, `ref` bindings, and
   references returned with an origin (`-> ref[a, b] T`), with the lifetime
   extension that such a reference implies. The human added them to Phase 1
   on 2026-11-15 (#12). Arrays, `Array[T, N]`, came with the compiler's
   results: Mojo types an unannotated literal as an array, and the human
   ruled on 2026-11-16 that the model follows it (#27).
3. An executable big-step interpreter with fuel and explicit run-time
   errors.
4. A parser written in Lean from `.mojo` source to the abstract syntax, so
   that the model runs on a `.mojo` file directly, as the compiler does. The
   human chose a Lean parser over a separate tool on 2026-11-15.
5. Our own conformance suite in `tests/conformance/` and its runner. Expected
   results are recorded from the pinned compiler through the wrapper; CI
   compares the model with them.

Gate G1: the model agrees with the recorded compiler results on our suite.
As an optional cross-check run outside this repository, it also agrees with
the compiler on the Isabelle formalisation's 65 programs. The human agreed
this wording on 2026-11-15.

Rejected: retargeting the Isabelle translator and passing its suite, which
would make the model depend on code and tests we may not reuse.

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

### Review depth

`REVIEW.md` at the root lists the high-stakes paths. Any PR that touches one
rates at least `high` for merge risk, and so gets the deep, multi-agent
review. The human chose the list on 2026-11-18 (#63): the core syntax, the
checker, the elaborator, the interpreter and the parser, plus the files that
decide what a pass means: the conformance runner, `known.json`,
`diagnostics.json`, the trusted-declaration and axiom checks, the lakefile,
the rulesets and the pre-commit configuration. Before the list existed, every
PR rated low, and the quick reviews missed soundness regressions that the
deep reviews later found (#91, #92, #94).

Rejected: only the four semantic directories, which would have given parser
changes and changes to what counts as agreement a quick review. Also rejected:
every model, build, toolchain and conformance file, which would have sent
docs-only PRs and recorded results to the deep review. `Driver/` and the build
scripts are left out.

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
