import VersoManual
import MojoGrimoire.Check.Transfer
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Transfer`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Reading and transferring: readable blocks" =>

:::moduleDocs (fingerprint := "3360571688760172665")
:::

:::readable MojoGrimoire.Check.copyPlace MojoGrimoire.Check.noOwnOrigin MojoGrimoire.Check.CheckError.late MojoGrimoire.Check.requireTransferable MojoGrimoire.Check.transferPlace (fingerprint := "3745399525283139153")
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
