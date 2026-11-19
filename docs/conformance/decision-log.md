# Decision log

Mojo has no written specification. The open-source Mojo compiler at the pinned
release is the reference, and the Lean model follows it (ADR-2026-11-15-1907).
This log records where the model departs from the compiler, and why.

A disagreement in which the model is wrong is a model bug. It is fixed, not
logged: the PR that fixes it says what changed, and the suite program that
found it keeps it fixed. The human ruled this on 2026-11-16.

Every entry is a **compiler bug**: the compiler is wrong, and the model does
exactly what the fixed compiler would do. The entry says what that behaviour
is, gives the evidence for it, and links an upstream report when there is
one. There is no other kind of entry. The human ruled out spec decisions on
2026-11-19 (ADR-2026-11-15-1907). A ruling is provisional until the human has
discussed it with Modular.

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
- Classification: compiler bug, ruled by the human on YYYY-MM-DD (#N)
- Decision and rationale: <what the fixed compiler does, which the model does from now on, and the evidence for it>
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

### D-0003: a struct built field by field destroys a field never assigned

- Date: 2026-11-18
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868)
- Programs:
  - `tests/conformance/structs/field_by_field_unset_destroyed.mojo`
  - `tests/conformance/structs/field_by_field_unset_nested.mojo`
  - `tests/conformance/structs/field_by_field_unset_overwritten.mojo`
  - `tests/conformance/structs/field_by_field_unset_destructor.mojo`
  - `tests/conformance/structs/field_by_field_unset_branch.mojo`
- Compiler: a variable of struct type declared without a value, whose
  fields are then assigned one by one, is destroyed whole even when some
  fields were never assigned. The compiler runs the destructor of each
  field that was never assigned, on whatever memory it holds. Each shape
  seen so far prints `drop 0` for such a field. With `Duo` holding two
  `Token`s that print `drop <n>` when destroyed:
  - at the end of the variable: `var d: Duo; d.left = Token(1);
    print(d.left.n)` prints `1`, `drop 1`, `drop 0`;
  - for a field assigned below a nested struct: `var r: Rack; r.z = 3`,
    where `Rack` holds a `Slot` that holds a `Token`, prints `drop 0` at
    the end, and so does `q.s.k = 4`;
  - when the part is assigned whole: `r.s.k = 1; r.s = Slot(Token(5), 2)`
    prints `drop 0` before the new value is stored, and
    `d.left = Token(6); d = Duo(Token(7), Token(8))` prints `drop 6`,
    `drop 0`;
  - when the struct has a `__deinit__` of its own: `var b: Box;
    b.a = Token(1)`, where `Box` holds two `Token`s and prints `box` in
    its `__deinit__`, prints `1`, `drop 1`, `drop 0`, `box`: it runs
    `Box`'s destructor on a value whose field `b` was never assigned;
  - when such a struct is built in only one branch of an `if`, or in a
    loop: `var b: Bin; if c: b.a = Mark(1)`, where `Bin` and `Mark` print
    a fixed line when destroyed, prints three `Mark` lines and the `Bin`
    one. When the destructors print a field, the lines show whatever
    memory the fields hold, which changes from run to run.
  The compiler is not consistent: once a field assigned this way is moved
  out, as in `d.left = Token(1); var t = d.left^`, it destroys nothing of
  `d`, and prints no `drop 0`.
- Model: destroys only the fields that hold a value. A variable declared
  without a value holds the blank of its type, the struct with no field
  assigned, and destroying a blank does nothing. The first three programs
  print the compiler's lines without the `drop 0`. `Box` and `Bin`, whose
  own destructors need the whole value, are rejected as
  `partiallyDestroyed`, as the straight-line `Box` was before: running its
  `__deinit__` would read a field never assigned, and skipping it would
  destroy a value without its destructor.
- Classification: compiler bug, ruled by the human on 2026-11-17 (#51).
  The human revisits the ruling if upstream shows that it is not a bug.
- Decision and rationale: the model destroys only what was assigned. A
  destructor run on memory that was never initialized reads garbage. The
  first shape, at the end of the variable, was checked again on the
  nightly 1.3.0.dev2026111705 on 2026-11-18, where it still prints
  `drop 0`.
- Upstream report: not filed yet. A draft on #51 awaits the human's
  approval; its link goes here once it is filed.

### D-0004: `@fieldwise_init` inside a cycle of structs through a list

- Date: 2026-11-18
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868)
- Program: `tests/conformance/structs/cycle_fieldwise_init.mojo`,
  `tests/conformance/structs/cycle_fieldwise_init_holder_first.mojo` and
  `tests/conformance/structs/cycle_fieldwise_init_both.mojo`
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
  each prints `1`. It still rejects a struct on a cycle with no list edge
  (`recursiveStruct`), as the compiler does.
- Classification: compiler bug, ruled by the human on 2026-11-18 (#47).
- Decision and rationale: the decorator is documented to produce the
  initializer that is written by hand, which compiles; the
  order-dependent, unrelated messages come from the synthesis inside the
  cycle, not from the layout, which a list edge keeps finite. The nightly
  1.3.0.dev2026111705, checked on 2026-11-18, accepts the forms with `A`
  declared first, and still rejects `cycle_fieldwise_init_holder_first`
  with the same non-'Deinitable' error. That error is the one of D-0006,
  modular/modular#7398, which probably has the same cause.
- Upstream report: not filed yet. A draft on #47 awaits the human's
  approval; its link goes here once it is filed.

### D-0005: a list literal of any length but 1 that initializes an `Int`

- Date: 2026-11-19
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868)
- Programs:
  - `tests/conformance/basics/int_literal_length_two.mojo`
  - `tests/conformance/basics/int_literal_length_three.mojo`
  - `tests/conformance/basics/int_literal_length_evaluated.mojo`
- Compiler: `Int` is `SIMD[DType.int, 1]`, and a literal where an `Int`
  is expected calls SIMD's `__list_literal__` initializer
  (`std/simd.mojo:941`). The stdlib documents that the number of elements
  must equal the vector's size, 1, but 1.2.0 checks it only with an
  `assert`, which a default build leaves out. So a default build accepts
  `var x: Int = [e1, …, en]` for every n. For n ≥ 2 it evaluates every
  element and keeps `e1`: `[1, 2]` and `[1, 2, 3]` print `1`, and
  `[f(1), f(2)]`, where `f` prints its argument, prints `f 1`, `f 2`,
  `1`. For n = 0, `var x: Int = []` builds a program that crashes with a
  segmentation fault (exit 139), so the suite leaves it out. Every
  position probed on 2026-11-19 behaves the same: an assignment, a
  `return`, a function argument, a field of `@fieldwise_init`, `append`
  on a `List[Int]`, an operand `x + [2, 3]`, and an element of a literal
  of `Int`s, where `var xs: List[Int] = [[1, 2], [3]]` prints `[1, 3]`.
  With `-D ASSERT=all` the program builds, then traps at run time:
  "mismatch in the number of elements in the SIMD variadic constructor".
- Model: rejects a literal of `Int`s of every length but 1, n = 0
  included. Where the literal initializes the `Int`, in a declaration, an
  assignment, a `return`, a construction or an enclosing literal, it is
  `noMatchingInit`. Passed to a function or a method, `append` among them,
  or as an operand, it is a `typeMismatch`, as for `[True]` there. `[]`
  is `noMatchingInit` only in a declaration, an assignment and a
  `return`; everywhere else, a construction and an enclosing literal
  included, it has no element type, and is `invalidType`. Whether the
  class should be `noMatchingInit` in every position waits on #154. A
  literal whose elements differ in type, `P([1, True])`, is a
  `typeMismatch` where the compiler reports an initialization, which #153
  tracks.
- Classification: compiler bug, ruled by the human on 2026-11-19 (#122).
  The ruling is provisional, until the human has discussed it with
  Modular.
- Decision and rationale: the model keeps rejecting these literals. The
  stdlib documents the constraint, and leaving it unchecked keeps
  elements the program wrote, or reads an `Int` that was never written.
  The nightly 1.3.0.dev2026111705, checked on 2026-11-18 and 2026-11-19,
  fixes it: it rejects every length but 1, in every position above, with
  "function instantiation failed" and the note "constraint failed:
  expected 1 elements in the SIMD list literal, found N"
  (`std/simd.mojo:1056`).
- Upstream report: none needed, since the nightly fixes it.

### D-0006: a struct cycle through a list, rejected as non-'Deinitable'

- Date: 2026-11-19
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868)
- Programs, under `tests/conformance/rejected/`:
  `recursive_list_field`, `recursive_list_cycle`,
  `recursive_list_array_cycle`, `recursive_list_cycle_beside_mixed`,
  `recursive_cycle_and_list_of_self`, `list_cycle_beside_self_loop_deinit`,
  `list_of_self_deinit_off_cycle`, `list_of_arrays_cycle_deinit` and
  `array_of_lists_cycle_deinit`.
- Compiler: rejects a struct on a cycle of fields whose edges are lists
  and arrays only, such as `struct Node: var children: List[Node]`, with
  "field 'children' has non-'Deinitable' type 'List[Node]'". It accepts
  the same cycle when some structs on it have a `__deinit__` of their own,
  but not always: it still rejects it when a struct on the cycle with no
  `__deinit__` holds a list of itself, or is held through two containers,
  `List[Array[B, 1]]` or `Array[List[B], 1]`, by one that has one. The
  `__deinit__` forms that it accepts are in `tests/conformance/structs/`,
  from `list_of_self_deinit` to `array_of_lists_cycle_both_deinit`. A
  cycle with a by-value edge and a list edge is accepted (D-0004 aside),
  and a cycle with no list edge, of by-value or array fields, is rejected,
  with or without `__deinit__`. The nightly 1.3.0.dev2026111705, checked on
  2026-11-19, gives the same results.
- Model: accepts every struct cycle with a list edge, with or without
  `__deinit__`, and rejects every cycle with no list edge
  (`recursiveStruct`). Each of the nine programs runs. Given an empty
  `__deinit__` on each struct, the workaround of modular/modular#7398,
  1.2.0 compiles each of them and prints what the model prints.
- Classification: compiler bug, ruled by the human on 2026-11-19 (#136).
  The ruling is provisional until the human has discussed it with Modular.
- Decision and rationale: the fixed compiler accepts every struct cycle
  with at least one list edge. The manual bases the ban on recursive
  structs on layout, and a list field has a fixed size. Modular tracks the
  rejection as modular/modular#7398, triaged by the Mojo compiler team:
  the synthesized `__deinit__` rejects a struct that holds itself through
  a conditionally `Deinitable` type, and a user-written `__deinit__` works
  around it. modular/modular#7290 reports a struct that cannot hold a
  `List` of itself. The D-0004 form with `B` declared first fails with the
  same message, probably from the same cause.
- Upstream report: modular/modular#7398 and modular/modular#7290, filed by
  others; no new report is needed.
