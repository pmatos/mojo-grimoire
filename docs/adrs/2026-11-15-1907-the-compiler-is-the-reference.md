# The open-source Mojo compiler at a pinned release is the reference, and every disagreement is recorded

Status: accepted
Tier: direction; area: semantics

## Decision

- Mojo has no written specification. The open-source Mojo compiler at a
  pinned release is the reference that the Lean model is tested against.
  The pin starts on the 1.2 release line and moves forward with new
  releases as needed.
- `MojoGrimoire.referenceMojo` in `lean/MojoGrimoire/Reference.lean` names
  the release line. A move to a newer release edits it, the conformance
  suite's recorded results and `docs/decisions/semantics.md` in one PR.
- Every test program runs through both the model and the compiler. Every
  disagreement is recorded in `docs/conformance/decision-log.md` and
  classified as a model bug, a compiler bug or a spec decision. A spec
  decision says what the model does and why.
- Where the compiler's behaviour is incidental rather than intended, the
  model may be relational (allow a set of outcomes) rather than copy it, and
  the decision log says so.

The human chose Mojo 1.2.x as the starting reference on 2026-11-15, and that
the project catches up with new releases as needed.

## Why

With no specification, fidelity has to be measured, not assumed. A pinned
reference makes recorded results reproducible; following releases keeps the
model relevant. The log keeps every choice of what counts as specification
visible, so that the proofs are about Mojo and not about compiler accidents.

## Rejected alternatives

- **Treat the documentation as the specification.** It is incomplete and does
  not cover ownership corner cases.
- **Test against the compiler's tip.** Expected results would go stale
  without any change on our side.
