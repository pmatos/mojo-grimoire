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

:::moduleDocs (fingerprint := "11146887827271562093")
:::

:::readable MojoGrimoire.Elab.elabPrintOps MojoGrimoire.Elab.elabPrintArgs (fingerprint := "17802690047684658857")
*Definition: the operands of print.* `print` reads its operands once every
operand is evaluated, and a place operand lives until it is done: each
operand is elaborated with the slots live after `print`, those of its
place operands and those that the later operands use live after it. A
subscript that Mojo reads late calls its getter when `print` reads it, so
it is elaborated with only the slots live once `print` has read its
operands, and those of the subscripts read after it: what its getter last
uses dies right after the getter, before `print` writes, and every other
operand keeps the getter's places alive until then, as the places of the
getters before it, and what the later operands use, live as its arguments
are evaluated (#191).
:::

:::readable MojoGrimoire.Elab.elabReturn MojoGrimoire.Elab.elabStmt MojoGrimoire.Elab.elabBlock (fingerprint := "18308385079530767380")
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
  its head live at its end, since the next iteration may use them. Its test
  is elaborated with the slots live at the head live after it. Every slot
  it uses is live there, so the test destroys only the temporaries it
  makes, each time it runs; they are not live at the head (`tempsIn`);
- a `return` gets no drops of its own: its value is elaborated with
  nothing live after it, and returning destroys whatever is still alive.
  When the value is a call that returns a reference, the owned slots it
  points into live until it is read, and die then, in the order of the
  owned slots; a subscript read late keeps only those, its getter
  destroying what else it last uses (#191).

A block elaborates each statement with the slots live after it, and the
types of the variables declared before it.
:::

:::readable MojoGrimoire.Elab.elabBody MojoGrimoire.Elab.ownedParams MojoGrimoire.Elab.paramEnv MojoGrimoire.Elab.elabFun (fingerprint := "18357588521383928537")
*Definition: function bodies.* A function owns its `var` parameters and
its local variables whose values are dropped; when several die at once,
the parameters die first, then the local variables, each the last declared
first. An owned parameter that its body never uses is dropped before the
body runs; the rest of the body is elaborated with nothing live at its
end, the parameters' types, and the references the body binds, which
`slotsOf` finds. The body's temporaries are named first
(`tempBlock`): each hidden variable is a local variable declared where
its temporary is made, so a temporary dies with the values that die
where it does, as the one declared last (#80).
:::

:::readable MojoGrimoire.Elab.elabDeinit (fingerprint := "13967661530387209184")
*Definition: destructors.* In `__deinit__(deinit self)` the fields of
`self` are slots of their own. Those whose values are dropped are owned on
entry, and die in their order when several die at once. So such a field
that the body never uses is destroyed before the body runs, and every
other one right after its own last use, as the compiler does. The body's
temporaries are named as in a function.
:::

:::readable MojoGrimoire.Elab.elabStruct MojoGrimoire.Elab.elabProgram (fingerprint := "9827350811176813833")
*Definition: programs.* A program is elaborated function by function:
every function, initializer, method and destructor.
:::
