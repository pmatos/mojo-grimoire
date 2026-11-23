import VersoManual
import MojoGrimoire.Check.Subscript
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Subscript`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Assigning a subscript of a struct: readable blocks" =>

:::moduleDocs (fingerprint := "12976235231042542554")
:::

:::readable MojoGrimoire.Check.valueSubscript (fingerprint := "8489678019998001525")
*Definition: a subscript that is a value.* A subscript `q[i]` of a struct
that declares `__getitem__` but not `__setitem__` is the value its getter
gives: the call `S.__getitem__(q, i)`. Assigning it is
$`\mathsf{immutablePlace}`, once that call has been checked and before the
value assigned is (#191).
:::

:::readable MojoGrimoire.Check.checkSetter (fingerprint := "6602736107007234452")
*Definition: checking a setter call.* Before it checks `q[i] = v` as the
call `S.__setitem__(q, i, v)`, the compiler checks the types of the getter
call `q[i]`, which is never made, so its implicit copies and the errors of
a later pass do not count, and then the type of `v` against the getter's
result. A literal of $`\mathsf{Int}`s of the wrong length is left to the
setter call, after its receiver. The checker's state is left as it was.
:::
