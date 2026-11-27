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

:::moduleDocs (fingerprint := "16518836012555365344")
:::

:::readable MojoGrimoire.Check.Access.canChange MojoGrimoire.Check.placeMutable MojoGrimoire.Check.passedMutable (fingerprint := "4781551392938097025")
*Definition: places that may change.* A function may change a place, by
assigning to it or passing it `mut`, unless its variable is a `read` or
`ref` parameter, or a reference that may not be changed; a `ref` binding
to a place reached through `p^` may change it, as the compiler allows. A
place passed to a `ref` parameter or a `ref self` receiver passes on a
mutable reference when it may be changed and is not reached through `p^`,
which the compiler borrows as a value that cannot be changed.
:::

:::readable MojoGrimoire.Check.passOn (fingerprint := "2491400132329808649")
*Definition: mutability through a parameter.* A reference that a callee
returns through a `mut` parameter may be changed; through a `ref`
parameter, when its argument may be; through a `read` parameter, never.
:::

:::readable MojoGrimoire.Check.locOfAs MojoGrimoire.Check.originsOf MojoGrimoire.Check.locOf (fingerprint := "16884867861159506642")
*Rule: located operands.* A located operand names a location. A place is
one: its origins are the place, or the same place in each origin of the
reference it goes through, and it passes on a mutable reference when its
variable may be changed and it is not reached through `p^`.
A call or a method call that returns a reference is one when every
argument passed to a parameter its origin names, a method's receiver
included, is a located operand in turn: its origins are those arguments'
origins, and it may be changed when each of them passes on a mutable
reference. A call of a name that a variable in scope hides is one, with
no origins and immutable, so that checking it as a call rejects it
(#176). Nothing else is one.

An origin argument that is not a located operand, a temporary, is left
out instead: the call's origins are those of its other origin
arguments, and it may not be changed through, as the compiler keeps the
temporary alive as long as the reference (#80). This is how the checker
reads a located operand (`locOf`). Strictly, for a `return`, such a call
is no located operand.
:::

:::readable MojoGrimoire.Check.calleeOf MojoGrimoire.Check.throughTemp MojoGrimoire.Check.tempOrigin MojoGrimoire.Check.tempArgs (fingerprint := "17136805677901233987")
*Rule: references into temporaries.* A located operand may point into a
temporary, which its origins leave out (#80). That is the case for a place
reached through a reference bound to one, and for a call with an origin
argument that is a temporary, or that may point into one in turn. A
reference bound with `ref` remembers it, so that a `return` of one that
may is $`\mathsf{escapingReference}`, as the compiler reports it. The
check comes after the type comparison, with the origins that do not stay
within the function's own. A `return` of a call whose origin argument is
itself a temporary is $`\mathsf{notAPlace}`, where the compiler reports an
escaping reference (#366). The name of the callee is what that error
reports (`calleeOf`).
:::

:::readable MojoGrimoire.Check.overlaps MojoGrimoire.Check.PassedLoc MojoGrimoire.Check.passedPlace MojoGrimoire.Check.locationArgs MojoGrimoire.Check.checkExclusive MojoGrimoire.Check.checkExclusive.go (fingerprint := "334350284564618373")
*Rule: argument exclusivity.* Two places overlap when they have the same
variable and one path is a prefix of the other. The arguments of a call
that are passed as locations are the located operands whose parameters
are `read`, `mut` or `ref`, and the receiver of a method unless its
`self` is `var`, except a receiver $`q\,\hat{}` that a `var self`
consumes, which counts as $`q` passed `mut`; an $`\mathsf{Int}` or a $`\mathsf{Bool}` passed `read`
is copied instead. A call is rejected when a location passed `mut`, of
any type, overlaps another location of the same call. A reference, and a
call that returns one, overlaps what its origins overlap: `n(first(xs),
xs)` is rejected when `n` takes its second argument `mut`. The error names
the place passed, or a call's first origin.
:::
