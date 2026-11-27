import VersoManual
import MojoGrimoire.Check.Logic
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Logic`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "The test of a struct operand: readable blocks" =>

:::moduleDocs (fingerprint := "11367347492647837597")
:::

:::readable MojoGrimoire.Check.passLeft MojoGrimoire.Check.testOperand (fingerprint := "11263943678275367833")
*Rule: the test of a struct operand.* A struct operand of `and` or `or`
is tested with its struct's `__bool__`, which takes only `self`, as the
declaration's check requires. What it returns must be a
$`\mathsf{Bool}`: anything else lacks `__mlir_bool__`, which converts
the result, and is `missingMethod`. This holds for the calls of
`__bool__` that inference makes, and for the left operand when both have
the same struct type, which the operator gives without a call of its
own. That operand is passed to `self` as an argument of a call is, from
the state before it was checked, or, for a place, from the state after
it. The receiver's misfit comes before the result's, as the pin reports
them.

A `mut self` takes only a place that may change (`immutablePlace`) or
a mutable returned reference, and no temporary, which the compiler
reports as a value that may not change (`immutablePlace`, #81). An
`out` or `deinit` `self` takes nothing (`invalidConvention`), where the
compiler takes a `deinit self` as it takes a `var self` (#361).

The left operand is not checked a second time, whatever its form: a
place, a call, an operator or a nested test (`passLeft`). That
check would start from the same state as the first and check the
operand by reference, as the first did, which fits wherever its value
did. Only the passing to `self` remains, from the state before the
operand, or, for a place, from the state after it. Checking it again
would double the cost at each level of a nested left operand.

A `var self` gets a copy of the left
operand on either path, even of a temporary or a transfer, since the
left operand may be the result: a struct that is not `ImplicitlyCopyable`
is `implicitCopy`. On a same-type test a `deinit self` takes that copy
too, which the pin reports before anything else of the test, though the
model then rejects the convention; on a mixed one the model rejects the
convention first (#361). The model moves a transfer $`p\,\hat{}` out of
$`p` there, where the compiler, on the left of a mixed `and` or `or`,
only borrows it and leaves $`p` initialized (#84).
:::

:::readable MojoGrimoire.Check.sameTest MojoGrimoire.Check.leftLacks MojoGrimoire.Check.leftTest MojoGrimoire.Check.copiedLate MojoGrimoire.Check.copiedValue MojoGrimoire.Check.leftConvention MojoGrimoire.Check.checkedBinaryTy (fingerprint := "13655322191062332502")
*Rule: the left operand of `and` and `or` comes first.* The compiler
converts the left operand of `and` or `or` with `__bool__` before it
looks at the right one (#357). Once the left operand's own expression is
typed, a type that lacks `__bool__`, found from its form (`leftLacks`,
`lackingTy`), is `missingMethod`, whatever the right operand holds, an
unknown name included; an integer literal is left to checking. Once the
left operand is checked, its test (`leftTest`) comes before the right
operand is checked: the call of `__bool__` that inference made, its
receiver's misfit or copy and a result that is no $`\mathsf{Bool}`, or,
when both operands have the same struct type (`sameTest`), the test that
`testOperand` checks, then a type that lacks `__bool__`. Both operands
have the same struct type when the left one's checked type is a struct
that declares `__bool__` and inference converted neither operand, as it
converts such a struct operand beside an operand of another type; this
reads no operand's form, so a chain of tests costs one check of each.

The left operand is checked by reference, uncopied, and copied where
checking it as a value copies what it gives (`copiedValue`): a place, or
a call that returns a reference. That copy comes before its test, but
when both operands have the same struct type and their struct's
`__bool__` borrows `self` (`copiedLate`): then it comes once the right
operand is checked, so the right operand's own errors come first, as the
pin reports them. A `var` or `deinit` `self` takes a copy as the left
operand is tested, which comes first. On a same-type test, an `out` or
`deinit` `self`, which the model rejects (`invalidConvention`) where the
pin takes a `deinit self` as a `var self` (#361), is rejected only once
the right operand is checked (`leftConvention`), so that the right
operand's errors come first; the test's other checks keep their place.

Once both operands are checked (`checkedBinaryTy`), the places among them
that are read late are checked again, but for `and` and `or`, whose
operands are read when tested; the operation then has the type that its
operands' types give, and only then is what a literal operand reads late
checked again (`recheckLiterals`, #282), since the compiler reports a
misfit of the types first. The test of a struct operand on the right of
`and` or `or` is checked there.
:::

:::readable MojoGrimoire.Check.typedSimdLeft (fingerprint := "3501249858413900342")
*Rule: a comparison that only the type phase converts.* A literal on the
left of a comparison that holds an inner literal of another length than
one where an $`\mathsf{Int}` is expected keeps the checks it had before
#166, which find errors the compiler does not report. The compiler fails
SIMD's constraint of that inner literal only when it instantiates the
call. So when the other operand is no literal, the comparison keeps no checks
from before #166 for another reason (`keepsBefore`), and the left literal
fits the other operand's type, with that inner literal fitting as the
compiler types it, as off the left (`literalFits`), the type phase types
the left literal and checks the right operand, read by reference (#96).
:::
