# Current decisions: semantics

This page says what holds today for what Mojo means in this project and what
the model takes as its reference.
[semantics-references.md](semantics-references.md) continues it with
references, [semantics-lists.md](semantics-lists.md) with lists and
arrays, and [semantics-parser.md](semantics-parser.md) with the parser and
the driver.

## The reference

The open-source Mojo compiler at a pinned release is the reference
(ADR-2026-11-15-1907). The pin is the 1.2 release line,
`MojoGrimoire.referenceMojo`, and within it the commit of the tag
`mojo/v1.2.0` of `modular/modular`. `scripts/build-mojo.sh` builds the
compiler from a checkout at that commit and refuses any other. The pin moves
forward with new releases as needed; each move updates the conformance
suite's recorded results, the script, the decision log and this page in the
same PR. The human chose this on 2026-11-15. The model follows the compiler,
and [the decision log](../conformance/decision-log.md) records each place
where it departs: a compiler bug or a spec decision
([conformance.md](conformance.md#the-decision-log)).

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
Each choice below was made from Mojo's manual at the pin, and confirmed or
corrected against the compiler when the suite recorded its results (#25):
where the compiler and the manual disagree, the model follows the compiler.

- Initialization is tracked per part of a variable: a field may be moved
  out and initialized again. The compiler destroys a struct whole, so a
  field moved out with `^` must be assigned again, at exactly its path,
  before the struct ends or a part above the field is assigned. Using the
  struct's other fields in between is allowed. Otherwise the program is
  rejected as `partiallyDestroyed`, which covers both of the compiler's
  messages: "destroyed out of the middle of a value" and "cannot be
  consumed, because ... is used later". The checker cannot tell which one
  the compiler gives, since that depends on what follows (#39). A part
  below a struct with a `__deinit__` of its own may not be uninitialized
  when the struct ends either. Inside `__deinit__`, `self`'s own fields may
  stay moved out, but not fields of its fields.
- Until a field moved out is assigned again at its path, the compiler
  reports a use of it, or of a part above it, as `uninitializedUse`, even
  after each of its sub-fields was assigned. The same holds for a loop
  body that leaves such a field moved out, and for overwriting the struct
  through a reference.
- `p^` of type `Int` or `Bool` is the place `p`: the compiler warns that
  the transfer has no effect, and uses `p` as if `^` were not there. So `p`
  keeps its value, may be a `read` parameter, a field of one, a
  reference, an element of a list or an array, or a field of an element,
  is read when other places are, and may be passed to a `mut` parameter.
  Inference rewrites `p^` to `p`, so the core calculus's transfer always
  moves (#50, #43). Any other element, or a field of one, is rejected as
  `transferFromElement`, as the compiler does.
- `p^` followed by a field or a method, `p^.f` or `p^.m(…)`, is the place
  `transferred p` (#66). The compiler warns that the transfer has no
  effect, and borrows `p`: `p^.f` is the field `p.f`, read, copied or
  passed as that place is, and `p^.m(…)` calls `m` on `p`. `p` must be
  whole (`uninitializedUse`) and a value that `p^` could transfer: not a
  `read` or `ref` parameter (`transferFromBorrowed`), nor an element
  (`transferFromElement`). A reference is `transferFromBorrowed` too,
  where the compiler reports `transferFromElement`, for `t^` as for
  `t^.k` (#85). Nothing may change through it:
  assigning to `p^.f`, `p^.f += 1`, passing it `mut`, and a `mut self`
  method are `immutablePlace`. A method that takes `var self` consumes
  `p`, once the arguments are read, and the receiver counts as passed
  `mut` for argument exclusivity; on `p^.f` it copies the field, which
  must be implicitly copyable. `p^.f^` moves the field `p.f`. The
  compiler lets `ref r = p^.f` change `p.f` through `r`, and so does the
  model. `p^.f` passed to a `ref` parameter, and `p^` as the receiver
  of a `ref self` method, pass on an immutable reference, and the call
  changes nothing
  (#91, [semantics-references.md](semantics-references.md#references)).
- A field moved out of a struct that was built field by field, and never
  initialized whole, is rejected like any other. The compiler accepts that
  program when the struct's other fields stay uninitialized (#51).
- A place operand, of a call, an operator, a list literal or `print`, must
  still be initialized once every operand is evaluated, since the
  compiler reads it then: `f(a.id, g(a^))` uses `a.id` after its move.
  So must the origins of an operand that is a call returning a reference,
  which the compiler also reads then (#76; see
  [semantics-references.md](semantics-references.md)).
- `print` takes string literals and values it can write: `Int`, `Bool`,
  and lists and arrays of them, nested ones included (#41). It reads a
  place by reference, so it copies nothing: a list may be printed from a
  `read` parameter or a `ref` binding. A struct, or a list or an array of
  structs, is rejected as `notPrintable`, as the compiler rejects a value
  that does not conform to `Writable`.
- `return x` moves a variable the function owns. Any other returned place
  is copied implicitly, so it must be implicitly copyable.
- At every return, explicit or implicit, a `mut` parameter and the `self`
  of `__init__` must be wholly initialized. Otherwise the program is
  rejected as `uninitializedAtExit`, the class of the compiler's "is
  uninitialized at (the implicit) return from this function" (#52).
- Argument exclusivity rejects a `mut` argument that overlaps another
  argument passed as a location. The manual exempts `Int` and `Bool`, but
  the compiler rejects two aliasing `mut` arguments of any type. An `Int`
  or a `Bool` passed to a `read` parameter is copied, so it is not a
  location and never clashes.
- After an `if`, a part counts as initialized only when both branches leave
  it initialized. A loop body must leave initialized every part that was
  initialized before the loop; as the compiler does, the checker reports
  a body that does not as `uninitializedUse`.
- Only a struct has fields, and only a struct or a list has methods. A
  field or a method that the type of its receiver lacks, whatever that
  type, is one class, `unknownAttribute`, named with the type's name: the
  compiler reports both as "has no attribute" (#42,
  [conformance.md](conformance.md#unknown-fields-and-methods)).
- An initialization whose arguments fit no initializer is one class,
  `noMatchingInit`, however they misfit: a construction `S(…)` with a
  wrong number of arguments, a wrong one, or a value passed to a `mut`
  parameter that is not a place or cannot change; a literal that does not
  fit the list or array it initializes, or that initializes a struct or a
  `Bool`; and `List[T](e1, …, en)`. The
  compiler reports each as "no matching function in initialization" (#46,
  [conformance.md](conformance.md#initializations-that-fit-no-initializer)).
- A declaration may not reuse the name of a variable in scope, a
  parameter included, so no variable hides another. Sibling blocks may
  reuse a name. ASAP elaboration relies on this, since it tracks
  variables by name.

### Lists and arrays

The choices for lists and arrays are on
[semantics-lists.md](semantics-lists.md).

### References

The decisions on `ref` bindings and functions that return a reference are
on [semantics-references.md](semantics-references.md).

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
  order, and a list its elements in index order.
- A temporary passed to a borrowing parameter is destroyed right after the
  call; the unused result of an expression statement is destroyed at once.
- An assignment evaluates its value, then its place, and destroys the old
  value after storing the new one.
- `return` evaluates its value, then destroys what the function still
  owns, in declaration order.
