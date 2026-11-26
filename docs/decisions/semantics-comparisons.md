# Current decisions: semantics, comparisons of arrays and lists

This page continues [semantics.md](semantics.md) and
[semantics-operators.md](semantics-operators.md) with what a comparison
means when it compares two arrays, two lists or two `Bool`s.

## Comparisons of arrays and lists

Two arrays of the same type compare with `<`, `<=`, `>`, `>=`, `==` and
`!=` when their element type does, and two lists of the same type with
`==` and `!=`, as the pinned nightly does. The human ruled on 2026-11-20
that the model follows the compiler fully (#166, option a); #185 extends
it to lists. Part 1 of #166 and #185 model the element types `Int`,
`Bool`, and arrays and lists of them (`MojoGrimoire.Check.Compare`):

- The order is lexicographic, element by element, with `False` before
  `True`, and recursive through nested arrays and lists: `[1, 9] < [2, 0]`
  and `[[1]] < [[2]]` are `True`, and two lists are equal when they have
  the same length and equal elements. The methods compare elements with
  their own `__lt__` and `__eq__`; for these types only the result shows.
- Both operands are passed by reference: a named array or list, an
  element or a field is read, not copied, and so is a call that returns a
  reference, also one whose origin is a temporary. A place is read once
  both operands are evaluated, as any operand, so `a == bump(a)` sees what
  `bump` changed. A value whose last use is the comparison is destroyed
  once it is done, as for a `read` argument.
- A literal compared with an array or a list is converted to the other
  operand's type, element by element, as a call converts its argument
  (part 2 of #166, `literalFits`): an array of `n` elements takes `n`
  that each fit its element type, a list any number, and an `Int`, a
  literal of `Int`s, as `var x: Int = [1]` does. An element that is an
  operator or a call fits by the result of the method it calls, also a
  struct's `__add__`, `__lt__` or `__call__`, and `List[u]()` fits only
  its own type. A literal on the right
  takes the left operand's type. One on the left takes the right
  operand's, unless that is a literal too, or a comparison that does not
  conform, such as an array of lists ordered: then it keeps its own type,
  an array of its first element's type. With `a = [1, 2]` and `xs` a list
  of `Int`s, `a == [[1], [2]]`, `a == [[1], 2]`, `[[1], [2]] == a`,
  `[1, 2] == a`, `[1, 2] == [[1], [2]]`, `[[1]] == [[[1]]]`, `[1] == xs`,
  `[] == xs`, `xs == [1, 2]` and `xs == [[1]]` run. A list has no `<`, so
  a literal compared with it by `<` keeps its own type. The literal on
  the right is checked as the method's argument (`rightParam`); one that
  does not fit is a type mismatch, found before the operands are read:
  `a == [[]]`, `[[1]] == [1]`, `xs == [True]`, `a == [p + p, 2]` with
  `p + p` a struct. A literal on the left that keeps its own type, as it
  does not fit or the comparison converts none, makes the right operand,
  which fits it no better, a type mismatch: `[1, 2, 3] == a`,
  `[True] == xs`, `[ys^] == xs`, and `[[1]] < v` with `v` an array of
  lists. An inner literal of another
  length where an `Int` is expected on the right, `a == [[1, 2], 3]`, fits
  no initializer of `Int` (`noMatchingInit`), but only once `a` is read,
  as in a call: beside an uninitialized `a` it is `uninitializedUse`.
  Otherwise a literal is an array, unless the other operand is an `Int`
  (see [semantics-lists.md](semantics-lists.md#arrays)).
- An operand of another type, an array or a list of another length or
  element type, an `Int`, a `Bool` or, beside an array, a list, is the
  compiler's "cannot be converted", `typeMismatch`. So are an `Int` or a
  `Bool` compared with an array or a list, and `[1] == []`. An integer
  literal compared with either, `1 == a`, fits none of the literal's
  overloads (`noMatchingMethod`).
- An element type that does not conform to `Equatable`, or to
  `Comparable` to order the arrays, is the compiler's "invalid call to
  '__eq__': violated constraint", `violatedConstraint`
  ([conformance-classes.md](conformance-classes.md#violated-constraints)):
  `None` for every operator, and a list to order them. A list has no
  order of its own: `xs < ys` is `missingMethod`.
- The pin's optimized build compares two one-element arrays as equal
  when a struct's `__deinit__` prints, where `-O0` compares the elements.
  The human ruled this a compiler bug on 2026-11-21 (#235,
  [D-0010](../conformance/decision-log.md)); the model compares the
  elements. Two lists in that position compare their elements at every
  optimization level.
- At `-O3`, the default, the pin also compares arrays of arrays of
  one-element arrays wrongly when two comparisons of them are printed
  together: `[[[1]]] > [[[0]]]` is `False` beside `==`, with no destructor
  involved. The human ruled this a compiler bug on 2026-11-21 (#257,
  [D-0013](../conformance/decision-log.md)); the model compares the
  elements, as `-O0` to `-O2` do.
- The checker finds both errors from the operands' types, once they are
  typed and before either is read: a mismatch first, then a constraint.
  So `var a: Array[Int, 1]` compared with `[1, 2]`, or an uninitialized
  list compared with an array, is a mismatch, not a use of an
  uninitialized value.

Two `Bool`s also compare with `<`, `<=`, `>` and `>=`, `False` first, as
`Int`s do (#185). A `Bool` compared with an `Int` is a type mismatch,
and `1 < True` fits none of the literal's overloads. A `Bool` compared
with an empty literal, `t == []` or `True < []`, is the compiler's
"cannot be converted from list literal to 'Bool'", `typeMismatch`,
found before the operands are read, so also beside an uninitialized
`t` (#286), in the type phase (`boolLiteralMisfit`). An empty literal on
the left, `[] == t`, stays `invalidType`, as on the compiler.

Part 2 of #166 changed the class of some comparisons that `main`
rejected otherwise. #260 bridged each statement and condition to
`main`'s result until part 4 of #96 typed every function before it
checked its flow, as the compiler does; part 4 removed that bridge (#281).
So `a == [[1, 2]]` with `a = [1]` is `noMatchingInit`, `[1] < xs` is
`typeMismatch`, and `[w[0][0]] == w[0]`, with `w: Array[List[Int], 1]`,
is `invalidatedReference`: the subscript `w[0]` invalidates the element
that the literal reads late (#282,
[semantics-references.md](semantics-references.md#references)), as the
compiler says.

A literal that holds a place whose value is not implicitly copyable is
ordered by its conversion to the other operand's type (#338). On the
left, beside a right operand that is no literal, one that fits is
converted, and its copy comes as its elements are built:
`[y, [x]] != rl`, with `y: List[Int]` and `rl: List[List[Int]]`, is
`implicitCopy`, as the compiler says. One that is not converted, or does
not fit, or that is compared with another literal, is built on its own
first, so that `[y] > al` and `[y] == t` are `implicitCopy` before the
misfit (`heldLeft`). Either way the operands' own expressions are typed
first, so that `[y] == -t` is `missingMethod`. On the right, beside a left operand that holds no
such place, one that does not fit is a type mismatch before its
elements are built: `rl == [y, [t]]` and `[[1]] >= [y]` are
`typeMismatch`.

Not yet modelled. Each stays rejected, with a class that is still not
the compiler's; where #185 changed the class, the bullet says so:

- The rest of the comparisons with a literal that holds a place whose
  value is not implicitly copyable keep every check they had before
  #166 (`keepsBefore`), and wait for #338: a literal on the right that
  fits an array whose comparison does not conform, `al < [y, [x]]`,
  is `implicitCopy` where the compiler reports `violatedConstraint`
  first, and one compared with an `Int` or a `Bool`, `x == [[y]]` or
  `[y, y] == x`, whose conversion waits for #165 and #170, keeps its
  class too. So does a comparison with `List[u]()`, which is no literal
  the compiler converts: `List[Int]() < a` is `missingMethod`, as it
  says, but beside such a literal the compiler converts the literal to
  its type, so `[y, [x]] == List[List[Int]]()` is `typeMismatch` where it
  reports `implicitCopy`, and `List[List[Int]]() == [y, [t]]` is
  `implicitCopy` where it reports `typeMismatch`.
- A literal on the left that holds an inner literal of another length
  where an `Int` is expected, `[[1, 2], 3] == a`. The compiler converts
  it, fails SIMD's constraint (`noMatchingInit`) in a later pass than its
  reads, and reports an uninitialized read in either operand first. That
  order is #338's; until then the literal is not converted and keeps the
  checks it had before #166: the right operand is copied, so a named one
  is `implicitCopy`, and an uninitialized read is `uninitializedUse`, as
  the compiler says.
- A transfer in a loop's condition, `while a^ < [1, 3] and t:`, which the
  compiler borrows and the model moves: the second check of the condition
  is stuck at run time (#84). `while ab^ < [True, True] and t:`, with
  `ab` an array of `Bool`s, takes that form with part 2. So does a
  transferred operand read later: `print([[1], [2]] == a^)` then
  `print(a[0])` runs on the compiler, which borrows `a`, and is
  `uninitializedUse` with part 2, where `main` gave `typeMismatch` (#84).
- A literal on the left with no type of its own that does not fit the
  right operand, or that the comparison does not convert, `[[]] == a`,
  `[[]] < v` or `[] == []`, which the compiler cannot type ("cannot emit an empty list without a contextual type", a message
  no pattern classifies); the model keeps its result, `invalidType`.
- An element type that holds a struct. The compiler requires the
  struct's conformance to `Equatable` or `Comparable`, not the methods it
  declares, and calls the struct's `__eq__` and `__lt__` element by
  element. Conformances come with #194; part 3 of #166 follows it, for
  arrays and lists. A list of structs compared with an empty literal,
  `List[P]() == []` or `!= []`, went from `invalidType` to
  `typeMismatch` with #185, since the literal now takes the list's type;
  the compiler gives `violatedConstraint` for a struct without the
  conformance.
- A list of `None`, `List[NoneType]`, and `xs == None`, which need `None`
  as a type and an expression (#183). `xs == None` and `xs != None` went
  from `implicitCopy` to `unknownVariable` with #185, since `xs` is now
  read uncopied and the model has no `None` expression; the compiler
  gives `typeMismatch`.
- An inner literal that initializes a `Bool`, `bs == [[True]]`,
  `a == [[True]]` or `[[True]] == a`, with `a` an array of `Bool`s,
  where the compiler finds no initializer (`noMatchingInit`, #165). `literalFits` leaves its fit
  unknown, so the comparison keeps the checks it had before part 2: a
  type mismatch beside a list on the left, and `implicitCopy` of a named
  array, or of a list on the right. A `Bool` operand compared with a
  literal, `t == [1]` or `bs[-1] >= [[3]]`, and a literal passed to a
  struct's `__eq__` that takes a `Bool`, are `noMatchingInit` for the
  compiler too, and `typeMismatch` in the model (#165), also
  `bs[-1] >= [[3]]`, whose negative index the flow phase finds after it
  (#96).
