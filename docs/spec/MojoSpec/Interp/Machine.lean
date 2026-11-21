import VersoManual
import MojoGrimoire.Interp.Machine
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Interp.Machine`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "The machine: readable blocks" =>

:::moduleDocs (fingerprint := "2336600503871602383")
:::

:::readable MojoGrimoire.Interp.Ref MojoGrimoire.Interp.Binding MojoGrimoire.Interp.Env (fingerprint := "10228878087589298434")
*Definition: references and variables.* A reference is a location of the
store and a path to a part of its value. A variable names a reference, and
says whether the function owns the value there, and has a static type:
its declared type, its parameter's, or for a `ref` binding the type of
what it names. The variables in scope are listed innermost first.
:::

:::readable MojoGrimoire.Interp.RunError MojoGrimoire.Interp.Result MojoGrimoire.Interp.Signal (fingerprint := "12799556844993829968")
*Definition: how evaluation stops.* A run stops early when it runs out of
fuel or indexes a list out of its bounds. It is stuck,
with a description, in a state that a program the checker accepts never
reaches. A call gives back a value, or a reference when its function has
an origin; a `return` carries it to the call.
:::

:::readable MojoGrimoire.Interp.Machine MojoGrimoire.Interp.EvalM MojoGrimoire.Interp.fail MojoGrimoire.Interp.stuck (fingerprint := "16235257191554833053")
*Definition: the machine.* The machine holds the store, an array of values
indexed by location, and the lines printed so far. Evaluation updates it,
and may stop with a signal; the machine is kept when it does, so a failed
run still shows what it printed.
:::

:::readable MojoGrimoire.Interp.take (fingerprint := "7253996121591754848")
*Definition: taking a value.* Taking the value out of a reference leaves
its blank in its place.
:::

:::readable MojoGrimoire.Interp.alloc MojoGrimoire.Interp.readRef MojoGrimoire.Interp.writeRef MojoGrimoire.Interp.emit (fingerprint := "4113611147714244786")
*Definition: the store.* A new location is added at the end of the store
and never reused. Reading and writing a reference reads and replaces the
part of its location's value that its path names. Adding and writing
change the store in place, so a run that adds $`n` locations takes time
linear in $`n`. `emit` adds a printed
line.
:::

:::readable MojoGrimoire.Interp.wrap MojoGrimoire.Interp.binary MojoGrimoire.Interp.unary (fingerprint := "12579659857558170853")
*Definition: arithmetic.* $`\mathsf{Int}` is 64-bit: an arithmetic operator
computes its integer function, and the result is wrapped into
$`[-2^{63}, 2^{63})`.
Comparisons give a $`\mathsf{Bool}`, and `==` and `!=` also compare two
$`\mathsf{Bool}`s. Negation wraps too, and `not` negates a
$`\mathsf{Bool}`.
:::

:::readable MojoGrimoire.Interp.placeTy MojoGrimoire.Interp.refTy (fingerprint := "15432595716733909718")
*Definition: static types.* The static type of a place follows from its
variable's type, through fields, list and array elements, and the element
of an $`\mathsf{Int}`, which is the $`\mathsf{Int}` (#127); that of a
reference is the type of the place or the result of the call it names.
So the interpreter tells whether a place is an $`\mathsf{Int}` whatever
its lists hold.
:::

:::readable MojoGrimoire.Interp.position MojoGrimoire.Interp.blankOf MojoGrimoire.Interp.emptyStruct (fingerprint := "3758052026648494389")
*Definition: indices and blanks.* An index into a list of length
$`l` names position $`i` when $`0 \le i < l`; any other index, a negative
one included, stops the run, since Mojo's `List` does not count from the
end. A variable declared without a value starts as the blank of its type:
for a struct type with fields, the struct whose fields are the blanks of
their types, and $`\bot` for any other type, so that its fields can be
assigned one by one (#51). The `self` of `__init__` starts as the struct
whose fields are the blanks of their types.
:::

:::readable MojoGrimoire.Interp.rangeLength MojoGrimoire.Interp.rangeElems MojoGrimoire.Interp.rangeList (fingerprint := "1765867250707510876")
*Definition: a range's list.* $`\mathsf{range}(a, b, s)` holds the
$`\mathsf{Int}`s $`a + k s`, for $`k = 0, 1, \ldots`, that come before
$`b` in the direction of $`s`: those below $`b` when $`s > 0`, those above
it when $`s < 0`, and none when $`s = 0`. Each lies between $`a` and $`b`,
so none wraps around, and the list is the one that unbounded arithmetic
gives (#121, D-0008); `rangeElems` builds it from its last element to its
first. The fuel $`f` left at the call bounds the list's length, as it
bounds the depth of evaluation: a range of more than $`f` elements stops
the run with `outOfFuel` before the list is built.
:::
