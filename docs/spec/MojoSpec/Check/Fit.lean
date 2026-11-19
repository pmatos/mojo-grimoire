import VersoManual
import MojoGrimoire.Check.Fit
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Fit`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Arguments that do not fit: readable blocks" =>

:::moduleDocs (fingerprint := "1667884896041032981")
:::

:::readable MojoGrimoire.Check.Fit MojoGrimoire.Check.Fit.misfit MojoGrimoire.Check.expectArg (fingerprint := "13691362365005740179")
*Definition: how a call reports a misfit.* A call of a function or a method
reports an argument that does not fit its parameter by the error itself: a
type mismatch, a wrong number of arguments, a value that is not a place or
a place that may not change passed `mut`. An initializer of the type $`t`
reports every such misfit as `noMatchingInit` $`t`, since the compiler
tries every initializer and reports only that none fits (#46). An
argument whose type is not its parameter's is such a misfit.
:::

:::readable MojoGrimoire.Check.passValue (fingerprint := "184049633496572427")
*Rule: passing a value.* A value that is not a place may not be passed
`out` or `deinit`, nor `mut`, which is a misfit of the call.
:::

:::readable MojoGrimoire.Check.iterableFits (fingerprint := "13744519018623115126")
*Rule: a source of $`\mathsf{List}[u](e)`.* The one argument of
$`\mathsf{List}[u](e)` fits the initializer of `List` from any iterable
when its type is a list or an array of $`u`, and $`u` can be copied,
explicitly or implicitly (#103). Any other type fits no initializer, and
is `noMatchingInit` $`\mathsf{List}[u]`.
:::

:::readable MojoGrimoire.Check.literalElem (fingerprint := "11550179997732153358")
*Definition: a literal of an expected type.* A literal of $`n` elements
whose type $`t` is expected where it stands must have a list or an array
type of a valid element type $`u`, and an array type must have the size
$`n`. A size that differs does not fit: an initialization of $`t` reports
it as `noMatchingInit` $`t`, and a conversion for a function's parameter
as a type mismatch.
:::

:::readable MojoGrimoire.Check.iterableLiteralTy (fingerprint := "14437912108218426291")
*Definition: the type of a literal argument of $`\mathsf{List}[u](e)`.*
Given the type of each element of a literal with no type expected, the
literal is an array of the type of its first element, which must be a
type a variable may have. The compiler infers that type while it looks
for an initializer, so a literal with no elements, or an element of
another type, fits no initializer: `noMatchingInit`
$`\mathsf{List}[u]` (#103). The places that the elements are read from
are checked again once every element is evaluated.
:::

:::readable MojoGrimoire.Check.holdsStrOrRange MojoGrimoire.Check.holdsStrOrRangeList (fingerprint := "3244732862091383215")
*Definition: an argument the model cannot type.* An expression holds a
string or a call of `range` when it is one, or a literal or an operator
holds one at any depth. Such an argument of the standard library's `range`
fits none of its forms (#121).
:::

:::readable MojoGrimoire.Check.RangeArgs MojoGrimoire.Check.RangeArgs.append MojoGrimoire.Check.RangeArgs.ofLate MojoGrimoire.Check.intShaped (fingerprint := "15000236733738162497")
*Definition: what the arguments of a range find.* Checking the arguments
of `range` records, in the order of the compiler's passes, whether one
fits no form of `range` once all are typed; the first use of an
uninitialized or invalidated value; whether one is a literal of
$`\mathsf{Int}`s, at any depth, of a length other than 1, which fails when
the call is instantiated; and the first constant index out of range. Two
records join, the first's errors first. An error of a later pass than
typing is a constant index out of range or else a use of a value. A type
is `intShaped` when it is $`\mathsf{Int}` or an array of such.
:::
