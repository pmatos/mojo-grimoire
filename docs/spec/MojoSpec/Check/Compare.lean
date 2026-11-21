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

:::moduleDocs (fingerprint := "1995305847277342139")
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

:::readable MojoGrimoire.Check.convertsTo MojoGrimoire.Check.literalFits MojoGrimoire.Check.elemsFit (fingerprint := "4517748301629835226")
*Rule: a literal that fits the other operand's type.* A comparison
converts a literal operand to the type $`t` of its other operand when it
compares $`t` (`seqCompare`) and $`t` is an array, or a list compared by
$`==` or $`!=`, the methods a list has (#166). A literal on the left is
converted only when the comparison of $`t` also conforms: beside an
array of lists ordered, it keeps its own type. The literal fits $`t`
element by element, as a call converts its argument: an array of $`n`
elements of $`u` takes $`n` elements that each fit $`u`; a list of $`u`
any number of them; and $`\mathsf{Int}`, whose initializer from a literal
takes $`\mathsf{Int}`s (#103), any number of elements that fit
$`\mathsf{Int}`, their count checked later (#170). Any other element fits
only its own type, as the operand's form gives it. A literal fits no
other type, except that whether one fits $`\mathsf{Bool}` is left to
#165: that fit, and the fit of an element whose type the form does not
give, is unknown, and so is the fit of a literal with an unknown element
and no element that does not fit.
:::

:::readable MojoGrimoire.Check.literalTy MojoGrimoire.Check.holdsLiteral MojoGrimoire.Check.literalPlaces MojoGrimoire.Check.placesOf MojoGrimoire.Check.copyMisfit MojoGrimoire.Check.operandFit MojoGrimoire.Check.fitTy MojoGrimoire.Check.operandMisfit MojoGrimoire.Check.byRef (fingerprint := "2667214114178237985")
*Rule: operands of a comparison of arrays or lists.* The misfit of a
binary operator is found from its operands' forms before they are read
(`operandTy`). A literal on the right of a comparison is converted to
the type of the left operand, and one on the left to the type of the
right operand unless that is a literal too; a literal that fits takes
that type (`operandFit`, `fitTy`). A literal on the right that does not
fit, or one on the left that does not fit and has a type of its own, is
a type mismatch, before the operands are read. A literal on the left
that does not fit keeps its own type, and the right operand is then
converted to it; it is built first, so a place in it whose value is not
implicitly copyable is first `implicitCopy` of that value's type
(`copyMisfit`). A literal whose fit is unknown gives no type, and is
left to the checks that follow, as before #166. An integer literal on
the left gives no type, so that its overloads report a comparison with
an array or a list (`noMatchingMethod`). An operand compared as an array
or a list is passed by reference, as the comparisons of `Array` and
`List` take a `read` argument: a place, or a call that returns a
reference, is read, uncopied; but not beside a literal whose fit is
unknown and which inference did not give the operand's type, beside a
list, or an array when that literal holds a literal.
:::

:::readable MojoGrimoire.Check.rightParam (fingerprint := "5344092844104288245")
*Rule: a right operand checked as an argument.* When the left operand of
a binary operator other than $`\mathsf{and}` and $`\mathsf{or}` is an
integer literal, the right one is the argument `rhs`, an
$`\mathsf{Int}`, of a method with several overloads, whose misfit is
`noMatchingMethod`. When the left operand's comparison converts a
literal to its type $`t` (`convertsTo`), and the right operand is a
literal that inference typed $`t`, the literal is the argument `other`
of the method, of type $`t`, converted to it as a call's argument is
(#166, #185): an element of another type is a type mismatch, and an
inner literal where an $`\mathsf{Int}` is expected follows the rules of
such literals.
:::

:::readable MojoGrimoire.Check.methodBinaryTy (fingerprint := "10037846033912567083")
*Rule: the result of a binary operator, once its operands are checked.*
A method that an operand's type lacks is `missingMethod`, and a
comparison of arrays or lists that does not fit is its misfit, found
again from the checked types; otherwise such a comparison gives a
$`\mathsf{Bool}`, and any other operator's result is `binaryTy`'s.
:::

:::readable MojoGrimoire.Check.compareOperands (fingerprint := "190374547422127713")
*Rule: the order of a comparison's operands.* The left operand is
checked, then the right one, as an argument when `rightParam` says so,
and the places they read are checked again for what changed after them.
A literal on the left converted to the type of the right operand whose
check fails an initializer, `noMatchingInit`, such as SIMD's constraint
of one element, fails in a later pass than the reads: the right operand
is read first, so that its own error, such as `uninitializedUse`, comes
first, as for a literal on the right.
:::
