# Current decisions: semantics

This page says what holds today for what Mojo means in this project and what
the model takes as its reference.

## The reference

The open-source Mojo compiler at a pinned release is the reference
(ADR-2026-11-15-1907). The pin is the 1.2 release line,
`MojoGrimoire.referenceMojo`, and within it the commit of the tag
`mojo/v1.2.0` of `modular/modular`. `scripts/build-mojo.sh` builds the
compiler from a checkout at that commit and refuses any other. The pin moves
forward with new releases as needed; each move updates the conformance
suite's recorded results, the script, the decision log and this page in the
same PR. The human chose this on 2026-11-15. Every disagreement between the
model and the compiler goes in
[the decision log](../conformance/decision-log.md).

Rejected: testing against the compiler's tip, where expected results would go
stale with no change on our side.

## Independence

The model is independent of the Isabelle formalisation `utting/mojo-semantics`
(ADR-2026-11-15-1908). It guides the Lean model: its definitions and the
statements of its theorems, such as its soundness theorem, may be used as
targets, which we state in our own terms and prove in Lean. Nothing here
calls, imports, vendors or mechanically translates it, and its test suite is
not copied. The compiler, not the Isabelle model, is the oracle. The human
ruled this on 2026-11-15.

Rejected: porting the Isabelle model and its suite, which would tie the
project to another codebase and to a suite with no licence.

## Scope of v1

v1 covers ownership and value semantics, structs, methods, lists, control
flow, integer and SIMD arithmetic, the static checker and the run-time
semantics, and a soundness theorem: accepted programs never fail with an
ownership or type error. Compile-time parameters and `comptime` evaluation,
Python interop, async, GPU kernels and codegen correctness are out of v1.

## The static checker

The checker, `MojoGrimoire.Check`, accepts a program of the core calculus
or rejects it with a class of error, `CheckError`. The conformance suite
compares these classes with the compiler's diagnostics, not their wording.
Each choice below was made from Mojo's manual at the pin. Each is to be
confirmed against the compiler when the suite records results (step 5 of
Phase 1), and any disagreement goes in the decision log.

- Initialization is tracked per part of a variable: a field may be moved
  out and initialized again. A variable may end with fields moved out, and
  the rest is destroyed field by field. The exception is a part that has a
  `__deinit__` of its own, which needs the whole value. Inside
  `__deinit__`, `self`'s fields may be moved out.
- `return x` moves a variable the function owns. Any other returned place
  is copied implicitly, so it must be implicitly copyable.
- Argument exclusivity rejects a `mut` argument that overlaps another
  argument passed as a location. As the manual says, it does not apply to
  `Int` and `Bool`.
- After an `if`, a part counts as initialized only when both branches leave
  it initialized. A loop body must leave initialized every part that was
  initialized before the loop.
- A declaration may not reuse the name of a variable in scope, a
  parameter included, so no variable hides another. Sibling blocks may
  reuse a name. ASAP elaboration relies on this, since it tracks
  variables by name.

## ASAP elaboration

Elaboration, `MojoGrimoire.Elab`, makes Mojo's destruction points explicit:
it inserts a `drop` wherever the compiler destroys a value, and is proved
to insert nothing else (`stripProgram_elabProgram`). The interpreter
destroys what a `drop` names, and what is still alive when a function
returns. As with the checker, each choice below is to be confirmed against
the compiler when the suite records results.

- A value dies right after the statement that last uses it, or right after
  its definition when nothing uses it. A value moved away with `^` is not
  destroyed there.
- A branch of an `if` that does not use a value the other branch uses
  destroys it first. A value a loop uses dies after the loop.
- A `var` parameter that the body never uses dies before the body runs.
- Inside `__deinit__`, each field of `self` dies on its own, after its own
  last use, and a field never used dies before the body runs. The human
  ruled on 2026-11-15 that the model gets this right from the start.
- Only values of struct type are dropped. Values destroyed at the same
  point die in the order of declaration, parameters first.
- A `return` gets no drops: the interpreter destroys what remains after
  evaluating the returned value.
