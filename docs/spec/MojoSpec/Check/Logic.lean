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

:::moduleDocs (fingerprint := "2677876846220635374")
:::

:::readable MojoGrimoire.Check.mainTest MojoGrimoire.Check.notOperand MojoGrimoire.Check.mainOperator MojoGrimoire.Check.bridged (fingerprint := "11158994644876913621")
*Rule: the bridge to `main`'s order (temporary, until #96 part 4).*
`main` rejected a test of a struct, by $`\mathsf{and}`, $`\mathsf{or}` or
$`\mathsf{not}`, as $`\mathsf{typeMismatch}` once its operands were
checked. When a statement, or the condition of an `if` or a `while`,
throws an error of the compiler's later pass (`CheckError.late`), it is
checked again from the same state, replaying `main`'s order
(`State.mainTests`). In that replay, a struct test is rejected as
$`\mathsf{typeMismatch}` where `main` rejected it: once the operands of
$`\mathsf{and}` or $`\mathsf{or}` are checked (`checkedBinaryTy`), once
the operand of $`\mathsf{not}` is (`notOperand`), and, for an operator
that inference made a call of a struct's method whose left operand is
$`\mathsf{and}` or $`\mathsf{or}` of two operands of that struct type,
before its operands are read, when the operator takes no
$`\mathsf{Bool}` (`binaryMisfit`), since `main` typed that operand as a
$`\mathsf{Bool}` and typed the operands first (`mainOperator`). When the
replay reaches such a test before the error, the statement is
$`\mathsf{typeMismatch}`, as on `main`; else the error stands.
:::


:::readable MojoGrimoire.Check.checkedBinaryTy (fingerprint := "12342285791881911388")
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
only borrows it and leaves $`p` initialized (#84). When the state
replays `main`'s order, a struct test is rejected once both operands are
checked, as `main` rejected it (`mainTest`).
:::
