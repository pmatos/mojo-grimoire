# mojo-grimoire

An executable, proof-carrying semantics of [Mojo](https://www.modular.com/mojo)
in Lean 4. Its fidelity is established by differential testing against the
open-source Mojo compiler: every test program runs through both the Lean model
and the compiler, and every disagreement is recorded in the
[decision log](docs/decision-log.md).

## Status

Phase 0 (groundwork). The Lean library is a placeholder; the build, CI and
axiom audit are in place.

## Scope (v1)

- Ownership and value semantics: moves, copies, `__copyinit__`/`__moveinit__`,
  argument conventions, references and origins, ASAP destruction.
- Structs, methods, lists, control flow, integer and SIMD arithmetic.
- The static checker (accept/reject plus error class) and the run-time
  semantics (output, run-time errors, destructor timing).
- Soundness: accepted programs never fail with an ownership or type error.

Out of scope for v1: compile-time parameters and `comptime` evaluation, Python
interop, async, GPU kernels, codegen correctness.

## Planned layout

| Layer | Module | Role |
|-------|--------|------|
| Core calculus | `MojoGrimoire.Core` | Syntax, checker, ASAP elaboration, interpreter; tested and proved sound. |
| Primitive ops | `MojoGrimoire.Primitive` | Semantics of the kgen/pop MLIR ops the stdlib uses; a parameter of the core. |
| Abstract spec | `MojoGrimoire.Spec` | High-level spec, linked to the core by a refinement proof. |

## Independence

This project is self-contained. The Isabelle/HOL formalisation
[utting/mojo-semantics](https://github.com/utting/mojo-semantics) is used only
as a reference point while bootstrapping: nothing here imports, vendors or
generates code from it, and our conformance suite is written independently.

## Building

Requires [elan](https://github.com/leanprover/elan); the toolchain
(Lean 4.35.0) is pinned in `lean-toolchain`.

```sh
lake build --wfail      # warnings, including any `sorry`, are errors
lake exe axiom-audit    # every declaration may use only propext, Classical.choice, Quot.sound
```

CI runs both on every push and pull request.
