import VersoManual
import MojoGrimoire.Interp.Value
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Interp.Value`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Values: readable blocks" =>

:::moduleDocs (fingerprint := "6836320963325718107")
:::

:::readable MojoGrimoire.Interp.Value (fingerprint := "6154955959241713508")
*Definition: values.* A value $`v` is one of:

```grammar MojoGrimoire.Interp.Value
v
int     n
bool    b
struct  S\{f_1 = v_1, \dots, f_k = v_k\}
list    [v^*]
none    \mathsf{None}
uninit  \bot
```

$`\mathsf{None}` is what a call that returns nothing gives, and $`\bot`
marks a location, or a field, that holds no value: before its first
assignment, or after its value was moved out.
:::

:::readable MojoGrimoire.Interp.Step MojoGrimoire.Interp.Value.get MojoGrimoire.Interp.Value.set (fingerprint := "2068701397655058607")
*Definition: parts of a value.* A path of steps names a part of a value:
each step is a field of a struct, or the element at a position of a list
or an array. An array is a list value whose length is the size $`N` of
its type $`\mathsf{Array}[t, N]`, which the checker ensures.
Reading a part, or replacing it with another value, fails when the path
does not lead to a part.
:::

:::readable MojoGrimoire.Interp.Value.show (fingerprint := "15008849415867136296")
*Definition: printing.* `print` writes an $`\mathsf{Int}` in decimal and a
$`\mathsf{Bool}` as `True` or `False`.
:::
