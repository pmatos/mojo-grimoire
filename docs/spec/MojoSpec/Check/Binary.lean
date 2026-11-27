import VersoManual
import MojoGrimoire.Check.Binary
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Binary`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Binary operations: readable blocks" =>

:::moduleDocs (fingerprint := "12406545064419752213")
:::

:::readable MojoGrimoire.Check.heldLeft (fingerprint := "4609557105210351087")
*Rule: how a literal on the left is built.* A literal on the left of a
comparison that holds a place whose value is not implicitly copyable
(`heldCopy`) is converted to the type of a right operand that is no
literal when it fits it (`operandFit`), and is built on its own, and
checked in full before the comparison's misfit, when the right operand
is a literal too, but `List[u]()`, or has a known type that the literal
is not converted to or does not fit. Either way the compiler first
types both operands' own expressions, then builds the literal, so its
copies come after an error in the right operand and before the
comparison's misfit (#338). A fit that is not known, and a right
operand whose type is not known, leave the comparison to the checks it
had before #166.
:::

:::readable MojoGrimoire.Check.checkBinary (fingerprint := "14048690194773262837")
*Rule: binary operations.* `checkExprAs` checks a binary operation by
`checkBinary`, passing it the checks it makes of the two operands, so
that this rule lives outside the mutual block of expressions. In the type
phase, a comparison that only that phase converts (`typedSimdLeft`) types
its left operand and checks its right one, read by reference, and gives a
$`\mathsf{Bool}`. Otherwise:

* a misfit found from the operands' forms (`operandMisfit`) is reported
  before they are read, once both are typed by `typeArg`, but a literal on
  the left that is built on its own (`heldLeft`) is checked in full
  instead, so that its own errors, its copies among them, come first,
  and so is a literal on the left of `and` or `or`. For `and` and `or`,
  the left operand's test (`leftTest`) comes between the two, before the
  right operand is typed;
* when the left literal is one that `heldLeft` builds, converted or not,
  and the check fails in the type phase, both operands' own expressions
  are typed first (`typedFirst`), so an error in the right operand comes
  before the literal's copy (#338);
* the right operand of an operator whose left operand is an integer
  literal expression (`intLiteral`), but `and` and `or`, is passed as to
  a `read` $`\mathsf{Int}` parameter of a method with several overloads:
  one that is no $`\mathsf{Int}` is `noMatchingMethod` (#88). A literal on
  the right of a comparison that converts it to the type of an array or a
  list on the left, and that inference gave that type, is passed as the
  method's `other` parameter of that type (`rightParam`, #166, #185);
* an operand compared as an array or a list, a place or a call that
  returns a reference, is read by reference, uncopied (`byRef`, #166,
  #185): the left operand first, then the right one, with the checks that
  a comparison kept from before #166 when `keepsBefore` holds
  (`Before.rightParam`);
* the left operand of `and` and `or` is converted with `__bool__`
  before the right operand is looked at (#357): a type that lacks
  `__bool__`, found from its form once it is typed (`leftLacks`), and,
  once it is checked, by reference and then copied as its value would be
  (`copiedValue`), its test (`leftTest`). When both operands have the
  same struct type (`sameTest`), the left one is copied only once the
  right one is checked, unless its `__bool__` takes a `var` or `deinit`
  `self` (`copiedLate`), and an `out` or `deinit` `self` is rejected only
  then (`leftConvention`). So the late copy of the left operand into
  the result (`copiedLate`), for a `__bool__` that does not take a
  `var` or `deinit` `self`, comes after both operands' own errors and
  the left operand's test, in a subscript's index as outside it (#362):
  `pz(t1 or t2)`, with a `mut self` `__bool__` and `t1` a `read`
  parameter, is `immutablePlace`;
* once both operands are checked, the operation is typed as
  `checkedBinaryTy` says, which checks the test of a struct operand on
  the right of `and` and `or`.
:::
