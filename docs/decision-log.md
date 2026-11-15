# Decision log

Mojo has no written specification. The open-source Mojo compiler at the pinned
commit is the reference, and every place where we decide what counts as
specification is recorded here.

Each mismatch between the Lean model and the compiler is classified as one of:

- **model bug**: the Lean model is wrong; fix the model.
- **compiler bug**: the compiler is wrong; record it, keep the model, report upstream when possible.
- **spec decision**: behaviour is incidental or ambiguous; we choose, and say why.

## Pinned reference

| Component | Version | Notes |
|-----------|---------|-------|
| Lean      | 4.35.0  | `lean-toolchain` |
| Mojo      | 1.2.x (exact commit TBD in Phase 0) | Moves forward with new releases; each bump gets an entry below. |

## Entries

<!--
Template:

### D-0001: <short title>
- Date: YYYY-MM-DD
- Mojo commit: <sha>
- Program(s): <path to test>
- Observed (compiler): ...
- Observed (model): ...
- Classification: model bug | compiler bug | spec decision
- Decision and rationale: ...
-->

None yet.
