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
- `-a` calls `__neg__`, and `not a` negates what `__bool__` gives.
  `a and b` and `a or b` convert each struct operand with its
  `__bool__`, unless both operands have the same struct type: then they
  give the operand that decides, tested by reference. A place that
  decides is copied, so a place of a struct that is not
  `ImplicitlyCopyable` is `implicitCopy`; a temporary is moved, so a
  `Movable` struct is accepted: a temporary left operand is moved out
  when it decides, and destroyed when the right one does. The right operand is evaluated only when the left
  one does not decide. What the left operand last uses dies once it is
  tested, before the right one runs; when the left one decides, what the
  right one would have used dies first. `Bool` operands follow the same
  order, as the pin does: the human ruled on 2026-11-20 to keep this
  order in #191.
- The test of the left operand, when both have the same struct type, is
  checked as the call of `__bool__` that the other operands get: what
  `__bool__` returns must be a `Bool`, which the compiler converts with
  `__mlir_bool__`, or the operator is `missingMethod`; a `mut self` takes
  only a place that may change (`immutablePlace`) and no temporary
  (`notAPlace`, #81).
- A `var self` `__bool__` gets a copy of the left operand of `and` or
  `or`, on either path, even of a temporary or `p^`, since the left
  operand may be the result: a struct that is not `ImplicitlyCopyable`
  is `implicitCopy`. The model and the pin differ on `p^` there: the
  model moves the value out of `p`, so a later use of `p` is
  `uninitializedUse`, while the pin, on the left of a mixed `and` or
  `or`, only borrows `p^`, with no warning, and leaves `p` initialized
  (`print(a^ or False); print(a.n)` runs). That is the bare `p^` in a
  borrowing position of #84. A temporary converted by `__bool__` dies once it is
  copied, before `__bool__` runs (`mk(2) and True` prints `del 2`, `bool
  2`, `del 2`); one that the operator may give, of the same struct type
  on both sides, lives until the test is done. The right operand and
  `not e` move a temporary into `self`, as a call does.
- The value that an assignment to a whole variable that the function
  owns, a local or a `var` parameter, replaces is not live after the
  assigned expression, whether or not the variable is used later
  (#99): in `o = O(wrap(rd(o)))`, the old `o` dies once `rd` returns,
  in `o = O(o.f or pb(p.f))` once `o.f` is tested, and in `a = a or b`,
  with `b` deciding, once `a` is, as the pin does at both levels. A
  `mut` parameter or `mut self` still loses its old value only when the
  store replaces it, where the pin destroys it at its last use too
  (#251). When the value is the target itself, as in `o = o`, or the
  operand of `and` or `or` that decides, as in `b = a and b` or
  `a = a and b` with a false `a`, the pin destroys the old value before
  it copies it, and its default level and `-O0` print different values:
  a compiler bug (#248, [D-0012](../conformance/decision-log-d0012.md),
  provisional). The model copies the value, then destroys the old one,
  as the pin does for any other target; `known.json` lists the six
  `structs/assign_target_*` programs.
- An operator method that inference calls must take as many operands,
  `self` among them, as its operator: two for a binary, reflected or
  in-place operator and one for `__neg__` and `__bool__`. The compiler
  rejects such a declaration when it parses it ("'__add__' requires 2
  operands"), used or
  not; the model rejects it as `arityMismatch`, the class the human
  ruled for that message (#214). The suite's
  `rejected/operator_method_bool_extra_param*` and
  `rejected/operator_method_add_one_operand` programs pin it. The other
  operator methods that the compiler checks
  in the same way, such as `__truediv__`, are not yet checked.
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
- A literal on either side of an array is an array, unless the other
  operand is an `Int` (see [semantics-lists.md](semantics-lists.md#arrays)).
  A literal on the right of a list is the argument of the list's `__eq__`
  or `__ne__`, converted to the list's type as a call's argument is:
  `xs == [1, 2]`, `xss == [[1], []]` and, with `xs` a list of `Int`s,
  `xs == [[1]]` run; an element of another type, `xs == [True]`, is a
  type mismatch, and an inner literal of another length where an `Int`
  is expected, `xs == [[1, 2]]`, fits no initializer of `Int`
  (`noMatchingInit`), as in a call.
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
- The checker finds both errors from the operands' types, once they are
  typed and before either is read: a mismatch first, then a constraint.
  So `var a: Array[Int, 1]` compared with `[1, 2]`, or an uninitialized
  list compared with an array, is a mismatch, not a use of an
  uninitialized value.

Two `Bool`s also compare with `<`, `<=`, `>` and `>=`, `False` first, as
`Int`s do (#185). A `Bool` compared with an `Int` is a type mismatch,
and `1 < True` fits none of the literal's overloads.

Not yet modelled. Each stays rejected, with a class that is still not
the compiler's; where #185 changed the class, the bullet says so:

- A literal compared with an operand whose type its form does not show
  to be the same, and that the compiler converts to that operand's type:
  one on the left of a list, `[1] == xs`, which the compiler converts to
  a list, and one that holds a literal beside an array, `a == [[1], [2]]`,
  `a == [[1], 2]` or `[[1]] == a`, with `a` an array of `Int`s, which run,
  each `[1]` initializing an `Int`, where `a == [[]]` and
  `a == [[1, 2]]` are type mismatches. The model still copies a named
  operand (`implicitCopy`), and otherwise gives `typeMismatch` or
  `invalidType`. Part 2 of #166 covers them (`convertsLiteral`).
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
- The literal on the right of a list is checked as a call checks its
  argument, with that check's gaps: on the right of an uninitialized
  list, an element that does not fit comes after the uninitialized use
  (#96), and an inner literal that initializes a `Bool`,
  `bs == [[True]]`, is a type mismatch, where the compiler finds no
  initializer (`noMatchingInit`, #165).

## What is not yet modelled

Each of these keeps the result the model gave before #191:

- A subscript of a struct that declares `__getitem__` or `__setitem__`,
  read or assigned, which the model rejects as `notAList`. A later part of #191 models reading and assigning it; a
  subscript used as a place beyond that, such as `p[i] op= e` or passing
  it `mut`, stays with #198.
- The methods that `Equatable` and `Comparable` supply by default (#194),
  an `if` or
  `while` condition of struct type (#195), and a call of a field (#196).
- `not` on an `Int` that `__bool__` gives, and `and` or `or` on an `Int`
  operand beside a struct, which the compiler accepts (#179, #187).
- The order of the compiler's passes across a call: an uninitialized
  receiver comes before an argument's type error in the model (#96), and
  a temporary receiver passed to `mut self` is `notAPlace` (#81).
- The order in which a call's temporaries are destroyed (#199), an
  in-place method whose result is not `None` (#200), a missing argument
  reported before a misfit of the others (#201), and the destination of
  `p op= e` on a type that is not a struct, which the model checks after
  `e` (#204).
