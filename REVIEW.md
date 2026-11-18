# Review instructions

The pm-risk skill reads this file from the PR's base branch, never from the
PR itself, and pm-cr reads it as review instructions. AGENTS.md holds the
rules; this file only names the paths that need a deeper review. The human
chose this list on 2026-11-18 (see `docs/decisions/process.md`).

## High-stakes paths

A change to any of these paths rates at least `high` for merge risk, so it
gets a deep review. The list covers the model's semantics, and the files that
decide what it means for the model to agree with the compiler.

- `lean/MojoGrimoire/Core/` (the core syntax)
- `lean/MojoGrimoire/Check/` (the checker)
- `lean/MojoGrimoire/Elab/` (the elaborator)
- `lean/MojoGrimoire/Interp/` (the interpreter)
- `lean/MojoGrimoire/Parse/` (the parser; parse-level rejections are pinned only by `#guard` tests, not by the suite)
- `scripts/conformance.py` (runs the suite and compares results)
- `tests/conformance/known.json` (accepted disagreements)
- `tests/conformance/diagnostics.json` (maps compiler messages to error classes)
- `lean/MojoGrimoireCheck.lean` (the trusted-declaration check)
- `lean/MojoGrimoireTest/Axioms.lean` (the axiom check)
- `lean/lakefile.lean` (build options and targets)
- `.github/rulesets/` (the merge gate on main)
- `.pre-commit-config.yaml` (every check the project runs)
