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

:::moduleDocs (fingerprint := "14277500069030721100")
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

:::readable MojoGrimoire.Check.operatorArity MojoGrimoire.Check.checkFun MojoGrimoire.Check.checkMethod MojoGrimoire.Check.checkInit (fingerprint := "4673339903109587582")
*Rule: functions, methods and initializers.* A function's body is checked.
A method of the struct $`S` has a first parameter `self` of type $`S`,
`read`, `mut`, `var` or `ref`. An operator method that inference calls
takes as many operands, `self` among them, as its operator: two for a
binary, reflected or in-place operator and one for `__neg__`, as the
compiler checks when it parses the declaration; otherwise
`arityMismatch` (#191). An initializer's first parameter is
`out self` of type $`S`, and it returns nothing.
:::

:::readable MojoGrimoire.Check.checkStruct (fingerprint := "13113239104476564352")
*Rule: structs.* A struct's fields and methods have distinct names, its
fields declarable types, and no field leads to a rejected cycle back to
the struct. Its initializer, its destructor, checked with the single
parameter `deinit self`, and its methods are checked.
:::

:::readable MojoGrimoire.Check.checkCopying (fingerprint := "11704993049387811985")
*Rule: copyable structs.* A struct that declares `Copyable` gets a copy
initializer synthesized from its fields, so each field's type must be
copyable; one that declares `ImplicitlyCopyable` needs each field's type
implicitly copyable. Otherwise the struct is rejected with
`uncopyableField`, naming its first such field, as the compiler does at
the declaration, even when nothing copies the struct (#164). A field's
struct is copyable as it declares, whatever its own fields.
:::

:::readable MojoGrimoire.Check.checkProgram (fingerprint := "9654407533411021076")
*Rule: programs.* A program is accepted when its structs and functions have
distinct names, every struct and function is accepted, `main`, if it is
declared, has no parameters and returns nothing, every copyable struct's
fields can be copied, and `main` is declared. The checks run in that
order. The compiler reports a copyable struct's fields after the
functions' bodies, `main`'s signature and the methods of the structs up
to it, and before its later passes and a missing `main`; the rest of its
order is left to #96 (#164). Otherwise the program is rejected with the
first error found, and where.
:::
