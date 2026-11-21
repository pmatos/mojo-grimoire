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

:::moduleDocs (fingerprint := "15206183391366332892")
:::

:::readable MojoGrimoire.Check.mark MojoGrimoire.Check.changePlace MojoGrimoire.Check.changedArgs (fingerprint := "8696379794358549962")
*Rule: changes.* A call changes as a whole each place it is passed `mut`,
and each place it is passed `ref` that the function may change and that
is not reached through `p^`; for a
call that returns a reference passed so, its origins; `append` and `pop`
change their list. The checker records the change once the
call's operands are checked, and marks as invalidated every reference
bound with `ref` whose origin the change invalidates. The mark of an
operand is the number of changes recorded once it is checked.
:::

:::readable MojoGrimoire.Check.requireUnchanged MojoGrimoire.Check.recheckLocs MojoGrimoire.Check.lateLocs MojoGrimoire.Check.recheckPlaces (fingerprint := "14336978713369692125")
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
then invalidates it.
:::
