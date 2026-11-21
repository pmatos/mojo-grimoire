import VersoManual
import MojoGrimoire.Elab.Late
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Elab.Late`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Subscripts read late: readable blocks" =>

:::moduleDocs (fingerprint := "10483923369512154981")
:::

:::readable MojoGrimoire.Elab.placeSlots MojoGrimoire.Elab.isGetter MojoGrimoire.Elab.lateValue (fingerprint := "18223303959924848957")
*Definition: subscripts read late.* A subscript of a struct that declares
`__getitem__` and `__setitem__` is a call of its getter that Mojo makes
when its operation reads the operand (`lateGetter`, #191). The places
among the getter's arguments, with the slots their indices use, and those
of the subscripts read late among them, live until then, and so does what
the later operands use while its arguments are evaluated. The getter
destroys what it last uses right after it is called; when it returns a
reference, what the reference points into lives until the operation is
done, as for any call that returns one.
:::
