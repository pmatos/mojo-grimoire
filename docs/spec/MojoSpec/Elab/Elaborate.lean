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

:::moduleDocs (fingerprint := "16039575607398524349")
:::

:::readable MojoGrimoire.Elab.needsDrop (fingerprint := "8574393401186773807")
*Definition: values that are dropped.* Only values of struct type, and
lists and arrays of values that are dropped. Values of $`\mathsf{Int}`,
$`\mathsf{Bool}`, string and $`\mathsf{None}` type have no destruction a
program can observe.
:::

:::readable MojoGrimoire.Elab.drops (fingerprint := "5696115969548938391")
*Definition: drops.* The `drop` statements for a set of slots, in the
order of the slots the function owns, which is the order in which the
compiler destroys values that die at once: its `var` parameters, then its
local variables, each the last declared first; in `__deinit__`, the fields
of `self` in their order. A slot the function does not own, such as a
borrowed parameter, is never dropped.
:::

:::readable MojoGrimoire.Elab.defs MojoGrimoire.Elab.usesStmt MojoGrimoire.Elab.movesStmt MojoGrimoire.Elab.dying (fingerprint := "14793584096165623495")
*Definition: what dies at a simple statement.* A declaration, `ref`
binding, assignment, expression or `print` uses, moves and defines slots as its parts do; an
assignment to a part of a slot, such as an element or a field, uses the
slot that holds it, and one through a reference the slots it may point
into. The
slots that die right after it are those it uses but does not move away,
and those it defines, unless they are live after it. A value defined and
never used dies right after its definition.
:::

:::readable MojoGrimoire.Elab.declared MojoGrimoire.Elab.declaredBlock (fingerprint := "17446437079533637378")
*Definition: local variables.* The variables of a type whose values are
dropped that a body declares, in order, each once. Variables of sibling blocks may share a
name, and then share a slot, since neither is live in the other.
:::

:::readable MojoGrimoire.Elab.callModes MojoGrimoire.Elab.methodModes (fingerprint := "16327785967890316099")
*Definition: operands passed by value.* A place passed to a `var`
parameter, or an $`\mathsf{Int}` or a $`\mathsf{Bool}` passed to a `read`
one, is passed by value: the call reads it once its arguments are
evaluated. Any other place is passed by reference, and used until the call
returns. The signature of what is called gives each parameter's
convention, so a `@fieldwise_init` struct takes its fields by value,
`append` its list by reference and its element by value, and `pop` its
list by reference and its index by value. `len`, which has no signature,
takes its list by reference. A method's receiver is passed by value only
to a `var self`; the receiver's type, from the variables declared so far,
gives the method.
:::

:::readable MojoGrimoire.Elab.Ctx MojoGrimoire.Elab.directOf MojoGrimoire.Elab.directArgs MojoGrimoire.Elab.opDrops MojoGrimoire.Elab.withDropsOf (fingerprint := "1980529672550102452")
*Definition: what an operation destroys.* Inside a function, elaboration
knows the program, the slots, the slots the function owns in the order they
die, and the types of the variables declared so far. An operation uses
directly the slots of the places among its operands, and those their
index expressions use; its other operands
are operations of their own. Given the slots live once it is done, the
slots it uses by value and nowhere later die once its operands are read,
in the order they are read; those it uses by reference and nowhere later
die once it is done, in the order of the owned slots. Its operands are
evaluated with those slots, and the ones it reads, live after them. An
operation that destroys nothing is left unwrapped.
:::

:::readable MojoGrimoire.Elab.consumedSlot MojoGrimoire.Elab.consumedIn MojoGrimoire.Elab.consumedList (fingerprint := "3815886912729584611")
*Definition: consumed receivers.* A method call on $`q\,\hat{}`, where
$`q` is a whole slot and the method takes `var self`, consumes $`q`: it
moves the value away, and the method destroys it. An expression consumes
the slots that the method calls in it consume, at any depth.
:::

:::readable MojoGrimoire.Elab.elabExpr MojoGrimoire.Elab.elabOps (fingerprint := "4247161697326049752")
*Definition: elaborating expressions.* Each call, method call, operator,
list literal and `.copy()` is wrapped with what it destroys, and its
operands are elaborated in turn, each with the slots that the later
operands use live after it. A place is left as it is. The operation at the
top of a statement leaves what dies once it is done to the statement, as
the compiler destroys a discarded result before those values. The right
operand of `and` and `or` may not run, so it is not elaborated, and the
operation destroys what it uses. A method call never destroys the slot it
consumes, though it uses it.
:::

:::readable MojoGrimoire.Elab.droppedIn MojoGrimoire.Elab.droppedList MojoGrimoire.Elab.droppedOpt MojoGrimoire.Elab.placeUses MojoGrimoire.Elab.envAfter (fingerprint := "17071799620170729577")
*Definition: helpers.* The slots that an elaborated expression destroys;
the slots that the places among a list of operands use; and the types of
the variables after a statement, which a declaration or a `ref` binding
extends.
:::

:::readable MojoGrimoire.Elab.elabStmt MojoGrimoire.Elab.elabBlock (fingerprint := "14342383368461656854")
*Definition: elaboration.* Given the slots live after a statement:

- a simple statement's expressions are elaborated, and the statement is
  followed by the drops of the slots that die at it and that its
  expressions neither destroy nor consume;
- the test of an `if` is elaborated with the slots live at the start of
  either branch live after it, and each branch starts with the drops of
  the slots live before the `if` that the test neither moves, destroys nor
  consumes and that are not live at the start of the branch;
- a `while` loop is followed by the drops of the slots live at its head
  that are dead after it and that its test does not consume, and its body is elaborated with the slots live at
  its head live at its end, since the next iteration may use them; its test
  is left as it is, since every slot it uses is live at the head;
- a `return` gets no drops of its own: its value is elaborated with nothing
  live after it, and returning destroys whatever is still alive.

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
