# Current decisions: lean-model

This page says what holds today for how the Lean model is built, checked and
organised.

## The package

`lean/` is one Lake package with no dependencies, pinned to Lean 4.36.0 in
`lean/lean-toolchain` (ADR-2026-11-15-1905). It has four libraries and an
executable:

- `MojoGrimoire`, the model;
- `MojoGrimoireTest`, its tests, whose root imports every module of `lean/`;
- `MojoGrimoireCheck`, which runs the axiom check;
- the executable `mojo-grimoire`, whose root is the one module
  `MojoGrimoireCli` (#23). It holds only the top-level `main`, which calls
  `MojoGrimoire.Driver.main`. It is outside `MojoGrimoire` because the spec
  document imports that library and is an executable with its own `main`.
  The axiom check names `MojoGrimoireCli` as a root, so it is checked like
  the rest, and every build links the executable;
- `MojoGrimoireCli`, the executable's root module declared as a library too
  (#100). `MojoGrimoireTest` imports it for the axiom check, and Lake builds
  an import first only when a library declares its module. Without this
  target, building `MojoGrimoireTest` alone failed with "unknown module
  prefix 'MojoGrimoireCli'". The human approved this target on 2026-11-18.

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

One exception, ruled by the human on 2026-11-27 (#343): Lean 4.36 generates,
for each inductive type `T` with two or more constructors, `T.ctorIdx`
implemented by the `unsafe` `T.ctorIdx._impl`, which reads the value's tag
with `getObjTagNat`. The check allows that pair only in its exact generated
shape (`isGeneratedCtorIdx` in `lean/MojoGrimoireTest/Axioms.lean`), and
`MojoGrimoireTest.AxiomsGuard` shows that a hand-written look-alike is
rejected. So "no declaration is unsafe" and "none is implemented by other
code" each have this one exception, and "the compiled code equals the
definitions that the proofs are about" also assumes that Lean's run-time tag
equals the constructor's index; a proof by native evaluation that uses
derived equality rests on it too.

Rejected: staying on Lean 4.35.0 to avoid the exception, which stops every
Lean update; and `genCtorIdx false`, which breaks `noConfusion`.

Rejected: `#print axioms` lines per theorem, where a missing line passes in
silence.
