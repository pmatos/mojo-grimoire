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

:::moduleDocs (fingerprint := "16558882463013679477")
:::

:::readable MojoGrimoire.Check.placeMutable MojoGrimoire.Check.callOrigins (fingerprint := "2885843637383139862")
*Rule: the origins of a call.* A call of a function that returns a
reference points into the arguments passed to the parameters its origin
names; each must be a place, since a temporary would not outlive the call.
The reference may be changed when every such parameter allows it: a `mut`
parameter does, a `ref` parameter does when its argument may be changed,
and a `read` parameter does not.
:::

:::readable MojoGrimoire.Check.refTarget (fingerprint := "5155544058376309071")
*Rule: what a reference names.* $`\mathsf{ref}~x = e` needs $`e` to be a
place, which must be initialized, or a call whose signature returns a
reference. A place gives a reference to itself, or to the origins
of the reference it goes through; a call gives the origins above. Any
other expression, a struct's construction included, is rejected.
:::

:::readable MojoGrimoire.Check.checkOrigin (fingerprint := "11490521454237148840")
*Rule: declared origins.* A function that returns a reference has a result,
and its origin names only parameters passed as locations: `read`, `mut`
or `ref`. A `var` parameter dies with the call, so a reference into it
would outlive its value.
:::
