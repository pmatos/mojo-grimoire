import VersoManual
import MojoGrimoire.Check.Compare
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Compare`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Comparisons: readable blocks" =>

:::moduleDocs (fingerprint := "16876984616171267366")
:::

:::readable MojoGrimoire.Check.compares MojoGrimoire.Check.seqCompare MojoGrimoire.Check.seqCompare.modelled MojoGrimoire.Check.seqCompare.conforms (fingerprint := "12823475274059033023")
*Definition: comparable arrays and lists.* $`<`, $`\le`, $`>`, $`\ge`,
$`==` and $`!=` compare. Two arrays compare when their element type
conforms to `Comparable`, to order them, or to `Equatable`, for $`==`
and $`!=`; two lists compare with $`==` and $`!=` when their element
type conforms to `Equatable`. $`\mathsf{Int}`, $`\mathsf{Bool}` and
arrays of them conform, and lists of them to `Equatable`; `None` does
not. A list has no order: it lacks the methods, and does not conform to
`Comparable` as an element (#185). An element type that holds a struct,
itself or through lists and arrays, is not modelled yet, since its
conformances come with #194: the comparison is left to the rules of
other operators, which reject it, with a class that is not yet the
compiler's.
:::

:::readable MojoGrimoire.Check.seqMisfit (fingerprint := "11246379863837844341")
*Rule: the misfit of a comparison of arrays or lists.* When one operand
of a comparison is an array or a list that compares, an operand of
another type is a type mismatch, as the compiler cannot convert it: the
right one when the left is such a sequence, and the sequence when the
left is an $`\mathsf{Int}` or a $`\mathsf{Bool}`. Two sequences of the
same type whose element type does not conform are `violatedConstraint`
of their type and the operator's method (#166).
:::

:::readable MojoGrimoire.Check.binaryMisfit (fingerprint := "6923297633895849814")
*Rule: the misfit of a binary operator from its operands' types.* An
operator whose left operand's type lacks the operator's method is
`missingMethod` of that type and method; for $`\mathsf{and}` and
$`\mathsf{or}`, so is a right operand whose type lacks `__bool__`
(#176). Otherwise the misfit is that of a comparison of arrays or lists
(`seqMisfit`).
:::

:::readable MojoGrimoire.Check.holdsLiteral MojoGrimoire.Check.convertsLiteral MojoGrimoire.Check.operandMisfit MojoGrimoire.Check.byRef (fingerprint := "15047511542355886965")
*Rule: operands of a comparison of arrays or lists.* The misfit of a
binary operator is found from its operands' forms before they are read
(`operandTy`). An integer literal on the left gives no type, so that its
overloads report a comparison with an array or a list
(`noMatchingMethod`), and an empty literal with no type on the right of
a comparison has a type that fits no array. A literal with no type
compared with a list, which the compiler converts to a list, is left to
the checks that follow, as before #166, and so is a literal that holds a
literal compared with an operand whose type its form does not show to be
the same, which the compiler converts element by element (part 2 of
#166): its operands are not passed by reference either. Any other
operand compared as an array or a list is passed by reference, as the
comparisons of `Array` and `List` take a `read` argument: a place, or a
call that returns a reference, is read, uncopied.
:::

:::readable MojoGrimoire.Check.rightParam (fingerprint := "15852281047781063043")
*Rule: a right operand checked as an argument.* When the left operand of
a binary operator other than $`\mathsf{and}` and $`\mathsf{or}` is an
integer literal, the right one is the argument `rhs`, an
$`\mathsf{Int}`, of a method with several overloads, whose misfit is
`noMatchingMethod`. When the left operand of $`==` or $`!=` is a list
and the right one a literal that inference typed as such a list, the
literal is the argument `other` of the list's `__eq__` or `__ne__`, of
the list's type, converted to it as a call's argument is (#185): an
element of another type is a type mismatch, and an inner literal where
an $`\mathsf{Int}` is expected follows the rules of such literals.
:::

:::readable MojoGrimoire.Check.methodBinaryTy (fingerprint := "10037846033912567083")
*Rule: the result of a binary operator, once its operands are checked.*
A method that an operand's type lacks is `missingMethod`, and a
comparison of arrays or lists that does not fit is its misfit, found
again from the checked types; otherwise such a comparison gives a
$`\mathsf{Bool}`, and any other operator's result is `binaryTy`'s.
:::
