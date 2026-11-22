# D-0012 in detail: an assignment whose value is the target itself destroys the old value first

This page holds the programs and the evidence of
[D-0012](decision-log.md#d-0012-an-assignment-whose-value-is-the-target-itself-destroys-the-old-value-first-provisional),
whose summary stays in the decision log, so that the log stays within the
file-size budget.

## Programs

The pin disagrees with the model on these six programs, which
`known.json` lists. `T` is `ImplicitlyCopyable`, with a printing
`__bool__` that returns `self.n != 0` and a printing `__deinit__`:

| Program, in `tests/conformance/structs/` | Statement | Pin, default level | Pin, `-O0` | Model, the fixed compiler |
| --- | --- | --- | --- | --- |
| `assign_target_self` | `o = o`, `o = T(4)` | del T 4, 1, del T 0 | del T 4, 4, del T 4 | del T 4, 4, del T 4 |
| `assign_target_and_right` | `b = a and b`, `a = T(1)`, `b = T(5)` | del T 5, bool 1, del T 1, 1, del T 1 | del T 5, bool 1, del T 1, 5, del T 5 | bool 1, del T 1, del T 5, 5, del T 5 |
| `assign_target_or_right` | `b = a or b`, `a = T(0)`, `b = T(5)` | del T 5, bool 0, del T 0, 0, del T 0 | del T 5, bool 0, del T 0, 5, del T 5 | bool 0, del T 0, del T 5, 5, del T 5 |
| `assign_target_and_left` | `a = a and b`, `a = T(0)`, `b = T(5)` | bool 0, del T 0, del T 5, 5, del T 5 | bool 0, del T 0, del T 5, 0, del T 0 | bool 0, del T 5, del T 0, 0, del T 0 |
| `assign_target_or_right_unread` | `b = a or b`, `a = T(1)`, `b = T(5)` | del T 5, bool 1, del T 1, 1, del T 1 | the same | bool 1, del T 5, del T 1, 1, del T 1 |
| `assign_target_field` | `h.u = h.t and h.u`, `h = H(T(0), T(7))` | del T 7, bool 0, 0, del T 0, del T 0 | the same | bool 0, del T 7, 0, del T 0, del T 0 |

Each prints the target's `n` after the assignment. In the first four, the
pin reads the target after it destroyed it, and its two levels print
different values. In the last two, the levels agree, but the pin still
destroys the old value before the test, before it is known whether the
target is the result.

## Compiler

For an assignment to another variable, such as `p = o` with `p = T(8)`,
`o = T(4)` and `o` not used later, the pin destroys the old `p`, copies
`o` into `p`, and destroys `o`, whose last use the copy is: it prints
`del T 8`, `del T 4`, `4`, at every level. Through a call, `b = pick(a,
b)`, it calls `pick` and copies its result before it destroys the old
`b`: `pick`, `del T 5`, `del T 1`, `5`.

When the value is the target itself, the pin applies the first order to
one value: it destroys the old value and then copies it, so it reads a
destroyed value. With `-O0` the destroyed bytes are still there and the
program prints the old value; the default build prints what the optimizer
left. Mojo 1.2.0 prints what the pin's default level prints, and the
nightlies 1.3.0.dev2026111705, 1.3.0.dev2026112017 and
1.3.0.dev2026112105 print what the pin prints, at both levels.

A struct with its own copy constructor is moved at its last use instead of
copied, so `o = o` then prints `4` and destroys nothing early. That is the
move, not a rule for self-assignment.

## Model

The model copies the value and then destroys the old one. As the pin
does for any other target, the old value dies at its last use: for a
fresh target that comes before the expression, and when the target is an
operand, it comes inside the expression, at the copy when the target
decides, so the old value dies after it. Main already did so for
`o = o`, and part 2 of #191 does it for `and` and `or`. In `assign_target_and_left`, the model
destroys `b`, whose last use is the right-hand side, before the replaced
`a`, as the pin does for `a = first(a, b)` (#252).

## Evidence

- Every other target's old value dies at its last use, at every level,
  on the pin, on Mojo 1.2.0 and on the nightly 1.3.0.dev2026112017 (the
  probes on #248). A fresh target's dies before the expression: `p = o`
  prints `del T 8` before it copies `o`. Through a call, the old `b` of
  `b = pick(a, b)` dies after the call, its last use.
- The default level and `-O0` print different values for the same
  program, which no fixed compiler would do.
- The twin `c = a and b`, whose target `c` is not an operand, prints
  `del T 9`, `bool 1`, `del T 1`, `del T 5`, `5`, `del T 5` at both
  levels, and the model agrees.
- `h.u = h.u` prints `del T 7`, `7`, `del T 1`, `del T 7` at both levels,
  and the model agrees, so it needs no record.
