import VersoManual
import MojoGrimoire.Elab.Operands
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Elab.Operands`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "What an operation destroys: readable blocks" =>

:::moduleDocs (fingerprint := "9929536457847720112")
:::

:::readable MojoGrimoire.Elab.Ctx MojoGrimoire.Elab.locOperand MojoGrimoire.Elab.directOf MojoGrimoire.Elab.opKeep MojoGrimoire.Elab.directArgs MojoGrimoire.Elab.placeUses MojoGrimoire.Elab.opDrops MojoGrimoire.Elab.withDropsOf (fingerprint := "16788260925323604352")
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
struct that Mojo reads late (`lateGetter`) whose getter returns a
reference uses, as any call that returns one, what the reference points
into; one whose getter returns a value uses nothing directly, since its
getter, called once the operands are read, destroys what it last uses
(#191). The places among a late getter's arguments live until its getter
is called (`placeUses`). Its other operands
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

:::readable MojoGrimoire.Elab.consumedSlot MojoGrimoire.Elab.consumedIn MojoGrimoire.Elab.consumedList (fingerprint := "10806009808688638107")
*Definition: consumed receivers.* A method call on $`q\,\hat{}`, where
$`q` is a whole slot and the method takes `var self`, consumes $`q`: it
moves the value away, and the method destroys it. An expression consumes
the slots that the method calls in it consume, at any depth, also inside
the argument of $`\mathsf{List}[u](e)` and the value of a temporary.
:::
