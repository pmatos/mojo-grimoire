# The model is independent of the Isabelle formalisation of Mojo

Status: accepted
Tier: direction; area: semantics

## Decision

- The Isabelle/HOL formalisation `utting/mojo-semantics` is a reference point
  while bootstrapping, and nothing more. Nothing in this repository imports,
  vendors, translates or generates code from it, and no build, test or CI
  step depends on it.
- Its published results may be read and compared against, and differences
  may be noted in the decision log, but its test programs and expected
  outputs are not copied. The conformance suite is written independently.
- It guides the Lean model. Its definitions and the statements of its
  theorems, such as the soundness theorem `run_safe`, may be studied and
  used as targets: we state the Lean theorem in our own terms and prove it
  in Lean. Nothing is translated mechanically, and no Lean proof calls,
  checks against or depends on Isabelle.
- Design ideas taken from it are re-expressed in this project's own terms
  and recorded where they bind, like any other design choice.
- The oracle is the compiler (ADR-2026-11-15-1907), not the Isabelle model.
  Comparing the Lean model with the Isabelle model's results is at most an
  optional cross-check, run outside this repository.

The human ruled on 2026-11-15 that this is an independent project with no
dependency on the Isabelle work, that no outreach to its author is planned,
and that the Isabelle work guides the Lean implementation, its proved
theorems included, without being called into.

## Why

The human wants an independent project. The Isabelle repository also states no
licence, so copying its code or suite is not permitted.

## Rejected alternatives

- **Port the Isabelle model and its suite.** It would tie the project to
  another codebase and to an unlicensed suite.
- **Ignore it entirely.** Its theorems show which properties are provable
  for this subset and how to state them; rediscovering them costs time.
- **Collaborate with its author.** Not planned; the human dropped that step
  from the Phase 0 plan.
