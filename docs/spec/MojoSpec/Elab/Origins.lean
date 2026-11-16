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

:::moduleDocs (fingerprint := "17765821851420592100")
:::

:::readable MojoGrimoire.Elab.TyEnv MojoGrimoire.Elab.placeTyOf MojoGrimoire.Elab.refCallee (fingerprint := "2511568776226270142")
*Definition: callees.* Elaboration follows the types of the variables
declared so far, to find the type of a place and so the signature of the
method a call names. A call's signature, that of a function, of a
struct's construction or of a method, comes with its arguments, the
receiver of a method first.
:::

:::readable MojoGrimoire.Elab.originArgs MojoGrimoire.Elab.refSlots (fingerprint := "12455551791382063524")
*Definition: what a reference points into.* A reference to a place points
into the slots that the place touches; one returned by a call, into the
slots that the arguments passed to the parameters its origin names touch,
when they are places, the receiver of a method first. A signature with no
origin, such as a struct's construction, points into nothing. The
reference has the type of the place, or the result type of the call.
:::

:::readable MojoGrimoire.Elab.addAlias MojoGrimoire.Elab.aliasStmt MojoGrimoire.Elab.aliasBlock MojoGrimoire.Elab.slotsOf (fingerprint := "14262126315433238538")
*Definition: the references of a body.* A pass through the body, in order,
records each `ref` binding with the slots it may point into, so that a
reference bound to another reference points into the same slots. Two
references of the same name in sibling blocks share one entry, with the
slots of both. The pass also records the type of each variable, starting
from the parameters', to find the methods that calls name.
:::
