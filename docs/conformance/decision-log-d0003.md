# D-0003 in detail: a variable that ends partly built

This page holds the programs and the evidence of
[D-0003](decision-log.md#d-0003-a-variable-that-ends-partly-built-is-rejected-r-provisional),
whose summary stays in the decision log. It was moved out of the log on
2026-11-19, so that the log stays within the file-size budget (#121).

## Programs

In `tests/conformance/structs/`:

- `field_by_field_unset_destroyed.mojo`, `field_by_field_unset_nested.mojo`,
  `field_by_field_unset_overwritten.mojo`,
  `field_by_field_unset_destructor.mojo`, `field_by_field_unset_branch.mojo`;
- `field_by_field_unset_whole_branch.mojo`,
  `field_by_field_unset_whole_loop.mojo`, `field_by_field_unset_ints.mojo`;
- `field_by_field_move_after_last_use.mojo` and its `_loop` variant (#144);
- `field_by_field_branch_move_other.mojo` and its `_both` variant (#137);
- `field_by_field_whole_branch_then_fields.mojo`.

And `rejected/field_by_field_move_all_one_path.mojo`, the moved-out mirror
of a struct built wholly on one path, on which the model agrees.

## Compiler

A variable of struct type declared without a value, whose fields are then
assigned one by one, is destroyed whole even when some fields were never
assigned. The compiler runs the destructor of each such field on whatever
memory it holds. With `Duo` holding two `Token`s that print `drop <n>`
when destroyed:

- at the end of the variable: `var d: Duo; d.left = Token(1);
  print(d.left.n)` prints `1`, `drop 1`, `drop 0`;
- for a field below a nested struct: `var r: Rack; r.z = 3`, where `Rack`
  holds a `Slot` that holds a `Token`, prints `drop 0`;
- when a part is assigned whole: `r.s.k = 1; r.s = Slot(Token(5), 2)`
  prints `drop 0` before the new value is stored;
- when the struct has a `__deinit__` of its own: `var b: Box;
  b.a = Token(1)`, where `Box` prints `box` in its `__deinit__`, prints
  `1`, `drop 1`, `drop 0`, `box`;
- when the struct is built in one branch of an `if` only, partly or
  wholly, or in a loop: `whole_branch` prints `mark gone` four times for
  two fields assigned, and `whole_loop` ten times for four;
- when the struct is assigned whole in one branch only and then given
  every field: `whole_branch_then_fields` prints `mark gone` six times for
  four fields assigned, on 1.2.0 and on the nightly.

The compiler also accepts a field moved out after another field's last
use (#144), and a field moved out in one branch while the other builds
another field (#137). With fields that print `drop <id>`, each of these
programs prints `drop <garbage>` first: it destroys a field never
assigned.

The compiler rejects the same shapes when a field was moved out rather
than never assigned: "field 'd.a' destroyed out of the middle of a value,
preventing the overall value from being destroyed", with or without a
`__deinit__`, and when the field is moved out on one path only, as in
`t.b = Res(2); t.a = Res(1); if c: var y = t.b^; var x = t.a^`.

The first shape still prints `drop 0` on the nightly 1.3.0.dev2026111705
(2026-11-18), and the `Box` variant prints `box gone 1 15`, `drop 1`,
`drop 0`.

## Model

The model rejects as `partiallyDestroyed` a variable, or a part assigned
whole, that may end with a field never assigned or moved out while it may
hold another, on some path. A variable assigned whole in only one branch
may end, and so may the `self` of `__init__` built wholly in only one
branch, which is whole once its fields are: the compiler accepts it with
clean output. Every program above is rejected, except
`whole_branch_then_fields`, where nothing ends partly built, and
`move_all_one_path`, which agrees.

## Evidence for R

The evidence, on 1.2.0 and on a nightly (1.3.0.dev2026111705 or
1.3.0.dev2026111905, which agree), for three cases that R's sentence does
not spell out:

- structs of `Int`s: the compiler's rule for a field moved out does not
  depend on a destructor. `var s = Seg(Pair(1, 2), Pair(3, 4));
  print(s.lo.x); var h = s.hi^` is rejected with "field 's.hi' destroyed
  out of the middle of a value", and so are `rejected/move_field_destroyed`
  and `rejected/move_every_field`, whose `Line` holds two `Point`s of
  `Int`s. So the model rejects `unset_ints` (`var p: Pair; p.x = 1`) too,
  though its output shows no bug. An `Int` field itself cannot be moved
  out, as `p.x^` copies it;
- a struct whole on one path and empty on another: the compiler judges a
  field moved out at the join of paths.
  `rejected/field_by_field_move_all_one_path` moves out every field of a
  struct built field by field, in one branch only, and is rejected, while
  `structs/field_by_field_move_every`, the same moves with no branch, is
  accepted. So `unset_whole_branch` and `unset_whole_loop` are rejected;
- a value held on only some paths: `var r: Res; if c: r = Res(1)` then
  `r = Res(2)` prints `drop 1`, `2`, `drop 2`, destroying the first value
  on the path that has one only. So the model, which destroys a part only
  on the paths that hold it, accepts `whole_branch_then_fields` and prints
  four `mark gone` lines, where the compiler also destroys the two fields
  never assigned.
