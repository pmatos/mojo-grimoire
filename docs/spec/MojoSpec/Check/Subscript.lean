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

:::moduleDocs (fingerprint := "13271994487085543330")
:::

:::readable MojoGrimoire.Check.valueSubscript (fingerprint := "8489678019998001525")
*Definition: a subscript read through its getter.* A subscript `q[i]` of
a struct that declares `__getitem__` but not `__setitem__` is what its
getter gives: the call `S.__getitem__(q, i)` (#191).
:::

:::readable MojoGrimoire.Check.assignGetter (fingerprint := "15761564175000790232")
*Rule: assigning a subscript with no setter.* The compiler first checks
the getter call `q[i]`, by reference. When the getter returns a value, or
a reference that may not be changed through, such as one of a `self`
that is `read`, the assignment is $`\mathsf{immutablePlace}`, before the
value assigned is checked. Through a reference that may be changed, the
value is checked against the type it points to; the assignment itself,
which writes through that reference, is not yet modelled and is
$`\mathsf{notAList}`, as for the other subscripts of a struct used as
places (#198).
:::

:::readable MojoGrimoire.Check.checkSetter (fingerprint := "16442885420364561359")
*Definition: checking a setter call.* Before it checks `q[i] = v` as the
call `S.__setitem__(q, i, v)`, the compiler checks the types of the getter
call `q[i]`, which is never made, so its implicit copies and the errors of
a later pass do not count, and then the type of `v` against the getter's
result. A literal of $`\mathsf{Int}`s of the wrong length is left to the
setter call, after its receiver. The checker's state is left as it was.
:::
