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

:::moduleDocs (fingerprint := "5820294513603318199")
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

:::readable MojoGrimoire.Check.ShapeStep MojoGrimoire.Check.Shape (fingerprint := "17175472047769601315")
*Definition: shapes.* The shape of a place is its variable and the steps
down from it, with indices left out:

```grammar MojoGrimoire.Check.ShapeStep
\sigma
field      .f
listElem   [\cdot]_{\mathsf{list}}
arrayElem  [\cdot]_{\mathsf{array}}
intElem    [\cdot]_{\mathsf{Int}}
```

Two places that differ only in their indices have the same shape. The
element of an $`\mathsf{Int}` is a step of its own, since it is no
location (#127).
:::

:::readable MojoGrimoire.Check.Path MojoGrimoire.Check.VarState MojoGrimoire.Check.State MojoGrimoire.Check.CheckM (fingerprint := "862987152442379284")
*Definition: the checker's state.* A path $`\pi = f_1 \dots f_n` names a
part of a variable: the empty path $`\epsilon` is the variable itself, and
$`f_1 \dots f_n` its field $`f_1.\dots.f_n`. For each variable in scope,
innermost first, the state holds its name, type and access, the set
$`U` of its uninitialized parts, the set $`M` of its parts moved out
with `^` and not assigned again, $`\epsilon` for the variable moved out
whole, and three sets for a struct built field by field (#51): the set
$`H` of its parts that may hold a value, on some path through the
function; the set $`T` of its touched parts, held whole when a part
inside them was moved out or assigned; and the set $`P` of its pieces,
the parts built from their fields, which Mojo never counts as whole. The state also says whether the current
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

:::readable MojoGrimoire.Check.partTy MojoGrimoire.Check.remainder MojoGrimoire.Check.initPart (fingerprint := "6758739688406185053")
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

:::readable MojoGrimoire.Check.atOrBelow MojoGrimoire.Check.partsWithin MojoGrimoire.Check.above MojoGrimoire.Check.piecesTo (fingerprint := "7551493476001580113")
*Definition: parts around a part.* The parts of $`U` at or below $`\rho`
are the $`\sigma` with $`\rho\sigma \in U`, $`\epsilon` included. The
parts of $`\rho` within a set of parts such as $`H` or $`U` are all of
$`\rho`, $`\{\epsilon\}`, when a part of the set is $`\rho` or above
it, and otherwise the parts of the set strictly below $`\rho`. The parts of $`H`
strictly above $`\rho` are the $`\pi \in H` with $`\pi \preceq \rho`
and $`\pi \neq \rho`. When $`\pi`, strictly above $`\rho`, is
uninitialized, assigning $`\rho` builds from their fields the parts from
$`\pi` down to the part just above $`\rho`.
:::

:::readable MojoGrimoire.Check.findVar MojoGrimoire.Check.lookup MojoGrimoire.Check.setVar MojoGrimoire.Check.setVar.go (fingerprint := "5327930066003656915")
*Definition: variables in scope.* A name refers to the innermost variable in
scope with that name, if there is one, and updating a variable replaces
the innermost variable with its name. An unknown name is rejected.
:::

:::readable MojoGrimoire.Check.elemOf MojoGrimoire.Check.indexedOf MojoGrimoire.Check.fixedLength MojoGrimoire.Check.placeTy MojoGrimoire.Check.placeTy.liftM MojoGrimoire.Check.rebase MojoGrimoire.Check.resolvePlace MojoGrimoire.Check.requireInit MojoGrimoire.Check.readPlace (fingerprint := "13959565986772566554")
*Definition: reading a place.* The type of a place is the type of its
variable, then of each field or element on the way; only a list or an
array has elements, and $`p\,\hat{}` has the type of $`p`. An index
may also go into an $`\mathsf{Int}`, a SIMD vector of width 1, whose one
element, at index 0, is the $`\mathsf{Int}` itself (#127). An array of
$`n` elements, and an $`\mathsf{Int}`, fix how many elements they have:
$`n` and 1. Reading a place's value needs the
part it names to be initialized, with no part in $`M` or $`P` at or
below it, and is otherwise rejected as a use of an uninitialized value: a
field moved out and refilled one sub-field at a time is still not whole,
and nor is a struct built field by field, even once every field is
assigned, as the compiler reports. Through a
reference, the reference must not be invalidated, and every origin must be
initialized: a value moved away cannot be used through a reference to it.
A place reached through a reference resolves to the same place in each of
its origins, the reference's variable replaced by the origin; any other
place resolves to itself. Replacing the variable of a place keeps each
$`\hat{}` on the way.
:::

:::readable MojoGrimoire.Check.shapeOf MojoGrimoire.Check.invalidates MojoGrimoire.Check.intIndexed (fingerprint := "16656027637097560338")
*Definition: invalidation.* The shape of $`p[e]` ends in
$`[\cdot]_{\mathsf{list}}` when $`p` is a list, in
$`[\cdot]_{\mathsf{Int}}` when it is an $`\mathsf{Int}`, and in
$`[\cdot]_{\mathsf{array}}` otherwise, and $`p\,\hat{}` has
the shape of $`p`. Changing a place of
shape $`(x, \mu)` as a whole invalidates a reference into a place of
shape $`(y, \omega)` when $`x = y`, $`\mu` is a prefix of $`\omega`,
and the rest of $`\omega` holds a $`[\cdot]_{\mathsf{list}}`: the
reference points into an element of a list that the changed place holds.
Changing one element does not invalidate a reference into it, and an
array keeps its elements in place. A place whose shape holds a
$`[\cdot]_{\mathsf{Int}}` goes through the element of an
$`\mathsf{Int}`, which the compiler reads with `__getitem__` and writes
with `__setitem__`: a value with no memory origin, into which no reference
may point. A place that cannot be typed is not one, and is left to the
checking that reports its error.
:::
