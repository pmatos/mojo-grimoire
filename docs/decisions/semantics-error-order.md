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
#96 lands it in parts.

Rejected: a local fix per construct (option (B)), since each needs another
deferral such as `lateElemTy`; and text order inside each tier, which
disagrees with the probes.

## Where the model differs today

The checker checks each function in one pass, in program order, and
reports the first error it meets. So it differs from the compiler in these
cases, which #96's parts fix.

### Calls and initializers

- The compiler checks every argument before it looks for an initializer,
  so an error in a later argument, `P(True, nope)`, comes first there,
  where the model reports the misfit, as it does for an ordinary call
  (#89).
- The compiler reports ownership errors only after every type error, so
  `P(b)` with `b` an uninitialized `Bool` is `noMatchingInit` there,
  where the model, which checks in program order, reports
  `uninitializedUse` (#96).
- The model finds a missing method from the operands' types before it
  reads them, once it has typed them, so that an error inside an operand
  comes first (`s + nope` is `unknownVariable`) and an uninitialized
  operand after (`var s: S; s + 1` is `missingMethod`); a struct, list
  or array operand is never copied first. It finds a misfit of an overload
  set as an ordinary call finds a misfit, once the argument is read, so
  `var b: Bool; xs[b]` is `uninitializedUse` in the model and
  `noMatchingMethod` in the compiler (#96).
- An uninitialized receiver comes before an argument's type error in the
  model (#96).

### Transfers of an element

The compiler rejects the transfer of an element once it has typed the
place, and the model does the same (#119,
[semantics.md](semantics.md#the-static-checker)). Its index check stops
at the first error of a later pass and leaves it out, so any error that
follows one in the same index, such as an unknown name, a type error or an
implicit copy, is not reported either (#96).

### The arguments of `range`

The compiler's order is tiered more finely than the passes that
[semantics-lists.md](semantics-lists.md#lists) gives for the arguments of
`range` in `List[u](range(…))`, and the rest is left to #96. Inside an
operation, the model checks in program order, as in any expression:
`range(xs[-1] + u)`, with `u` uninitialized, is `negativeIndex`. An
argument whose check stops at a later pass's error does not record what it
moved, so `range(g(p^, xs[-1]), p.x)` is `negativeIndex` where the
compiler reports `p` uninitialized. A constant index into an array comes
before the literal and before an index into a list on the compiler, and
the model reports it as any index. A nested `List[Int](range([1, 2]))`
fails at once in the model, before a use of an uninitialized value in
another argument.

### Types that a variable hides

Where a hidden type comes among a program's errors is in
[conformance-classes.md](conformance-classes.md#types-that-a-variable-hides).
Two cases differ (#96). A later pass's error before it, such as a use of
an uninitialized value, comes first in the model. A hidden type in a
function comes after an error in a struct's method in the model, which
checks structs first, and one in a struct's method comes after a later
struct's `recursiveStruct` there.

### Copyable structs whose fields cannot be copied

In its first pass, the compiler checks the bodies of the functions and
`main`'s signature, wherever they are declared, then each struct in
declaration order: its methods, then its copy initializer. Its later
passes, such as a use of an uninitialized value or a missing return, and
a missing `main` come after. The model checks every struct, then every
function and `main`'s signature, then the fields of the structs that
declare `Copyable` or `ImplicitlyCopyable`
([conformance-classes.md](conformance-classes.md#copyable-structs-whose-fields-cannot-be-copied)),
then that `main` exists. Three cases differ, as on `main` (#164). A later
pass's error in a body comes first in the model (`uninitializedUse`,
`missingReturn`). So does a first-pass error in a method of a struct
declared after the bad one. And "attempt to resolve a recursive reference
to declaration" is ordered with this error by declaration, where the
model reports `recursiveStruct` first.

## Temporary bridges to `main`'s order

Three bridges keep the results that `main` gave where a change exposed
the compiler's order before the model could follow it. Part 4 of #96
removes all three.

- The struct tests of #191, by `and`, `or` and `not`:
  [semantics-operators.md](semantics-operators.md#methods-that-a-struct-declares).
- The comparisons that part 2 of #166 converts, bridged statement by
  statement to `main`'s twin (#281):
  [semantics-comparisons.md](semantics-comparisons.md).
- The checks of an assignment (#280). The checker checks the indices of
  the place before the value, as the compiler does. `typedFirst` then
  makes an index's error of a later pass wait for the value's errors of
  earlier passes, which `CheckError.pass` ranks. The human ruled on
  2026-11-25 that this is a bridge of this kind. Between a literal of
  `Int`s of the wrong length and a constant index into an array, the
  compiler's order differs between `-O0` and `-O3`. The model keeps the
  order at `-O0`, and no suite program pins it.

Other notes that wait for #96 stay on their pages: the comparisons not yet
modelled in [semantics-comparisons.md](semantics-comparisons.md), and
`break` and `continue`, which are supported after #96's flow parts
([semantics-parser.md](semantics-parser.md)).
