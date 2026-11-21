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

:::moduleDocs (fingerprint := "17040301232712701240")
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
