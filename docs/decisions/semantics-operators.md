# Current decisions: semantics, operators and calls on structs

This page continues [semantics.md](semantics.md) with what an operator, a
subscript or a call means when its operand is a struct of the program.
[semantics-comparisons.md](semantics-comparisons.md) says what it means
when it compares two arrays, two lists or two `Bool`s.

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
  only a place that may change, and a place that may not or a temporary
  is `immutablePlace`, as the compiler reports both (#81).
- The compiler converts the left operand of `and` or `or` before it
  looks at the right one (#357), and so does the model. After the left
  operand's own errors, its conversion comes first: a type that lacks
  `__bool__` (`missingMethod`), then the call of `__bool__`, its
  receiver's mutability or its `var self` copy, then a result that is no
  `Bool`, a struct included: with `B.__bool__(var self) -> W`, `B(1) or c`
  is the copy's `implicitCopy`. Only then come the right operand's errors, an unknown name
  included, and its own conversion: `v and a`, with `V` lacking
  `__bool__` and `a` a `read` operand of a `mut self` `__bool__`, is
  `missingMethod`. When both operands have the same struct type, the left
  one is copied after the right one's own errors, `t0 or T(zz)` is
  `unknownVariable`, unless its `__bool__` takes a `var` or `deinit`
  `self`, whose copy comes first. The model still rejects a `deinit
  self` that the pin takes as a `var self` (#361), and on a same-type
  test only after the right operand's errors. The suite's
  `order/logic_left_*` programs hold these orders, recorded from the pin.
- When both operands have the same struct type, the copy of the left
  operand into the result comes after both operands' own errors and the
  left operand's test, unless a `var` or `deinit` `self` takes it first
  (#362, `order/logic_own_*`). With `pz(x: T)`, `pz(t1 or t2)` is
  `missingMethod` when `__bool__` returns an `Int`; with a `mut self`
  `__bool__` it is `immutablePlace` when `t1` is a `read` parameter, and
  `implicitCopy` when `t1` is a variable, whose test passes, for a `T`
  that is not `ImplicitlyCopyable`. A transfer on the right comes first
  too: `pz(hl[0].t or t2^)`, with `t2` a `read` parameter, is
  `transferFromBorrowed`, and `eatT(rr^)` of a `ref` binding `rr` on the
  right is `transferFromElement`. A misfit inside the left operand comes
  before every copy: `pz(idT(lT[0] or bv) or t1)` is `typeMismatch`. The
  pin keeps this order in a subscript's index too, and so does the
  model, but for the copy that a `var` or `deinit` `self` takes: in an
  index the model still reports that copy after the other errors, until
  #356. With `T(Copyable)` and `__bool__(var self) -> Int`,
  `lT[pz((t1 and t2))].n` is `implicitCopy` on the pin and
  `missingMethod` in the model. A call that returns a reference into a
  temporary origin argument is passed by reference, as the pin passes
  `pz(same(T(1)))` and `same(same(T(1)))` (#80), so
  `pz(same(same(T(1))) or t2)` is the `mut self` receiver,
  `immutablePlace`, on both.
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
- Part 4c of #96 removed the bridge that kept `main`'s results for these
  tests. The type phase reports a statement's type error first, and a
  statement with none gives its flow error: `b = (x^ or y) and x.f` with
  `b` a `Bool` is `uninitializedUse`, `print(y or x, k)` is
  `notPrintable`, and `(y or S(xs[1 - 2], True)) + y` is `negativeIndex`,
  as the compiler reports them. The own expressions of a call's
  arguments, and of `print`'s, are typed before a misfit or an argument
  that cannot be printed, but a literal argument is not built before it
  (#89, #96 parts 9 and 4c): `f2(not m, m or m2)`, with `m` `Movable`, is
  `implicitCopy`, and `print(y or w, bi(w))`, with `T` not `Writable`,
  is `bi(w)`'s misfit, as the compiler reports them.
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
  provisional). The model copies the value, then destroys the old one.
  As the pin does for any other target, the old value dies at its last
  use: for a fresh target that comes before the expression, and when the
  target is an operand, it comes inside the expression, at the copy when
  the target decides, so the old value dies after it.
  `known.json` lists the six `structs/assign_target_*` programs.
- A subscript `p[i]` read as a value calls `__getitem__`. When the struct
  also declares `__setitem__`, the subscript is a place: Mojo locates `p`
  and evaluates `i` in order, but calls the getter only when it reads the
  operand, once every operand of its operation is evaluated, so a later
  operand that changes or moves `p` comes first. The getters are called
  before the operation reads its other operands, so `print(x.n, x[0])`
  with a getter that changes `x` prints the changed `x.n`; a list
  literal reads its elements in order. An argument copied into a `var`
  parameter, or into a struct field of a `@fieldwise_init` construction,
  is copied before the getters. A getter destroys what it last uses
  right after it, in any operation and in a `return`, but what a getter
  that returns a reference points into, which lives until the operation
  is done, as for any call that returns a reference. The index of a
  subscript read late, such as `w[h(s)]`, is evaluated in operand order,
  so what the later operands use lives while it is.
  With no setter it is a value, and the getter is called in order.
- On the left of `and` or `or`, a subscript of a struct with a setter is
  read as one with no setter is: its getter is called once, as it is
  evaluated, and what its index last uses dies before it. The pin calls
  the getter twice when the subscript decides, and keeps the index's
  values alive for the second call even when it does not: a compiler bug
  (#211, [D-0011](../conformance/decision-log-d0011.md), provisional),
  which `known.json` lists for its six programs.
- `p[i] = v` calls `__setitem__` when the struct declares both, evaluating
  `i` before `v`. The compiler first checks the types of the getter call
  `p[i]`, then the type of `v` against the getter's result, then the
  setter call; the getter is not run, so nothing is copied for it, and a
  literal of `Int`s of the wrong length fails only after the setter's
  receiver. `v` is read as it is evaluated: a subscript read late there
  calls its getter before those in `i`. With a getter and no setter the
  compiler checks the getter call `p[i]` by reference first. A getter that
  returns a value, or a reference that may not be changed through, makes
  `p[i] = v` `immutablePlace`, before `v` is checked. Through a reference
  that may be changed, `v` is checked against what it points to; the
  write through the reference is not yet modelled, so the model then
  reports `notAList`, as for the other subscripts of a struct used as
  places (#198).
- `p[i] = v` and `p[i] op= v` on a struct that declares `__setitem__`
  but not `__getitem__` are `missingMethod` of `__getitem__`, as the
  compiler reports them once it has typed `p`, before `i`, `v` and a
  later pass's errors (#296).
- Where a value of a type is expected, an argument, an initial value or a
  returned value, a call that returns a reference to a value that is not
  `ImplicitlyCopyable` reports a type that does not fit before its
  implicit copy, as the pin does: `ti(g(w))` with `g` returning
  `ref [w] W` and `ti` taking an `Int` is `typeMismatch`. A getter's index
  is typed before its receiver is read, and an implicit copy in the
  index, or of a place passed to a `var` index parameter, also comes
  before a use of a moved or uninitialized receiver.
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

## What is not yet modelled

Each of these keeps the result the model gave before #191:

- A subscript of a struct used as a place beyond reading and assigning it:
  `p[i] op= e`, passing it `mut` (the compiler writes the getter's value
  back), reading a field, an element or a method of its value, its
  transfer, its copy and `ref r = p[i]`, which the model rejects as
  `notAList` (#198).
- The methods that `Equatable` and `Comparable` supply by default (#194),
  an `if` or
  `while` condition of struct type (#195), and a call of a field (#196).
- `not` on an `Int` that `__bool__` gives, and `and` or `or` on an `Int`
  operand beside a struct, which the compiler accepts (#179, #187).
- The order of the compiler's passes across a call
  ([semantics-error-order.md](semantics-error-order.md#calls-and-initializers)).
- The order in which a call's temporaries are destroyed (#199), an
  in-place method whose result is not `None` (#200), a missing argument
  reported before a misfit of the others (#201), and the destination of
  `p op= e` on a type that is not a struct, which the model checks after
  `e` (#204).
