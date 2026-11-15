# Current decisions: lean-model

This page says what holds today for how the Lean model is built, checked and
organised.

## The package

`lean/` is one Lake package with no dependencies, pinned to Lean 4.35.0 in
`lean/lean-toolchain` (ADR-2026-11-15-1905). It has three libraries:

- `MojoGrimoire`, the model;
- `MojoGrimoireTest`, its tests, whose root imports every module of `lean/`;
- `MojoGrimoireCheck`, which runs the axiom check.

`scripts/build-lean.sh` is the one way to build it. It applies the build's
guards and runs `lake build --wfail`. The roadmap's layers, the core calculus,
the primitive-op layer and the abstract spec, will be namespaces of
`MojoGrimoire` as the phases add them.

Rejected: depending on Mathlib now. Nothing needs it yet, and it can come later
at the same pin with the human's ruling.

## What the Lean code may not do

The build fails on any warning, on a declaration that depends on an axiom other
than Lean's three standard ones or a native-evaluation axiom that holds, on
`unsafe` or `partial` code, and on `implemented_by` or `extern`
(ADR-2026-11-15-1906). It also fails when a `.lean` file of `lean/` is not
imported by `MojoGrimoireTest`'s root. So a new module is imported there in
the same PR.

Rejected: `#print axioms` lines per theorem, where a missing line passes in
silence.
