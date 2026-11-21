# Current decisions: semantics, operators and calls on structs

This page continues [semantics.md](semantics.md) with what an operator or
a call means when its operand is a struct of the program.

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
  a struct or a variable named in a type position (#193), an `if` or
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
