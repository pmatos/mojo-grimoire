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
- A field moved out of a struct that was built field by field, and never
  initialized whole, is rejected like any other. The compiler accepts that
  program when the struct's other fields stay uninitialized (#51).
- A place operand, of a call, an operator, a list literal or `print`, must
  still be initialized once every operand is evaluated, since the
  compiler reads it then: `f(a.id, g(a^))` uses `a.id` after its move.
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
- The only methods modelled are `append`, `pop()`, `pop(i)` and the
  built-in `len`, which a function named `len` hides (#40). `pop()` takes
  its list `mut`, removes the last element and gives it back as an owned
  value of the element type. On an empty list it fails at run time, as the
  compiler's bounds check does. `pop(i)` removes and gives back the
  element at the `Int` index `i` (#58). Its index is evaluated before the
  list is read, and is checked only at run time: a negative index, even a
  constant one, fails as out of bounds, as the stdlib's `check_bounds`
  does. A wrong call of `pop` is an arity or a type mismatch in the model.
  The compiler reports both as "no matching method", which no pattern of
  the suite classifies, so only Lean tests cover them. An index must be
  an `Int`. An index `xs[i]` made only of integer literals, negation,
  `+`, `-`, `*`, `//` and `%` is computed when the program is compiled,
  and is rejected when it is negative (`negativeIndex`). `//` and `%` round toward negative infinity
  and give 0 for a zero divisor, as the compiler does.

### Arrays

Arrays, `Array[T, N]`, hold exactly `N` elements inline. They follow the
rules of lists, with these differences, which the compiler at the pin
shows. The human ruled on 2026-11-16 that the model follows the compiler
here (#27).

- A literal `[e1, …, en]` is an `Array[T, n]`, with `T` the type of `e1`,
  unless a list is expected where it stands. A list is expected by the
  declared type of a variable, the type of a place assigned to, a
  function's result, a parameter, and the element type of an enclosing
  literal or of the list that `append` adds to. A literal with no type
  expected and no elements, `var xs = []`, is rejected.
- An array has no methods. `len` and indexing work as on a list. At run
  time an array is a list value whose length is its size `N`.
- An array's size is part of its type, so `[1, 2, 3]` is not an
  `Array[Int, 2]`. The size in a type is an integer literal.
- A constant index into an array of `N` elements is rejected when it is `N`
  or more (`constantIndexOutOfBounds`); one known only at run time fails
  then, as on a list. A constant index into a list fails only at run time.
- A struct may not hold an array, or a list, of itself: the compiler
  rejects both, and so does the model (`recursiveStruct`).

Rejected: keeping every literal a `List`, which would accept programs that
the compiler rejects, such as `append` to an unannotated literal.

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
  reference must stay within the function's origin (`escapingReference`).
  A place through a list element, or through a field of an element of a
  list or an array, has an origin of its own and may not be returned, as
  the compiler does (#56): `return xs[0]` for a list `xs`. An element of an
  array may be returned. A field of the parameter itself is still accepted,
  though the compiler rejects it too (#67).
- A reference overlaps what its origins overlap, for argument
  exclusivity. A reference through another reference points into the same
  place of each of the other's origins.
- A reference into an element of a list is invalidated when the list, or a
  place that holds it, changes as a whole. That means it is assigned,
  passed `mut`, or passed `ref` from a place that may be changed, which
  includes `append` and `pop`. Using the reference afterwards, on any path
  or on a later iteration of a loop, is rejected (`invalidatedReference`),
  as the compiler does (#55). Changing one element, reading the list,
  or assigning a whole array does not invalidate it, since an array holds
  its elements in place. Any other change to an origin while a reference to it
  is live is not rejected.
- A place operand that goes through a list element is located before the
  operands after it are evaluated, and read once they all are. A later
  operand that changes the list invalidates it, and the model rejects the
  operation, as the compiler does: `print(xs[0], xs.pop())`.
- An assignment through a reference into a list element is rejected
  (`invalidatedReference`) when its own value invalidates the reference:
  `ref e = xs[0]; e = grow(xs)`. The compiler accepts that and stores into
  a stale element, as it does for `xs[0] = grow(xs)`; the human ruled on
  2026-11-16 that this is a compiler bug (#57,
  [D-0002](../conformance/decision-log.md)). The model evaluates the value
  of `xs[0] = grow(xs)` first, then stores into the grown list. It keeps
  rejecting the `ref` form, since running it could leave the interpreter
  stuck when the call shrinks the list.
- An assignment into a list element is rejected (`argumentExclusivity`)
  when the value is a call that builds its result in place and is passed
  `mut` the list, or a place that holds it: `xs[0] = xs.pop()`. A call
  builds its result in place unless it returns an `Int`, a `Bool` or a
  reference. `pop` always does, since its result has a generic type.
- A call that returns a reference, used as a value, copies the value
  implicitly.
- Elaboration counts each use of a reference as a use of its origins, so
  their values live until the reference's last use.

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
  destroyed there.
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
  compiler does: `f(a.id, g(a))` sees what `g` did to `a`. An `Int` or a
  `Bool` passed to a `read` parameter is passed by value.
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
- `^` after a term is binary XOR, as in the compiler's postfix loop
  (`ParserExprs.cpp`), when the next token can start an expression
  (`isPrimaryExprStart`), is not `.`, and lies in the same statement. XOR is
  outside the subset, so `x^ + 1`, `x^ (1)`, `x^ * 2` and `x^ == 3` are
  syntax errors. Otherwise `^` is a transfer: `f(x^)`, `(x^)`, `x^` at the
  end of a line, and `x^` before `<`, `and` or `or` (#54); before `if`, `in`
  or `is` it is not XOR either, but the model reads none of those forms.
  The compiler continues a statement onto a deeper-indented line, and,
  inside call arguments and subscripts, onto any line, so there `x^` with
  `+ 1` on the next line is XOR. Inside a parenthesized expression or a
  list literal it does not, and `(x^` with `+ 1)` at the statement's column
  fails to parse. The model's lexer ignores line breaks inside brackets, so
  it reads XOR in all of these, and ends the logical line outside them,
  where the indented line is a syntax error: each is a syntax error in the
  model as in the compiler. The model does not read a field of a transfer,
  so `s^.f`, which the compiler accepts, stays a syntax error (#66).
- The parser writes the type `None` where the program leaves a type
  implicit, since no variable of the subset has that type. Inference then
  gives `var x = e` the type of `e`, and a literal `[e1, …, en]` the type
  expected where it stands, or else `Array[T, n]` (see Arrays).
  What it cannot find stays `None`, and the checker rejects it.
- The exit code says how a run ended: 0 finished, 1 rejected
  (`rejected: CLASS in DECL` on standard error), 2 a run-time error
  (`run-time error: NAME`), 3 a syntax error (`syntax error: line N:
  MESSAGE`), 4 a command line or file that cannot be used. The conformance
  suite compares these, and the printed lines, with the compiler's.
