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

:::moduleDocs (fingerprint := "15173989851661100415")
:::

:::readable MojoGrimoire.Elab.callModes MojoGrimoire.Elab.methodModes (fingerprint := "8918438346001052769")
*Definition: operands passed by value.* A place passed to a `var`
parameter, or an $`\mathsf{Int}` or a $`\mathsf{Bool}` passed to a `read`
one, is passed by value: the call reads it once its arguments are
evaluated. Any other place is passed by reference, and used until the call
returns. The signature of what is called gives each parameter's
convention, so a `@fieldwise_init` struct takes its fields by value,
`append` its list by reference and its element by value, and `pop` its
list by reference and its index by value. `len`, which has no signature,
takes its list by reference, and the standard library's `range` its
$`\mathsf{Int}`s by value (#121). A method's receiver is passed by value only
to a `var self`; the receiver's type, from the variables declared so far,
gives the method.
:::

:::readable MojoGrimoire.Elab.Ctx MojoGrimoire.Elab.directOf MojoGrimoire.Elab.opKeep MojoGrimoire.Elab.directArgs MojoGrimoire.Elab.opDrops MojoGrimoire.Elab.withDropsOf (fingerprint := "6670769228017152069")
*Definition: what an operation destroys.* Inside a function, elaboration
knows the program, the slots, the slots the function owns in the order they
die, and the types of the variables declared so far. An operation uses
directly the slots of the places among its operands, and those their
index expressions use, and, by reference, the slots that a call returning
a reference passed by reference points into, so that they outlive it:
`len(first(xs))` destroys `xs` once `len` is done. By value, it uses the
owned slots that such a call read by value points into, in the order of
the owned slots, since Mojo reads the reference only once every operand
is evaluated. A literal $`[e]_{\mathsf{Int}}` uses what $`e` uses, by
value, since Mojo reads it as it reads $`e` (#103). Its other operands
are operations of their own. Given the slots live once it is done, the
slots it uses by value and nowhere later die once its operands are read,
in the order they are read; those it uses by reference and nowhere later
die once it is done, in the order of the owned slots. Its operands are
evaluated with those slots, and the ones it reads, live after them. An
operation that destroys nothing is left unwrapped.
:::

:::readable MojoGrimoire.Elab.consumedSlot MojoGrimoire.Elab.consumedIn MojoGrimoire.Elab.consumedList (fingerprint := "1304641025228155356")
*Definition: consumed receivers.* A method call on $`q\,\hat{}`, where
$`q` is a whole slot and the method takes `var self`, consumes $`q`: it
moves the value away, and the method destroys it. An expression consumes
the slots that the method calls in it consume, at any depth, also inside
the argument of $`\mathsf{List}[u](e)`.
:::

:::readable MojoGrimoire.Elab.droppedIn MojoGrimoire.Elab.droppedList (fingerprint := "8181381296588003787")
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

:::readable MojoGrimoire.Elab.elabExpr MojoGrimoire.Elab.elabOps (fingerprint := "1860024666557582413")
*Definition: elaborating expressions.* Each call, method call, operator,
list literal, $`\mathsf{List}[u](e)` and `.copy()` is wrapped with what it
destroys, and its operands are elaborated in turn, each with the slots that the later
operands use live after it. A place is left as it is, and a literal
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

:::readable MojoGrimoire.Elab.elabExpr_uses MojoGrimoire.Elab.elabOps_uses MojoGrimoire.Elab.elabExpr_dropped MojoGrimoire.Elab.elabOps_dropped (fingerprint := "3444364245793344875")
*Lemma: elaboration finds uses and drops.* The slots that an elaboration
gives as used are those that the expression, or list of operands, uses,
and the slots it gives as destroyed are those that its elaborated form
destroys. So each operation decides its drops as it would by walking its
operands again, and a right-nested chain of operators, such as
$`a\ \mathsf{and}\ (b\ \mathsf{or}\ \ldots)` or $`k + (k + \ldots)`, is elaborated
in time linear in its depth (#283). The proofs are by mutual induction on
expressions and lists of them.
:::
