# Every change reaches main as a squash-merged PR with a Conventional Commit title, up to date with main

Status: accepted
Tier: direction; area: process

## Decision

- A repository ruleset on `main`, versioned in `.github/rulesets/main.json`,
  requires a pull request, blocks force pushes and deletion, requires linear
  history and requires the `pre-commit` and `PR title` checks to pass. It has
  no bypass actors: nobody, admins included, pushes to `main` directly. In an
  emergency the human edits the ruleset in GitHub settings, then restores it
  from the file.
- The ruleset sets `strict_required_status_checks_policy` to `true`. A pull
  request merges only when its branch contains the head of `main` and the
  required checks passed on the branch's own head.
- The live ruleset follows the file. It is created with
  `gh api -X POST repos/pmatos/mojo-grimoire/rulesets --input .github/rulesets/main.json`,
  and an edit is applied with
  `gh api -X PUT repos/pmatos/mojo-grimoire/rulesets/<id> --input .github/rulesets/main.json`
  and read back.
- PRs merge by squash only. The commit on `main` is `<PR title> (#N)`, and the
  branch is deleted on merge.
- Commit messages and PR titles are Conventional Commits. One checker,
  `conventional-pre-commit`, runs as the local `commit-msg` hook and, in CI,
  against the PR title, through the same `.pre-commit-config.yaml`.
  Dependabot's commit prefix is `ci`.

The human asked on 2026-11-15 for this repository to be set up as jsse and
funk are, with `main` protected and Conventional Commits.

## Why

Agents commit to this repository. Every change must be reviewable and gated by
CI, history on `main` must stay linear and readable, and commit messages must
be machine-readable. Checks that ran on an older `main` no longer describe
what a merge produces. funk reached these rules first, and this repository
adopts them as they stand there.

## Rejected alternatives

- **A merge queue.** GitHub offers one only to repositories that an
  organization owns.
- **commitlint, as jsse uses.** A second implementation in Node that could
  disagree with the local hook.
- **Also lint commits pushed to `main`.** Every commit on `main` is a squash
  whose header is the PR title, which is already checked.
