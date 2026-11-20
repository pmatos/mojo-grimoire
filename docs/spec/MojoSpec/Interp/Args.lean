import VersoManual
import MojoGrimoire.Interp.Args
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Interp.Args`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Arguments and operands: readable blocks" =>

:::moduleDocs (fingerprint := "226037231256560057")
:::

:::readable MojoGrimoire.Interp.Arg MojoGrimoire.Interp.bindParams (fingerprint := "14136961392570647166")
*Definition: arguments.* A call receives each argument as a place, passed
by reference to a `read`, `mut`, `ref` or `out` parameter; as a value,
moved or copied into a `var` parameter, which the callee owns, or copied
into a `read` parameter of type $`\mathsf{Int}` or $`\mathsf{Bool}`; or
as a temporary, a value passed to a borrowing parameter, which the caller
destroys after the call. The callee's parameters are bound to them, each
value at a new location.
:::

:::readable MojoGrimoire.Interp.Operand MojoGrimoire.Interp.Pending (fingerprint := "3308486933099740856")
*Definition: operands read late.* An operand that is a place passed by
value, or the reference that a call returns, is first only located; it is read once every operand of its
operation has been evaluated, as Mojo does. A call's arguments wait in
the same way: those passed by value are read when the call is made, and
a copy into a `var` parameter is marked as one. An
$`\mathsf{Int}` or a $`\mathsf{Bool}` passed to a `read` parameter is
passed by value. A subscript of a struct that declares `__getitem__`
and `__setitem__` is an operand of its own: its receiver is located and
its index evaluated in order, and its getter is called, with the drops
that elaboration gave it, when it is read (#191). A pending argument read
into a temporary is passed to a borrowing parameter.
:::

:::readable MojoGrimoire.Interp.lateCall (fingerprint := "14366948641063428480")
*Definition: the getter of an operand.* An operand that is a subscript
read late is a call of its getter, wrapped or not with the drops that
elaboration gave it (`lateGetter`, #191): the getter, its arguments and
those drops.
:::

:::readable MojoGrimoire.Interp.Result.read MojoGrimoire.Interp.Operand.rank MojoGrimoire.Interp.Pending.rank MojoGrimoire.Interp.fieldRank MojoGrimoire.Interp.loadFirst (fingerprint := "13312276054387161042")
*Definition: reading the operands.* A call's result gives its value, or
the value its reference points to. An operation's operands are read in
three rounds, each in order: the copies into `var` parameters, and into
struct fields of a `@fieldwise_init` construction, then the subscripts
read late, whose getters Mojo calls then, then the other operands (#191).
:::

:::readable MojoGrimoire.Interp.Operand.undropped MojoGrimoire.Interp.Pending.undroppedAll MojoGrimoire.Interp.Operand.drops MojoGrimoire.Interp.Pending.dropsAll MojoGrimoire.Interp.Operand.temps MojoGrimoire.Interp.Pending.tempsAll MojoGrimoire.Interp.lateRoots MojoGrimoire.Interp.lateRootsAll (fingerprint := "6489010712924700225")
*Definition: testing a subscript read late.* On the left of `and` or
`or`, the compiler calls the getter of a subscript read late, and those
of the subscripts read late among its arguments, once to test it,
destroying nothing, and again for the result when it decides, with its
drops (#191). An operand can be stripped of its getters' drops, its
temporaries passed as values that the getter does not destroy, so each
dies once; it gives its drops in the order they run, and its
temporaries; the variables among a subscript's arguments
tell which of the right operand's drops wait for its second call.
:::

:::readable MojoGrimoire.Interp.asInt MojoGrimoire.Interp.asBool MojoGrimoire.Interp.lookupVar (fingerprint := "2000511689573242902")
*Definition: helpers.* An index is an $`\mathsf{Int}`, a condition a
$`\mathsf{Bool}`, and a variable is looked up in scope; anything else is
stuck.
:::

:::readable MojoGrimoire.Interp.listMethodOn (fingerprint := "4165786308319436228")
*Definition: the methods of a list.* `append` adds a value at the end of a
list. `pop()` removes the last element and gives it back, failing with
$`\mathsf{indexOutOfBounds}` on an empty list, and `pop(i)` removes the
element at the position $`i` names and gives it back, failing with
$`\mathsf{indexOutOfBounds}` when $`i` is negative or past the last
element.
:::

:::readable MojoGrimoire.Interp.rangeOf (fingerprint := "14567767655669818897")
*Definition: the list of a range.* The standard library's `range` reads
its $`\mathsf{Int}`s by value and gives the list `rangeList` builds from
them, with the call's fuel: the end alone counts from 0, and the step is
1 unless a third argument gives it (#121).
:::
