# The Lean build fails on sorry, untrusted axioms, unsafe code and any warning

Status: accepted
Tier: direction; area: lean-model

## Decision

- `MojoGrimoireCheck` runs
  `#check_axioms MojoGrimoire MojoGrimoireTest MojoGrimoireCli` as
  its last command (`lean/MojoGrimoireTest/Axioms.lean`). It fails, naming
  each declaration, on one that:
  - depends on an axiom other than `propext`, `Classical.choice`,
    `Quot.sound` or an axiom of native evaluation that holds when the check
    runs it again;
  - is `unsafe` or `partial`;
  - has an `implemented_by` or an `extern` attribute.

  One exception (the human, 2026-11-27, #343): Lean 4.36 gives every
  inductive type but a one-constructor one a `T.ctorIdx` implemented by the
  `unsafe` `T.ctorIdx._impl`. The check accepts this pair only for two or
  more constructors and in exactly the generated shape
  (`isGeneratedCtorIdx`), whoever wrote it; `MojoGrimoireTest.AxiomsGuard`
  shows that any other pair is rejected.

  It also fails when a `.lean` file of `lean/` is not imported or lies
  outside the checked roots, when a root has no declaration, and when any
  text follows it.
- `scripts/build-lean.sh` builds with `lake build --wfail`, so any warning
  fails the build, a `sorry` inside an `example` included.
- Code that must be `partial`, `unsafe` or `extern` stays out of `lean/`
  until this ADR is edited to allow it.

The check is funk's, ported as it stands there.

## Why

The model's interpreter runs the definitions that the soundness proofs are
about, so compiled code must not differ from them, and no proof may rest on a
claim nobody checked. An `example` is not a declaration, so the check never
sees one; only `--wfail` catches a `sorry` in it.

Lean needs the pair for `noConfusion`. It narrows three guarantees: "no
declaration is unsafe" and "none is implemented by other code" each get this
exception, and "the compiled code equals the definitions that the proofs are
about", native proofs included, also assumes that Lean's run-time tag equals
the constructor's index.

## Rejected alternatives

- **A text search for `sorry` and `partial`.** It cannot see axioms used
  through other declarations, nor code that a macro writes.
- **`#print axioms` for each theorem.** A missing line passes in silence.
- **A separate executable that loads the built modules.** It is a second
  Lake entry point to guard.
- **Staying on Lean 4.35.0.** It stops every Lean update;
  `genCtorIdx false` breaks `noConfusion`.
