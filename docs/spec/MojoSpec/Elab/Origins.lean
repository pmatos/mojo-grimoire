import VersoManual
import MojoGrimoire.Elab.Origins
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Elab.Origins`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "The origins of references: readable blocks" =>

:::moduleDocs (fingerprint := "7667708469332525899")
:::

:::readable MojoGrimoire.Elab.TyEnv MojoGrimoire.Elab.placeTyOf MojoGrimoire.Elab.refCallee (fingerprint := "6911629136506755872")
*Definition: callees.* Elaboration follows the types of the variables
declared so far, to find the type of a place and so the signature of the
method a call names.
:::

:::readable MojoGrimoire.Elab.originArgs MojoGrimoire.Elab.refSlots (fingerprint := "15620349403481297493")
*Definition: what a reference points into.* A reference to a place points
into the slots that the place touches; one returned by a call, into the
slots of the arguments passed to the parameters its origin names, the
receiver of a method first. A signature with no origin, such as a struct's
construction, points into nothing.
:::

:::readable MojoGrimoire.Elab.addAlias MojoGrimoire.Elab.aliasStmt MojoGrimoire.Elab.aliasBlock MojoGrimoire.Elab.slotsOf (fingerprint := "7734006516643555398")
*Definition: the references of a body.* A pass through the body, in order,
records each `ref` binding with the slots it may point into, so that a
reference bound to another reference points into the same slots. Two
references of the same name in sibling blocks share one entry, with the
slots of both.
:::
