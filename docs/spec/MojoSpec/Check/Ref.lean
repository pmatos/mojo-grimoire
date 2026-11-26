import VersoManual
import MojoGrimoire.Check.Ref
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Ref`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "References: readable blocks" =>

:::moduleDocs (fingerprint := "9425781608200571173")
:::

:::readable MojoGrimoire.Check.refTarget (fingerprint := "15477698907736277328")
*Rule: what a reference names.* $`\mathsf{ref}~x = e` needs $`e` to be a
place, which must be initialized, or a call or a method call whose
signature returns a reference. A place gives a reference to itself, or
to the origins of the reference it goes through, and may be changed when
its variable may be: through $`p\,\hat{}` too, as the compiler allows. A
call gives its origins as a located operand, and is rejected when an
origin argument is none. A call of a name that a variable in scope hides
is checked as a call, which rejects it when the variable's type has no
`__call__` (#176).
Any other expression, a struct's construction included, is rejected.
A place through the element of an $`\mathsf{Int}` has no memory origin,
and is $`\mathsf{escapingReference}`, in a binding or a return alike,
once the place is typed, and in a return once its type is compared with
the result type, before any later error (#127).
:::

:::readable MojoGrimoire.Check.refSubscripts (fingerprint := "3736224206595262529")
*Rule: references that a subscript changes.* A reference bound with
`ref` is subscripted as one that may change when it may be changed, as
the rule above finds, with each `ref` parameter taken as one that may
change, and each reference as one that may when it is subscripted so
(#282). The compiler does not know a `ref` parameter's mutability, so it
subscripts `ref e = v`, with `v` a `ref` parameter, as one that may
change, though nothing may be changed through `e`. A reference that a
call returns through a `read` parameter is subscripted as one that may
not.
:::

:::readable MojoGrimoire.Check.withinOrigin (fingerprint := "1783623240663657123")
*Rule: a returned reference.* A function that returns a reference returns
one within its origin: each origin of the returned location, with its
indices into arrays left out, is a parameter the origin names. The compiler
gives a field and an element of a list an origin of their own, so returning
one, or anything under one, is $`\mathsf{escapingReference}`; an element
of an array, at any depth, stays within the array's origin.
:::

:::readable MojoGrimoire.Check.checkOrigin (fingerprint := "15391653035526331512")
*Rule: declared origins.* A function that returns a reference has a result,
and its origin names only parameters passed as locations: `read`, `mut`
or `ref`. A `var` parameter dies with the call, so a reference into it
would outlive its value.
:::
