# mojo-grimoire

mojo-grimoire is an executable, proof-carrying semantics of Mojo in Lean 4,
whose fidelity is established by differential testing against the open-source
Mojo compiler. GitHub repo: **`pmatos/mojo-grimoire`**. Use this owner/repo
for every `gh` and GitHub MCP call.

## How this project is built

A human guides; agents build. The human sets the direction: the roadmap, the
scope of v1 and the calls only they can make. Agents do the rest: design,
implementation, proofs, tests, docs, ADRs, reviews and PRs. Leave everything
so that the next agent, starting cold, can continue from the repository alone.

## Direction questions and standing rules

- An unanswered direction question waits. Record it in a `human-ready` issue.
  Never choose an answer because a timeout expires or the human is
  unavailable. Continue work that does not depend on the answer.
- Routine implementation choices, such as naming and test details, may
  proceed within the ticket's scope and must be recorded.
- Ask the human before introducing new tooling or checking machinery,
  including hooks and verifiers, before adding a Lean dependency, and before
  changing the roadmap.

ADR-2026-11-15-1904 records these rules.

## Ambition without shortcuts

- Finish everything the ticket asks for. File additional work separately and
  obtain the human's ruling before widening the ticket.
- Size is never a reason to cut scope. Large work gets a plan: break it into
  issues and a sequence of reviewable PRs, then deliver all of them.
- No `sorry`, stub or placeholder to make work look finished. Anything left is
  tracked in an issue that says what remains.
- A real blocker is a contradiction in the decisions, a missing direction
  call, or a technical limit you have evidence for. Name it, with what would
  unblock it.

## Where we are going: roadmap, decisions, ADRs

| Document | Path | Answers |
| -------- | ---- | ------- |
| Roadmap | the human's roadmap document; its phases are summarised on [`docs/decisions/process.md`](docs/decisions/process.md) | What we build next, and in what order |
| Decision pages | [`docs/decisions/`](docs/decisions/) | What holds today, per area |
| ADRs | [`docs/adrs/`](docs/adrs/) | What we decided, and why |
| Decision log | [`docs/conformance/decision-log.md`](docs/conformance/decision-log.md) | Where the model and the compiler disagree, and what we chose |

- An agent starting cold reads the decision pages first. When a page and an
  ADR disagree, the page wins, and the ADR is fixed or deleted.
- If your work would contradict any of them, surface the conflict explicitly.
  Never override one silently.

## The two rules of the model

- **The compiler is the reference.** Mojo has no written specification. The
  open-source compiler at the pinned release (1.2.x today) is the reference,
  and every disagreement goes in the decision log as a model bug, a compiler
  bug or a spec decision (ADR-2026-11-15-1907).
- **The project is independent.** The Isabelle formalisation
  `utting/mojo-semantics` is a reference point only. Never import, vendor,
  translate or generate code from it, and never copy its test programs or
  expected outputs (ADR-2026-11-15-1908).

## ADRs

Write an ADR in `docs/adrs/` only for a direction decision that binds more
than one module. Its form is Decision, Why and Rejected alternatives, in about
300 words, named by the UTC minute it was written. A proof's internal
structure, a choice the next PR of the same ticket may revise, and detail
that only one module needs go in that module's doc comment or on the area
page. An ADR is edited in place when its decision changes; a deleted ADR gets
a row in `docs/adrs/removed/AREA.json`. A PR that adds or changes an ADR
updates its area page in the same PR and regenerates the index with
`python3 scripts/adr_index.py --write`. Naming, rules and template:
[`docs/adrs/README.md`](docs/adrs/README.md) (ADR-2026-11-15-1902).

## Every change goes through a PR

A ruleset on `main` ([`.github/rulesets/main.json`](.github/rulesets/main.json))
blocks direct pushes, force pushes and deletion for everyone, the human
included. Every commit reaches `main` as the squash merge of a PR whose
required checks, `pre-commit` and `PR title`, are green
(ADR-2026-11-15-1900).

1. Branch from an up-to-date `main`. Never commit on `main`.
2. Write commit messages as Conventional Commits; the `commit-msg` hook checks.
3. Open a PR whose title is a Conventional Commit header: squash merging makes
   it the commit message on `main`. Body: what changed and why, `Closes #N`.
4. If the PR is behind `main`, merge `main` into it and wait for its checks on
   the new head. Never resolve a conflict in `docs/adrs/INDEX.md` by hand:
   resolve the rest, then run `python3 scripts/adr_index.py --write`.
5. Merge by squash once CI is green. Never merge red.

Format: `type(scope)!: summary`. Types: `feat`, `fix`, `perf`, `refactor`,
`docs`, `test`, `build`, `ci`, `chore`, `style`, `revert`. Write the summary
in the imperative mood, lower case, no full stop, under 72 characters.

## Hooks and checks

Run `./scripts/ensure-hooks.sh` before anything else in a clone. Claude's
`SessionStart` hook runs it, and a `PreToolUse` gate blocks edits and shell
commands until it succeeds. Start agents in another worktree with
`./scripts/agent-session.sh --worktree <path> <agent-command> [args...]`.

- Prerequisites: `pre-commit` (`uv tool install pre-commit`) and `elan`.
- Never bypass checks: no `--no-verify`, no `SKIP=`, no overridden
  `core.hooksPath`. If hooks cannot install or run, report why and do not
  commit until the environment is fixed.
- Before pushing, run the smoke test,
  `pre-commit run --all-files --hook-stage pre-push`. The slow `lean-build`
  hook is skipped there; it runs on a commit that touches `lean/`, and in CI.
- Every check lives in `.pre-commit-config.yaml`. Add new checks there, not in
  a workflow, and give each new hook a step in one job of
  `.github/workflows/ci.yml`: the `ci-hooks` hook fails until it has one
  (ADR-2026-11-15-1903).

## The Lean code

- Build only with `scripts/build-lean.sh`; it applies the guards that keep
  Lake's git calls and CI tokens away from this repository
  (ADR-2026-11-15-1905).
- The build fails on any warning, on `sorry`, on an axiom beyond Lean's
  standard three, on `unsafe` or `partial` code, and on `implemented_by` or
  `extern` (ADR-2026-11-15-1906).
- Import every new module from `lean/MojoGrimoireTest.lean`, or the axiom
  check fails.

## File-size budget

Every text file is at most **20,000 bytes**, so any agent can read any file
whole in one pass (ADR-2026-11-15-1901). When a file would exceed it, split by
responsibility into focused sibling files or modules, and update imports and
links. Never minify or shorten names to fit.

## Working safely

- Kill processes only by a PID you recorded; never `pkill -9 <pattern>`.
- Give long builds and test runs an explicit timeout up front.
- Clear stale build caches before declaring that a repro still fails.

## Agent skills

- **Issue tracker:** GitHub issues on `pmatos/mojo-grimoire`, via `gh`. See
  [`docs/agents/issue-tracker.md`](docs/agents/issue-tracker.md).
- **Triage labels:** `needs-triage`, `needs-info`, `agent-ready`, `human-ready`,
  `wontfix`. See [`docs/agents/triage-labels.md`](docs/agents/triage-labels.md).
- **Domain docs:** `CONTEXT.md` (glossary, created lazily) and `docs/adrs/`. See
  [`docs/agents/domain.md`](docs/agents/domain.md).
