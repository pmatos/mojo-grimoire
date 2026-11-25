import VersoManual
import MojoGrimoire.Check.Elems
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Elems`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Elements of literals: readable blocks" =>

:::moduleDocs (fingerprint := "6892036622954281026")
:::

:::readable MojoGrimoire.Check.checkIterableElems (fingerprint := "13926820991139293986")
*Rule: the elements of an iterable literal.* The elements of a literal
$`[e^*]_{?}`, with no type expected, that is the argument of
$`\mathsf{List}[u](\ldots)` are checked in order, each as passed to a
`var` parameter, a nested such literal's elements in turn. Each gives its
type, with the places it is read from once every element is evaluated and
the number of changes recorded once it was checked; `iterableLiteralTy`
gives the literal's type from them. Any other element is checked by the
check that the checker of expressions gives (`Below`).
:::

:::readable MojoGrimoire.Check.intMisfit MojoGrimoire.Check.readIntElems (fingerprint := "17985810138896482431")
*Rule: the elements of a literal of $`\mathsf{Int}`s.* For a literal
$`[e^*]_{\mathsf{Int}}` of any length but 1, `intMisfit` gives the type
of its first element that is no $`\mathsf{Int}`, nor such a literal, each
typed in `State.typing`: a place by the `typePlace` it is given, an
error that the compiler reports later left out; a nested literal by its
own elements; and any other element by the check it is given, one whose
error the compiler reports later having its `lateElemTy`. `readIntElems`
then reads the elements as $`\mathsf{Int}`s passed `var`, a nested such
literal's in turn, and gives what each reads late. `rejectIntLiteral`
reports the misfit, as the rule of expressions says.
:::
