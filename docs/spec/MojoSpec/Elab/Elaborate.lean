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

:::moduleDocs (fingerprint := "3809248701040443006")
:::

:::readable MojoGrimoire.Elab.needsDrop (fingerprint := "8076625837927918720")
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

:::readable MojoGrimoire.Elab.defs MojoGrimoire.Elab.usesStmt MojoGrimoire.Elab.movesStmt MojoGrimoire.Elab.dying (fingerprint := "1628413221074025610")
*Definition: what dies at a simple statement.* A declaration, `ref`
binding, assignment, expression or `print` uses, moves and defines slots as its parts do; an
assignment to a part of a slot, such as an element or a field, uses the
slot that holds it, and one through a reference the slots it may point
into. The
slots that die right after it are those it uses but neither moves away nor
destroys or consumes in its expressions, and those it defines, unless they
are live after it. A value defined and never used dies right after its
definition, even when the expression that gives it destroys or consumes
the old value of the same slot, as `s = s^.consume()` does: what the
expression destroys or consumes dies before the statement defines
anything.
:::

:::readable MojoGrimoire.Elab.declared MojoGrimoire.Elab.declaredBlock (fingerprint := "17446437079533637378")
*Definition: local variables.* The variables of a type whose values are
dropped that a body declares, in order, each once. Variables of sibling blocks may share a
name, and then share a slot, since neither is live in the other.
:::

:::readable MojoGrimoire.Elab.placeUses MojoGrimoire.Elab.envAfter (fingerprint := "13050787995386939579")
*Definition: helpers.* The slots that a list of operands read by reference
uses directly, and the types of the variables after a statement, which a
declaration or a `ref` binding extends.
:::

:::readable MojoGrimoire.Elab.elabReturn MojoGrimoire.Elab.elabStmt MojoGrimoire.Elab.elabBlock (fingerprint := "3429393690790417993")
*Definition: elaboration.* Given the slots live after a statement:

- a simple statement's expressions are elaborated, and the statement is
  followed by the drops of the slots that die at it, given what its
  expressions destroy or consume. The value that an assignment to a whole
  slot replaces is not live after its expression, whether or not the new
  one is;
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
  owned slots.

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

:::readable MojoGrimoire.Elab.elabStruct MojoGrimoire.Elab.elabProgram (fingerprint := "16301212516985014332")
*Definition: programs.* A program is elaborated function by function:
every function, initializer, method and destructor.
:::
