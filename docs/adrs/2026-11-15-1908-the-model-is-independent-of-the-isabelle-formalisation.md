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
- Design ideas taken from it are re-expressed in this project's own terms
  and recorded where they bind, like any other design choice.

The human ruled on 2026-11-15 that this is an independent project with no
dependency on the Isabelle work, and that no outreach to its author is
planned.

## Why

The human wants an independent project. The Isabelle repository also states no
licence, so copying its code or suite is not permitted.

## Rejected alternatives

- **Port the Isabelle model and its suite.** It would tie the project to
  another codebase and to an unlicensed suite.
- **Collaborate with its author.** Not planned; the human dropped that step
  from the Phase 0 plan.
