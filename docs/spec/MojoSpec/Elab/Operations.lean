import VersoManual
import MojoGrimoire.Elab.Operations
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Elab.Operations`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Elaborating operations: readable blocks" =>

:::moduleDocs (fingerprint := "11071766344013542632")
:::

:::readable MojoGrimoire.Elab.droppedIn MojoGrimoire.Elab.droppedList (fingerprint := "1383764278707033588")
*Definition: what an elaborated expression destroys.* The slots that the
drops of an elaborated expression, or list of operands, name, at every
depth, also inside the argument of $`\mathsf{List}[u](e)`.
:::

:::readable MojoGrimoire.Elab.Elaborated MojoGrimoire.Elab.Elaborated.op (fingerprint := "14122874099859979553")
*Definition: an elaboration.* An elaborated expression, or list of
operands, with the slots that the input uses and those that the
elaborated form destroys. An elaborated operation is wrapped with what it
destroys once its operands are read and once it is done, and destroys
those slots before the ones its operands destroy.
:::

:::readable MojoGrimoire.Elab.elabExpr MojoGrimoire.Elab.elabOps MojoGrimoire.Elab.elabLate (fingerprint := "1757302389012888379")
*Definition: elaborating expressions.* Each call, method call, operator,
list literal, $`\mathsf{List}[u](e)` and `.copy()` is wrapped with what it
destroys, and its operands are elaborated in turn, each with the slots that the later
operands use, and the places of the subscripts read late before it, live
after it. A subscript read late whose getter returns a value is read only
once every operand is evaluated: it is elaborated with the slots live
then and those of the subscripts read late after it, so its getter
destroys what it last uses right after it is called, while the places of
those read late before it, and what the later operands use, live as its
arguments are evaluated, in operand order (#191).
On the left of `and` or `or`, a subscript read late is elaborated as a
call of its getter made as it is evaluated, as a subscript of a struct
with no setter is, so it destroys what its index last uses before its
getter is called; the compiler reads it again there, a bug (D-0011,
#211). As the right operand, such a subscript keeps only what its
reference points into. A place is left as it is, and a literal
$`[e]_{\mathsf{Int}}` has only its element elaborated: the operation that
reads it destroys what its element uses. The operation at the
top of a statement leaves what dies once it is done to the statement, as
the compiler destroys a discarded result before those values. The right
operand of `and` and `or` may not run: elaborated with the slots live
after the operation, and those that a call of it returning a reference
points into (`opKeep`), it destroys what it uses once it is read when it
runs, and the operation destroys what it uses when it does not, before
what the left operand last uses, which dies once that is tested (#191).
A method call never destroys the slot it
consumes, though it uses it. The argument of $`\mathsf{List}[u](e)` is
used by reference, as that of `len`, so a value whose last use it is dies
once the new list is built. So is an operand of a comparison of two
arrays or two lists, a place or a call that returns a reference, which
the comparison reads by reference (`MojoGrimoire.Check.byRef`, #166,
#185): what it last uses dies once the comparison is done.

Each elaboration also gives the slots that the expression uses and those
that its elaborated form destroys, built from those of its operands. The
later operands are elaborated first, so that an operand finds what those
after it use without walking them again.
:::

:::readable MojoGrimoire.Elab.droppedIn_withDropsOf (fingerprint := "4372154141026476684")
*Lemma.* An operation that elaboration wraps destroys what its wrapper
names, then what its operands destroy.
:::

:::readable MojoGrimoire.Elab.elabExpr_uses MojoGrimoire.Elab.elabOps_uses MojoGrimoire.Elab.elabLate_uses MojoGrimoire.Elab.elabExpr_dropped MojoGrimoire.Elab.elabOps_dropped MojoGrimoire.Elab.elabLate_dropped (fingerprint := "9983275770642050946")
*Lemma: elaboration finds uses and drops.* The slots that an elaboration
gives as used are those that the expression, or list of operands, uses,
and the slots it gives as destroyed are those that its elaborated form
destroys. So each operation decides its drops as it would by walking its
operands again, and a right-nested chain of operators, such as
$`a\ \mathsf{and}\ (b\ \mathsf{or}\ \ldots)` or $`k + (k + \ldots)`, is elaborated
in time linear in its depth (#283). The proofs are by mutual induction on
expressions and lists of them.
:::
