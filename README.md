# mojo-grimoire

An executable, proof-carrying semantics of [Mojo](https://www.modular.com/mojo)
in Lean 4. Its fidelity is established by differential testing against the
open-source Mojo compiler: every test program runs through both the Lean model
and the compiler. The model follows the compiler, and the
[decision log](docs/conformance/decision-log.md) records where it departs.

## Status

Phase 1, the core calculus, is complete. A Lean parser reads `.mojo` source,
and the model checks, elaborates and runs it. On the conformance suite in
`tests/conformance/`, the model agrees with the pinned compiler, the nightly
1.3.0.dev2026111905. The exceptions are the programs that `known.json` lists,
each of which follows a compiler bug that the decision log records. Work now
closes the gaps with the compiler that Phase 1 found (#163). Phase 2, the
soundness proofs (#30), comes next.

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

## Related work

[MojoProof](https://robertboy18.github.io/MojoProof/) also uses Lean 4, but it
works on the other side of the compiler. It takes the LLVM IR that
`mojo build` emits for a GPU kernel and proves that kernel correct against a
specification. Its theorems are about one compiled kernel at a time.
mojo-grimoire instead models the Mojo language itself: which programs the
compiler accepts, which error it reports for the others, and what an
accepted program does when it runs. Differential testing against the
compiler, program by program, establishes that the model is faithful. GPU
kernels and code generation are out of scope for v1 here, and they are what
MojoProof is about.

The project is independent of the Isabelle/HOL formalisation
[utting/mojo-semantics](https://github.com/utting/mojo-semantics): nothing here
imports, vendors or generates code from it, and the conformance suite is
written independently.

## Development

Requirements: [elan](https://github.com/leanprover/elan) (the toolchain, Lean
4.36.0, is pinned in `lean/lean-toolchain`) and
[pre-commit](https://pre-commit.com) (`uv tool install pre-commit`).

```sh
./scripts/ensure-hooks.sh                           # install the git hooks
scripts/build-lean.sh                               # build, test and check the axioms
pre-commit run --all-files --hook-stage pre-push    # the fast checks, before a push
```

Every change reaches `main` through a squash-merged pull request with a
Conventional Commit title. [AGENTS.md](AGENTS.md) has the working rules.

### The explorer

To try a program on the compiler and the model side by side, build the
model and the spec, then start the explorer with the compiler's wrapper,
which `scripts/install-mojo.sh DIR` prints:

```sh
scripts/build-lean.sh && scripts/build-spec.sh
scripts/explorer.py --mojo /path/to/wrapper/mojo    # or MOJO=... scripts/explorer.py
```

Open the URL it prints, which carries the session's token. Ctrl/Cmd+Enter
runs the program. A token of the editor links to its section of the spec,
and the suite's programs are under Examples.
[conformance.md](docs/decisions/conformance.md#the-explorer) says what it
compares.

## Licence

MIT; see [LICENSE](LICENSE).
