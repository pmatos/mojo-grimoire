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

:::moduleDocs (fingerprint := "7785684939964426616")
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

:::readable MojoGrimoire.Interp.Operand MojoGrimoire.Interp.Operand.load MojoGrimoire.Interp.Pending MojoGrimoire.Interp.Pending.loadAll (fingerprint := "3189860708977689654")
*Definition: operands read late.* An operand that is a place passed by
value, or the reference that a call returns, is first only located; it is read once every operand of its
operation has been evaluated, as Mojo does. A call's arguments wait in
the same way: those passed by value are read when the call is made. An
$`\mathsf{Int}` or a $`\mathsf{Bool}` passed to a `read` parameter is
passed by value.
:::

:::readable MojoGrimoire.Interp.Result.read MojoGrimoire.Interp.asInt MojoGrimoire.Interp.asBool MojoGrimoire.Interp.lookupVar (fingerprint := "16932192272348915616")
*Definition: helpers.* A call's result gives its value, or the value its
reference points to. An index is an $`\mathsf{Int}`, a condition a
$`\mathsf{Bool}`, and a variable is looked up in scope; anything else is
stuck.
:::

:::readable MojoGrimoire.Interp.intElem MojoGrimoire.Interp.fixIndices (fingerprint := "17025294742309079598")
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
