import VersoManual
import MojoGrimoire.Check.Program
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Program`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Programs: readable blocks" =>

:::moduleDocs (fingerprint := "13749254774008970487")
:::

:::readable MojoGrimoire.Check.paramState (fingerprint := "2476441051695739929")
*Definition: parameters on entry.* A `read` or `ref` parameter is
read-only, a `mut` parameter mutable, a `var` parameter owned, the
`self` of `__init__` constructing and wholly uninitialized, and the
`self` of `__deinit__` dying.
:::

:::readable MojoGrimoire.Check.checkDistinct MojoGrimoire.Check.checkConventions (fingerprint := "16872799893102637145")
*Rule: declarations.* Names that must be unique are rejected when one
repeats. Only the `self` of `__init__` may be `out`, and only the
`self` of `__deinit__` `deinit`.
:::

:::readable MojoGrimoire.Check.checkBody (fingerprint := "12932844156238584689")
*Rule: function bodies.* The parameters have distinct names and declarable
types, and the result type is declarable or $`\mathsf{None}`. An origin
names parameters passed as locations, and needs a result. The body is
checked from the parameters' states on entry. If its end can be reached,
the result type must be $`\mathsf{None}`, and the state there is checked
as at a return.
:::

:::readable MojoGrimoire.Check.checkFun MojoGrimoire.Check.checkMethod MojoGrimoire.Check.checkInit (fingerprint := "7171310884170030588")
*Rule: functions, methods and initializers.* A function's body is checked.
A method of the struct $`S` has a first parameter `self` of type $`S`,
`read`, `mut`, `var` or `ref`. An initializer's first parameter is
`out self` of type $`S`, and it returns nothing.
:::

:::readable MojoGrimoire.Check.checkStruct (fingerprint := "3160326823263783562")
*Rule: structs.* A struct's fields and methods have distinct names, its
fields declarable types, and no field contains the struct. Its initializer,
its destructor, checked with the single parameter `deinit self`, and its
methods are checked.
:::

:::readable MojoGrimoire.Check.checkProgram (fingerprint := "15780048166987490747")
*Rule: programs.* A program is accepted when its structs and functions have
distinct names, every struct and function is accepted, and it has a
function `main` with no parameters that returns nothing. Otherwise it is
rejected with the first error found, and where.
:::
