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

:::moduleDocs (fingerprint := "18237080337807734158")
:::

:::readable MojoGrimoire.Check.checkedBinaryTy (fingerprint := "18237080337807734158")
*Rule: binary operations.* Once both operands are checked, the places
among them that are read late are checked again, but for `and` and `or`,
whose operands are read when tested; the operation then has the type
that its operands' types give. A struct operand of `and` or `or` is
tested with its struct's `__bool__`, which takes only `self`, as the
declaration's check requires. What it returns must be a
$`\mathsf{Bool}`: anything else lacks `__mlir_bool__`, which converts
the result, and is `missingMethod`. This holds for the calls of
`__bool__` that inference makes, and for the left operand when both have
the same struct type, which the operator gives without a call of its
own. That operand is passed to `self` as an argument of a call is, from
the state before it was checked: a `mut self` takes only a place that
may change (`immutablePlace`) or a mutable returned reference, and no
temporary (`notAPlace`, #81). A `var self` gets a copy of the left
operand on either path, even of a temporary or a transfer, since the
left operand may be the result: a struct that is not `ImplicitlyCopyable`
is `implicitCopy`. The model moves a transfer $`p\,\hat{}` out of
$`p` there, where the compiler, on the left of a mixed `and` or `or`,
only borrows it and leaves $`p` initialized (#84).
:::
