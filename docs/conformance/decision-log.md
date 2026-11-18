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

### D-0003: a struct built field by field destroys a field never assigned

- Date: 2026-11-18
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868)
- Programs: `tests/conformance/structs/field_by_field_unset_destroyed.mojo`,
  `field_by_field_unset_nested.mojo`, `field_by_field_unset_overwritten.mojo`,
  `field_by_field_unset_destructor.mojo` and
  `field_by_field_unset_branch.mojo`, in the same directory.
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
