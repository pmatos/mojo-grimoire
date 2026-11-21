# D-0011 in detail: a getter-and-setter subscript that decides `and`/`or` calls its getter twice

This page holds the programs and the evidence of
[D-0011](decision-log.md#d-0011-a-getter-and-setter-subscript-that-decides-andor-calls-its-getter-twice-provisional),
whose summary stays in the decision log, so that the log stays within the
file-size budget.

## Programs

The pin disagrees with the model on these six programs, which
`known.json` lists:

- `structs/operator_method_bool_getter_twice`: the getter runs twice when
  the subscript decides. It runs with the left operand's values, with a
  temporary argument, and under `print`.
- `structs/operator_method_bool_getter_temporary`: an index built as a
  temporary is read twice and destroyed once.
- `structs/operator_method_bool_getter_drop_order`: the subscript does not
  decide, and the index's value dies after the getter instead of before
  it.
- `structs/operator_method_bool_getter_index_order`: as the last, with
  `and` and a right operand that changes the receiver.
- `rejected/operator_method_bool_getter_consumed`: the getter takes its
  index `var`, and the second call uses the temporary that the first
  consumed.
- `rejected/operator_method_bool_getter_transfer`: as the last, with the
  index a variable transferred with `^`, which the pin reports as a use
  of an uninitialized `k`.

The last four are the side effects that the human ruled part of the same
bug (question A on #211, 2026-11-21).

## Compiler

When a struct declares both `__getitem__` and `__setitem__`, and `w[i]` is
the left operand of `and` or `or` and decides the result, the pin calls
the getter twice: once to test the value, and once to read the result. The
index expression runs once. The reproducer prints `get 0`, `get 0`,
`True`. The default build and `-O0` agree, and so does the newer nightly
1.3.0.dev2026112017.

With a setter, the pin also keeps the index's values alive for the second
read, even when the subscript does not decide. Probed with `t = T(-5)` and
`w = W(2)`:

| Expression | With `__setitem__` | Without |
| --- | --- | --- |
| `var r = w[t.n]` | del T, get, del W | del T, get, del W |
| `if w[t.n]:` | del T, get, del W | del T, get, del W |
| `not w[t.n]` | del T, get, del W | del T, get, del W |
| `False or w[t.n]` | del T, get, del W | del T, get, del W |
| `w[t.n] or False`, not deciding | get, del W, del T | del T, get, del W |
| `w[t.n] and True`, not deciding | get, del W, del T | del T, get, del W |
| `w[t.n] or False`, deciding | get, del T, get, del W | del T, get, del W |

A getter that takes its index as `var k: K`, read as `v[K(5)] or False`,
is rejected with "use of uninitialized value '(expression temporary)'",
because the second call uses the temporary that the first consumed.
Without a setter the pin accepts it and prints `get 1 5`, `del K 5`,
`True`.

Without a setter, the pin calls each getter once and accepts the last
two. `structs/operator_method_bool_getter_var_self` agrees with the pin:
its left operands are the tests `__bool__(w[i])` that inference makes of
a mixed `and` or `or`, not bare subscripts, and the pin reads each
subscript once there.

## Model

The model calls the getter once and destroys values in the order the pin
uses for the same struct without `__setitem__`. Each of the six programs
prints, or accepts, what its twin without `__setitem__` gives on the pin,
at the default level and at `-O0`.

## Evidence

- `and` and `or` never write, so whether the struct has a setter cannot
  matter to them. Without `__setitem__`, the pin calls the getter once.
- With or without a setter, `if w[0]:`, `not w[0]`, `w[0] == True` and
  `w[0] + 1` call the getter once.
- With a getter that changes state, `def __getitem__(mut self, i: Int) ->
  Int` incrementing `self.n`, `w[0] or 9` tests 1 and returns 2, a value
  it never tested.
- The double call changes the destroy order: with a setter, another
  value's destructor runs between the two calls.
