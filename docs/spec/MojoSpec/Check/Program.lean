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

:::moduleDocs (fingerprint := "16386356784703605396")
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

:::readable MojoGrimoire.Check.checkBody (fingerprint := "17402035727393658499")
*Rule: function bodies.* The parameters have distinct names and declarable
types, and the result type is declarable or $`\mathsf{None}`; a type in
which a variable hides a name is `valueAsType`, in that order. An origin
names parameters passed as locations, and needs a result. The body is
checked from the parameters' states on entry, with no reference
invalidated and no change recorded, beside its twin, the body that
`main`'s inference gave the same declaration: a free function's for a
function, the same struct's for a member. If its end can be reached,
the result type must be $`\mathsf{None}`, and the state there is checked
as at a return.
The body is checked in the phase it is given; a missing return is a
check of the flow phase.
:::

:::readable MojoGrimoire.Check.operatorArity MojoGrimoire.Check.checkFun MojoGrimoire.Check.checkMethod MojoGrimoire.Check.checkInit (fingerprint := "2604146257645790029")
*Rule: functions, methods and initializers.* A function's body is checked.
A method of the struct $`S` has a first parameter `self` of type $`S`,
`read`, `mut`, `var` or `ref`. An operator method that inference calls
takes as many operands, `self` among them, as its operator: two for a
binary, reflected or in-place operator and one for `__neg__` and
`__bool__`, as the
compiler checks when it parses the declaration; otherwise
`arityMismatch` (#191). An initializer's first parameter is
`out self` of type $`S`, and it returns nothing.
Each is checked in the phase it is given.
:::

:::readable MojoGrimoire.Check.checkFields MojoGrimoire.Check.checkMethods (fingerprint := "4262877697978545447")
*Rule: structs.* A struct's fields and methods have distinct names, its
fields declarable types, and no field leads to a rejected cycle back to
the struct. Its initializer, its destructor, checked with the single
parameter `deinit self`, and its methods are checked. Among the methods,
the first error in declaration order is reported, as the compiler does.
The model keeps no order between them and the initializer and the
destructor, so a `valueAsType` in either of those is reported only when
no method has another error (#193).
They are checked in the phase it is given.
:::

:::readable MojoGrimoire.Check.checkCopying (fingerprint := "4967680146187123200")
*Rule: copyable structs.* A struct that declares `Copyable` gets a copy
initializer synthesized from its fields, so each field's type must be
copyable; one that declares `ImplicitlyCopyable` needs each field's type
implicitly copyable. Otherwise the struct is rejected with
`uncopyableField`, naming its first such field, as the compiler does at
the declaration, even when nothing copies the struct (#164). A field's
struct is copyable as it declares, whatever its own fields.
:::

:::readable MojoGrimoire.Check.checkPhase MojoGrimoire.Check.checkProgram (fingerprint := "5556822136045573711")
*Rule: programs.* A program is checked twice, first in the type phase and
then in the flow phase, and is rejected with the first error of the first
phase that finds one: the compiler reports its errors in tiers, its type
errors before its later passes' (ADR-2026-11-21-1941). In each phase, a
program is accepted when its structs and functions have distinct names,
every struct and function is accepted, `main`, if it is declared, has no
parameters and returns nothing, every copyable struct's fields can be
copied, and, in the flow phase, `main` is declared. The checks run in
that order. The compiler reports a copyable struct's fields after the
functions' bodies, `main`'s signature and the methods of the structs up
to it, and before its later passes and a missing `main`; the rest of its
order is left to #96 (#164). A type that a variable hides in a struct's
initializer, destructor or method, `valueAsType`, is reported there too,
just before that struct's copyability check: the compiler checks those bodies after
the functions'. When the struct declares its own `__init__` and the type is
in its destructor or a method, it comes just after that check instead: the
compiler checks the copy initializer right after `__init__`, which the
model takes to come first. The bodies of the structs after it are then not checked,
since the compiler reports their errors later; their fields still are
(#193). Otherwise the program is rejected with the first error found, and
where.
:::
