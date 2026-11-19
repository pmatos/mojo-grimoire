import VersoManual
import MojoGrimoire.Check.Env
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Env`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "The program's tables: readable blocks" =>

:::moduleDocs (fingerprint := "12847369634894333029")
:::

:::readable MojoGrimoire.Check.findStruct MojoGrimoire.Check.findFun MojoGrimoire.Check.fieldTy MojoGrimoire.Check.findMethod MojoGrimoire.Check.fieldOf MojoGrimoire.Check.fieldNames (fingerprint := "4257948032270631622")
*Definition: lookups.* The checker finds a struct or a function of the
program by its name, the first one declared with that name, and a field or
method of a struct by its name. `fieldOf` gives the type of the field
$`f` of a value of type $`t`. Only a struct has fields: when $`t` is
any other type, or a struct with no field $`f`, $`f` is an unknown
attribute of the type, named with the type's name; an unknown struct is
rejected as such. `fieldNames` gives the names of the fields of a struct
type, and none for any other type.
:::

:::readable MojoGrimoire.Check.Signature MojoGrimoire.Check.Signature.allParams MojoGrimoire.Check.funSig (fingerprint := "16001441666545275462")
*Definition: signatures.* What a call needs to know of what it calls is
its signature: the parameter that takes a method's receiver, absent for a
function or a construction; its other parameters; its result; for a result
that is a reference, the parameters it points into; and whether the result
has a generic type, which Mojo builds in place whatever type it stands
for. A function's signature takes its parameters as they are declared; a
method's takes the first, `self`, as its receiver.
:::

:::readable MojoGrimoire.Check.listMethod (fingerprint := "1574394717472103448")
*Definition: the methods of a list.* A list of $`t` has two methods, which
take their list `mut` and depend on the number $`n` of arguments of the
call: `append` takes one `var` argument of type $`t` and gives
$`\mathsf{None}`, and `pop` gives a $`t`, a generic result. With
$`n = 0`, `pop` takes no argument; with any other $`n`, it takes one
`read` argument `i` of type $`\mathsf{Int}`, so that a call with two
arguments is an arity mismatch.
:::

:::readable MojoGrimoire.Check.typeName (fingerprint := "7030328644115975064")
*Definition: type names.* The name of a type, as Mojo writes it without
its parameters, names the type in an error about its methods or about
the elements of a list literal of that type.
:::

:::readable MojoGrimoire.Check.callSig MojoGrimoire.Check.methodSig (fingerprint := "13319122873340366001")
*Definition: the signature of a call.* $`f(e^*)` constructs the struct
$`f`, when the program declares one, with the parameters of its `__init__`
after `self`, or with one `var` parameter per field if it is
`@fieldwise_init`, and is rejected if it has neither; otherwise it calls
the function $`f`. `len` has no signature, since it takes a list or an
array of any type. $`p.m(e^*)` calls a method of the type of $`p`: one of
a list's methods, or a method of a struct, whose `self` takes $`p`; a
method of a struct with no parameter at all is rejected. An array has no
methods, nor does any other type: a method that the type lacks is an
unknown attribute of the type, as a missing field is, named with the
type's name. Inference, the checker and
elaboration all read the signatures of calls here.
:::

:::readable MojoGrimoire.Check.copyingOf (fingerprint := "11191475259856383167")
*Definition: how a type is copied.* $`\mathsf{Int}` and
$`\mathsf{Bool}` are implicitly copyable, as in Mojo; a struct is copied as
it declares; a list or an array is copied only explicitly, with
`.copy()`, and only when its elements can be copied; string literals and $`\mathsf{None}` are
never copied.
:::

:::readable MojoGrimoire.Check.hasDeinit (fingerprint := "13047813040906958986")
*Definition: types with a destructor.* A type has a destructor of its own
when it is a struct that declares `__deinit__`.
:::

:::readable MojoGrimoire.Check.validTy (fingerprint := "16319643588843478444")
*Definition: declarable types.* A variable, parameter or field may have the
type $`\mathsf{Int}`, $`\mathsf{Bool}`, a struct of the program, or a
list or an array of values of such a type, and no other. So may a
function's result, unless it is `None`, and the elements of a list
literal.
:::

:::readable MojoGrimoire.Check.elemBase (fingerprint := "16152550111862490354")
*Definition: element types.* The element type of a type $`t` is that of
its elements through any number of lists and arrays, or $`t` itself.
:::

:::readable MojoGrimoire.Check.throughList (fingerprint := "15034747893672114577")
*Definition: list edges.* A field of type $`t` holds the struct it reaches
through a list when some list wraps it, under any number of arrays and
lists.
:::

:::readable MojoGrimoire.Check.successors MojoGrimoire.Check.reach (fingerprint := "4205337989175697884")
*Definition: reachable structs.* A field leads to the struct of its
element type. The successors of a struct, through the fields whose type
satisfies a predicate, are the structs that those fields lead to. The
structs reached from a set within $`n` steps are the set and, step by
step, the successors of the structs added by the last step that were not
reached yet, until a step adds none. When the $`n` steps run out before
that, the search gives nothing, rather than the structs it has reached so
far.
:::

:::readable MojoGrimoire.Check.rejectedCycle (pin := MojoGrimoire.Check.elemBase) (pin := MojoGrimoire.Check.throughList) (pin := MojoGrimoire.Check.successors) (pin := MojoGrimoire.Check.reach) (fingerprint := "17617289590823502105")
*Definition: rejected cycles.* A field leads to the struct of its element
type, through a list when some list wraps it. A cycle of fields none of
which is through a list is rejected: a struct that holds itself, directly
or through arrays, has no finite layout. A cycle with a field through a
list is accepted, whatever its other fields, since the list keeps it
finite; the compiler rejects some of these, a compiler bug (D-0006). A
field of the struct $`S` that is not through a list is rejected when it
leads back to $`S` along fields none of which is through a list. Each
step of the search adds a struct of the program not reached yet, except
perhaps the last, which adds only names that the program does not
declare, so the search ends within one step more than the program has
structs. A search that runs out of steps rejects the field, so the check
never accepts a field it has not searched to the end.
:::

:::readable MojoGrimoire.Check.passedByValue (fingerprint := "8359022073465340314")
*Definition: places passed by value.* A place passed to a `var`
parameter, or an $`\mathsf{Int}` or a $`\mathsf{Bool}` passed to a
`read` one, is passed by value. Any other place is passed by reference.
:::

:::readable MojoGrimoire.Check.consumedReceiver (fingerprint := "18022522862863130174")
*Definition: consumed receivers.* A method call whose receiver is
$`q\,\hat{}` consumes $`q` when the method's `self` is `var`: Mojo
transfers $`q` into it. Any other receiver is passed by its convention.
:::
