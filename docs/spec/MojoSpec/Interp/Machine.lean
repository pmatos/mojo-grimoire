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

:::moduleDocs (fingerprint := "13008170621965223899")
:::

:::readable MojoGrimoire.Interp.Ref MojoGrimoire.Interp.Binding MojoGrimoire.Interp.Env (fingerprint := "5146776138028628767")
*Definition: references and variables.* A reference is a location of the
store and a path to a part of its value. A variable names a reference, and
says whether the function owns the value there. The variables in scope are
listed innermost first.
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

:::readable MojoGrimoire.Interp.alloc MojoGrimoire.Interp.readRef MojoGrimoire.Interp.writeRef MojoGrimoire.Interp.emit (fingerprint := "3528105872701788051")
*Definition: the store.* A new location is added at the end of the store
and never reused. Reading and writing a reference reads and replaces the
part of its location's value that its path names. `emit` adds a printed
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

:::readable MojoGrimoire.Interp.position MojoGrimoire.Interp.emptyStruct (fingerprint := "2926155158370350068")
*Definition: indices and empty structs.* An index into a list of length
$`l` names position $`i` when $`0 \le i < l`; any other index, a negative
one included, stops the run, since Mojo's `List` does not count from the
end. The `self`
of `__init__` starts as the struct with every field $`\bot`.
:::
