# Current decisions: semantics, operators and calls on structs

This page continues [semantics.md](semantics.md) with what an operator or
a call means when its operand is a struct of the program, and when it
compares two arrays, two lists or two `Bool`s.

## Methods that a struct declares

An operator or a call on a struct value calls the method that the struct
declares itself, with the operand read by reference, as the pinned nightly
1.3.0.dev2026111905 does. The human ruled this on 2026-11-20 (#191,
option A). Inference (`MojoGrimoire.Parse.Dispatch`) makes such an
operator a call of the method as a function, `S.m(r, …)`, with the
receiver first, which the checker, elaboration and the interpreter treat
as any other call: `t + 1` on a `Movable` struct copies nothing and
leaves `t` usable, a method whose `self` is `mut` needs a receiver that
may change, `var self` copies a place implicitly, and a temporary
receiver, such as `T(5) + 1` or `-(-t)`, is destroyed right after the
call. The operator's result has the method's declared type, whatever it
is: `t < u` may give an `Int`.

- A binary operator `a op b` calls the method of `a`'s struct that `op`
  names (`__add__`, `__sub__`, `__mul__`, `__floordiv__`, `__mod__`,
  `__lt__`, `__le__`, `__gt__`, `__ge__`, `__eq__`, `__ne__`) when `b`
  fits its parameter. Otherwise it calls the reflected method of `b`'s
  struct when `a` fits it. A method fits only when its operands can also
  be passed with their conventions: a `mut` parameter, `self` among them,
  takes only a place that may change, or a call that returns a reference
  it may change through, so `1 + t` on a read-only or temporary `t` whose
  `__radd__` takes `mut self` is the left operand's `noMatchingMethod`. A
  `ref` binding may change what it points to as the reference it is bound
  to may, also when that is the result of an operator or of `__call__`,
  which returns a reference through a `mut` parameter. A list literal
  operand is passed to the method as a call passes it: to a `mut` or
  `ref` parameter as a temporary, never as the place it holds. The reflected methods are `__radd__`, `__rsub__`, `__rmul__`,
  `__rfloordiv__` and `__rmod__` for arithmetic; `__gt__`, `__ge__`,
  `__lt__` and `__le__` for `<`, `<=`, `>` and `>=`; and `__eq__` and
  `__ne__` for themselves. The reflected method is tried whatever `a` is: an `Int`, a
  `Bool`, a list, a struct of another type or of the same type, one that
  lacks the method or one whose method does not fit. The operands are
  still evaluated left to right: `pr(1) + mk(2)` prints `pr` first.
- When neither method fits, the left one is called and the checker
  reports its misfit, such as `t + True` (`typeMismatch`). With no left
  method, the operator stays as it is, and the checker reports what the
  left type lacks (`missingMethod`) or the misfit of its built-in operator
  (`1 + t` is `noMatchingMethod`). `!=` never falls back to `__eq__`, nor
  any operator to another of the left operand's methods.
- `-a` calls `__neg__`.
- An operator method that inference calls must take as many operands,
  `self` among them, as its operator: two for a binary, reflected or
  in-place operator and one for `__neg__`. The compiler rejects such a
  declaration when it parses it ("'__add__' requires 2 operands"), used or
  not; the model rejects it as `arityMismatch`. Which class this message
  maps to is not yet settled, so no pattern matches it and no suite
  program pins it. The other operator methods that the compiler checks
  in the same way, such as `__truediv__` or `__bool__`, are not yet
  checked.
- `p += e`, `p -= e` and `p *= e` on a struct call `__iadd__`, `__isub__`
  and `__imul__`, with no fallback to `__add__`: a struct that lacks the
  method is `missingMethod`. The destination must be a place that may
  change, whatever the convention of the method's `self`
  (`immutablePlace`), which the compiler checks once it has typed the
  destination's indices, before it looks the method up or checks `e`. On any other type, `p op= e` is `p = p op e`,
  with no reflected method.
- A call `f(…)` of a variable or a parameter `f` whose struct declares
  `__call__` calls it. The variable hides a function, `len`, `range`,
  `print` or a struct of its name, also as `print(…)` on a line of its
  own; a variable whose type lacks `__call__` is `missingMethod`, as
  [semantics.md](semantics.md#the-static-checker) says.
- Inside a struct's methods, `Self` is the struct, in the types of
  parameters, results, variables and list literals, and `Self(…)` builds
  it. As the type of a field, or outside a struct, it is left as the name
  of a struct that no program declares (#203).

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
and `1 < True` fits none of the literal's overloads.

Within one statement, the model keeps `main`'s result wherever `main`
agreed with the compiler, until #96 part 4 orders the model's errors as
the compiler does (`Check.Block.bridged`). A statement, or a condition,
that the checker rejects is checked again. A probe lets the error of each
comparison with a literal operand pass, and numbers the comparisons. When
it finds no other error and lets exactly one comparison's error pass, and
the same probe of the statement as `main` checked it finds no other error
either and lets no error of the same class pass at the same comparison,
that error stands: it is the statement's only one, and #166 changed it.
It stands too when `main`'s first error is of its class at the same
comparison. Otherwise the statement is
checked as `main` did, from the same state, with the body that `main`'s
inference gave, and `main`'s error is reported. No class of error stands
over `main`'s by its kind. So `print([x] != [[1]], [[1], y] >= rl)`
stays `typeMismatch`, `print([y^] != rl, [y, [x]] != rl)` stays
`implicitCopy`, and `print(a == [[1], [2]], [a] == n)` stays
`implicitCopy`, as `main` and the compiler say. A program of several
statements is not bridged across statements; process.md's exceptions
cover those.

Not yet modelled. Each stays rejected, with a class that is still not
the compiler's; where #185 changed the class, the bullet says so:

- A comparison of which either operand is a literal that holds a place
  whose value is not implicitly copyable, at any depth, such as `ys` or
  `a` in `[ys] == xs`, `[[ys]] == 1`, `[a] == [[1], [2]]` or
  `xs == [ys]`. The compiler builds the literal, and copies the place,
  in an order against the literal's conversion and the misfit that
  waits for #96. The comparison keeps every check it had before #166
  (`keepsBefore`): most are `implicitCopy`, as the compiler says, but
  `xs == [ys]`, a type mismatch for the compiler, is `implicitCopy` too.
  So does a comparison with `List[u]()`, which is no literal the
  compiler converts: `List[Int]() < a` is `missingMethod`, as it says.
- A literal on the left that holds an inner literal of another length
  where an `Int` is expected, `[[1, 2], 3] == a`. The compiler converts
  it, fails SIMD's constraint (`noMatchingInit`) in a later pass than its
  reads, and reports an uninitialized read in either operand first. That
  order is #96's; until then the literal is not converted and keeps the
  checks it had before #166: the right operand is copied, so a named one
  is `implicitCopy`, and an uninitialized read is `uninitializedUse`, as
  the compiler says.
- A literal on the right that holds an inner literal of another length
  where an `Int` is expected, beside another error of the statement:
  `v >= [[[3, 0]]]` with `v: Array[List[Int], 1]`, or `a == [[1, 2], ux]`
  with `ux` an uninitialized `Int`. The compiler fails SIMD's constraint
  (`noMatchingInit`) as it instantiates, after every other pass, and
  reports the comparison's `violatedConstraint` or the uninitialized read
  first. The model rejects the literal at once; deferring it is #170.
  These went from `implicitCopy`, the copy of the named operand, to
  `noMatchingInit` with part 2 of #166.
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
  compiler too, and `typeMismatch` in the model (#165). The model now
  reports that mismatch before it reads the `Bool`, so `bs[-1] >= [[3]]`
  went from `negativeIndex` to `typeMismatch` with part 2 of #166.

## What is not yet modelled

Each of these keeps the result the model gave before #191:

- `not`, `and` and `or` on a struct operand, which do not yet call its
  `__bool__`, and the order in which `and` and `or` destroy what their
  `Bool` operands last use. A later part of #191 models them.
- A subscript of a struct that declares `__getitem__` or `__setitem__`,
  read or assigned, which the model rejects as `notAList`. A later part of #191 models reading and assigning it; a
  subscript used as a place beyond that, such as `p[i] op= e` or passing
  it `mut`, stays with #198.
- The methods that `Equatable` and `Comparable` supply by default (#194),
  an `if` or
  `while` condition of struct type (#195), and a call of a field (#196).
- `not` and `and` on an `Int` that `__bool__` gives, or on an `Int`
  operand beside a struct, which the compiler accepts (#179, #187).
- The order of the compiler's passes across a call: an uninitialized
  receiver comes before an argument's type error in the model (#96), and
  a temporary receiver passed to `mut self` is `notAPlace` (#81).
- The order in which a call's temporaries are destroyed (#199), an
  in-place method whose result is not `None` (#200), a missing argument
  reported before a misfit of the others (#201), and the destination of
  `p op= e` on a type that is not a struct, which the model checks after
  `e` (#204).
