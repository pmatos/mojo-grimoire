import VersoManual
import MojoGrimoire.Elab.Elaborate
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Elab.Elaborate`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "ASAP elaboration: readable blocks" =>

:::moduleDocs (fingerprint := "730968381018173176")
:::

:::readable MojoGrimoire.Elab.Ctx MojoGrimoire.Elab.locOperand MojoGrimoire.Elab.directOf MojoGrimoire.Elab.opKeep MojoGrimoire.Elab.directArgs MojoGrimoire.Elab.placeUses MojoGrimoire.Elab.opDrops MojoGrimoire.Elab.withDropsOf (fingerprint := "9300171350076979394")
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
value, since Mojo reads it as it reads $`e` (#103). A subscript of a
struct that Mojo reads late (`lateGetter`) uses the places among its
getter's arguments, its receiver among them, by value, as a call
returning a reference does when its getter returns one; one whose getter
returns a value uses nothing directly, since its getter, called once the
operands are read, destroys what it last uses (#191). Its other operands
are operations of their own. Given the slots live once it is done, the
slots it uses by value and nowhere later die once its operands are read,
in the order they are read; those it uses by reference and nowhere later
die once it is done, in the order of the owned slots. Its operands are
evaluated with those slots, and the ones it reads, live after them. An
operation that destroys nothing is left unwrapped. An operand read once
it is done keeps alive what a call's reference points into, and for a
subscript read late only that. The slots that a list
of operands read by reference uses directly are the union of theirs.
:::

:::readable MojoGrimoire.Elab.consumedSlot MojoGrimoire.Elab.consumedIn MojoGrimoire.Elab.consumedList (fingerprint := "1304641025228155356")
*Definition: consumed receivers.* A method call on $`q\,\hat{}`, where
$`q` is a whole slot and the method takes `var self`, consumes $`q`: it
moves the value away, and the method destroys it. An expression consumes
the slots that the method calls in it consume, at any depth, also inside
the argument of $`\mathsf{List}[u](e)`.
:::

:::readable MojoGrimoire.Elab.elabExpr MojoGrimoire.Elab.elabOps MojoGrimoire.Elab.elabLate (fingerprint := "14889608858862996066")
*Definition: elaborating expressions.* Each call, method call, operator,
list literal, $`\mathsf{List}[u](e)` and `.copy()` is wrapped with what it
destroys, and its operands are elaborated in turn, each with the slots that the later
operands use, and the places of the subscripts read late before it, live
after it. A subscript read late whose getter returns a value is read only
once every operand is evaluated: it is elaborated with the slots live
then and those of the subscripts read late after it, so its getter
destroys what it last uses right after it is called, while the places of
those read late before it live as its arguments are evaluated (#191).
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
arrays, a place or a call that returns a reference, which the comparison
reads by reference (`MojoGrimoire.Check.byRef`, #166): what it last uses
dies once the comparison is done.
:::

:::readable MojoGrimoire.Elab.droppedIn MojoGrimoire.Elab.droppedList MojoGrimoire.Elab.droppedOpt MojoGrimoire.Elab.envAfter (fingerprint := "148560885156345098")
*Definition: helpers.* The slots that an elaborated expression destroys,
also inside the argument of $`\mathsf{List}[u](e)`; and the types of
the variables after a statement, which a declaration or a `ref` binding
extends.
:::

:::readable MojoGrimoire.Elab.elabPrintOps MojoGrimoire.Elab.elabPrintArgs (fingerprint := "13326758052447682054")
*Definition: the operands of print.* `print` reads its operands once every
operand is evaluated, and a place operand lives until it is done: each
operand is elaborated with the slots live after `print`, those of its
place operands and those that the later operands use live after it. A
subscript that Mojo reads late calls its getter when `print` reads it, so
it is elaborated with only the slots live once `print` has read its
operands, and those of the subscripts read after it: what its getter last
uses dies right after the getter, before `print` writes, and every other
operand keeps the getter's places alive until then, as the places of the
getters before it live as its arguments are evaluated (#191).
:::

:::readable MojoGrimoire.Elab.elabReturn MojoGrimoire.Elab.elabStmt MojoGrimoire.Elab.elabBlock (fingerprint := "12807690894885017943")
*Definition: elaboration.* Given the slots live after a statement:

- a simple statement's expressions are elaborated, and the statement is
  followed by the drops of the slots that die at it, given what its
  expressions destroy or consume; the operands of `print` are elaborated
  by `elabPrintArgs`. The value that an assignment to a whole slot
  replaces is not live after its expression, whether or not the new one
  is;
- the test of an `if` is elaborated with the slots live at the start of
  either branch live after it, and each branch starts with the drops of
  the slots live before the `if` that the test neither moves, destroys nor
  consumes and that are not live at the start of the branch;
- a `while` loop is followed by the drops of the slots live at its head
  that are dead after it and that its test does not consume, and its body is elaborated with the slots live at
  its head live at its end, since the next iteration may use them; its test
  is left as it is, since every slot it uses is live at the head;
- a `return` gets no drops of its own: its value is elaborated with
  nothing live after it, and returning destroys whatever is still alive.
  When the value is a call that returns a reference, the owned slots it
  points into live until it is read, and die then, in the order of the
  owned slots; a subscript read late keeps only those, its getter
  destroying what else it last uses (#191).

A block elaborates each statement with the slots live after it, and the
types of the variables declared before it.
:::

:::readable MojoGrimoire.Elab.elabBody MojoGrimoire.Elab.ownedParams MojoGrimoire.Elab.paramEnv MojoGrimoire.Elab.elabFun (fingerprint := "16178615905400234092")
*Definition: function bodies.* A function owns its `var` parameters and
its local variables whose values are dropped; when several die at once,
the parameters die first, then the local variables, each the last declared
first. An owned parameter that its body never uses is dropped before the
body runs; the rest of the body is elaborated with nothing live at its
end, the parameters' types, and the references the body binds, which
`slotsOf` finds.
:::

:::readable MojoGrimoire.Elab.elabDeinit (fingerprint := "15846165684164288143")
*Definition: destructors.* In `__deinit__(deinit self)` the fields of
`self` are slots of their own. Those whose values are dropped are owned on
entry, and die in their order when several die at once. So such a field
that the body never uses is destroyed before the body runs, and every
other one right after its own last use, as the compiler does.
:::

:::readable MojoGrimoire.Elab.elabStruct MojoGrimoire.Elab.elabProgram (fingerprint := "8521216551808215384")
*Definition: programs.* A program is elaborated function by function:
every function, initializer, method and destructor.
:::
