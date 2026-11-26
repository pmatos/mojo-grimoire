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

:::moduleDocs (fingerprint := "2003819829620663284")
:::

:::readable MojoGrimoire.Check.seqCompare MojoGrimoire.Check.seqCompare.modelled MojoGrimoire.Check.seqCompare.conforms (fingerprint := "11022081997966745842")
*Definition: comparable arrays and lists.* Two arrays compare when their element type
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

:::readable MojoGrimoire.Check.convertsTo MojoGrimoire.Check.literalFits MojoGrimoire.Check.elemsFit (fingerprint := "7642984156404013587")
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
only its own type, as the operand's form gives it, and so does a literal
that has a type, such as `List[u]()` or one that inference typed. A literal fits no
other type, except that whether one fits $`\mathsf{Bool}` is left to
#165: that fit, and the fit of an element whose type the form does not
give, is unknown, and so is the fit of a literal with an unknown element
and no element that does not fit. On the left, so is the fit of an
inner literal of another length than one where an $`\mathsf{Int}` is
expected: the order of SIMD's failure and the reads waits for #338, and
such a literal keeps the checks it had before #166.
Off the left, such an inner literal fits as the compiler types it, which
the type phase uses (`typedSimdLeft`).
:::

:::readable MojoGrimoire.Check.nestedTest MojoGrimoire.Check.lackingTy (fingerprint := "7903400112366600565")
*Rule: the operands of a test.* For $`\mathsf{and}` and
$`\mathsf{or}`, the misfit needs of an operand only whether its form
gives a type that lacks `__bool__`, such as a struct without it, an
array or `None` (`lackingTy`): a nested test gives one only when both of
its operands give it, so its operand that is no test is asked first, and
when that gives none, the form of the whole nested test is not computed,
which keeps the check of a chain of tests linear in its length.
:::

:::readable MojoGrimoire.Check.literalTy MojoGrimoire.Check.holdsLiteral MojoGrimoire.Check.operandFit MojoGrimoire.Check.fitTy MojoGrimoire.Check.operandMisfit MojoGrimoire.Check.byRef (fingerprint := "12444868017315229753")
*Rule: operands of a comparison of arrays or lists.* The misfit of a
binary operator is found from its operands' forms before they are read
(`operandTy`).
Any operator but a comparison keeps the checks it had before #166, and
$`\mathsf{and}` and $`\mathsf{or}` ask of their operands only what
`lackingTy` gives. A literal on the right of a comparison is converted to
the type of the left operand, and one on the left to the type of the
right operand unless that is a literal too; a literal that fits takes
that type (`operandFit`, `fitTy`). A literal on the right that does not
fit, or one on the left that does not fit and has a type of its own, is
a type mismatch, before the operands are read. A literal on the left
that does not fit keeps its own type, and the right operand is then
converted to it. A comparison with a literal that holds a place whose
value is not implicitly copyable takes the checks it had before #166
(`keepsBefore`). A literal whose fit is unknown gives no type, and is
left to the checks that follow, as before #166. A $`\mathsf{Bool}` on
the left of an empty literal with no type is a type mismatch, on this
path and the one before #166 (`boolLiteralMisfit`). An integer literal on
the left gives no type, so that its overloads report a comparison with
an array or a list (`noMatchingMethod`). An operand compared as an array
or a list is passed by reference, as the comparisons of `Array` and
`List` take a `read` argument: a place, or a call that returns a
reference, is read, uncopied; but not beside a literal whose fit is
unknown and which inference did not give the operand's type, beside a
list, or an array when that literal holds a literal.
:::

:::readable MojoGrimoire.Check.literalPlaces MojoGrimoire.Check.placesOf MojoGrimoire.Check.heldCopy MojoGrimoire.Check.emptyList MojoGrimoire.Check.keepsBefore MojoGrimoire.Check.Before.holdsLiteral MojoGrimoire.Check.Before.convertsLiteral MojoGrimoire.Check.Before.operandMisfit MojoGrimoire.Check.Before.byRef MojoGrimoire.Check.Before.rightParam (fingerprint := "7518772121282594310")
*Rule: comparisons that keep the checks they had before #166.* A
literal holds the places that are its elements, at any depth. A
comparison of which either operand is a literal that holds a place whose
value is not implicitly copyable, or is an empty list built by
`List[u]()`, which is no literal the compiler converts, keeps every
check it had before #166:
the compiler builds such a literal, and copies the place, in an order
against the literal's conversion and the comparison's misfit that waits
for #338. In a program checked as `main` did, every comparison keeps
them. Before #166, a comparison with a literal that the compiler
converts, one that holds a literal with types not known to be the same,
or one with no type of its own beside a list, found no misfit from the
forms of its operands, passed neither by reference, and checked only a
literal on the right of $`==` or $`!=` of a list as the argument `other`
of the list's type. A $`\mathsf{Bool}` compared with an empty literal is
a type mismatch there too (`boolLiteralMisfit`, #286).
:::

:::readable MojoGrimoire.Check.rightParam MojoGrimoire.Check.rightParamOf (fingerprint := "10936977070781752747")
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
such literals. A comparison that keeps the checks it had before #166
(`keepsBefore`) checks its right operand by `Before.rightParam` instead,
and which of the two applies is decided before the left operand is read
(`rightParamOf`).
:::

:::readable MojoGrimoire.Check.methodBinaryTy (fingerprint := "6442713632575443771")
*Rule: the result of a binary operator, once its operands are checked.*
A method that an operand's type lacks is `missingMethod`, and a
comparison of arrays or lists that does not fit is its misfit, found
again from the checked types; otherwise $`\mathsf{and}` and
$`\mathsf{or}` on operands of the same struct type give the operand that
decides, of that type: each place operand was copied, implicitly (#191);
such a comparison gives a $`\mathsf{Bool}`, and any other operator's
result is `binaryTy`'s.
:::
