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

:::moduleDocs (fingerprint := "4410575708631120963")
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

:::readable MojoGrimoire.Check.iterableFits (fingerprint := "8966902570167571758")
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
