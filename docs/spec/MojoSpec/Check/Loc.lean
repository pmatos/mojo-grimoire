import VersoManual
import MojoGrimoire.Check.Loc
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Loc`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Located operands: readable blocks" =>

:::moduleDocs (fingerprint := "9408697929668008984")
:::

:::readable MojoGrimoire.Check.Access.canChange MojoGrimoire.Check.placeMutable (fingerprint := "514862980997807548")
*Definition: places that may change.* A function may change a place, by
assigning to it or passing it `mut`, unless its variable is a `read` or
`ref` parameter, or a reference that may not be changed.
:::

:::readable MojoGrimoire.Check.passOn (fingerprint := "2491400132329808649")
*Definition: mutability through a parameter.* A reference that a callee
returns through a `mut` parameter may be changed; through a `ref`
parameter, when its argument may be; through a `read` parameter, never.
:::

:::readable MojoGrimoire.Check.locOf MojoGrimoire.Check.originsOf (fingerprint := "12111583348071281347")
*Rule: located operands.* A located operand names a location. A place is
one: its origins are the place, or the same place in each origin of the
reference it goes through, and it may be changed when its variable may be.
A call or a method call that returns a reference is one when every
argument passed to a parameter its origin names, a method's receiver
included, is a located operand in turn: its origins are those arguments'
origins, and it may be changed when each of them passes on a mutable
reference. Nothing else is one.
:::

:::readable MojoGrimoire.Check.refCall MojoGrimoire.Check.calleeOf MojoGrimoire.Check.locatedOrigins (fingerprint := "15658119373482322397")
*Rule: a call as a location.* A call or a method call whose signature
returns a reference is used as a location by `ref`, by `len` and by an
argument passed by reference. Each argument passed to a parameter its
origin names must then be a located operand, or the call is rejected with
$`\mathsf{notAPlace}`: a temporary would not outlive the call.
:::
