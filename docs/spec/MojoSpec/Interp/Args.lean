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

:::moduleDocs (fingerprint := "8589200513718073534")
:::

:::readable MojoGrimoire.Interp.Arg MojoGrimoire.Interp.bindParams (fingerprint := "12042878878789727990")
*Definition: arguments.* A call receives each argument as a place, passed
by reference to a `read`, `mut`, `ref` or `out` parameter; as a value,
moved or copied into a `var` parameter, which the callee owns, or copied
into a `read` parameter of type $`\mathsf{Int}` or $`\mathsf{Bool}`; or
as a temporary, a value passed to a borrowing parameter, which the caller
destroys after the call. The callee's parameters are bound to them, each
value at a new location, with the parameter's type.
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

:::readable MojoGrimoire.Interp.lateCall (fingerprint := "11407878043055436380")
*Definition: the getter of an operand.* An operand that is a subscript
read late is a call of its getter, wrapped or not with the drops that
elaboration gave it (`lateGetter`, #191): the getter, its arguments and
those drops.
:::

:::readable MojoGrimoire.Interp.Result.read MojoGrimoire.Interp.Operand.rank MojoGrimoire.Interp.Pending.rank MojoGrimoire.Interp.fieldRank MojoGrimoire.Interp.loadFirst (fingerprint := "1139034311398040777")
*Definition: reading the operands.* A call's result gives its value, or
the value its reference points to. An operation's operands are read in
three rounds, each in order: the copies into `var` parameters, and into
struct fields of a `@fieldwise_init` construction, then the subscripts
read late, whose getters Mojo calls then, then the other operands (#191).
:::

:::readable MojoGrimoire.Interp.asInt MojoGrimoire.Interp.asBool MojoGrimoire.Interp.lookupVar MojoGrimoire.Interp.fillTemp (fingerprint := "4249809753148583741")
*Definition: helpers.* An index is an $`\mathsf{Int}`, a condition a
$`\mathsf{Bool}`, and a variable is looked up in scope; anything else is
stuck. A temporary that elaboration names is moved into its hidden
variable, which must still be blank, and passed as its place (`fillTemp`).
:::

:::readable MojoGrimoire.Interp.intElem MojoGrimoire.Interp.fixIndices (fingerprint := "9312942343898440180")
*Definition: the indices of an assigned place.* An assignment into the
element of an $`\mathsf{Int}` keeps the order of `__setitem__`'s
arguments (#127). Into any other place, the indices are evaluated first,
outermost first, each replaced by its value, as the compiler does before
it evaluates the value (#205). Once each index is evaluated, the element
it names is located, so that an index out of bounds stops the run where
the compiler's does, before any later index is evaluated. The element
is located again once the value is evaluated, in the list as the value
left it (D-0002).
:::

:::readable MojoGrimoire.Interp.copiedTest (fingerprint := "18126999313800057970")
*Definition: a copied test.* A test of a struct operand that inference
made, a call of a `__bool__` whose `self` is `var`, gives `self` a copy
of its operand when it is the left operand of `and` or `or`, as the
compiler does, since that operand may be the result; a temporary operand
is destroyed once it is copied, before `__bool__` runs.
:::

:::readable MojoGrimoire.Interp.listMethodOn (fingerprint := "5127198834850758513")
*Definition: the methods of a list.* `append` adds a value at the end of a
list. `pop()` removes the last element and gives it back, failing with
$`\mathsf{indexOutOfBounds}` on an empty list, and `pop(i)` removes the
element at the position $`i` names and gives it back, failing with
$`\mathsf{indexOutOfBounds}` when $`i` is negative or past the last
element.
:::

:::readable MojoGrimoire.Interp.rangeOf (fingerprint := "52919588600753195")
*Definition: the list of a range.* The standard library's `range` reads
its $`\mathsf{Int}`s by value and gives the list `rangeList` builds from
them, with the call's fuel: the end alone counts from 0, and the step is
1 unless a third argument gives it (#121).
:::
