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

:::moduleDocs (fingerprint := "11892859305903092470")
:::

:::readable MojoGrimoire.Check.paramState (fingerprint := "17131055927722852879")
*Definition: parameters on entry.* A `read` or `ref` parameter is
read-only, a `mut` parameter mutable, a `var` parameter owned, the
`self` of `__init__` constructing and wholly uninitialized, and the
`self` of `__deinit__` dying. No parameter starts with a field moved out,
touched or built from its fields, and each holds its whole value but the
`self` of `__init__`, which holds nothing.
:::

:::readable MojoGrimoire.Check.checkDistinct MojoGrimoire.Check.checkConventions (fingerprint := "18041074665712261837")
*Rule: declarations.* Names that must be unique are rejected when one
repeats. Only the `self` of `__init__` may be `out`, and only the
`self` of `__deinit__` `deinit`.
:::

:::readable MojoGrimoire.Check.checkBody (fingerprint := "2409811792939589629")
*Rule: function bodies.* The parameters have distinct names and declarable
types, and the result type is declarable or $`\mathsf{None}`. An origin
names parameters passed as locations, and needs a result. The body is
checked from the parameters' states on entry, with no reference
invalidated and no change recorded. If its end can be reached,
the result type must be $`\mathsf{None}`, and the state there is checked
as at a return.
:::

:::readable MojoGrimoire.Check.checkFun MojoGrimoire.Check.checkMethod MojoGrimoire.Check.checkInit (fingerprint := "2391775556140320310")
*Rule: functions, methods and initializers.* A function's body is checked.
A method of the struct $`S` has a first parameter `self` of type $`S`,
`read`, `mut`, `var` or `ref`. An initializer's first parameter is
`out self` of type $`S`, and it returns nothing.
:::

:::readable MojoGrimoire.Check.checkStruct (fingerprint := "6948326983854275523")
*Rule: structs.* A struct's fields and methods have distinct names, its
fields declarable types, and no field contains the struct. Its initializer,
its destructor, checked with the single parameter `deinit self`, and its
methods are checked.
:::

:::readable MojoGrimoire.Check.checkProgram (fingerprint := "12688032733967879011")
*Rule: programs.* A program is accepted when its structs and functions have
distinct names, every struct and function is accepted, and it has a
function `main` with no parameters that returns nothing. Otherwise it is
rejected with the first error found, and where.
:::
