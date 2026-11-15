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

:::moduleDocs (fingerprint := "11614065151354432943")
:::

:::readable MojoGrimoire.Elab.needsDrop (fingerprint := "15115138920881222977")
*Definition: values that are dropped.* Only values of struct type. Values
of $`\mathsf{Int}`, $`\mathsf{Bool}` and string type have no destruction a
program can observe.
:::

:::readable MojoGrimoire.Elab.drops (fingerprint := "15437604090103189340")
*Definition: drops.* The `drop` statements for a set of slots, in the
order of the slots the function owns: its `var` parameters, then its local
variables in order of declaration. A slot the function does not own, such
as a borrowed parameter, is never dropped.
:::

:::readable MojoGrimoire.Elab.defs MojoGrimoire.Elab.usesStmt MojoGrimoire.Elab.movesStmt MojoGrimoire.Elab.dying (fingerprint := "5419894816775520890")
*Definition: what dies at a simple statement.* A declaration, assignment,
expression or `print` uses, moves and defines slots as its parts do. The
slots that die right after it are those it uses but does not move away,
and those it defines, unless they are live after it. A value defined and
never used dies right after its definition.
:::

:::readable MojoGrimoire.Elab.declared MojoGrimoire.Elab.declaredBlock (fingerprint := "898749486316296204")
*Definition: local variables.* The variables of struct type that a body
declares, in order, each once. Variables of sibling blocks may share a
name, and then share a slot, since neither is live in the other.
:::

:::readable MojoGrimoire.Elab.elabStmt MojoGrimoire.Elab.elabBlock (fingerprint := "464646655348832722")
*Definition: elaboration.* Given the slots live after a statement:

- a simple statement is followed by the drops of the slots that die at it;
- each branch of an `if` starts with the drops of the slots live before the
  `if` that the test does not move and the branch never uses;
- a `while` loop is followed by the drops of the slots live at its head
  that are dead after it, and its body is elaborated with the slots live at
  its head live at its end, since the next iteration may use them;
- a `return` gets no drops: returning destroys whatever is still alive.

A block elaborates each statement with the slots live after it.
:::

:::readable MojoGrimoire.Elab.elabBody MojoGrimoire.Elab.ownedParams MojoGrimoire.Elab.elabFun (fingerprint := "15755492251377003521")
*Definition: function bodies.* A function owns its `var` parameters of
struct type and its local variables of struct type. A `var` parameter its
body never uses is dropped before the body runs; the rest of the body is
elaborated with nothing live at its end.
:::

:::readable MojoGrimoire.Elab.elabDeinit (fingerprint := "4508317085367363934")
*Definition: destructors.* In `__deinit__(deinit self)` the fields of
`self` are slots of their own, owned on entry. So a field the body never
uses is destroyed before the body runs, and every other field right after
its own last use, as the compiler does.
:::

:::readable MojoGrimoire.Elab.elabStruct MojoGrimoire.Elab.elabProgram (fingerprint := "8120113390903795418")
*Definition: programs.* A program is elaborated function by function:
every function, initializer, method and destructor.
:::
