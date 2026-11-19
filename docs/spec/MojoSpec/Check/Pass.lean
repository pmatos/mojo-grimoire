import VersoManual
import MojoGrimoire.Check.Pass
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Pass`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Passing places: readable blocks" =>

:::moduleDocs (fingerprint := "3615873095296089646")
:::

:::readable MojoGrimoire.Check.lift MojoGrimoire.Check.expect (fingerprint := "8319086590657683010")
*Definition: helpers.* `lift` runs a lookup of the program's tables inside
the checker, and `expect` rejects a type other than the one expected.
:::

:::readable MojoGrimoire.Check.requireMutable (fingerprint := "3665794792439843375")
*Definition: requiring a place that may change.* A place that is assigned
to or passed `mut` must be one the function may change, and not reached
through $`q\,\hat{}`: the compiler borrows $`q` there as a value that
cannot be changed. Passed `mut` to an initializer, such a place is
reported as the initializer's misfit.
:::

:::readable MojoGrimoire.Check.copyPlace MojoGrimoire.Check.noOwnOrigin MojoGrimoire.Check.CheckError.late MojoGrimoire.Check.requireTransferable MojoGrimoire.Check.transferPlace (fingerprint := "14982648558514621564")
*Rule: reading and moving a place.* Using a place $`p` as a value copies it
implicitly: $`p` must be initialized, and its type implicitly copyable.
Transferring it, $`p\,\hat{}`, needs $`p` initialized and a variable
that the function may change, owned or held `mut`, not a `read` or `ref`
parameter (`transferFromBorrowed`); afterwards $`p` is uninitialized and
holds nothing, its path is added to $`M`, the part of $`H` above it, if
any, to $`T`, the parts of $`T` strictly below it and of $`P` at or below
it are removed, and a variable moved out whole keeps nothing in $`T`. The
value in $`p` must have an origin of its own: an element of a list or an
array, or a part of one, cannot be transferred out, nor can a value
through a reference bound with `ref`, even one that may be changed. The
compiler rejects both alike (`transferFromElement`), once the place has a
type and before anything else. Its later errors, which such a transfer
comes before, are the use of an uninitialized or invalidated value and a
constant index out of range. These conditions, without the move, are
what $`q\,\hat{}` before a field or a method needs of $`q`.
:::

:::readable MojoGrimoire.Check.passPlace (fingerprint := "2500036056060291548")
*Rule: passing a place.* A place passed to a `read` or `ref` parameter
must be initialized and of the parameter's type; one passed `mut` must
also be a place the function may change; one passed `var` is copied
implicitly. No argument may be passed `out` or `deinit`. A misfit is
reported as the call's fit says.
:::
