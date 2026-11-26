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

:::moduleDocs (fingerprint := "2227814630432759629")
:::

:::readable MojoGrimoire.Check.passLeft MojoGrimoire.Check.checkedBinaryTy (fingerprint := "14619223166697949421")
*Rule: binary operations.* Once both operands are checked, the places
among them that are read late are checked again, but for `and` and `or`,
whose operands are read when tested; the operation then has the type
that its operands' types give, and only then is what a literal operand
reads late checked again (`recheckLiterals`, #282), since the compiler
reports a misfit of the types first. A struct operand of `and` or `or` is
tested with its struct's `__bool__`, which takes only `self`, as the
declaration's check requires. What it returns must be a
$`\mathsf{Bool}`: anything else lacks `__mlir_bool__`, which converts
the result, and is `missingMethod`. This holds for the calls of
`__bool__` that inference makes, and for the left operand when both have
the same struct type, which the operator gives without a call of its
own. That operand is passed to `self` as an argument of a call is, from
the state before it was checked, or, for a place, from the state after
it.

A `mut self` takes only a place that may change (`immutablePlace`) or
a mutable returned reference, and no temporary (`notAPlace`, #81). An
`out` or `deinit` `self` takes nothing (`invalidConvention`), though the
declaration's check rejects such a `__bool__` first.

The left operand is not checked a second time, whatever its form: a
place, a call, an operator or a nested test (`passLeft`). That
check would start from the same state as the first and check the
operand as a value, as the first did, or, for a returned reference, by
reference, which fits wherever the value did. Only the passing to
`self` remains, from the state before the operand, or, for a place,
from the state after it. Checking it again would double the cost at
each level of a nested left operand.

A `var self` gets a copy of the left
operand on either path, even of a temporary or a transfer, since the
left operand may be the result: a struct that is not `ImplicitlyCopyable`
is `implicitCopy`. The model moves a transfer $`p\,\hat{}` out of
$`p` there, where the compiler, on the left of a mixed `and` or `or`,
only borrows it and leaves $`p` initialized (#84).
:::

:::readable MojoGrimoire.Check.typedSimdLeft (fingerprint := "5939084892300411783")
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
