# Current decisions: semantics

This page says what holds today for what Mojo means in this project and what
the model takes as its reference.

## The reference

The open-source Mojo compiler at a pinned release is the reference
(ADR-2026-11-15-1907). The pin is the 1.2 release line,
`MojoGrimoire.referenceMojo`, and within it the commit of the tag
`mojo/v1.2.0` of `modular/modular`. `scripts/build-mojo.sh` builds the
compiler from a checkout at that commit and refuses any other. The pin moves
forward with new releases as needed; each move updates the conformance
suite's recorded results, the script, the decision log and this page in the
same PR. The human chose this on 2026-11-15. Every disagreement between the
model and the compiler goes in
[the decision log](../conformance/decision-log.md).

Rejected: testing against the compiler's tip, where expected results would go
stale with no change on our side.

## Independence

The model is independent of the Isabelle formalisation `utting/mojo-semantics`
(ADR-2026-11-15-1908). It guides the Lean model: its definitions and the
statements of its theorems, such as its soundness theorem, may be used as
targets, which we state in our own terms and prove in Lean. Nothing here
calls, imports, vendors or mechanically translates it, and its test suite is
not copied. The compiler, not the Isabelle model, is the oracle. The human
ruled this on 2026-11-15.

Rejected: porting the Isabelle model and its suite, which would tie the
project to another codebase and to a suite with no licence.

## Scope of v1

v1 covers ownership and value semantics, structs, methods, lists, control
flow, integer and SIMD arithmetic, the static checker and the run-time
semantics, and a soundness theorem: accepted programs never fail with an
ownership or type error. Compile-time parameters and `comptime` evaluation,
Python interop, async, GPU kernels and codegen correctness are out of v1.

## The static checker

The checker, `MojoGrimoire.Check`, accepts a program of the core calculus
or rejects it with a class of error, `CheckError`. The conformance suite
compares these classes with the compiler's diagnostics, not their wording.
Each choice below was made from Mojo's manual at the pin. Each is to be
confirmed against the compiler when the suite records results (step 5 of
Phase 1), and any disagreement goes in the decision log.

- Initialization is tracked per part of a variable: a field may be moved
  out and initialized again. A variable may end with fields moved out, and
  the rest is destroyed field by field. The exception is a part that has a
  `__deinit__` of its own, which needs the whole value. Inside
  `__deinit__`, `self`'s fields may be moved out.
- `return x` moves a variable the function owns. Any other returned place
  is copied implicitly, so it must be implicitly copyable.
- Argument exclusivity rejects a `mut` argument that overlaps another
  argument passed as a location. As the manual says, it does not apply to
  `Int` and `Bool`.
- After an `if`, a part counts as initialized only when both branches leave
  it initialized. A loop body must leave initialized every part that was
  initialized before the loop.
- A declaration may not reuse the name of a variable in scope, a
  parameter included, so no variable hides another. Sibling blocks may
  reuse a name. ASAP elaboration relies on this, since it tracks
  variables by name.

### Lists

Lists, `List[T]`, follow the same rules, with these choices (#17):

- An element is part of its list for initialization: it is initialized
  whenever the list is, and cannot be transferred out (`xs[i]^`).
- Two places that go through elements of the same list overlap for
  argument exclusivity, whatever their indices.
- A list is copied only explicitly, with `.copy()`, and only when its
  elements can be copied.
- The only methods modelled are `append` and the built-in `len`, which a
  function named `len` hides. An index must be an `Int`. An index made
  only of integer literals, negation, `+`, `-` and `*` is computed when
  the program is compiled, and is rejected when it is negative
  (`negativeIndex`).

### References

`ref x = e` bindings and functions that return `ref [a, b] T` follow these
choices (#18):

- A reference's origins are the places it may point into: the place it is
  bound to, or the arguments passed to the parameters a returned
  reference's origin names. Those arguments must be places.
- A use of a reference needs every origin initialized, so a value moved
  away cannot be used through a reference to it. A value cannot be
  transferred out through a reference.
- A reference may be changed when every origin allows it: a `mut`
  parameter does, a `ref` parameter as its argument does, a `read`
  parameter does not.
- An origin names only `read`, `mut` or `ref` parameters, and a returned
  reference must stay within the function's origin.
- A reference overlaps what its origins overlap, for argument
  exclusivity. Changing an origin while a reference to it is live is not
  rejected.
- A call that returns a reference, used as a value, copies the value
  implicitly.
- Elaboration counts each use of a reference as a use of its origins, so
  their values live until the reference's last use.

## ASAP elaboration

Elaboration, `MojoGrimoire.Elab`, makes Mojo's destruction points explicit:
it inserts a `drop` wherever the compiler destroys a value, and is proved
to insert nothing else (`stripProgram_elabProgram`). The interpreter
destroys what a `drop` names, and what is still alive when a function
returns. As with the checker, each choice below is to be confirmed against
the compiler when the suite records results.

- A value dies right after the statement that last uses it, or right after
  its definition when nothing uses it. A value moved away with `^` is not
  destroyed there.
- A branch of an `if` that does not use a value the other branch uses
  destroys it first. A value a loop uses dies after the loop.
- A `var` parameter that the body never uses dies before the body runs.
- Inside `__deinit__`, each field of `self` dies on its own, after its own
  last use, and a field never used dies before the body runs. The human
  ruled on 2026-11-15 that the model gets this right from the start.
- Only values of struct type are dropped. Values destroyed at the same
  point die in the order of declaration, parameters first.
- A `return` gets no drops: the interpreter destroys what remains after
  evaluating the returned value.

## The interpreter

The interpreter, `MojoGrimoire.Interp`, runs an elaborated program with
fuel (#21). Its outcome is the class of error that rejects the program, or
the lines printed and how the run ends. These choices are to be confirmed
against the compiler when the suite records results:

- `Int` is 64-bit and wraps around on overflow. `//` rounds toward
  negative infinity and `%` takes the sign of the divisor. Both give 0 for
  a zero divisor, as Mojo's standard library defines them.
- An index out of bounds stops the run with an error. A negative index
  is out of bounds: Mojo's `List` does not count from the end.
- A struct without a `__deinit__` has its fields destroyed in declaration
  order, and a list its elements in index order.
- A temporary passed to a borrowing parameter is destroyed right after the
  call; the unused result of an expression statement is destroyed at once.
- An assignment evaluates its value, then its place, and destroys the old
  value after storing the new one.
- `return` evaluates its value, then destroys what the function still
  owns, in declaration order.

## The parser and the driver

`MojoGrimoire.Parse` reads a `.mojo` file into the core calculus, and
`mojo-grimoire FILE [--fuel N]` runs it (#23). It reads the subset the
model covers and fails with a syntax error, line and message, on anything
else. These choices hold:

- A struct's conformances give its copying: `ImplicitlyCopyable` implicit,
  `Copyable` explicit, and otherwise none. Other conformances, `raises` and
  the decorator `@fieldwise_init` aside, are read and ignored.
- `var` and `owned` parameters are both owned; a parameter with no
  convention is `read`; `self` may omit its type.
- `p += e`, `-=` and `*=` are `p = p op e`; `print(...)` on a line of its
  own is the print statement; docstrings are skipped.
- The parser writes the type `None` where the program leaves a type
  implicit, since no variable of the subset has that type. Inference then
  gives `var x = e` the type of `e`, and a list literal the type of its
  first element, or, when empty, the element type it is expected to have.
  What it cannot find stays `None`, and the checker rejects it.
- The exit code says how a run ended: 0 finished, 1 rejected
  (`rejected: CLASS in DECL` on standard error), 2 a run-time error
  (`run-time error: NAME`), 3 a syntax error (`syntax error: line N:
  MESSAGE`), 4 a command line or file that cannot be used. The conformance
  suite compares these, and the printed lines, with the compiler's.
