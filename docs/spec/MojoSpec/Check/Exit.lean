import VersoManual
import MojoGrimoire.Check.Exit
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Exit`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Ends, exits, joins and loops: readable blocks" =>

:::moduleDocs (fingerprint := "9653002926282475736")
:::

:::readable MojoGrimoire.Check.holdsAll (fingerprint := "14941134587914973476")
*Definition: holding a part whole.* The parts $`H` hold all of the part
$`q` when one of them is at or above $`q`, or $`q` is a struct and they
hold each of its fields. A part held whole whose field was moved out and
assigned again is recorded as its fields, which hold all of it.
:::

:::readable MojoGrimoire.Check.partlyBuilt MojoGrimoire.Check.cannotEnd MojoGrimoire.Check.checkEnd (fingerprint := "4637612087144218755")
*Rule: the end of a variable.* The compiler destroys a struct whole, so a
variable may not end when it still holds a part, in $`H`, and a field is
in $`M`, moved out and not assigned again, or $`\epsilon` is in both
$`M` and $`P`, so that it was moved out whole and then built from its
fields. A variable that holds nothing may end with fields moved out, since
nothing of it is destroyed (#51), unless a field in $`M` is at or below a
touched part in $`T`: a field moved out of a part held whole, or out of
one whose inside was assigned. Nor may it end partly built, however it got
there, which is the human's ruling R on D-0003, provisional until it is
discussed with Modular. It is partly built when a part $`u` in $`U` and a
different part $`h` in $`H` meet: disjoint, or $`h` above $`u`, or
$`u` above $`h` while $`H` does not hold all of $`u`; or when a piece
in $`P` with a part of $`U` at or above it has a part of $`H` at,
above or below it. Since $`U`, $`H` and $`P` hold what may be so on
some path, a field uninitialized on one path and held on another counts,
as the compiler counts a field moved out on one path only. A part held
whole on every path that holds it does not, as for a variable assigned
whole in only one branch; a part built from its fields is a piece, which
counts even when the join of $`H` folded its fields into it. This
rejects a struct built in only one branch of an `if`, even wholly, or in
a loop, and a struct whose fields are all `Int`s too. The `self` of
`__init__` built wholly in one branch is not, since it is whole once its
fields are, and is no piece then. The `self` of
`__deinit__` is destroyed field by field: each of its fields is a value
of its own, which may stay moved out. Each error is
$`\mathsf{partiallyDestroyed}`.
It is a check of the flow phase's last stage, `ends` (`flowThrowAt`),
which the type phase skips: the compiler reports it after a function's
other flow errors (#159).
:::

:::readable MojoGrimoire.Check.checkExit (fingerprint := "5193778193178771892")
*Rule: a return.* When a function returns, each `mut` parameter and the
`self` of `__init__` must be wholly initialized, since the caller holds
them, with no piece in $`P`: otherwise the error is
$`\mathsf{uninitializedAtExit}`, or a use of the variable when it is
itself the only piece and nothing of it is uninitialized, as the compiler
reports. The `mut` parameters are checked in their order, then the
`self` of `__init__`, as the compiler reports them. Every variable must
then be allowed to end; the parameters are checked first, since the
compiler reports a parameter left uninitialized before a variable that may
not end.
The whole check is the flow phase's, a use's stage, but for a variable
that may not end, which is the last stage's.
:::

:::readable MojoGrimoire.Check.endScope (fingerprint := "4884605194247682373")
*Rule: the end of a scope.* The variables a block declared end with it,
each checked as above if the end of the block is reached, and leave the
sets of invalidated references.
:::

:::readable MojoGrimoire.Check.joinUninit MojoGrimoire.Check.joinMay MojoGrimoire.Check.joinStates (fingerprint := "17266608188786013820")
*Rule: joining branches.* After an `if`, a part is uninitialized when
either branch leaves it so, and may hold a value when either branch may;
$`M`, $`T` and $`P` are the unions of the branches' sets, and
a reference is invalidated when either branch invalidates it. A branch
that cannot reach its end, because it returned, does not count. A loop
joins $`M`, $`H`, $`T` and $`P` the same way, as described below.
:::

:::readable MojoGrimoire.Check.checkLoop (fingerprint := "11520629417625361493")
*Rule: loops.* A loop body that can reach its end must leave initialized
every part that was initialized before the loop, and may not add to $`M` a
part that was initialized before it, or its next iteration would use a
moved value. A part uninitialized before the loop may be assigned and
moved out in each iteration. As Mojo does, the
checker reports such a part as a use of an uninitialized value.
The check is the flow phase's.
:::
