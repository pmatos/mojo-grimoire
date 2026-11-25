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

## Where the model differs today

The checker's phases follow the compiler's tiers, and each phase its
order across the declarations, but the order inside a statement or an
expression of the type tier is still the model's. So it differs from the compiler in these
cases, which #96's later parts fix.

### Calls and initializers

- The compiler checks every argument before it looks for an initializer,
  so an error in a later argument, `P(True, nope)`, comes first there,
  where the model reports the misfit, as it does for an ordinary call
  (#89).
- The model finds a missing method from the operands' types before it
  reads them, once it has typed them, so that an error inside an operand
  comes first (`s + nope` is `unknownVariable`) and an uninitialized
  operand after (`var s: S; s + 1` is `missingMethod`); a struct, list
  or array operand is never copied first.

### The arguments of `range`

The compiler's order is tiered more finely than the passes that
[semantics-lists.md](semantics-lists.md#lists) gives for the arguments of
`range` in `List[u](range(…))`, and the rest is left to #96. Its flow
errors come before its instantiation errors, as in any expression:
`range(xs[-1] + u)`, with `u` uninitialized, is `uninitializedUse`, and
so is `range(g(p^, xs[-1]), p.x)`. Among the instantiation errors, a
constant index into an array comes before the literal and before an index
into a list on the compiler, and the model reports the literal first.

## Temporary bridges to `main`'s order

Two bridges keep the results that `main` gave where a change exposed
the compiler's order before the model could follow it. They act in every
phase, and Part 4 of #96 removes both. A third, which made an index's
error of a later pass wait for an assigned value's (#280), is gone: each
pass now has its phase (Part 7).

- The struct tests of #191, by `and`, `or` and `not`:
  [semantics-operators.md](semantics-operators.md#methods-that-a-struct-declares).
- The comparisons that part 2 of #166 converts, bridged statement by
  statement to `main`'s twin (#281):
  [semantics-comparisons.md](semantics-comparisons.md).

Other notes that wait for #96 stay on their pages: the comparisons not yet
modelled in [semantics-comparisons.md](semantics-comparisons.md), and
`break` and `continue`, which are supported after #96's flow parts
([semantics-parser.md](semantics-parser.md)).
