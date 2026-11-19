# Decision log

Mojo has no written specification. The open-source Mojo compiler at the pinned
version is the reference, and the Lean model follows it (ADR-2026-11-15-1907).
This log records where the model departs from the compiler, and why.

A disagreement in which the model is wrong is a model bug. It is fixed, not
logged: the PR that fixes it says what changed, and the suite program that
found it keeps it fixed. The human ruled this on 2026-11-16.

Every departure is a **compiler bug**: the compiler is wrong, and the model
does exactly what the fixed compiler would do. Its entry says what that
behaviour is, gives the evidence for it, and links an upstream report when
there is one. There is no other kind of departure; the only other entries
record the moves of the Mojo pin. The human ruled out spec decisions on
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
| Mojo      | nightly 1.3.0.dev2026111905, which reports `Mojo 1.3.0.dev2026111905 (a549e6a6)` | none public; source read at `10c54f6f5bf5725e3da0d189a67735594696a262` of `modular/modular` | the version in `MojoGrimoire.referenceMojo`; the wheels and their sha256 in `scripts/install-mojo.sh` |

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
  `scripts/build-mojo.sh`, removed by D-0007, built the compiler from a
  checkout at that commit and refused any other. The Phase 0 baseline at this pin is
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

### D-0003: a variable that ends partly built is rejected (R, provisional)

- Date: 2026-11-18, revised 2026-11-19
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868)
- Programs, all in `tests/conformance/structs/`:
  - `field_by_field_unset_destroyed.mojo`, `field_by_field_unset_nested.mojo`,
    `field_by_field_unset_overwritten.mojo`,
    `field_by_field_unset_destructor.mojo`, `field_by_field_unset_branch.mojo`;
  - `field_by_field_unset_whole_branch.mojo`,
    `field_by_field_unset_whole_loop.mojo`, `field_by_field_unset_ints.mojo`;
  - `field_by_field_move_after_last_use.mojo` and its `_loop` variant (#144);
  - `field_by_field_branch_move_other.mojo` and its `_both` variant (#137);
  - `field_by_field_whole_branch_then_fields.mojo`;
  - `rejected/field_by_field_move_all_one_path.mojo`, the moved-out mirror
    of a struct built wholly on one path, on which the model agrees.
- Compiler: a variable of struct type declared without a value, whose
  fields are then assigned one by one, is destroyed whole even when some
  fields were never assigned. The compiler runs the destructor of each
  such field on whatever memory it holds. With `Duo` holding two `Token`s
  that print `drop <n>` when destroyed:
  - at the end of the variable: `var d: Duo; d.left = Token(1);
    print(d.left.n)` prints `1`, `drop 1`, `drop 0`;
  - for a field below a nested struct: `var r: Rack; r.z = 3`, where
    `Rack` holds a `Slot` that holds a `Token`, prints `drop 0`;
  - when a part is assigned whole: `r.s.k = 1; r.s = Slot(Token(5), 2)`
    prints `drop 0` before the new value is stored;
  - when the struct has a `__deinit__` of its own: `var b: Box;
    b.a = Token(1)`, where `Box` prints `box` in its `__deinit__`, prints
    `1`, `drop 1`, `drop 0`, `box`;
  - when the struct is built in one branch of an `if` only, partly or
    wholly, or in a loop: `whole_branch` prints `mark gone` four times for
    two fields assigned, and `whole_loop` ten times for four;
  - when the struct is assigned whole in one branch only and then given
    every field: `whole_branch_then_fields` prints `mark gone` six times
    for four fields assigned, on 1.2.0 and on the nightly.
  The compiler also accepts a field moved out after another field's last
  use (#144), and a field moved out in one branch while the other builds
  another field (#137). With fields that print `drop <id>`, each of these
  programs prints `drop <garbage>` first: it destroys a field never
  assigned.
  The compiler rejects the same shapes when a field was moved out rather
  than never assigned: "field 'd.a' destroyed out of the middle of a
  value, preventing the overall value from being destroyed", with or
  without a `__deinit__`, and when the field is moved out on one path only,
  as in `t.b = Res(2); t.a = Res(1); if c: var y = t.b^; var x = t.a^`.
- Model: rejects as `partiallyDestroyed` a variable, or a part assigned
  whole, that may end with a field never assigned or moved out while it
  may hold another, on some path. A variable assigned whole in only one
  branch may end, and so may the `self` of `__init__` built wholly in only
  one branch, which is whole once its fields are: the compiler accepts
  it with clean output. Every program above is rejected, except
  `whole_branch_then_fields`, where nothing ends partly built, and
  `move_all_one_path`, which agrees.
- Classification: compiler bug, ruled by the human on 2026-11-17 (#51).
  The fixed behaviour is R, ruled by the human on 2026-11-19 (#51): a
  variable that ends with only some of its fields set is rejected, however
  it got there, as the compiler already does for a field moved out. **R is
  provisional** until the human has discussed it with Modular's engineers;
  if that changes the semantics, the model changes to match.
- Decision and rationale: the model does what the fixed compiler would do,
  and the fixed compiler applies its rule for a field moved out to a field
  never assigned, at a join of paths too. R replaces the 2026-11-17
  behaviour, which destroyed only the fields assigned and so matched
  neither the compiler nor R. The evidence, on 1.2.0 and on a nightly
  (1.3.0.dev2026111705 or 1.3.0.dev2026111905, which agree), for three
  cases that R's sentence does not spell out:
  - structs of `Int`s: the compiler's rule for a field moved out does not
    depend on a destructor. `var s = Seg(Pair(1, 2), Pair(3, 4));
    print(s.lo.x); var h = s.hi^` is rejected with "field 's.hi'
    destroyed out of the middle of a value", and so are
    `rejected/move_field_destroyed` and `rejected/move_every_field`, whose
    `Line` holds two `Point`s of `Int`s. So the model rejects `unset_ints`
    (`var p: Pair; p.x = 1`) too, though its output shows no bug. An `Int`
    field itself cannot be moved out, as `p.x^` copies it;
  - a struct whole on one path and empty on another: the compiler judges
    a field moved out at the join of paths.
    `rejected/field_by_field_move_all_one_path` moves out every field of a
    struct built field by field, in one branch only, and is rejected,
    while `structs/field_by_field_move_every`, the same moves with no
    branch, is accepted. So `unset_whole_branch` and `unset_whole_loop`
    are rejected;
  - a value held on only some paths: `var r: Res; if c: r = Res(1)` then
    `r = Res(2)` prints `drop 1`, `2`, `drop 2`, destroying the first value
    on the path that has one only. So the model, which destroys a part
    only on the paths that hold it, accepts `whole_branch_then_fields` and
    prints four `mark gone` lines, where the compiler also destroys the
    two fields never assigned.

  The first shape still prints `drop 0` on the nightly
  1.3.0.dev2026111705 (2026-11-18), and the `Box` variant prints
  `box gone 1 15`, `drop 1`, `drop 0`.
- Upstream report: not filed yet. A draft on #51 awaits the human's
  approval; its link goes here once it is filed.

### D-0004: `@fieldwise_init` inside a cycle of structs through a list

- Date: 2026-11-18, reduced 2026-11-19 at the move to the nightly (D-0007)
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868);
  nightly 1.3.0.dev2026111905 since D-0007
- Program: `tests/conformance/structs/cycle_fieldwise_init_holder_first.mojo`
- Compiler: accepts a cycle of structs with a list edge and a plain
  by-value edge, such as `A` holding a `List[B]` and `B` holding an `A`,
  when each initializer is written by hand, in either declaration order
  (`structs/cycle_through_list` and `cycle_through_list_holder_first`).
  With `@fieldwise_init` on `B`, the struct that holds the other by value,
  and `B` declared first, it rejects the program with "field 'bs' has
  non-'Deinitable' type 'List[B]'". With `@fieldwise_init` on `A` alone it
  compiles (`cycle_fieldwise_init_list_holder`).
- Model: accepts it, as it accepts the hand-written form, and prints `1`.
  It still rejects a struct on a cycle with no list edge
  (`recursiveStruct`), as the compiler does.
- Classification: compiler bug, ruled by the human on 2026-11-18 (#47).
- Decision and rationale: the decorator is documented to produce the
  initializer that is written by hand, which compiles. The error is the
  one of D-0006, modular/modular#7398, which probably has the same cause.
- Fixed by the nightly: Mojo 1.2.0 also rejected the decorated forms with
  `A` declared first, `cycle_fieldwise_init` with "invalid implicit move:
  unexpected keyword argument 'move'", and `cycle_fieldwise_init_both`,
  with both structs decorated, with "invalid call to '__init__': no
  candidates found". The nightly 1.3.0.dev2026111905 compiles both, and
  each prints `1`, as the model does; `known.json` no longer lists them.
- Upstream report: not filed yet. A draft on #47 awaits the human's
  approval; its link goes here once it is filed.

### D-0005: a list literal of any length but 1 that initializes an `Int`

- Date: 2026-11-19; resolved the same day at the move to the nightly (D-0007)
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868)
- Programs, in `tests/conformance/basics/`: `int_literal_length_two`,
  `int_literal_length_three` and `int_literal_length_evaluated`.
- Compiler: `Int` is `SIMD[DType.int, 1]`, and a literal where an `Int`
  is expected calls SIMD's `__list_literal__` initializer. The stdlib
  documents that the number of elements must equal the vector's size, 1,
  but 1.2.0 checked it only with an `assert`, which a default build leaves
  out. So it accepted `var x: Int = [e1, …, en]` for every n, in every
  position: for n ≥ 2 it evaluated every element and kept `e1`, so
  `[1, 2]` printed `1`; for n = 0 the program crashed with a segmentation
  fault.
- Model: rejects a literal of `Int`s of every length but 1, n = 0
  included: `noMatchingInit` where the literal initializes the `Int`, in a
  declaration, an assignment, a `return`, a construction or an enclosing
  literal; a `typeMismatch` passed to a function or a method, or as an
  operand; and `[]` outside a declaration, an assignment and a `return`
  is `invalidType`. Whether the class should be `noMatchingInit` in every
  position waits on #154, and a literal whose elements differ in type on
  #153.
- Classification: compiler bug, ruled by the human on 2026-11-19 (#122).
  The ruling is provisional, until the human has discussed it with
  Modular.
- Decision and rationale: the model rejects these literals, as the stdlib
  documents.
- Resolved at the nightly: 1.3.0.dev2026111905 rejects every length but 1,
  in every position above, with "function instantiation failed" and the
  note "constraint failed: expected 1 elements in the SIMD list literal,
  found N" (`std/simd.mojo:1094` at `10c54f6f5b`), which
  `diagnostics.json` classes as `noMatchingInit`. The three programs agree
  with the model, and `known.json` no longer lists them. Passed to a
  function or a method, or as an operand, the nightly's error is
  `noMatchingInit` too, where the model reports `typeMismatch`, or
  `invalidType` for `[]`; no suite program holds such a position, and #154
  holds the question.
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

### D-0007: pin the nightly 1.3.0.dev2026111905 as the reference

- Date: 2026-11-19
- Mojo release and commit: 1.3.0.dev2026111905, which reports
  `Mojo 1.3.0.dev2026111905 (a549e6a6)`; its own commit is not public, and
  its source is read at `10c54f6f5bf5725e3da0d189a67735594696a262` of
  `modular/modular`, "[Release] Pin lockfiles to Mojo 1.3.0.dev2026111905"
- Program: n/a
- Compiler: n/a
- Model: n/a
- Classification: n/a, a pin is not a disagreement
- Decision and rationale: the human ruled on 2026-11-19 that the reference
  is the latest nightly, pinned as the wheel `mojo==1.3.0.dev2026111905`
  from Modular's nightly index and checked by sha256 (#160).
  `scripts/install-mojo.sh` replaces `scripts/build-mojo.sh`: it installs
  the wheel outside the repository and refuses it unless the wheels of the
  driver, `mojo` (`8fe3eaa6…`), the compiler, `mojo_compiler`
  (`55270afc…`), and the standard library, `mojo_compiler_mojo_libs`
  (`80df184f…`), have their pinned sha256. Every suite program was
  recorded again from the nightly. Against the results of 1.2.0, only
  five changed outcome, all departures that the nightly fixes: D-0005's
  three programs, which it now rejects, and two of D-0004's, which it now
  compiles. One program changed against the model,
  `basics/int_literal_left_comparison`, until then in `rejected/`: the
  nightly reads a literal `[e]` on the left of a comparison with an `Int`
  as an `Int`, and the model follows it. D-0002, D-0003 and D-0006
  reproduce unchanged.
