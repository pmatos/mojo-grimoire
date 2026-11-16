# mojo-grimoire

An executable, proof-carrying semantics of [Mojo](https://www.modular.com/mojo)
in Lean 4. Its fidelity is established by differential testing against the
open-source Mojo compiler: every test program runs through both the Lean model
and the compiler. The model follows the compiler, and the
[decision log](docs/conformance/decision-log.md) records where it departs.

## Status

Phase 0, groundwork. The Lean package, its checks and the project's process
are in place; the model itself starts in Phase 1.

## Scope of v1

- Ownership and value semantics: moves, copies, `__copyinit__`/`__moveinit__`,
  argument conventions, references and origins, ASAP destruction.
- Structs, methods, lists, control flow, integer and SIMD arithmetic.
- The static checker (accept or reject, with the error class) and the run-time
  semantics (output, run-time errors, destructor timing).
- Soundness: accepted programs never fail with an ownership or type error.

Out of scope for v1: compile-time parameters and `comptime` evaluation, Python
interop, async, GPU kernels and codegen correctness.

## Layout

| Path | What it holds |
| ---- | ------------- |
| `lean/` | The Lean package: `MojoGrimoire` (the model), `MojoGrimoireTest` (its tests) and `MojoGrimoireCheck` (the axiom check) |
| `docs/decisions/` | What holds today, one page per area |
| `docs/adrs/` | Architecture decision records and their generated index |
| `docs/conformance/` | The decision log of disagreements with the compiler |
| `scripts/` | The build script and the checks that the pre-commit hooks run |

The project is independent of the Isabelle/HOL formalisation
[utting/mojo-semantics](https://github.com/utting/mojo-semantics): nothing here
imports, vendors or generates code from it, and the conformance suite is
written independently.

## Development

Requirements: [elan](https://github.com/leanprover/elan) (the toolchain, Lean
4.35.0, is pinned in `lean/lean-toolchain`) and
[pre-commit](https://pre-commit.com) (`uv tool install pre-commit`).

```sh
./scripts/ensure-hooks.sh                           # install the git hooks
scripts/build-lean.sh                               # build, test and check the axioms
pre-commit run --all-files --hook-stage pre-push    # the fast checks, before a push
```

Every change reaches `main` through a squash-merged pull request with a
Conventional Commit title. [AGENTS.md](AGENTS.md) has the working rules.

## Licence

MIT; see [LICENSE](LICENSE).
