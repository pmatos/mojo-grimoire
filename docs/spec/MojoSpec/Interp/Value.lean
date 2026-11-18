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

:::moduleDocs (fingerprint := "7451052750227518831")
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
assignment, or after its value was moved out. A location of a struct type
with fields that holds no value holds its blank instead, as the next
blocks say.
:::

:::readable MojoGrimoire.Interp.Step MojoGrimoire.Interp.Value.get MojoGrimoire.Interp.Value.set (fingerprint := "5790956165834944557")
*Definition: parts of a value.* A path of steps names a part of a value:
each step is a field of a struct, or the element at a position of a list
or an array. An array is a list value whose length is the size $`N` of
its type $`\mathsf{Array}[t, N]`, which the checker ensures.
Reading a part, or replacing it with another value, fails when the path
does not lead to a part.
:::

:::readable MojoGrimoire.Interp.Value.blank MojoGrimoire.Interp.Value.blankFields MojoGrimoire.Interp.Value.empty MojoGrimoire.Interp.Value.emptyFields (fingerprint := "15081830602198242352")
*Definition: blanks.* What is left of a value taken out of its location
is its blank: for a struct with fields, the struct with each field
replaced by its blank, and $`\bot` for any other value. A blank keeps the
shape of its struct, so that its fields can be assigned one by one. A
value holds nothing when it is $`\bot`, or a struct with fields that each
hold nothing; a struct with no fields holds itself.
:::

:::readable MojoGrimoire.Interp.Value.show (fingerprint := "16992733688740114149")
*Definition: printing.* `print` writes an $`\mathsf{Int}` in decimal, a
$`\mathsf{Bool}` as `True` or `False`, and a list or an array as its
elements written so, separated by `, ` between brackets: `[1, 2]`,
`[[True], []]`, and `[]` when it is empty.
:::
