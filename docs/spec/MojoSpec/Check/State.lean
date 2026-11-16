import VersoManual
import MojoGrimoire.Check.State
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.State`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "The checker's state: readable blocks" =>

:::moduleDocs (fingerprint := "5809354481053193351")
:::

:::readable MojoGrimoire.Check.Access (fingerprint := "4845031522016519524")
*Definition: access.* How a function holds a variable:

```grammar MojoGrimoire.Check.Access
a
owned         \mathsf{owned}
constructing  \mathsf{constructing}
mutable       \mathsf{mutable}
readOnly      \mathsf{readOnly}
dying         \mathsf{dying}
alias         \mathsf{alias}(p^*, m)
```

A local variable or a `var` parameter is $`\mathsf{owned}`; the `self`
of `__init__` is $`\mathsf{constructing}`; a `mut` parameter is
$`\mathsf{mutable}`; a `read` or `ref` parameter is
$`\mathsf{readOnly}`; and the `self` of `__deinit__` is
$`\mathsf{dying}`. A reference bound with `ref` is
$`\mathsf{alias}(p^*, m)`: it may point into the places $`p^*`, its
origins, and may be changed when $`m` holds.
:::

:::readable MojoGrimoire.Check.ShapeStep MojoGrimoire.Check.Shape (fingerprint := "6801575715281342423")
*Definition: shapes.* The shape of a place is its variable and the steps
down from it, with indices left out:

```grammar MojoGrimoire.Check.ShapeStep
\sigma
field      .f
listElem   [\cdot]_{\mathsf{list}}
arrayElem  [\cdot]_{\mathsf{array}}
```

Two places that differ only in their indices have the same shape.
:::

:::readable MojoGrimoire.Check.Path MojoGrimoire.Check.VarState MojoGrimoire.Check.State MojoGrimoire.Check.CheckM (fingerprint := "16624616066391890561")
*Definition: the checker's state.* A path $`\pi = f_1 \dots f_n` names a
part of a variable: the empty path $`\epsilon` is the variable itself, and
$`f_1 \dots f_n` its field $`f_1.\dots.f_n`. For each variable in scope,
innermost first, the state holds its name, type and access, the set
$`U` of its uninitialized parts, and the set $`M` of its fields moved out
with `^` and not assigned again. The state also says whether the current
point can be reached; after a `return` it cannot. It holds the set of
references bound with `ref` that are invalidated, and the shapes of the
places changed as a whole so far in the current statement, in order. The checker runs in a monad
that reads and updates this state and may reject the program.
:::

:::readable MojoGrimoire.Check.splitPlace MojoGrimoire.Check.splitPlace.indexed MojoGrimoire.Check.throughTransfer (fingerprint := "13723236062265300283")
*Definition: the parts of a place.* A place is a variable and a path:
$`x` is $`x` with $`\epsilon`, and $`p.f` is the variable of $`p`
with the path of $`p` followed by $`f`. The checker does not follow the
elements of a list or an array: the path of a place that goes through
$`p[e]` stops at $`p`, so an element counts as initialized when its list
or array is. $`p\,\hat{}` has the variable and path of $`p`. A place is
reached through a transfer when $`p\,\hat{}` is on its way down from its
variable, not counting its indices: nothing may be changed through it.
:::

:::readable MojoGrimoire.Check.initialized MojoGrimoire.Check.uninitialize (fingerprint := "11992667982633253845")
*Definition: initialized parts.* With $`\pi \preceq \rho` for "$`\pi` is
a prefix of $`\rho`", the part $`\rho` is initialized in $`U` when no
uninitialized part is above or below it:

17163`\mathrm{init}(U, \rho) \iff \forall \pi \in U.\ \pi \not\preceq \rho \wedge \rho \not\preceq \pi`

Uninitializing $`\rho` leaves $`U` alone if a part above $`\rho` is
already uninitialized, and otherwise adds $`\rho` and removes the parts
below it.
:::

:::readable MojoGrimoire.Check.partTy MojoGrimoire.Check.remainder MojoGrimoire.Check.initPart (fingerprint := "2792872999317184741")
*Definition: initializing a part.* Initializing $`\rho` removes from
$`U` the parts below $`\rho`. If a part $`\pi` above $`\rho` is
uninitialized, as when `__init__` sets the first field of `self`,
$`\pi` is split: it is replaced by the parts of $`\pi` that are not on
the way down to $`\rho`, the other fields of each struct passed on the
way, which stay uninitialized. `partTy` gives the type of a part, and
`remainder` the parts left on the way down.
:::

:::readable MojoGrimoire.Check.partPlace MojoGrimoire.Check.below MojoGrimoire.Check.union (fingerprint := "7669376000255197553")
*Definition: parts and sets of parts.* The part $`\pi` of the variable
$`x` is the place $`x.\pi`. The parts of $`U` strictly below $`\rho`
are the $`\sigma` with $`\rho\sigma \in U` and $`\sigma \neq \epsilon`.
Sets are lists without repeats, kept in the order they are found:
$`A \cup B` keeps $`A` and adds the elements of $`B` not in it.
:::

:::readable MojoGrimoire.Check.lookup MojoGrimoire.Check.setVar MojoGrimoire.Check.setVar.go (fingerprint := "778544696017225873")
*Definition: variables in scope.* A name refers to the innermost variable in
scope with that name, and updating a variable replaces the innermost
variable with its name. An unknown name is rejected.
:::

:::readable MojoGrimoire.Check.elemOf MojoGrimoire.Check.placeTy MojoGrimoire.Check.placeTy.liftM MojoGrimoire.Check.rebase MojoGrimoire.Check.resolvePlace MojoGrimoire.Check.requireInit MojoGrimoire.Check.readPlace (fingerprint := "5600170809980915703")
*Definition: reading a place.* The type of a place is the type of its
variable, then of each field or element on the way; only a list or an
array has elements, and $`p\,\hat{}` has the type of $`p`. Reading a place's value needs the
part it names to be initialized, with no field in $`M` at or below it, and
is otherwise rejected as a use of an uninitialized value: a field moved out
and refilled one sub-field at a time is still not whole. Through a
reference, the reference must not be invalidated, and every origin must be
initialized: a value moved away cannot be used through a reference to it.
A place reached through a reference resolves to the same place in each of
its origins, the reference's variable replaced by the origin; any other
place resolves to itself. Replacing the variable of a place keeps each
$`\hat{}` on the way.
:::

:::readable MojoGrimoire.Check.shapeOf MojoGrimoire.Check.invalidates (fingerprint := "1346872709055547422")
*Definition: invalidation.* The shape of $`p[e]` ends in
$`[\cdot]_{\mathsf{list}}` when $`p` is a list, and in
$`[\cdot]_{\mathsf{array}}` when it is an array, and $`p\,\hat{}` has
the shape of $`p`. Changing a place of
shape $`(x, \mu)` as a whole invalidates a reference into a place of
shape $`(y, \omega)` when $`x = y`, $`\mu` is a prefix of $`\omega`,
and the rest of $`\omega` holds a $`[\cdot]_{\mathsf{list}}`: the
reference points into an element of a list that the changed place holds.
Changing one element does not invalidate a reference into it, and an
array keeps its elements in place.
:::
