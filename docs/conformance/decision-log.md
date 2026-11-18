# Decision log

Mojo has no written specification. The open-source Mojo compiler at the pinned
release is the reference, and the Lean model follows it (ADR-2026-11-15-1907).
This log records where the model departs from the compiler, and why.

A disagreement in which the model is wrong is a model bug. It is fixed, not
logged: the PR that fixes it says what changed, and the suite program that
found it keeps it fixed. The human ruled this on 2026-11-16.

Each entry is classified as one of:

- **compiler bug**: the compiler is wrong. The model keeps its behaviour, and
  the entry links an upstream report when there is one.
- **spec decision**: the behaviour is incidental or ambiguous. The entry says
  what the model does and why.

Every compiler bug that the human rules on is also listed in
[compiler-bugs.json](compiler-bugs.json), with a minimal reproducer and the
state of its upstream report, so that it can be confirmed later on a newer
compiler. Upstream reports are filed only with the human's approval.

## Pinned reference

| Component | Version | Commit | Where it is pinned |
| --------- | ------- | ------ | ------------------ |
| Lean      | 4.35.0  | n/a    | `lean/lean-toolchain` |
| Mojo      | 1.2.0, tag `mojo/v1.2.0` of `modular/modular` | `527d069ee11a41ac5320af1f9402db0a66b2b868` | the release line in `MojoGrimoire.referenceMojo`; the commit in `scripts/build-mojo.sh` |

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

### D-0001: pin Mojo 1.2.0 as the reference

- Date: 2026-11-15
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868)
- Program: n/a
- Compiler: n/a
- Model: n/a
- Classification: n/a, a pin is not a disagreement
- Decision and rationale: the reference is the commit of the tag
  `mojo/v1.2.0`, the newest tag of the 1.2 release line on 2026-11-15.
  `scripts/build-mojo.sh` builds the compiler from a checkout at that commit
  and refuses any other. The Phase 0 baseline at this pin is
  [phase0-baseline.md](phase0-baseline.md).

### D-0002: a store into a list element after a call that grows the list

- Date: 2026-11-16
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868)
- Program: `tests/conformance/lists/store_after_grow.mojo`
- Compiler: accepts `xs[0] = bump(xs)`, where `bump` appends to `xs` and
  returns 5, and prints `1 3`. It locates `xs[0]` before it evaluates the
  call, the call grows the list, and the store lands in a stale element, in
  the buffer that the append replaced when it reallocated. When the list has capacity reserved
  beforehand, so the append does not reallocate, the same program prints
  `5 3`. When the call shrinks the list instead, as in
  `xs[1] = shrink(xs)` where `shrink` pops twice from `[1, 2, 3]`, the
  compiler stores past the new length with no error. The `ref` form,
  `ref e = xs[0]; e = grow(xs)`, is accepted too, and its store also misses
  the list.
- Model: evaluates the value before it locates the element, so
  `store_after_grow` prints `5 3`, and the shrink case fails at run time
  with `indexOutOfBounds`. The `ref` form is rejected
  (`invalidatedReference`): the call invalidates `e` before the store, and
  running it could leave the interpreter stuck when the call shrinks the
  list, since `e` would name an element that no longer exists.
- Classification: compiler bug, ruled by the human on 2026-11-16 (#57).
- Decision and rationale: the model keeps its behaviour. A store into a
  stale element writes to memory the list no longer owns, and whether the
  store is lost depends on whether the call happened to reallocate the
  list's buffer.
- Upstream report: not filed yet. A draft on #57 awaits the human's
  approval; its link goes here once it is filed.

### D-0004: `@fieldwise_init` inside a cycle of structs through a list

- Date: 2026-11-18
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868)
- Programs: `tests/conformance/structs/cycle_fieldwise_init.mojo`,
  `cycle_fieldwise_init_holder_first.mojo` and
  `cycle_fieldwise_init_both.mojo`
- Compiler: accepts a cycle of structs with a list edge and a plain
  by-value edge, such as `A` holding a `List[B]` and `B` holding an `A`,
  when each initializer is written by hand, in either declaration order
  (`structs/cycle_through_list` and `cycle_through_list_holder_first`).
  With `@fieldwise_init` on `B`, the struct that holds the other by value,
  it rejects the same program, with a message that depends on the order of
  the declarations. With `A` declared first, it fails with "invalid
  implicit move: unexpected keyword argument 'move'": the synthesized
  initializer of `B` calls `A.__init__(move=...)`, which is not synthesized
  yet inside the cycle, and the call resolves against `A`'s own
  `__init__`. With `B` declared first, it fails with "field 'bs' has
  non-'Deinitable' type 'List[B]'". With both structs `@fieldwise_init`
  and `A` first, it fails with "invalid call to '__init__': no candidates
  found". With `@fieldwise_init` on `A` alone it compiles
  (`cycle_fieldwise_init_list_holder`).
- Model: accepts all of them, as it accepts the hand-written forms, and
  each prints `1`. It still rejects a struct on a cycle made only of list
  and array edges, or with no list edge (`recursiveStruct`), as the
  compiler does.
- Classification: compiler bug, ruled by the human on 2026-11-18 (#47).
- Decision and rationale: the decorator is documented to produce the
  initializer that is written by hand, which compiles; the
  order-dependent, unrelated messages come from the synthesis inside the
  cycle, not from the layout, which a list edge keeps finite. The nightly
  1.3.0.dev2026111705, checked on 2026-11-18, accepts the forms with `A`
  declared first, and still rejects `cycle_fieldwise_init_holder_first`
  with the same non-'Deinitable' error.
- Upstream report: not filed yet. A draft on #47 awaits the human's
  approval; its link goes here once it is filed.
