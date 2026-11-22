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

:::moduleDocs (fingerprint := "17755364568086492621")
:::

:::readable MojoGrimoire.Check.mainTest MojoGrimoire.Check.mainRead MojoGrimoire.Check.notOperand MojoGrimoire.Check.bridged (fingerprint := "17590098889019667583")
*Rule: the bridge to `main`'s order (temporary, until #96 part 4).*
`main` rejected a test of a struct, by $`\mathsf{and}`, $`\mathsf{or}` or
$`\mathsf{not}`, as $`\mathsf{typeMismatch}` once its operands were
checked. When a statement, or the condition of an `if` or a `while`,
throws an error, it is checked again from the same state, replaying
`main`'s order (`State.mainTests`). In that replay, a struct test is
rejected as $`\mathsf{typeMismatch}` where `main` rejected it: once the
operands of $`\mathsf{and}` or $`\mathsf{or}` are checked
(`checkedBinaryTy`), and once the operand of $`\mathsf{not}` is
(`notOperand`). `main` read the operand that inference tests with a
call of `__bool__` as a value, which copies a place: a struct that is
not `ImplicitlyCopyable` is then $`\mathsf{implicitCopy}` in the replay
(`mainRead`). The replay runs twice: with the checks of the test itself
before that rejection, and without them (`State.ownChecks`), as `main`
had none. When the two end alike, that is the replay's result. When they
differ, a check of the test's own failed first, an error that `main`
could not report: it stands only when the statement holds no other
error, which a third run, in the model's own order without those checks,
shows by passing; else `main` reported the test's
$`\mathsf{typeMismatch}` first, and the replay without those checks
gives `main`'s result. When the replay's result is an error that is not
of the compiler's later pass (`CheckError.late`), the statement has that
error, as on `main`; else the first error stands.
:::

:::readable MojoGrimoire.Check.sameTest MojoGrimoire.Check.mainFormTy MojoGrimoire.Check.methodOperator MojoGrimoire.Check.mainCallee MojoGrimoire.Check.mainOperator (fingerprint := "4964960514335170472")
*Rule: an operator on a struct test, in the replay.* An operand that is
$`\mathsf{and}` or $`\mathsf{or}` of two operands of the same struct
type has that type, and inference may call a method of that struct for
an operator on it, or one that takes it. `main` typed it as a
$`\mathsf{Bool}`, and chose the operator's method from those types as
inference does (`MojoGrimoire.Parse.chooseBinary`): the method of the
left operand's struct, whether or not the right one fits it, else the
reflected method of the right operand's struct when it takes the left
operand's type, not `mut`, and its `self` takes the right operand. In
the replay, at a call of an operator's method that inference made with
such an operand, the operator is recovered from the method's name, and
the call is checked as a call of `main`'s method when `main` chose one.
When it chose none, `main` rejected the operator's misfit on those types
($`\mathsf{missingMethod}`, `operandMisfit`; for `-`, `unaryMisfit`)
once it had typed the operands, leaving out an error of the later pass
and stopping at a struct test; with no misfit, it read the operands in
order, as the call does (`mainOperator`). An operator that inference
left as it is, with no method of the test's struct, finds its misfit
in the replay with $`\mathsf{and}` and $`\mathsf{or}` typed as a
$`\mathsf{Bool}` at any depth, a same-type test too, so that
$`[x\ \mathsf{or}\ y]` is an array of $`\mathsf{Bool}`s
(`mainFormTy`), as `main` did.
:::

:::readable MojoGrimoire.Check.checkedBinaryTy (fingerprint := "13676210965822808734")
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
replays `main`'s order, a struct test is rejected as `main` rejected it
once both operands were checked (`mainTest`), after these checks of the
test itself, whose errors `main` could not report. When the state leaves
those checks out (`State.ownChecks`), the test is rejected so, or passes
with no check of its own, a tested call of `__bool__` taken as a
$`\mathsf{Bool}`.
:::
