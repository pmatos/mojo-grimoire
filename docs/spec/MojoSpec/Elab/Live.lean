import VersoManual
import MojoGrimoire.Elab.Live
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Elab.Live`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Uses, moves and liveness: readable blocks" =>

:::moduleDocs (fingerprint := "7911769236395021182")
:::

:::readable MojoGrimoire.Elab.Slots MojoGrimoire.Elab.Slots.of MojoGrimoire.Elab.Slots.isSlot (fingerprint := "3465937767195176188")
*Definition: slots.* A slot is what elaboration destroys on its own. It is
a variable, except in `__deinit__`, where each field $`f` of `self` is
the slot $`\mathit{self}.f`. A use of a place touches the slot of its
variable, through any $`p\,\hat{}` on the way; in `__deinit__`, a use of $`\mathit{self}.f.\ldots` touches
$`\mathit{self}.f`, and a use of `self` itself touches every field. A
place is a whole slot when transferring it or assigning to it moves or
defines the slot: a variable, other than `self` in `__deinit__`, or a
field of `self` there. A
reference is no slot: a use of it touches every slot it may point into, so
that their values live as long as it is used.
:::

:::readable MojoGrimoire.Elab.diff (fingerprint := "9653185907753345644")
*Definition: sets of slots.* Sets of slots are lists without repeats, kept
in the order they are found. Their union $`A \cup B` is the checker's;
$`A \setminus B` keeps the slots of $`A` not in $`B`.
:::

:::readable MojoGrimoire.Elab.indexUses MojoGrimoire.Elab.uses MojoGrimoire.Elab.usesList (fingerprint := "16851513916571064759")
*Definition: uses.* An expression uses the slots of every place it reads,
copies, transfers or calls a method on, the slots its index expressions
use, and those of its arguments. A use of an element of a list or an
array uses the slot of the list or array.
:::

:::readable MojoGrimoire.Elab.indexMoves MojoGrimoire.Elab.moves MojoGrimoire.Elab.movesList (fingerprint := "15611526501584066692")
*Definition: moves.* An expression moves away the whole slots it
transfers with `^`. Transferring a part of a slot does not move the slot:
what is left of it is still destroyed. Moves inside index expressions
count too. A method that takes `var self` on $`p\,\hat{}` consumes $`p`,
which the expression alone does not show: elaboration finds it with the
method's signature.
:::

:::readable MojoGrimoire.Elab.usesOpt (fingerprint := "8395889635373146699")
*Definition: uses of an optional expression.* None when it is absent.
:::

:::readable MojoGrimoire.Elab.liveStmt MojoGrimoire.Elab.liveBlock (fingerprint := "3328152987503357313")
*Definition: liveness.* A slot is live at a point when a path from there
uses it before defining it again. Liveness runs backwards:

- a declaration, with or without an initial value, or an assignment to a
  whole slot, defines the slot, so it is live before only if the value
  uses it;
- an assignment to a part of a slot uses the slot;
- a `ref` binding, an expression or a `print` uses what its expressions
  use;
- before an `if`, the slots its test uses and those live at the start of
  either branch are live;
- before a `while`, the slots its test uses, those live after it, and those
  live at the start of its body when those two are live at its end;
- before a `return`, only the slots its value uses.

For the loop, one pass through the body gives the fixed point: the body's
liveness keeps each slot live after it, or removes it, or adds it, whatever
else is live, so a second pass adds nothing.
:::
