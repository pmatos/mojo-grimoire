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

Each entry below keeps a summary, with the heading `### D-NNNN: <title>`
that `scripts/conformance.py` looks for when `known.json` cites the entry.
An entry whose detail would push this file past the file-size budget
(ADR-2026-11-15-1901) keeps it on a page of its own,
`decision-log-dNNNN.md`, which the summary links.

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
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868);
  reproduces unchanged on the pinned nightly 1.3.0.dev2026111905 (D-0007)
- Program: `tests/conformance/lists/store_after_grow.mojo`
- Compiler: `xs[0] = bump(xs)`, where `bump` appends to `xs`, locates the
  element before the call and stores into a stale buffer, printing `1 3`
  ([detail](decision-log-d0002.md#compiler)).
- Model: evaluates the value before it locates the element, so it prints
  `5 3`; the shrinking and `ref` forms are on
  [the detail page](decision-log-d0002.md#model).
- Classification: compiler bug, ruled by the human on 2026-11-16 (#57).
- Decision and rationale: the model keeps its behaviour, since the
  compiler's store writes to memory the list no longer owns
  ([detail](decision-log-d0002.md#decision-and-rationale)).
- Upstream report: not filed yet. A draft on #57 awaits the human's
  approval; its link goes here once it is filed.

### D-0003: a variable that ends partly built is rejected (R, provisional)

- Date: 2026-11-18, revised 2026-11-19
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868);
  reproduces unchanged on the pinned nightly 1.3.0.dev2026111905 (D-0007)
- Programs: thirteen in `tests/conformance/structs/`, from
  `field_by_field_unset_destroyed.mojo` on, and
  `rejected/field_by_field_move_all_one_path.mojo`, all listed on
  [the detail page](decision-log-d0003.md#programs).
- Compiler: a variable of struct type declared without a value, whose
  fields are then assigned one by one, is destroyed whole even when some
  fields were never assigned: the compiler runs the destructor of each
  such field on whatever memory it holds. It rejects the same shapes when
  a field was moved out rather than never assigned: "field 'd.a' destroyed
  out of the middle of a value, preventing the overall value from being
  destroyed". Every shape probed is on
  [the detail page](decision-log-d0003.md#compiler).
- Model: rejects as `partiallyDestroyed` a variable, or a part assigned
  whole, that may end with a field never assigned or moved out while it
  may hold another, on some path
  ([detail](decision-log-d0003.md#model)).
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
  neither the compiler nor R. The evidence for the cases that R's sentence
  does not spell out is on
  [the detail page](decision-log-d0003.md#evidence-for-r).
- Upstream report: not filed yet. A draft on #51 awaits the human's
  approval; its link goes here once it is filed.

### D-0004: `@fieldwise_init` inside a cycle of structs through a list

- Date: 2026-11-18, reduced 2026-11-19 at the move to the nightly (D-0007)
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868);
  nightly 1.3.0.dev2026111905 since D-0007
- Program: `tests/conformance/structs/cycle_fieldwise_init_holder_first.mojo`
- Compiler: rejects a cycle of structs through a list when `@fieldwise_init`
  is on the struct that holds the other by value and that struct is
  declared first, with "non-'Deinitable' type"; the hand-written
  initializer compiles ([detail](decision-log-d0004.md#compiler)).
- Model: accepts it, as it accepts the hand-written form, and prints `1`.
- Classification: compiler bug, ruled by the human on 2026-11-18 (#47).
- Decision and rationale: the decorator is documented to produce the
  hand-written initializer; the error is probably D-0006's
  ([detail](decision-log-d0004.md#decision-and-rationale); what the
  nightly fixed is [there too](decision-log-d0004.md#fixed-by-the-nightly)).
- Upstream report: not filed yet. A draft on #47 awaits the human's
  approval; its link goes here once it is filed.

### D-0005: a list literal of any length but 1 that initializes an `Int`

- Date: 2026-11-19; resolved the same day at the move to the nightly (D-0007)
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868)
- Programs, in `tests/conformance/basics/`: `int_literal_length_two`,
  `int_literal_length_three` and `int_literal_length_evaluated`.
- Compiler: 1.2.0 accepted a list literal of any length where an `Int` is
  expected, kept its first element, and crashed on an empty one
  ([detail](decision-log-d0005.md#compiler)).
- Model: rejects a literal of `Int`s of every length but 1 as
  `noMatchingInit` (#154).
- Classification: compiler bug, ruled by the human on 2026-11-19 (#122),
  provisional.
- Decision and rationale: the model rejects these literals, as the stdlib
  documents. The nightly rejects them too, so the three programs agree and
  `known.json` no longer lists them ([detail](decision-log-d0005.md#resolved-at-the-nightly)).
- Upstream report: none needed, since the nightly fixes it.

### D-0006: a struct cycle through a list, rejected as non-'Deinitable'

- Date: 2026-11-19
- Mojo release and commit: 1.2.0 (527d069ee11a41ac5320af1f9402db0a66b2b868);
  reproduces unchanged on the pinned nightly 1.3.0.dev2026111905 (D-0007)
- Programs: nine under `tests/conformance/rejected/`, listed on
  [the detail page](decision-log-d0006.md#programs).
- Compiler: rejects a struct on a cycle of fields whose edges are lists
  and arrays only, such as `struct Node: var children: List[Node]`, with
  "has non-'Deinitable' type", and accepts some of these cycles when
  structs on it have a `__deinit__` ([detail](decision-log-d0006.md#compiler)).
- Model: accepts every struct cycle with a list edge, and rejects every
  cycle with no list edge (`recursiveStruct`).
- Classification: compiler bug, ruled by the human on 2026-11-19 (#136),
  provisional.
- Decision and rationale: the fixed compiler accepts every struct cycle
  with at least one list edge, since a list field has a fixed size
  ([detail](decision-log-d0006.md#decision-and-rationale)).
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

### D-0008: a range whose start and end lie 2^63 apart aborts (provisional)

- Date: 2026-11-19
- Mojo release and commit: nightly 1.3.0.dev2026111905 (D-0007); 1.2.0
  (527d069ee11a41ac5320af1f9402db0a66b2b868) aborts the same way
- Programs: none in the suite; `#guard` tests in
  `lean/MojoGrimoireTest/Parse/ListRange.lean` pin the cases
  ([why](decision-log-d0008.md#programs)).
- Compiler: `List[Int](range(start, end, step))` aborts at run time when
  the range is not empty and `start - end` is ±2^63, such as
  `range(-1, Int.MAX, Int.MAX)` ([detail](decision-log-d0008.md#compiler)).
- Model: builds the plain list, `[-1, 9223372036854775806]` for
  `range(-1, Int.MAX, Int.MAX)`.
- Classification: compiler bug, ruled by the human on 2026-11-19 (#121),
  provisional.
- Decision and rationale: the fixed compiler builds the range's elements,
  none of which overflows; only the reserved size does
  ([detail](decision-log-d0008.md#decision-and-rationale)).
- Upstream report: not filed yet. A draft on #121 awaits the human's
  approval; its link goes here once it is filed.

### D-0009: an index of an `Int` other than 0 is ignored (provisional)

- Date: 2026-11-21
- Mojo release and commit: nightly 1.3.0.dev2026111905 (D-0007)
- Programs: five in `tests/conformance/basics/`, `int_index_*`, listed on
  [the detail page](decision-log-d0009.md#programs).
- Compiler: `Int` is `SIMD[DType.int, 1]`, whose `__getitem__` and
  `__setitem__` check no index. `k[1]`, `k[-1]` and `k[three()]` read `k`,
  and `k[1] = 5` stores into it, with no error, also with `-O0` and
  `-D ASSERT=all` ([detail](decision-log-d0009.md#compiler)).
- Model: index 0 reads and writes the `Int`; any other index is checked
  as an array's of length 1: `constantIndexOutOfBounds` or `negativeIndex`
  for a constant one, `indexOutOfBounds` at run time for a computed one.
- Classification: compiler bug, ruled by the human on 2026-11-20 (#127),
  option A. The ruling is provisional, until the human has discussed it
  with Modular.
- Decision and rationale: the fixed compiler applies its own rule for
  arrays on the pin, by analogy, since neither the docs nor the compiler
  state one for `Int` ([evidence](decision-log-d0009.md#evidence)).
- Upstream report: not filed yet. A draft on #127 awaits the human's
  approval; its link goes here once it is filed.

### D-0010: one-element arrays compare equal beside a printing destructor (provisional)

- Date: 2026-11-21
- Mojo release and commit: nightly 1.3.0.dev2026111905 (D-0007)
- Program: `tests/conformance/arrays/compare_beside_printing_deinit.mojo`
- Compiler: an optimized build compares two one-element arrays as equal
  when a struct's `__deinit__` prints ([detail](decision-log-d0010.md)).
- Model: compares the elements.
- Classification: compiler bug, ruled by the human on 2026-11-21 (#235),
  provisional.
- Decision and rationale: the fixed compiler compares the elements, as
  `-O0` and every control do ([evidence](decision-log-d0010.md#evidence)).
- Upstream report: not filed; a draft on #235 awaits the human.

### D-0012: arrays of arrays of one-element arrays compare wrongly at -O3 (provisional)

- Date: 2026-11-21
- Mojo release and commit: nightly 1.3.0.dev2026111905 (D-0007)
- Program: `tests/conformance/arrays/compare_deep_one_element.mojo`
- Compiler: at the default level, `-O3`, `e > z` is `False` for
  `e = [[[1]]]` and `z = [[[0]]]` when another comparison of the same
  arrays is printed with it; `-O0`, `-O1` and `-O2` print the right `True`
  ([detail](decision-log-d0012.md#compiler)).
- Model: compares the elements, and prints `True False`.
- Classification: compiler bug, ruled by the human on 2026-11-21 (#257),
  provisional. It is a sibling of D-0010, with no printing destructor.
- Decision and rationale: the fixed compiler compares the elements one by
  one, as `-O0`, `-O1` and `-O2` do
  ([evidence](decision-log-d0012.md#evidence)).
- Upstream report: not filed; a draft on #257 awaits the human.
