# Mojo Formal Semantics in Lean — Roadmap

This is the human's original roadmap, written on 2026-11-14 and kept here
as written. It is not updated as the project moves. What holds today is on
the decision pages in [`decisions/`](decisions/): in particular,
[`decisions/process.md`](decisions/process.md) records how Phase 1 was
re-scoped to keep the project independent of the Isabelle formalisation, and
which steps of Phase 0 were dropped. Two diagrams of the original, the model
architecture and the timeline, are not reproduced.

## Goal and scope

Build an executable, proof-carrying semantics of Mojo in Lean 4 whose fidelity is established by differential testing against the open-source Mojo compiler. Mojo has no written spec, so the compiler at a pinned commit is the reference, and every place where we choose what counts as spec is recorded in a decision log.

**In scope for v1** (through Phase 5):

- Ownership and value semantics: moves, copies, `__copyinit__`/`__moveinit__`, argument conventions (`read`, `mut`, `owned`, `out`, `deinit`), references and origins, ASAP destruction.
- Structs, methods, lists, control flow, integer and SIMD arithmetic.
- The static checker (accept/reject plus error class) and the run-time semantics (output, run-time errors, destructor timing).
- A soundness theorem in the style of "accepted programs never fail with an ownership or type error".

**Out of scope for v1:** compile-time parameters and `comptime` evaluation (Phase 6), Python interop, async, GPU kernels and memory models, codegen correctness.

## Starting point

We start from an existing Isabelle formalisation of Mojo's ownership core and port it to Lean, rather than starting from scratch. Nothing for Mojo exists in Lean yet.

| Asset | What it gives us | How we use it |
| --- | --- | --- |
| [utting/mojo-semantics](https://github.com/utting/mojo-semantics) (Isabelle/HOL) | Micro-Mojo: syntax, big-step semantics with fuel, ownership/type checker with ASAP drop insertion, soundness proof (`run_safe`). A `.mojo` translator and a 65-program suite with outputs recorded against Mojo 1.2.0. | Template for the Lean model, the theorem to replicate, and a ready-made conformance suite. Its known divergences are our first backlog. |
| [Mojo compiler](https://modular.com/blog/mojo-open-source) (open source since 18 Aug 2026, Apache 2.0 with LLVM exceptions) | The reference. Built from source with Bazel. Compiler lives under `KGEN`. | Oracle at the level of outputs, and of intermediate results such as destructor placement after the ownership pass. |
| [Lean-MLIR](https://github.com/opencompl/lean-mlir) | SSA and region semantics for MLIR-style IRs in Lean, with peephole-verification tooling. | Candidate host for the primitive-op layer (Phase 5). |
| [Mojo grammar reference](https://docs.modular.com/mojo/reference/mojo-grammar), proposals, [forum design threads](https://forum.modular.com/c/mojo/language-design/20) | Concrete syntax and design intent. | Parser for the translator; context for the decision log. |

Two constraints: the Isabelle repo states no license yet, and Modular does not accept outside compiler contributions until the end of 2026 ([Linuxiac](https://linuxiac.com/mojo-programming-language-goes-fully-open-source/)).

## Architecture

The Lean model has three layers, and its fidelity to Mojo is measured, not assumed: every test program runs through both the model and the compiler, and every disagreement lands in the decision log.

The core calculus is the layer we test and prove soundness for. The primitive-op layer is a parameter, so core proofs don't depend on how kgen/pop ops are modelled. The abstract spec sits on top and is linked to the core by a refinement proof.

## Phases and milestones

Phases 0 to 5 take us to a sound, conformance-tested Lean model of Mojo's runtime core in roughly 28 to 34 person-weeks; compile-time semantics follows as a research phase. Durations are focused person-weeks, not calendar time.

### Phase 0: Groundwork (2 weeks)

- Build Mojo from source at a pinned commit (1.2.x); script the build.
- Build utting/mojo-semantics with Isabelle2026 and reproduce its 65-program suite.
- Contact the author: licence, collaboration or fork, shared test suite.
- Lean project skeleton: pinned toolchain, Lake, CI with an axiom audit (`#print axioms`, no `sorry`).

**Gate G0:** both the compiler and the Isabelle model reproduce the recorded results at our pinned commit, and the licence question is settled.

### Phase 1: Port Micro-Mojo to Lean (4–6 weeks)

- Abstract syntax, executable big-step interpreter (fuel, explicit errors), static checker and ASAP elaboration as Lean functions.
- Retarget the translator to emit Lean terms; conformance runner that compares against the recorded `.expected.json`.

**Gate G1:** the Lean model passes the same suite as the Isabelle model, with the same known divergences.

### Phase 2: Soundness in Lean (4–6 weeks, can overlap Phase 3)

- Port `run_safe`: checked programs never fail with an ownership or type error.
- Prove that elaboration inserts only drops, and that elaborated programs are still accepted (the Isabelle work only tests the latter).

**Gate G2:** both theorems proved, axiom audit clean in CI.

### Phase 3: Conformance harness at scale (4 weeks)

- Type-aware random program generator for the subset.
- Harvest the compiler's own tests (especially expected-error tests), stdlib tests and manual examples into the suite.
- Coverage of the compiler's ownership pass while fuzzing.
- Second oracle: compare destructor placement after the ownership pass, not only printed output (add an IR dump locally if none exists).
- Start the decision log: every mismatch is classified as model bug, compiler bug, or spec decision.

**Gate G3:** nightly differential runs, a coverage report for the ownership pass, and the decision log in use.

### Phase 4: Close gaps and widen the subset (6–8 weeks)

- Fix the known divergences: field-by-field ASAP `__deinit__`, short-circuit `and`/`or`, name reuse in disjoint scopes.
- Add traits and conformance, the full set of argument conventions, origins in depth, `Optional`/variant types.

**Gate G4:** the known-divergences list is empty for the original suite, and the subset covers the manual's ownership and value-semantics chapters.

### Phase 5: Primitive layer and abstract spec (8 weeks)

- Parameterise the core over the semantics of the primitive MLIR ops the stdlib calls through `__mlir_op` (kgen/pop); model integer and SIMD ops with Lean `BitVec`.
- Evaluate Lean-MLIR as the host for that layer.
- Write the abstract spec and prove that the concrete model refines it.

**Gate G5:** arithmetic, including overflow, matches the compiler on generated tests, and refinement is proved for the core.

### Phase 6: Compile-time semantics (research, 3+ months)

- Parameters, `comptime` evaluation, trait resolution and overload resolution, with their own model and harness.
- Start with a scoping study: which parts of the compile-time interpreter the stdlib actually depends on.

### Throughout: engagement with Modular

- Share the decision log as questions for the language team; track the enum and pattern-matching proposals.
- Write-up after G2 (workshop paper or blog), then a pitch to contribute conformance tests once compiler contributions open.

## Timeline

At midpoint estimates, v1 (gate G5) lands after about 31 weeks of focused work for one engineer; compile-time semantics follows as open-ended research.

Engagement with Modular runs alongside every phase. Phases 2 and 3 can be interleaved, since proofs and harness work rarely block each other.

## Risks and mitigations

| Risk | Impact | Mitigation |
| --- | --- | --- |
| Compiler behaviour changes under us (post-1.0 churn) | Recorded expectations go stale; false mismatches | Pin a commit; re-record nightly against tip in a separate job and diff the diffs |
| Isabelle repo has no licence, or the author prefers not to collaborate | Can't reuse the translator or suite directly | Ask in Phase 0; fallback is a clean-room Lean model using only the paper-level design, and our own suite |
| Ownership pass internals are undocumented and unstable | Second oracle (IR-level) is costly to maintain | Keep output-level comparison as the primary oracle; IR dumps are a debugging aid, not a gate |
| Model reproduces compiler accidents as spec | Proofs about the wrong thing | Decision log; relational semantics where behaviour is incidental; review log entries with Modular |
| Generator bias: random programs miss the interesting cases | Conformance looks better than it is | Coverage of the ownership pass drives generator work; harvest compiler expected-error tests |
| Primitive ops (kgen/pop) have no public semantics | Phase 5 stalls | Treat primitives as a parameter; start with the few ops `Int`/`SIMD`/`Bool` use; read their lowering in the compiler source |
| Compile-time semantics is far larger than the runtime core | Phase 6 becomes open-ended | Keep it out of v1; scope it with a usage study first |

## Open questions

- [ ] What time budget does this get (research allocation, client work, or side project)? It decides whether the estimates above are 7 months or 18.
- [ ] Collaborate with the Isabelle author, or build independently in Lean?
- [ ] Host the primitive layer in Lean-MLIR, or keep a self-contained model?
- [ ] Which Mojo commit do we pin for G0?
- [ ] When and how do we approach Modular: after G2 with results, or earlier with the decision log?
- [ ] Target venue for a first write-up?

## Sources

- [utting/mojo-semantics (GitHub)](https://github.com/utting/mojo-semantics)
- [Mojo is now open source (Modular)](https://modular.com/blog/mojo-open-source)
- [Mojo goes fully open source (Linuxiac)](https://linuxiac.com/mojo-programming-language-goes-fully-open-source/)
- [Lean-MLIR (opencompl)](https://github.com/opencompl/lean-mlir)
- [Verifying Peephole Rewriting in SSA Compiler IRs (ITP 2024)](https://export.arxiv.org/pdf/2407.03685)
- [First-Class Verification Dialects for MLIR (PLDI 2025)](https://pldi25.sigplan.org/details/pldi-2025-papers/60/First-Class-Verification-Dialects-for-MLIR)
- [Mojo inline MLIR reference](https://mojolang.org/docs/reference/inline-mlir/)
- [Mojo grammar reference](https://docs.modular.com/mojo/reference/mojo-grammar)
- [Modular forum: language design](https://forum.modular.com/c/mojo/language-design/20)
