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

:::moduleDocs (fingerprint := "4609831481487925457")
:::

:::readable MojoGrimoire.Check.valueSubscript (fingerprint := "8489678019998001525")
*Definition: a subscript read through its getter.* A subscript `q[i]` of
a struct that declares `__getitem__` but not `__setitem__` is what its
getter gives: the call `S.__getitem__(q, i)` (#191).
:::

:::readable MojoGrimoire.Check.setterOnly (fingerprint := "8155823455014461326")
*Definition: a setter without a getter.* A type is a struct that
declares `__setitem__` but not `__getitem__`.
:::

:::readable MojoGrimoire.Check.rejectSetterOnly (fingerprint := "12929467708356621375")
*Rule: assigning a subscript with no getter.* A place assigned to that
holds a subscript `q[i]` of a struct with a setter and no getter is
$`\mathsf{missingMethod}` of `__getitem__` (#296). The compiler reports it
once it has typed `q`, from its variable outward, so the errors of `q`
itself come first, but before `i`, the value assigned, and the errors of
a later pass, such as a read of a moved or uninitialized receiver. Of
several such subscripts, the one nearest the place's variable is
reported. A place that cannot be typed is left to the checking that
reports its error.
:::

:::readable MojoGrimoire.Check.assignGetter (fingerprint := "6488846667628778942")
*Rule: assigning a subscript with no setter.* The compiler first types
the getter call `q[i]`, by reference: its type errors and its implicit
copies come first, but not the errors of a later pass, such as a read of
a moved receiver. When the getter returns a value, or a reference that may
not be changed through, such as one of a `self` that is `read`, the
assignment is $`\mathsf{immutablePlace}`, before those later errors and
before the value assigned is checked. Through a reference that may be changed, the
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
