# Current decisions: semantics, lists and arrays

This page continues [semantics.md](semantics.md) with the choices for
lists and arrays. An index of an `Int`, which reads its one element, is
on [semantics-int-index.md](semantics-int-index.md).

## Lists

Lists, `List[T]`, follow the rules of
[the static checker](semantics.md#the-static-checker), with these choices
(#17):

- An element is part of its list for initialization: it is initialized
  whenever the list is, and cannot be transferred out (`xs[i]^`).
- Two places that go through elements of the same list overlap for
  argument exclusivity, whatever their indices.
- A list is copied only explicitly, with `.copy()`, and only when its
  elements can be copied.
- The only methods modelled are `append`, `pop()`, `pop(i)` and the
  built-in `len`, which a function named `len` hides (#40), and a variable
  or a parameter in scope too (#176), which calls its struct's `__call__`
  when it declares one (#191). `pop()` takes
  its list `mut`, removes the last element and gives it back as an owned
  value of the element type. On an empty list it fails at run time, as the
  compiler's bounds check does. `pop(i)` removes and gives back the
  element at the `Int` index `i` (#58). Its index is evaluated before the
  list is read, and is checked only at run time: a negative index, even a
  constant one, fails as out of bounds, as the stdlib's `check_bounds`
  does. `pop` has several overloads, so a wrong call of it, a wrong number
  of arguments or a list that may not change included, is
  `noMatchingMethod`, as the compiler reports "no matching method" (#88,
  #169). An index must be an `Int`: an index of a list or an array calls
  `__getitem__`, which has several overloads too, so one that is no `Int`
  is `noMatchingMethod`. A literal of `Int`s of the wrong length, as an
  index or the argument of `pop`, still fails SIMD's constraint
  (`noMatchingInit`, see below). An index `xs[i]` made only of integer literals, negation,
  `+`, `-`, `*`, `//` and `%` is computed when the program is compiled,
  and is rejected when it is negative (`negativeIndex`). `//` and `%` round toward negative infinity
  and give 0 for a zero divisor, as the compiler does.
- `List[T]()` is an empty list. `List[T](e1, …, en)` with arguments is
  rejected (`noMatchingInit`), as the compiler rejects it, but for one
  list or array argument (see below) (#46). The only
  initializer of `List` at the pin that takes the elements as arguments
  (`std/collections/list.mojo:463`) also needs the keyword argument
  `__list_literal__`, which only a list literal passes: since Mojo 25.4, a
  literal `[e1, …, en]` calls `T(e1, …, en, __list_literal__: ())` for the
  type `T` expected where it stands, or `List` by default
  (`docs/site/releases/v0.25.4.md:117`). The same call explains why a
  literal that does not fit the list or array it initializes is
  `noMatchingInit` too.
- `List[T](e)` with one argument that is a list or an array of `T` is a
  new list of copies of its elements, in order, as the compiler builds it
  through the initializer of `List` from any iterable
  (`std/collections/list.mojo:485`). The human ruled on 2026-11-18 that
  the model follows the compiler here (#103). The argument may be a
  literal, a variable, a place such as an element, or a call's result. A
  literal there has no type expected, so it is an array, and `[[1], [2]]`
  is an array of arrays, which fits no `List[Int]`. The initializer takes
  the argument by `ref`: a place must be initialized, and is borrowed, so
  `^` on it has no effect, and `xs^` needs a value that could be
  transferred, as `xs^.f` does. A mutable place passed so may be changed,
  which invalidates a reference into one of its elements; through `xs^`,
  or from a `read` parameter, it is not. The new list is built in the
  place it is assigned to, so `xss[0] = List[Int](pick(xss, ys))`, with
  `pick` returning a mutable reference into `xss` or `ys`, is
  `argumentExclusivity`, as for any call that builds its result in place.
  A temporary argument is destroyed
  once its elements are copied, and a variable whose last use is the
  argument dies once the new list is built.
- `T` must be the source's element type, and must be copyable,
  explicitly or implicitly. A literal argument whose elements differ in
  type, also inside a nested literal, fits no initializer, since the
  compiler infers the literal's type while it looks for one. Any other
  argument in the subset, an empty literal among them, fits no
  initializer either (`noMatchingInit`); a string literal is outside the
  subset (#180). The compiler reports a
  `List[T]` source whose elements cannot be copied as "cannot construct
  'List[T]' with itself", which the suite also maps to `noMatchingInit`
  ([conformance-classes.md](conformance-classes.md#initializations-that-fit-no-initializer)).
- `List[T](range(…))` with one, two or three `Int` arguments, the end, the
  start and the end, or a step too, is the list of the range's `Int`s,
  from the start, 0 by default, by the step, 1 by default, up to the end
  and without it, or down to it for a negative step; a step of 0 gives
  `[]`. The human ruled on 2026-11-19 that the model takes `range` only
  as the argument of `List[T](…)` (#121). A range is not a value of its
  own: `range` anywhere else, as in `var r = range(3)`,
  `len(range(3))` or `range(range(3))`, is outside the subset, exit 3
  ([semantics-parser.md](semantics-parser.md#outside-the-subset), #180),
  though the compiler accepts the first two. A function or a struct of the program, or a variable in scope,
  named `range` is used instead; called, a variable is rejected as
  `missingMethod`, as the compiler reports that its type has no
  `__call__` (#176). Any other iterable that
  the compiler accepts as the one argument of `List[T](…)` stays outside
  the subset. The arguments are evaluated from left to right, as `read`
  arguments of type `Int`, so a place among them is read once all are
  evaluated, and a literal `[e]` is the `Int` `e`. `T` must be `Int`.
  Errors come in the order of the compiler's passes, which differs from
  the order of the arguments. First, an error of typing in any argument:
  an unknown name or attribute, or a misfit of a call inside it. Then a
  misfit of `range`, `noMatchingInit`: a wrong number of arguments, an
  argument that is not an `Int`, though it is uninitialized or reads such
  a value or a constant index out of range, or a `T` other than `Int`: every argument is typed before any
  is read. An open literal is a misfit too, unless every element that is
  not a literal, at any depth, is an `Int` and, as the first argument, it
  is not empty and its first element, at any depth, is not an empty
  literal: the compiler takes such a literal for an `Int`, and fails only
  when it instantiates the call.
  Then a use of an uninitialized or invalidated value; the elements of a
  literal are read late, as an operation's operands, so a later argument
  that changes their list invalidates them. Then, in the model, that
  literal, `noMatchingInit` again, and then a constant index out of
  range: between the literal and a constant index into an array, the
  compiler's order depends on the optimization level, and is left
  undefined (#331). An argument
  that holds a string literal or a call of `range`, at any depth, is
  outside the subset, whatever error comes first (#180). The
  compiler reports the misfits as "no matching function in call to
  'range'" or "no matching function in initialization", and the literal
  as "function instantiation failed"; the suite maps each to
  `noMatchingInit`, the first by the ruling of 2026-11-19 (#121). Where
  the compiler's finer order differs is in
  [semantics-error-order.md](semantics-error-order.md#the-arguments-of-range). The list is the one that unbounded
  arithmetic gives, also at the extreme values of `Int`. A non-empty range
  whose start and end lie exactly 2^63 apart aborts on the compiler, a
  compiler bug by a provisional ruling ([D-0008](../conformance/decision-log.md)):
  the model builds the list, which Lean tests pin, since the suite cannot
  record the abort cleanly. A range longer than the fuel, such as
  `range(9223372036854775807)`, runs out of it before the list is built
  (`outOfFuel`); the compiler fails to allocate it, depending on the
  machine's memory, so no suite program holds one, and Lean tests pin the
  model.
- `List[T](capacity=n)` stays a syntax error: the model does not read
  keyword arguments.
- `len` of a list or an array is its length, and of an `Int`, a SIMD
  vector of width 1, is 1, as on the nightly. `len` of a `Bool`, `None` or
  a struct without `Sized`, even one that declares `__len__`, or with a
  wrong number of arguments, is "no matching function in call to 'len'",
  which the suite maps to `noMatchingInit` (#190). The misfit comes after
  an error of typing in an argument and before any read. A string literal
  is outside the subset (#180). A `Sized` struct is still
  `noMatchingInit`, though the compiler accepts it (#230). A literal
  passed to `len` is an `Array[T, n]` of its first element's type `T`,
  to which the others are converted; a misfit, also inside one, is
  `noMatchingInit` before its copies, and an empty first element fits
  none (#341).

## Arrays

Arrays, `Array[T, N]`, hold exactly `N` elements inline. They follow the
rules of lists, with these differences, which the compiler at the pin
shows. The human ruled on 2026-11-16 that the model follows the compiler
here (#27).

- A literal `[e1, …, en]` is an `Array[T, n]`, with `T` the type of `e1`,
  unless a list is expected where it stands. A list is expected by the
  declared type of a variable, the type of a place assigned to, a
  function's result, a parameter, and the element type of an enclosing
  literal or of the list that `append` adds to, and by a list on the left
  of `==` or `!=`. A literal with no type expected and no elements,
  `var xs = []`, is rejected. One with no type expected that is or holds
  an empty literal, passed where no list, array or `Int` is expected,
  does not fit: `typeMismatch` for a parameter, `noMatchingInit` for an
  initializer (#341).
- An array has no methods; two arrays compare
  ([semantics-comparisons.md](semantics-comparisons.md#comparisons-of-arrays-and-lists)).
  `len` and indexing work as on a list. At run time an array is a list
  value whose length is its size `N`.
- An array's size is part of its type, so `[1, 2, 3]` is not an
  `Array[Int, 2]`. The size in a type is an integer literal. A literal of
  another size, or with an element of another type, fits no initializer
  of the list or array it initializes (`noMatchingInit`): declared,
  assigned, returned, inside a literal of an expected type, or passed to
  a construction. Passed to a function or a method, the compiler converts
  it, and reports one that does not fit, even inside it, as a type
  mismatch, as the model does. So is an element of a literal with no
  expected type that differs from the first (#46).
- A literal that initializes a declared variable, a place or a result of
  a type that is neither a list nor an array, a struct or a `Bool`, is
  `noMatchingInit` too, since that type has no initializer from a list
  literal.
- An `Int` has one. Mojo's `Int` is `SIMD[DType.int, 1]`
  (`std/simd.mojo:111` at the nearest public commit of the pinned
  nightly), whose `__list_literal__` initializer (`std/simd.mojo:1066`)
  takes the elements as `Int`s. So a literal `[e]`
  of one `Int` element, where an `Int` is expected, is the value of `e`.
  The human ruled on 2026-11-18 that the model follows the compiler here
  (#103). The probes of that day show where an `Int` is expected: the
  declared type of a variable, the type of a place assigned to, a
  function's result, a parameter of any convention but `mut`, which needs
  a place, an initializer's or a method's parameter, `append` and
  `pop(i)` on a `List[Int]`, an index, and the element type of an
  enclosing literal, so `var xs: List[Int] = [[1], [2]]` is `[1, 2]` and
  `var x: Int = [[1]]` is `1`. An operator other than `and` and `or`
  expects an `Int` of either operand when the other is an `Int`: `x + [2]`
  and `[2] - x` are `Int`s, and `x < [2]`, `[2] < x` and `[1] == x`
  `Bool`s. Mojo 1.2.0 read a literal on the left as an `Int` for the
  arithmetic operators only; the pinned nightly reads `[2] < x` and
  `[1] == x` so too (#160). Where nothing is expected, such as the argument of
  `List[Int](…)`, the operand of `-`, `and` or `or`, or `print`, the
  literal stays an array.
- The compiler reads `[e]` as it reads the operand `e`: a place in it is
  read once every operand of the operation is evaluated, so
  `[x] + bump(x)`, with `bump` changing `x`, reads the changed `x`, a
  later operand that moves or invalidates the place is rejected, and a
  value whose last use is the place is destroyed after the other
  operands. Inference therefore puts `e` in the literal's stead. Passed
  `mut` or `ref`, the literal is a temporary instead: `bump([x])` and
  `bump([pick(x)])`, with `bump` taking `mut`, are rejected, and passed
  `ref`, the temporary is filled from `e` when the call is made, after
  its other arguments, so `both([x], bump(x))` sees the changed `x`, but
  a reference that `pick([x])` returns does not see a later change. A literal returned by a
  function that returns a reference is no place either. A literal
  made only of literals and operators stays, typed `Int`: the compiler
  does not compute an index that holds one when it compiles the program,
  so `xs[[-1]]` and `arr[[2]]` fail only at run time.
- An element that is not an `Int`, `[True]`, fits no initializer of `Int`
  (`noMatchingInit`), and passed to a function, or as the right operand of
  an operator other than `and` and `or`, it is a type mismatch, but for
  an integer literal's operator, whose overloads none fits
  (`noMatchingMethod`, #88). As the
  left operand of an arithmetic operator, `[True] + x`, or an operand of
  `and` and `or`, `x or [True]`, the compiler reports that the array has
  no `__add__` or `__bool__`, `missingMethod` (#176).
- A literal of any length but 1 where an `Int` is expected fits no
  initializer of `Int` either, and the model rejects it in every position
  (#153, #154). So does the pinned nightly, but for operands that it never
  instantiates: the right operand of `or` after a variable that holds
  `True`, dropped at `-O1` and above, a compiler bug (D-0014), and the
  neighbours that #346 asks about. Inference types it `Int`, and
  each of its elements, as SIMD's initializer takes them. The checker
  types each element without reading it, as the compiler does, and the
  first that is no `Int`, nor such a literal of `Int`s, is a misfit,
  before any element is read: `var z: Int; var y: Int = [z + 1, True]` is
  `noMatchingInit`. A literal with no misfit has its elements read, then the
  compiler fails SIMD's constraint "expected 1 elements in the SIMD list
  literal, found N" (`noMatchingInit`), so `var z: Int; print(rd([z, 2]))`
  is `uninitializedUse`. A misfit is reported by the position:

  | Position | No misfit, `[1, 2]`, `[]`, `[[1], [2]]`, `[x, x]` | Misfit, `[1, True]`, `[[1], True]`, `[True, False]` |
  | --- | --- | --- |
  | Initializes the `Int`: a declaration, an assignment to a variable, a field or an element, a `return`, a construction `P(…)`, an element of an enclosing literal | `noMatchingInit` | `noMatchingInit`: "no matching function in initialization" |
  | Converted: an argument of a function or a method, `append`, an operand of an operator other than `and` and `or` whose left operand is no integer literal, `+=` | `noMatchingInit` | `typeMismatch`: "cannot be converted from list literal to 'Int'" |
  | An index of a list or an array, the argument of `pop`, the right operand of an integer literal's operator | `noMatchingInit` | `noMatchingMethod`: "no matching method in call to '__getitem__'", as for `xs[True]` (#169) |

  A nested literal counts as one element: `rd([[1, True], 3])` is a type
  mismatch, `P([[1, True], 3])` and `[[1, True]]` in a declaration are
  `noMatchingInit`, and `rd([[1, 2], 3])` and `rd([[], 3])` are
  `noMatchingInit`. Mojo 1.2.0 accepted every literal of `Int`s of such a
  length, a compiler bug by a provisional ruling (#122,
  [D-0005](../conformance/decision-log.md)), which the nightly fixes. The
  nightly reports the failed constraint after every other error of the
  program, even one in a later function. The model reports it after every
  type error and every flow error, in the instantiation phase's order
  ([semantics-error-order.md](semantics-error-order.md#the-order-of-the-instantiation-phase), #170). Passed `mut`, any literal is a temporary, which the compiler
  reports as a value that may not change, `immutablePlace` (#81).
- A constant index into an array of `N` elements is rejected when it is `N`
  or more (`constantIndexOutOfBounds`); one known only at run time fails
  then, as on a list. A constant index into a list fails only at run time.
- A struct may not hold an array of itself: the compiler rejects it, and
  so does the model (`recursiveStruct`). A struct may hold a list of
  itself, which the compiler rejects in some cases, depending on
  `__deinit__`, a compiler bug (D-0006, #136). The rule for cycles through
  several structs is in [semantics.md](semantics.md#the-static-checker).

Rejected: keeping every literal a `List`, which would accept programs that
the compiler rejects, such as `append` to an unannotated literal.
