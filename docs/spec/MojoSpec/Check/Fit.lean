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

:::moduleDocs (fingerprint := "13757989865106505685")
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

:::readable MojoGrimoire.Check.wrongIntLiteral MojoGrimoire.Check.State.typing MojoGrimoire.Check.lateElemTy MojoGrimoire.Check.rejectIntLiteral (fingerprint := "5042045329698814885")
*Rule: a literal of the wrong length where an $`\mathsf{Int}` is
expected.* A literal $`[e^*]_{\mathsf{Int}}` of any length but 1, which
`wrongIntLiteral` picks out, fits no initializer of $`\mathsf{Int}`,
which is $`\mathsf{SIMD}[\mathsf{int}, 1]` (#153, #154). The compiler
types its elements before it reads any. So each element is typed first,
in the state's `State.typing`, where every variable is whole and no
reference invalidated. An element whose check still gives an error that
the compiler reports after its types, one of a later pass or a nested
literal's failed constraint, has its `lateElemTy`: the result of its
operator, call or method, the type of the place it reads, the list that
$`\mathsf{List}[u](e)` builds, an array of its first element, or else
$`\mathsf{Int}`. The first element that is no $`\mathsf{Int}`, nor such
a literal of $`\mathsf{Int}`s, is a misfit, reported before any element
is read: by a function or a method, which converts the literal, as a type
mismatch, and by an initializer of $`t` as `noMatchingInit` $`t`. With no
misfit, the state is restored, the elements are read, and checked again
once each is read, and the compiler then fails SIMD's constraint of one
element: `noMatchingInit` $`\mathsf{Int}`, or $`t` for an initializer of
$`t`. It never returns.
:::
