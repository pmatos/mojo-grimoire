# Current decisions: semantics, lists and arrays

This page continues [semantics.md](semantics.md) with the choices for
lists and arrays.

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
  argument in the subset, an empty literal and a string among them, fits
  no initializer either (`noMatchingInit`). The compiler also accepts
  other iterables, such as `range(n)`, which are outside the subset until
  #121 is ruled. The compiler
  reports a `List[T]` source whose elements cannot be copied as "cannot
  construct 'List[T]' with itself", which the suite also maps to
  `noMatchingInit`
  ([conformance.md](conformance.md#initializations-that-fit-no-initializer)).
- `List[T](capacity=n)` stays a syntax error: the model does not read
  keyword arguments.

## Arrays

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
- An `Int` has one. Mojo 1.2.0's `Int` is `SIMD[DType.int, 1]`
  (`std/simd.mojo:120`), whose `__list_literal__` initializer
  (`std/simd.mojo:941`) takes the elements as `Int`s. So a literal `[e]`
  of one `Int` element, where an `Int` is expected, is the value of `e`.
  The human ruled on 2026-11-18 that the model follows the compiler here
  (#103). The probes of that day show where an `Int` is expected: the
  declared type of a variable, the type of a place assigned to, a
  function's result, a parameter of any convention but `mut`, which needs
  a place, an initializer's or a method's parameter, `append` and
  `pop(i)` on a `List[Int]`, an index, and the element type of an
  enclosing literal, so `var xs: List[Int] = [[1], [2]]` is `[1, 2]` and
  `var x: Int = [[1]]` is `1`. An operator other than `and` and `or` on
  an `Int` expects one as its right operand, and an arithmetic operator,
  through the `__radd__` family, as its left: `x + [2]` and `[2] - x` are
  `Int`s, and `x < [2]` a `Bool`, but `[2] < x` and `[1] == x` compare an
  array with an `Int`, a type mismatch, since `Array` has the comparison
  methods. Where nothing is expected, such as the argument of
  `List[Int](…)`, the operand of `-`, `and` or `or`, or `print`, the
  literal stays an array.
- The compiler reads `[e]` as it reads the operand `e`: a place in it is
  read once every operand of the operation is evaluated, so
  `[x] + bump(x)`, with `bump` changing `x`, reads the changed `x`, a
  later operand that moves or invalidates the place is rejected, and a
  value whose last use is the place is destroyed after the other
  operands. Inference therefore puts `e` in the literal's stead. Passed
  `mut` or `ref`, a literal of a place is a temporary instead: `bump([x])`,
  with `bump` taking `mut`, is rejected, and passed `ref`, the temporary
  is filled from the place when the call is made, after its other
  arguments, so `both([x], bump(x))` sees the changed `x`, but a
  reference that `pick([x])` returns does not see a later change. A literal returned by a
  function that returns a reference is no place either. A literal
  made only of literals and operators stays, typed `Int`: the compiler
  does not compute an index that holds one when it compiles the program,
  so `xs[[-1]]` and `arr[[2]]` fail only at run time.
- An element that is not an `Int`, `[True]`, fits no initializer of `Int`
  (`noMatchingInit`), and passed to a function, or as the right operand of
  an operator other than `and` and `or`, it is a type mismatch. As the
  left operand of an arithmetic operator, `[True] + x`, or an operand of
  `and` and `or`, `x or [True]`, the compiler reports that the array has
  no `__add__` or `__bool__`, a message the suite does not classify. A literal of another length is accepted by a default
  build, which keeps its first element, and `[]` crashes; the model keeps
  rejecting both, as above, until #122 is ruled.
- A constant index into an array of `N` elements is rejected when it is `N`
  or more (`constantIndexOutOfBounds`); one known only at run time fails
  then, as on a list. A constant index into a list fails only at run time.
- A struct may not hold an array, or a list, of itself: the compiler
  rejects both, and so does the model (`recursiveStruct`). The rule for
  cycles through several structs is in
  [semantics.md](semantics.md#the-static-checker).

Rejected: keeping every literal a `List`, which would accept programs that
the compiler rejects, such as `append` to an unannotated literal.
