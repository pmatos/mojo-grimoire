# Current decisions: semantics

This page says what holds today for what Mojo means in this project and what
the model takes as its reference.

## The reference

The open-source Mojo compiler at a pinned release is the reference
(ADR-2026-11-15-1907). The pin is the 1.2 release line,
`MojoGrimoire.referenceMojo`, and moves forward with new releases as needed;
each move updates the conformance suite's recorded results and this page in
the same PR. The human chose this on 2026-11-15. Every disagreement between
the model and the compiler goes in
[the decision log](../conformance/decision-log.md).

Rejected: testing against the compiler's tip, where expected results would go
stale with no change on our side.

## Independence

The model is independent of the Isabelle formalisation `utting/mojo-semantics`
(ADR-2026-11-15-1908). It is a reference point while bootstrapping: nothing
here imports, vendors or generates code from it, and its test suite is not
copied. The human ruled this on 2026-11-15.

Rejected: porting the Isabelle model and its suite, which would tie the
project to another codebase and to a suite with no licence.

## Scope of v1

v1 covers ownership and value semantics, structs, methods, lists, control
flow, integer and SIMD arithmetic, the static checker and the run-time
semantics, and a soundness theorem: accepted programs never fail with an
ownership or type error. Compile-time parameters and `comptime` evaluation,
Python interop, async, GPU kernels and codegen correctness are out of v1.
