# Current decisions: semantics, elaboration and the interpreter

This page continues [semantics.md](semantics.md) with the choices for
elaboration, which makes destruction explicit, and for the interpreter,
which runs the elaborated program.

## ASAP elaboration

Elaboration, `MojoGrimoire.Elab`, makes Mojo's destruction points explicit:
it inserts a `drop` wherever the compiler destroys a value, and is proved
to insert nothing else (`stripProgram_elabProgram`). The interpreter
destroys what a `drop` names, and what is still alive when a function
returns. As with the checker, each choice below was confirmed or corrected
against the compiler's recorded results (#25).

- A value dies right after its last use, which may be inside a statement:
  right after a nested operation reads it, when the operation takes it by
  value (a `var` argument, an `Int` or `Bool` passed `read`, an operator's
  operand), and right after the operation is done when it takes it by
  reference. The core calculus marks these points with `withDrops`. A
  value last used by the statement itself, by `print` or by the operation
  at the top of the statement, dies right after the statement, since the
  compiler destroys a discarded result first. A value never used dies
  right after its definition. A value moved away with `^` is not
  destroyed there, nor one that `p^.m(…)` gives to a method that takes
  `var self`.
- A branch of an `if` that does not use a value the other branch uses
  destroys it first. A value a loop uses dies after the loop.
- A `var` parameter that the body never uses dies before the body runs.
- Inside `__deinit__`, each field of `self` dies on its own, after its own
  last use, and a field never used dies before the body runs. The human
  ruled on 2026-11-15 that the model gets this right from the start.
- Only values of struct type are dropped. Values destroyed at the same
  point die as the compiler destroys them: the parameters first, then the
  local variables, each the last declared first; the fields of `self` in
  `__deinit__` in their order; values read by value in the order they are
  read.
- A `return` gets no drops of its own: its value is elaborated, and the
  interpreter destroys what remains after evaluating it.

## The interpreter

The interpreter, `MojoGrimoire.Interp`, runs an elaborated program with
fuel (#21). Its outcome is the class of error that rejects the program, or
the lines printed and how the run ends. These choices were confirmed or
corrected against the compiler's recorded results (#25):

- `Int` is 64-bit and wraps around on overflow. `//` rounds toward
  negative infinity and `%` takes the sign of the divisor. Both give 0 for
  a zero divisor, as Mojo's standard library defines them.
- An index out of bounds stops the run with an error. A negative index
  is out of bounds: Mojo's `List` does not count from the end.
- An operand that is a place passed by value, an argument, an operator's
  operand, a list element or a printed value, is located in order but read
  only once every operand of its operation has been evaluated, as the
  compiler does: `f(a.id, g(a))` sees what `g` did to `a`. So is an
  operand that is a call returning a reference (#76): `print(pick(a, b,
  True), bump(a))` sees what `bump` did to `a`. The operand of a unary
  operator, of `and` and of `or` is read at once, as the compiler does. An
  `Int` or a `Bool` passed to a `read` parameter is passed by value.
- `print` writes its values separated by spaces: an `Int` in decimal, a
  `Bool` as `True` or `False`, and a list or an array as `[1, 2]`, its
  elements written so and separated by `, `, `[]` when it is empty (#41).
- A struct without a `__deinit__` has its fields destroyed in declaration
  order, and a list its elements in index order. A variable of struct type
  declared without a value holds the blank of its type, the struct with
  no field assigned, and a value taken out of a place leaves its blank:
  so its fields can be assigned one by one. A value that holds nothing, a
  blank included, is not destroyed. A struct that is partly built is never
  destroyed: the checker rejects the program (#51, D-0003).
- A temporary passed to a borrowing parameter is destroyed right after the
  call; the unused result of an expression statement is destroyed at once.
  A temporary origin argument of a call that returns a reference, whose
  value is dropped, is the exception: elaboration gives it a hidden
  variable, which the interpreter fills, and it dies where elaboration
  drops it, at the last use of the reference (#80,
  [semantics-references.md](semantics-references.md#references)).
- An assignment evaluates the indices of its place first, outermost
  first, and stops at an index out of bounds, as the compiler does
  (#205). It then evaluates its value, locates the element in the list as
  the value left it (D-0002), and destroys the old value after storing the
  new one. Into an `Int`'s element, it locates the `Int` and evaluates
  the index first, and reads the index after the value (#127). The
  checker checks the indices before the value too, so the value sees what
  an index moves out or changes, then that the place may be changed
  (#174). An index's error of a later pass than typing waits for the
  value's errors of earlier passes (#280).
- `return` evaluates its value, then destroys what the function still
  owns, in declaration order.
