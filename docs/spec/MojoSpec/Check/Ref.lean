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

:::moduleDocs (fingerprint := "12841365528181985004")
:::

:::readable MojoGrimoire.Check.refTarget (fingerprint := "2020074255154290093")
*Rule: what a reference names.* $`\mathsf{ref}~x = e` needs $`e` to be a
place, which must be initialized, or a call or a method call whose
signature returns a reference. A place gives a reference to itself, or
to the origins of the reference it goes through; a call gives its origins
as a located operand, and is rejected when an origin argument is none.
Any other expression, a struct's construction included, is rejected.
:::

:::readable MojoGrimoire.Check.withinOrigin (fingerprint := "1783623240663657123")
*Rule: a returned reference.* A function that returns a reference returns
one within its origin: each origin of the returned location, with its
indices into arrays left out, is a parameter the origin names. The compiler
gives a field and an element of a list an origin of their own, so returning
one, or anything under one, is $`\mathsf{escapingReference}`; an element
of an array, at any depth, stays within the array's origin.
:::

:::readable MojoGrimoire.Check.checkOrigin (fingerprint := "8624302706198507778")
*Rule: declared origins.* A function that returns a reference has a result,
and its origin names only parameters passed as locations: `read`, `mut`
or `ref`. A `var` parameter dies with the call, so a reference into it
would outlive its value.
:::
