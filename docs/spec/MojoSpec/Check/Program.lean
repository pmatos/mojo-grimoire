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

:::moduleDocs (fingerprint := "14111025864232253597")
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

:::readable MojoGrimoire.Check.checkDistinct MojoGrimoire.Check.checkConventions (fingerprint := "3840921892517559410")
*Rule: declarations.* Names that must be unique are rejected when one
repeats. Only the `self` of `__init__` may be `out`, and only the
`self` of `__deinit__` `deinit`.
:::

:::readable MojoGrimoire.Check.BodyResult MojoGrimoire.Check.checkSignature MojoGrimoire.Check.checkBody (fingerprint := "7336102420651066353")
*Rule: function bodies.* The signature: the parameters have distinct names
and declarable types, and the result type is declarable or $`\mathsf{None}`; a type in
which a variable hides a name is `valueAsType`, in that order. An origin
names parameters passed as locations, and needs a result. The body is
checked from the parameters' states on entry, with no reference
invalidated and no change recorded. If its end can be reached,
the result type must be $`\mathsf{None}`, and the state there is checked
as at a return.
The body is checked in the phase it is given, and in the flow phase up
to the stage it is given. A body that can reach its end where it must
return a result gives its missing return instead of the check at a
return; the flow phase reports it first. The body also gives what the
instantiation phase records in it (`InstEvent`).
:::

:::readable MojoGrimoire.Check.operatorArity MojoGrimoire.Check.checkFun MojoGrimoire.Check.checkMethod MojoGrimoire.Check.checkInit (fingerprint := "2547135469488102416")
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

:::readable MojoGrimoire.Check.checkFields MojoGrimoire.Check.memberCheck MojoGrimoire.Check.checkStruct (fingerprint := "14296206318854017213")
*Rule: structs.* A struct's own declaration is checked with the free
functions, in the order of the declarations: its fields and methods have
distinct names, and its fields declarable types. Its members are checked
once every free function is: its initializer, its destructor, checked with
the single parameter `deinit self`, and its methods, each with its
signature and its body, in their order (`memberCheck`, which the flow
phase uses too). The copy initializer that the compiler synthesizes is
checked right after `__init__`: the struct's copyability holds, and for
an implicit one no field, taken in order, leads to a rejected cycle back to
the struct. Otherwise no field leads to such a cycle, checked after the
last member, and then the copyability of a struct that declares no
`__init__` (#164).
:::

:::readable MojoGrimoire.Check.checkCopying MojoGrimoire.Check.located (fingerprint := "4026125360921521139")
*Rule: copyable structs.* A struct that declares `Copyable` gets a copy
initializer synthesized from its fields, so each field's type must be
copyable; one that declares `ImplicitlyCopyable` needs each field's type
implicitly copyable. Otherwise the struct is rejected with
`uncopyableField`, naming its first such field, as the compiler does at
the declaration, even when nothing copies the struct (#164). A field's
struct is copyable as it declares, whatever its own fields. In the
implicit copy initializer after `__init__`, a field on a rejected cycle
is the error at its place too. The type phase locates the error of each
body there, or gives its missing return (`located`).
:::

:::readable MojoGrimoire.Check.checkTypes MojoGrimoire.Check.declBodies MojoGrimoire.Check.checkFlow (fingerprint := "18106343609100170426")
*Rule: programs.* A program is checked in three phases, the type phase,
the flow phase and the instantiation phase
(`MojoGrimoire.Check.checkProgram`), and is rejected with the first error
of the first phase that finds one: the compiler reports its errors in
tiers (ADR-2026-11-21-1941).

The type phase follows the compiler's first pass (#96 part 6). First, no
struct has the name of another struct or of a function. Then, in the
order of the declarations in the source, each free function, `main`'s
parameters and result resolved before it must take nothing and return
nothing, before its conventions and body, and
a function of the name of an earlier one at its place; and each struct's
own declaration. Last, each struct's members, in the order of the
declarations. A body that can reach its end without returning the result
it declares is not rejected there: the type phase gives it to the flow
phase.

The flow phase follows the compiler's pass manager (#96 part 5). First,
the first missing return in the order of the declarations is rejected.
Then each body is checked in the order of the declarations, the members
of the structs interleaved with the free functions (`declBodies`), up to
every stage. When that finds a value that may not end, it is checked again
up to the stage of uses, whose error comes first: so a value that may not
end comes after the body's uses and what it leaves at a return (#159).
Last, `main` must be declared.
:::
