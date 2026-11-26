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

:::moduleDocs (fingerprint := "4126304478045253151")
:::

:::readable MojoGrimoire.Check.Fit MojoGrimoire.Check.Fit.misfit MojoGrimoire.Check.expectArg (fingerprint := "15738289546311638140")
*Definition: how a call reports a misfit.* A call of a function or a method
reports an argument that does not fit its parameter by the error itself: a
type mismatch, a wrong number of arguments, a value that is not a place or
a place that may not change passed `mut`. An initializer of the type $`t`
reports every such misfit as `noMatchingInit` $`t`, since the compiler
tries every initializer and reports only that none fits (#46). A method
or an operator $`m` with several overloads reports it, a wrong number of
arguments included, as `noMatchingMethod` $`m`, for the same reason
(#88). An argument whose type is not its parameter's is such a misfit.
:::

:::readable MojoGrimoire.Check.passValue (fingerprint := "184049633496572427")
*Rule: passing a value.* A value that is not a place may not be passed
`out` or `deinit`, nor `mut`, which is a misfit of the call.
:::

:::readable MojoGrimoire.Check.notPlaceError (fingerprint := "11750609785983197812")
*Definition: a value passed `mut`.* A value that is not a place, passed
`mut`, is $`\mathsf{notAPlace}`. A subscript of a struct that Mojo reads
late, passed `mut`, such as the receiver of an operator method that takes
`mut self`, is $`\mathsf{notAList}` of its struct, as is any subscript
of a struct used as a place beyond reading and assigning it, whose
write-back is not yet modelled (#198). Either is reported as the call's
fit says.
:::

:::readable MojoGrimoire.Check.iterableFits (fingerprint := "13744519018623115126")
*Rule: a source of $`\mathsf{List}[u](e)`.* The one argument of
$`\mathsf{List}[u](e)` fits the initializer of `List` from any iterable
when its type is a list or an array of $`u`, and $`u` can be copied,
explicitly or implicitly (#103). Any other type fits no initializer, and
is `noMatchingInit` $`\mathsf{List}[u]`.
:::

:::readable MojoGrimoire.Check.rejectHidden (fingerprint := "3061063770040030119")
*Rule: a hidden type.* A type in which a variable hides a name is
`valueAsType` of the name: the type of a declared variable, before any
other error of its declaration, and that of $`\mathsf{List}[u](\ldots)`,
before its arguments are checked, as the compiler does (#193).
:::

:::readable MojoGrimoire.Check.literalElem (fingerprint := "10361419412845338351")
*Definition: a literal of an expected type.* A literal of $`n` elements
whose type $`t` is expected where it stands must have a list or an array
type of an element type $`u` a variable may have (`declarableTy`),
otherwise `valueAsType` when a variable hides a name in $`t`, and an array type must have the size
$`n`. A size that differs does not fit: an initialization of $`t` reports
it as `noMatchingInit` $`t`, and a conversion for a function's parameter
as a type mismatch.
:::

:::readable MojoGrimoire.Check.iterableLiteralTy (fingerprint := "3935624038139464072")
*Definition: the type of a literal argument of $`\mathsf{List}[u](e)`.*
Given the type of each element of a literal with no type expected, the
literal is an array of the type of its first element, which must be a
type a variable may have. The compiler infers that type while it looks
for an initializer, so a literal with no elements, or an element of
another type, fits no initializer: `noMatchingInit`
$`\mathsf{List}[u]` (#103). The places that the elements are read from
are checked again once every element is evaluated.
:::

:::readable MojoGrimoire.Check.holdsStrOrRange MojoGrimoire.Check.holdsStrOrRangeList (fingerprint := "10596365314781892554")
*Definition: an argument the model cannot type.* An expression holds a
string or a call of the standard library's `range` when it is one, or a
literal or an operator holds one at any depth; a function of the program
named `range` is no such call. Such an argument of the standard library's `range`
fits none of its forms (#121).
:::

:::readable MojoGrimoire.Check.RangeArgs MojoGrimoire.Check.RangeArgs.append MojoGrimoire.Check.RangeArgs.ofLate (fingerprint := "9014630784740985675")
*Definition: what reading the arguments of a range finds.* Reading the
arguments of `range`, once they are typed, records the errors of the
compiler's later passes in the order it reports them: the first use of an
uninitialized or invalidated value, then whether a nested literal of
$`\mathsf{Int}`s of the wrong length fails when the call is instantiated,
then the first constant index out of range. It also records the places each argument read without an error
reads late, with its mark. Two records join, the first's errors first. An
error of a later pass than typing is a constant index out of range,
a nested literal's failed constraint, or else a use of a value.
:::

:::readable MojoGrimoire.Check.rangeList (fingerprint := "9415688692766148126")
*Rule: $`\mathsf{List}[u](\mathsf{range}(e^*))`.* The arguments of
`range` are typed first, and the state that typing leaves is dropped.
An argument that fits no form of `range`, no argument or more than three,
or $`u` other than $`\mathsf{Int}` is `noMatchingInit`
$`\mathsf{List}[u]`. Then the arguments are read, and the errors of the
later passes come in the compiler's order: a use of an uninitialized or
invalidated value, the places read late checked again, a literal of
$`\mathsf{Int}`s of the wrong length, `noMatchingInit`
$`\mathsf{List}[u]`, then a constant index out of range (#121). The
call gives a $`\mathsf{List}[\mathsf{Int}]`.
The type phase finds none of the later passes' errors: it skips the uses
and the reads late, the literal and the constant index.
:::

:::readable MojoGrimoire.Check.wrongIntLiteral MojoGrimoire.Check.State.typing MojoGrimoire.Check.lateElemTy MojoGrimoire.Check.rejectIntLiteral (fingerprint := "2483683588594454497")
*Rule: a literal of the wrong length where an $`\mathsf{Int}` is
expected.* A literal $`[e^*]_{\mathsf{Int}}` of any length but 1, which
`wrongIntLiteral` picks out, fits no initializer of $`\mathsf{Int}`,
which is $`\mathsf{SIMD}[\mathsf{int}, 1]` (#153, #154). The compiler
types its elements before it reads any. So each element is typed first,
in the state's `State.typing`, where every variable is whole and no
reference invalidated. An element whose check still gives an error that
the compiler reports after its types, one of a later pass or a nested
literal's failed constraint, has its `lateElemTy`, as has such an
argument of `range` (#121): the result of its
operator, call or method, the type of the place it reads, the list that
$`\mathsf{List}[u](e)` builds, an array of its first element, or else
$`\mathsf{Int}`. The first element that is no $`\mathsf{Int}`, nor such
a literal of $`\mathsf{Int}`s, is a misfit, reported before any element
is read: by a function or a method, which converts the literal, as a type
mismatch, and by an initializer of $`t` as `noMatchingInit` $`t`. With no
misfit, the state is restored, the elements are read, and checked again
once each is read, and the compiler then fails SIMD's constraint of one
element: `noMatchingInit` $`\mathsf{Int}`, or $`t` for an initializer of
$`t`; a method or an operator with several overloads keeps
`noMatchingInit` $`\mathsf{Int}`, since the literal fits the overload
that takes an $`\mathsf{Int}` and fails once it is chosen (#169). In the
flow phase it never returns. The type phase skips that failure of
instantiation: there the literal passes once its elements are read.
:::
