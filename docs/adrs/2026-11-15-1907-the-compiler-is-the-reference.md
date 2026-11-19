# The open-source Mojo compiler at a pinned release is the reference, and the model departs from it only by a logged decision

Status: accepted
Tier: direction; area: semantics

## Decision

- Mojo has no written specification. The open-source Mojo compiler at a
  pinned release is the reference that the Lean model is tested against.
  The pin starts on the 1.2 release line and moves forward with new
  releases as needed.
- `MojoGrimoire.referenceMojo` in `lean/MojoGrimoire/Reference.lean` names
  the release line, and `scripts/build-mojo.sh` names the exact commit. A
  move to a newer release edits both, the conformance suite's recorded
  results, the decision log and `docs/decisions/semantics.md` in one PR.
- Every test program runs through both the model and the compiler, and the
  model follows the compiler. A disagreement in which the model is wrong is
  a model bug: it is fixed, and the fixing PR says what changed.
- The model departs from the compiler only where the compiler has a bug.
  There, the model does exactly what the fixed compiler would do, backed by
  evidence: the Mojo docs, the compiler's own rule for a related case, or a
  nightly that fixes it. There is no third kind of departure. Each departure
  is recorded in `docs/conformance/decision-log.md`.
- A ruling on a compiler bug is provisional until the human has discussed it
  with Modular's engineers. If that discussion changes the semantics, the
  model follows.

The human chose Mojo 1.2.x as the starting reference on 2026-11-15, and that
the project catches up with new releases as needed. On 2026-11-16 the human
ruled that the model matches the compiler in the large, while it can still
find bugs in the compiler when something is broken. On 2026-11-19 the human
ruled out the third kind of departure, the spec decision: "Either the model
matches the compiler or the compiler has a bug and needs to be fixed to match
the model. That's the rule. We cannot have a third option here."


## Why

With no specification, fidelity has to be measured, not assumed. A pinned
reference makes recorded results reproducible; following releases keeps the
model relevant. The log keeps every choice of what counts as specification
visible, so that the proofs are about Mojo and not about compiler accidents.
Logging only departures keeps the log short enough to read and to share with
Modular.

## Rejected alternatives

- **Treat the documentation as the specification.** It is incomplete and does
  not cover ownership corner cases.
- **Spec decisions**, where the model departs because the compiler's
  behaviour seems incidental, and the model may then allow a set of
  outcomes. Such a departure invents a behaviour that no compiler has, and
  it cannot be taken to Modular as a fix. Removed on 2026-11-19, before any
  entry used it.
- **Log every disagreement, model bugs included.** Their entries repeated
  what the fixing PR and the suite record, and hid the departures.
- **Test against the compiler's tip.** Expected results would go stale
  without any change on our side.
