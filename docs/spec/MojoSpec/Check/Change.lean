import VersoManual
import MojoGrimoire.Check.Change
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Change`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Changes and late re-checks: readable blocks" =>

:::moduleDocs (fingerprint := "15849310890999484462")
:::

:::readable MojoGrimoire.Check.mark MojoGrimoire.Check.invalidatedBy MojoGrimoire.Check.changePlace MojoGrimoire.Check.changedArgs (fingerprint := "16208851434039671369")
*Rule: changes.* A call changes as a whole each place it is passed `mut`,
and each place it is passed `ref` that the function may change and that
is not reached through `p^`; for a
call that returns a reference passed so, its origins; `append` and `pop`
change their list. The checker records the change once the
call's operands are checked, and marks as invalidated every reference
bound with `ref` whose origin the change invalidates. The mark of an
operand is the number of changes recorded once it is checked.
:::

:::readable MojoGrimoire.Check.Access.subscriptsMutable MojoGrimoire.Check.subscriptsMutable MojoGrimoire.Check.subscript (fingerprint := "745385924708920763")
*Rule: subscripts.* Once the index of $`q[i]` is evaluated, $`q` must
not be invalidated by it, and $`q` is passed to `__getitem__`. An array
passed so as a mutable `self` is changed as a whole, as far as the
references into an element of a list inside it go (#282): with
`v: Array[List[Int], 1]`, the subscript in `print(v[0][0], v[0])`
invalidates `v[0][0]` before it is read, and a `ref` binding to
`v[0][0]` is invalidated by any later subscript of `v`. Its `self` is
mutable when its variable may be changed, is a `ref` parameter, whose
mutability the compiler does not know, or is a reference bound with `ref`
that is subscripted so (`refSubscripts`), and when $`q` is not reached
through $`p\,\hat{}`. A `read` parameter, and a subscript of a list,
change nothing. The references that such a subscript invalidates are kept
apart from the others, as `State.interior` says.
:::

:::readable MojoGrimoire.Check.requireUnchanged MojoGrimoire.Check.recheckLocs MojoGrimoire.Check.lateLocs MojoGrimoire.Check.literalLocs MojoGrimoire.Check.elemLocs MojoGrimoire.Check.recheckPlaces MojoGrimoire.Check.recheckLiterals (fingerprint := "15939276191922570524")
*Rule: places read late.* Mojo reads a place operand only once every
operand of its operation is evaluated, and a place passed by reference is
used during the call. So once the operands are checked, every operand that
is a place must still be initialized: `f(a.id, g(a^))` is a use of `a.id`
after its move. So must every origin of a call that returns a reference
and is a located operand, passed by reference, or read by value, which
Mojo also does only then: `two(first(xs), take(xs^))` and
`print(pick(a, b, True), eat(a^))` are rejected. An origin argument that
is a temporary is left out. It is also rejected as invalidated when a
change recorded after its mark invalidates it: in `print(xs[0], xs.pop())`, `pop` changes
the list that holds `xs[0]` before `xs[0]` is read. A place located once
$`k` changes were recorded is invalidated when a change recorded since
then invalidates it. A literal operand is built from its elements only
once every operand is evaluated, so what its elements read is read late
too: `print([xs[0]], xs.pop())` is rejected (#282). A literal among the
elements of a literal is built in its turn, before the elements after it
are evaluated, so it reads late only what a literal $`[e]_{\mathsf{Int}}`,
the $`\mathsf{Int}` $`e`, reads; that it reads the rest after the
operation's later operands waits for #308.
:::
