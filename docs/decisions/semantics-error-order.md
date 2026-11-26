# Current decisions: semantics, the order of errors

This page continues [semantics.md](semantics.md) with the order in which
the model reports the errors of a program that it rejects. The suite
compares a rejection's first error, so the model must find the errors in
the compiler's order. Each part of #96 edits this page as it changes that
order.

## The compiler's tiers

The pinned compiler reports a program's errors in three tiers, probed on
the nightly 1.3.0.dev2026111905 for #96:

1. "failed to parse": type errors, overload resolution included. The
   bodies of the free functions and `main`'s signature come first, in
   declaration order, then each struct in declaration order.
2. "failed to run the pass manager": a missing return anywhere in the
   program comes first, and the pass stops there. Then each function in
   declaration order, struct methods among the free functions: its uses of
   values, invalidations, errors at exit and partial destructions, before
   the next function's. A missing `main` comes after every error of this
   tier.
3. "function instantiation failed": a literal of `Int`s of the wrong
   length, a constant index out of range of an array, and a negative
   constant index of a `List`. From `main`, a function's own errors come
   first, in text order, then its callees, the last call first, depth
   first.

The human ruled on 2026-11-20 that the checker follows this order, by
checking a type phase, then a flow phase, then an instantiation phase over
the whole program (#96, option (A)), and on 2026-11-22 that each tier
keeps the compiler's own order inside it, as the probes show. The plan of
#96 lands it in parts (ADR-2026-11-21-1941).

Rejected: a local fix per construct (option (B)), since each needs another
deferral such as `lateElemTy`; and text order inside each tier, which
disagrees with the probes.

## The checker's phases

`MojoGrimoire.Check.checkProgram` checks the whole program three times,
in the type phase, the flow phase and the instantiation phase, and reports
the first error of the first phase that finds one (#96 parts 4 and 7).
Each phase takes the same path through each body, with the phase in the
checker's state, and visits the bodies in its own order, below; the
instantiation phase checks them with the statements that destroy values
(`dropsProgram`). Each phase skips the checks of the other phases, at the
place where they reject (`flowCheck`, `instCheck`):

- the flow checks: a use of an uninitialized value or of a part moved out,
  a reference that a change invalidated, a part destroyed while it is
  built from its fields, what a function leaves at a `return` or its
  end, and what a loop's body leaves for the next iteration. The type
  phase finds where a body can reach its end without returning its
  result, and the flow phase reports that missing return first;
- the instantiation checks, which the instantiation phase runs after the
  flow phase (Part 7, below): a literal of `Int`s of the wrong length,
  which in the other phases gives the type that its place expects, and a
  constant index that is negative or beyond an array's or an `Int`'s last
  element;
- a missing `main`, which comes after the flow phase. `main`'s
  signature and the fields of copyable structs are checked in the type
  phase.

So in the type phase every variable is whole and no reference is
invalidated. A program that the model accepts takes the same path in every
phase as before, since the skipped checks find nothing in it.

A comparison whose left operand is a literal that holds an inner literal
of another length where an `Int` is expected keeps the checks it had
before #166 ([semantics-comparisons.md](semantics-comparisons.md)), and
those find errors that the compiler does not report. When that literal
fits the other operand, no literal, as the compiler types it, the type
phase checks only the operands' own expressions (`typedSimdLeft`).

The suite's area `order/` holds the pairs of the ruling's matrix across
two tiers that the model parses (`order/pairs/`, `order/pairs2/`), the
other probes that the phases fixed, and one program for each difference
below that Part 4 removed, recorded from the pin.

Reporting type errors first also reports, before a flow or an
instantiation error, the model's own wrong type-tier rejections and the
errors that it orders wrongly inside the tier. Each such program that
Part 4 changed is listed on its PR with the open issue of its rejection,
as [process.md](process.md#one-issue-several-prs) allows.

## The order of the flow phase

The flow phase follows the order of the compiler's pass manager (#96
part 5, `checkFlow`), probed on the pin:

1. A missing return, anywhere in the program, in the order of the
   declarations, comes before every other flow error. The type phase finds
   it as it checks the body, and the flow phase reports it.
2. Then each function in the order of the declarations in the source, the
   members of a struct interleaved with the free functions, and in a
   struct its members in their order: a function's errors all come before
   the next function's.
3. Inside a function, its uses of values and what it leaves at a
   `return` or its end come in the order of the body, and a value that
   may not end, `partiallyDestroyed`, comes after them all (#159). The
   model checks a body once through every stage (`Stage`), and, only
   when that finds a value that may not end, once more without it.

The plan of #96 put the errors at a return after every use. The pin
reports an exit error at an early `return` before a use after it
(`order/flow_use_after_exit`), so the two share a stage. The suite's
`order/flow_*` and `order/missing_return_*` programs hold the pairs of
each rule.

A missing `main` comes after the flow phase, and before the
instantiation phase.

## The order of the instantiation phase

The instantiation phase follows the compiler's instantiation of the
functions from `main` (#96 part 7, `MojoGrimoire.Check.checkInst`),
probed on the pin (`order/inst_*`, `tests/sweep/order7/`):

1. In a body, its own errors come first, in the order of the body: a
   literal of `Int`s of the wrong length, and a constant index out of an
   array's or an `Int`'s range, negative or past its last element. An
   index of an `Int` other than 0 is D-0009's, and takes the array's rule.
2. Then its calls, the last first, each instantiated depth first, once:
   free functions, methods, initializers, operator methods, getters and
   setters, and a destructor where the value is destroyed, after its last
   use, as elaboration places it. A value destroyed inside an expression
   is destroyed after its statement. The destructor is the one that the
   struct declares, or else the one that the compiler synthesizes, which
   destroys the fields, the last first; a list's or an array's destroys its
   elements. In `f(g())`, `f` is the last call. A negative constant index
   of a `List` fails as a call does.
3. Then the bodies that `main` does not reach, in the order of the
   declarations. The compiler never instantiates them and accepts them,
   which #264 tracks.

At `-O0` the compiler takes a constant index into an array as a call
too, so its order there differs from `-O3`'s, the reference, when such
an index stands beside another error of the body (#324). The model keeps
the order at `-O3`, and the suite holds no such program. The model does
not follow a struct's `__bool__` that a condition calls (#195).

At `-O1` and above the pin drops the right operand of `or` when a
variable that holds `True` is on its left, and with it a literal of
`Int`s of the wrong length inside it, which only `-O0` rejects. The
human ruled this a compiler bug on 2026-11-26 (#324,
[D-0014](../conformance/decision-log.md)): the fixed compiler rejects
it at every level, and so does the model (`noMatchingInit`). The same
difference under a variable that holds `False` on the left of `and`
and in an `if` branch, and a literal `True` on the left of `or` or
`False` on the left of `and`, which the pin runs at every level, wait
on #346.

## The order of the type phase

The type phase follows the order of the compiler's first pass (#96 part
6, `checkTypes`), probed on the pin
(`order/type_*`, `tests/sweep/order6/`):

1. A struct of the name of another struct or of a function comes first.
2. Then the declarations in the order of the source. A free function's
   signature and body: `main`'s parameters and result are resolved, and
   then it must take nothing and return nothing, before its conventions
   and its body; a function of the name of an earlier one fails at its
   place. A struct's own declaration: the names of its fields and methods,
   and the types of its fields.
3. Then each struct in the order of the declarations: its initializer,
   destructor and methods, signature and body, in their order. The copy
   initializer that the compiler synthesizes is checked right after
   `__init__`, and an implicit one there also meets a field on a cycle
   that the fixed compiler rejects, field by field. Otherwise such a cycle
   comes after the last member, and then the copy initializer of a struct
   that declares no `__init__`. A hidden type, `valueAsType`, takes its
   place in that order like any error (#193).

The compiler resolves a method's or a function's signature where a body
first refers to it, which the model does not follow yet (#231).

## The order inside a call

Inside a call, the compiler reports a call's errors in this order (#96
part 9, #89), probed on the pin (`order/call_*`):

1. The callee: an unknown function or method comes first.
2. Each argument's own expression, in full, left to right: an unknown
   name, an operator's misfit, a transfer with no origin of its own, and
   every error of a call nested in it, its implicit copies included. A
   literal's own expressions are its elements; converting it to the
   parameter's type is part of the match.
3. The number of arguments.
4. Each argument's type and mutability, left to right, the receiver of a
   method first: a value of the wrong type, a receiver or a place passed
   `mut` that may not change.
5. The implicit copies of the arguments, and of the value that a call
   returns a reference to.
6. The exclusivity of the arguments passed by reference.

The checker checks a call's arguments as before, in one pass, and puts
its errors in that order where they meet (`callOrder`). When the check
fails, the arguments' own expressions are typed first, as the type phase
types them (`ownArgs`). The arity is checked before any argument. When
an argument fails with an implicit copy, the arguments are checked again
without copies (`copyChecks`), so that a later argument's misfit comes
first. Exclusivity is checked after the arguments. This holds for calls,
methods, initializers and the operators' methods.

## The order inside a place

The compiler types a place from its variable outward (#96 part 10, #142,
#227), probed on the pin (`order/place_*`): the variable, then each
field and each subscript in turn. A subscript is checked once the place it
indexes is typed: a type that cannot be indexed comes first, then the
index's own expression, then the index's misfit. So an unknown variable
comes before its index's type, `zz[True]`, an unknown field before an
index after it, `l[0].nope[zz]`, and a subscript of a struct that
declares neither `__getitem__` nor `__setitem__` before its index,
`p[zz]`. An assignment types its target place in full before the value
it assigns: `p.nope = zz` is `unknownAttribute`, and `p[0] = zz`
`notAList`.

The checker checks a place's indices as before (`indicesOf`). When that
fails with an error of the type phase, the place is typed in the
compiler's order first (`typePlace`), and its error comes first
(`checkIndices`). An assignment types its target, `placeTy`, before it
checks the value. A place through a subscript of a struct that declares
`__getitem__` or `__setitem__` has no type in the model, which types
such a subscript only as a call (#198): it keeps the index's error and
the target's mutability (`throughGetter`).

## The order inside declarations and literals

A declaration's initializer is typed before its name is found to be
declared already (#96 part 11, #134), probed on the pin
(`order/decl_*`): `var s = s.nope` is `unknownAttribute` where `s`
exists, and so is `ref s = s.nope`. The initializer's own expression
comes first: a literal with no type expected in full, since its elements
give its type, `var s = [1, True]` a `typeMismatch`, and a call by
reference. A literal is built with the declared type before the duplicate:
`var s: List[Int] = [True]` is `noMatchingInit`, but `var s: Int = [1, 2]`
is the redefinition, since that literal fails only when it is
instantiated. A value's other conversion to a declared type comes after
the duplicate: `var s: Int = True` is the redefinition. A declared type that names no
type comes before both, which the model classes otherwise (#237,
`tests/sweep/order11/decl_i10`, `decl_i11`).

A value's type comes before its implicit copy, as in a call: the value
of a declaration, an assignment and a `return`, and an element of a
literal. `var b: Int = xs`, with `xs` a `List[Int]`, is `typeMismatch`,
and `var a: List[Int] = [xs]` `noMatchingInit`; `var a: List[Int] = xs`
alone is `implicitCopy` (`order/decl_copy_*`). An assignment to a place
that may not change is reported before the value's own errors, as #174
found for its type: `x = zz`, with `x` a `read` parameter, is
`immutablePlace` (`order/decl_assign_*`).

Inside a literal with no type expected, the compiler reports, in this
order (#133, `order/decl_lit_*`, `order/decl_empty_*`):

1. The own expressions of all its elements, at any depth: an unknown
   name, an operator's misfit, a call's misfit or arity. `[[], zz]` is
   `unknownVariable`, and `[[], [1 + True]]` `noMatchingMethod`.
2. Its elements built in order: an empty literal, which has no type, and
   an inner literal with elements, with its own misfits and copies.
   `[[], [1, True]]` is the empty literal, `[[1, True], []]` a
   `typeMismatch`, and `[[xs], [1]]` `implicitCopy`.
3. The literal's own misfit, then the copies of its places: `[xs, [1]]`
   is `typeMismatch`.

A literal that initializes a type that is not a list or an array, or an
`Int` with a length other than 1, types only its elements' own
expressions before its misfit: `var q: Int = [[xs]]` is `noMatchingInit`,
and `var q: Int = [xs, zz]` `unknownVariable`. A literal passed to `len`
is typed by `len`, which the model does not follow yet (#341).

The checker types the initializer first when the duplicate name is found
(`valueOwn`, `typedFirst`). A literal's check that fails in the type
phase types its elements' own expressions first (`ownArgs`), then builds
its inner literals in order (`literalElems`). When a value's check
reports an implicit copy, it checks the value again without copies
(`copyLast`), and a misfit comes first. The compiler's
"invalid redefinition of 'V'" is `duplicate`.

Inside a comparison, the compiler converts a literal operand to the type
of the other operand, and that conversion decides the order of its copies
and misfits. The model types such a literal as one with no type expected,
which #338 tracks (`tests/sweep/order11/decl_cmp_*`).

## The order inside an operator

The model finds a missing method from the operands' types before it
reads them, once it has typed them, as the compiler does: an error
inside an operand comes first (`s + nope` is `unknownVariable`), and an
uninitialized operand after (`var s: S; s + 1` is `missingMethod`). A
struct, list or array operand is never copied first.

## Where the model differs today

The checker's phases follow the compiler's tiers, and each phase its
order across the declarations, statements and expressions. The model
still differs from the compiler in these cases.

### The arguments of `range`

The compiler's order is tiered more finely than the passes that
[semantics-lists.md](semantics-lists.md#lists) gives for the arguments of
`range` in `List[u](range(…))`, and the rest is left to #339. Its flow
errors come before its instantiation errors, as in any expression:
`range(xs[-1] + u)`, with `u` uninitialized, is `uninitializedUse`, and
so is `range(g(p^, xs[-1]), p.x)`. Among the instantiation errors, a
constant index into an array comes before an index into a list on the
compiler. It comes before the literal at the default level, `-O3`, even
when the literal comes first in the text, but after it at `-O0` (#331).
The model reports the literal first.

## Comparisons not yet ordered

A comparison whose literal operand holds a place that cannot be copied
implicitly, and the other comparisons not yet modelled, stay on their
page, [semantics-comparisons.md](semantics-comparisons.md), with their
order tracked on #338. No bridge to `main`'s order remains: Part 4c of
#96 removed the last two, for the struct tests of #191 and the
comparisons of part 2 of #166 (#281).

`break` and `continue` stay outside the subset until #276 supports them
after #96's flow parts ([semantics-parser.md](semantics-parser.md)).
