import VersoManual
import MojoGrimoire.Check.Range
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Range`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "The arguments of range: readable blocks" =>

:::moduleDocs (fingerprint := "11904756722083066207")
:::

:::readable MojoGrimoire.Check.typeLiteral MojoGrimoire.Check.typeRangeArgs (fingerprint := "11531330452791615058")
*Rule: typing the arguments of `range`.* Each argument of the standard
library's `range` in the argument of $`\mathsf{List}[u](\ldots)` is typed
in the type phase (`typing`) by the `typeArg` that the checker of expressions gives,
and an open literal by its elements, at any depth. The typing gives whether
an argument fits no form of `range`: one that is not an
$`\mathsf{Int}`, or an open literal with an element that is not, at any
depth, or, as the first argument, a literal whose first element, at any
depth, is an empty literal. It also gives whether an argument is an open
literal of $`\mathsf{Int}`s, which the compiler takes for an
$`\mathsf{Int}` and rejects only when it instantiates the call (#121).
:::

:::readable MojoGrimoire.Check.readRangeArgs (fingerprint := "8675768994125759930")
*Rule: reading the arguments of `range`.* The arguments are then read in
order as $`\mathsf{Int}`s passed to `read` parameters, and an open
literal's elements in turn: a place once the `checkIndices` it is given
has checked its indices, and any other argument by the check it is given.
An error of the instantiation phase is recorded (`lateErrors`), and the
arguments and elements after it are still read, so that `rangeList`
reports the passes in the compiler's order.
:::
