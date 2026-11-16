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

:::moduleDocs (fingerprint := "14010994217253651371")
:::

:::readable MojoGrimoire.Check.findStruct MojoGrimoire.Check.findFun MojoGrimoire.Check.fieldTy MojoGrimoire.Check.findMethod MojoGrimoire.Check.fieldOf MojoGrimoire.Check.fieldNames (fingerprint := "17441515373986636163")
*Definition: lookups.* The checker finds a struct or a function of the
program by its name, the first one declared with that name, and a field or
method of a struct by its name. `fieldOf` gives the type of the field
$`f` of a value of type $`t`, and rejects $`t` when it is not a struct,
or when the struct is unknown or has no field $`f`. `fieldNames` gives
the names of the fields of a struct type, and none for any other type.
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

:::readable MojoGrimoire.Check.listMethod (fingerprint := "5898892595285092841")
*Definition: the methods of a list.* A list of $`t` has two methods, which
take their list `mut` and depend on the number $`n` of arguments of the
call: `append` takes one `var` argument of type $`t` and gives
$`\mathsf{None}`, and `pop` gives a $`t`, a generic result. With
$`n = 0`, `pop` takes no argument; with any other $`n`, it takes one
`read` argument `i` of type $`\mathsf{Int}`, so that a call with two
arguments is an arity mismatch.
:::

:::readable MojoGrimoire.Check.typeName (fingerprint := "5915273905220259329")
*Definition: type names.* The name of a type, as Mojo writes it without
its parameters, names the type in an error about its methods.
:::

:::readable MojoGrimoire.Check.callSig MojoGrimoire.Check.methodSig (fingerprint := "7317073360924282579")
*Definition: the signature of a call.* $`f(e^*)` constructs the struct
$`f`, when the program declares one, with the parameters of its `__init__`
after `self`, or with one `var` parameter per field if it is
`@fieldwise_init`, and is rejected if it has neither; otherwise it calls
the function $`f`. `len` has no signature, since it takes a list or an
array of any type. $`p.m(e^*)` calls a method of the type of $`p`: one of
a list's methods, or a method of a struct, whose `self` takes $`p`. An
array has no methods, nor does any other type. Inference, the checker and
elaboration all read the signatures of calls here.
:::

:::readable MojoGrimoire.Check.copyingOf (fingerprint := "4318683737232947193")
*Definition: how a type is copied.* $`\mathsf{Int}` and
$`\mathsf{Bool}` are implicitly copyable, as in Mojo; a struct is copied as
it declares; a list or an array is copied only explicitly, with
`.copy()`, and only when its elements can be copied; string literals and $`\mathsf{None}` are
never copied.
:::

:::readable MojoGrimoire.Check.hasDeinit (fingerprint := "18219250075115973939")
*Definition: types with a destructor.* A type has a destructor of its own
when it is a struct that declares `__deinit__`.
:::

:::readable MojoGrimoire.Check.validTy (fingerprint := "2209953286527928859")
*Definition: declarable types.* A variable, parameter or field may have the
type $`\mathsf{Int}`, $`\mathsf{Bool}`, a struct of the program, or a
list or an array of values of such a type, and no other.
:::

:::readable MojoGrimoire.Check.elemBase MojoGrimoire.Check.contains (fingerprint := "14586368853234422197")
*Definition: containment.* A type $`t` contains the struct $`S` when it is
$`S`, a struct with a field whose type contains $`S`, or a list or an
array of a type that contains $`S`. The search looks through lists and
arrays to the type of their elements, and is bounded by the number of
structs of the program, since a longer chain of fields repeats a struct.
A struct whose field contains the struct itself is rejected: held
directly it would be infinite, and held in a list or an array the
compiler rejects it too.
:::

:::readable MojoGrimoire.Check.passedByValue (fingerprint := "8359022073465340314")
*Definition: places passed by value.* A place passed to a `var`
parameter, or an $`\mathsf{Int}` or a $`\mathsf{Bool}` passed to a
`read` one, is passed by value. Any other place is passed by reference.
:::
