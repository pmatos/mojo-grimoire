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

:::moduleDocs (fingerprint := "11639007521595796043")
:::

:::readable MojoGrimoire.Check.paramState (fingerprint := "17933977108324489146")
*Definition: parameters on entry.* A `read` parameter is read-only, a
`ref` parameter held as one, read-only too but subscripted as one that
may change (#282), a `mut` parameter mutable, a `var` parameter owned, the
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

:::readable MojoGrimoire.Check.checkBody (fingerprint := "5091061206299341465")
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
The body is checked in the phase it is given, and in the flow phase up
to the stage it is given. A body that can reach its end where it must
return a result gives its missing return instead of the check at a
return; the flow phase reports it first.
:::

:::readable MojoGrimoire.Check.operatorArity MojoGrimoire.Check.checkFun MojoGrimoire.Check.checkMethod MojoGrimoire.Check.checkInit (fingerprint := "3449962383786144700")
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

:::readable MojoGrimoire.Check.checkFields MojoGrimoire.Check.memberCheck MojoGrimoire.Check.checkStruct (fingerprint := "6651492033574983426")
*Rule: structs.* A struct's own declaration is checked with the free
functions, in the order of the declarations: its fields and methods have
distinct names, and its fields declarable types. Its members are checked
once every free function is: its initializer, its destructor, checked with
the single parameter `deinit self`, and its methods, each with its
signature and its body, in their order (`memberCheck`, which the flow
phase uses too). The copy initializer that the compiler synthesizes is
checked right after `__init__`, or after the last member when the struct
declares none: no field leads to a rejected cycle back to the struct, and
the struct's copyability holds (#164).
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

:::readable MojoGrimoire.Check.checkTypes MojoGrimoire.Check.flowBodies MojoGrimoire.Check.checkFlow MojoGrimoire.Check.checkProgram (fingerprint := "9577042352613035195")
*Rule: programs.* A program is checked twice, first in the type phase and
then in the flow phase, and is rejected with the first error of the first
phase that finds one: the compiler reports its errors in tiers, its type
errors before its later passes' (ADR-2026-11-21-1941).

The type phase follows the compiler's first pass (#96 part 6). First, no
struct has the name of another struct or of a function. Then, in the
order of the declarations in the source, each free function, `main`'s
signature before its body, which must take nothing and return nothing, and
a function of the name of an earlier one at its place; and each struct's
own declaration. Last, each struct's members, in the order of the
declarations. A body that can reach its end without returning the result
it declares is not rejected there: the type phase gives it to the flow
phase.

The flow phase follows the compiler's pass manager (#96 part 5). First,
the first missing return in the order of the declarations is rejected.
Then each body is checked in the order of the declarations, the members
of the structs interleaved with the free functions (`flowBodies`), up to
every stage. When that finds a value that may not end, it is checked again
up to the stage of uses, whose error comes first: so a value that may not
end comes after the body's uses and what it leaves at a return (#159).
Last, `main` must be declared.
:::
