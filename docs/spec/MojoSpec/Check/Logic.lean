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

:::moduleDocs (fingerprint := "8493855474499774398")
:::

:::readable MojoGrimoire.Check.binaryOperands (fingerprint := "2547842348004514096")
*Rule: an operator's types come before a use of an uninitialized value.*
The compiler finds that a binary operator rejects its operands' types as
it types them, before the later pass that finds a use of an
uninitialized value. So when checking the operands of an operator other
than $`\mathsf{and}` and $`\mathsf{or}` gives
$`\mathsf{uninitializedUse}`, both have a shape and one holds a test of
a struct (`logicShape`), and their forms give types (`operandTy`) that
the operator rejects, that error is reported instead, as on `main`: in
$`k + ((t(0)~\mathsf{and}~x\,\hat{})~\mathsf{or}~x.f)` with $`k` an
$`\mathsf{Int}`, the $`\mathsf{Bool}` that $`+` does not take. A right
operand passed as an argument (`rightParam`), such as the one of an
integer literal's operator, misfits as that argument does (`expectArg`),
$`\mathsf{noMatchingMethod}` for the literal's overloads; any other
operation misfits as `methodBinaryTy` says.
:::

:::readable MojoGrimoire.Check.checkedBinaryTy (fingerprint := "12617917204618938053")
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
