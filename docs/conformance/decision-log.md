# Decision log

Mojo has no written specification. The open-source Mojo compiler at the pinned
release is the reference, and every disagreement between it and the Lean model
is recorded here (ADR-2026-11-15-1907).

Each entry is classified as one of:

- **model bug**: the Lean model is wrong. The entry stays until the fix merges,
  and the fix cites it.
- **compiler bug**: the compiler is wrong. The model keeps its behaviour, and
  the entry links an upstream report when there is one.
- **spec decision**: the behaviour is incidental or ambiguous. The entry says
  what the model does and why.

## Pinned reference

| Component | Version | Where it is pinned |
| --------- | ------- | ------------------ |
| Lean      | 4.35.0  | `lean/lean-toolchain` |
| Mojo      | 1.2.x   | `MojoGrimoire.referenceMojo`; the exact commit is chosen in Phase 0 |

Each move of the Mojo pin gets an entry below.

## Entry template

```markdown
### D-NNNN: <short title>

- Date: YYYY-MM-DD
- Mojo release and commit: <version> (<sha>)
- Program: <path to the test program>
- Compiler: <what the compiler does>
- Model: <what the model does>
- Classification: model bug | compiler bug | spec decision
- Decision and rationale: <what the model does from now on, and why>
```

## Entries

None yet.
