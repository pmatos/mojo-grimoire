import VersoManual
import MojoGrimoire.Parse.Infer
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Parse.Infer`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Type inference: readable blocks" =>

:::moduleDocs (fingerprint := "8455550574986616351")
:::

:::readable MojoGrimoire.Parse.TyEnv MojoGrimoire.Parse.binaryResult (fingerprint := "7491183084080357663")
*Definition: the types in scope.* Inference keeps the types of the
variables in scope, innermost first. An arithmetic operator gives an
$`\mathsf{Int}`, and every other binary operator a $`\mathsf{Bool}`.
:::

:::readable MojoGrimoire.Parse.inferPlace MojoGrimoire.Parse.inferExpr MojoGrimoire.Parse.inferList (fingerprint := "17223929135659761574")
*Definition: the types of places and expressions.* A variable has its
declared type, a field the type its struct declares, and an element the
element type of its list or array, and $`p\,\hat{}` the type of $`p`. A literal has its own type, and
`p.copy()` the type of $`p`. A negation gives an $`\mathsf{Int}`, `not` a
$`\mathsf{Bool}`, and a binary operator the type of its result, as above.
A call or a method call
has the result of its signature. A call of a struct that cannot be built
still has the struct's type, so that the checker reports why, and `len`
gives an $`\mathsf{Int}`. Any other call with no signature has no type. A literal left open takes the type expected where
it stands, a list type or an array type, and the checker compares an
array's size with the literal's length. With no list or array expected, it is
an array of its elements, of the type of the first: Mojo's
$`\mathsf{Array}[t, n]`. The elements of a literal are expected to have its
element type, and the arguments of a call the types of its parameters; the
argument of `append` is expected to be an element of the list, and the
index of `pop(i)` an $`\mathsf{Int}`. The drops
that elaboration inserts have the type of their operation. Inference fills
in the literals inside an expression as it goes; where it finds no type,
it gives none. A transfer $`p\,\hat{}` of an $`\mathsf{Int}` or a
$`\mathsf{Bool}` becomes the place $`p`, since Mojo does not move such a
value, wherever $`p` is: also an element of a list or an array, or a field
of one.
:::

:::readable MojoGrimoire.Parse.openLiteralTy MojoGrimoire.Parse.elemExpected MojoGrimoire.Parse.paramTys MojoGrimoire.Parse.unsignedResult (fingerprint := "18258247691432712068")
*Definition: expected types.* A literal expected to have a list type or an
array type has that type, which the checker compares with its elements;
otherwise its elements decide. Its elements are expected to have its
element type. The arguments of a call or a method call are expected to
have the types of the parameters of its signature, for the number of
arguments of the call, and those of a call with no signature nothing. So
`append` takes an element of its list, `pop()` nothing and `pop(i)` an
$`\mathsf{Int}`, and a struct that cannot be built takes nothing. A call
with no signature has the type of a struct the program declares, `len`'s
$`\mathsf{Int}`, or none.
:::

:::readable MojoGrimoire.Parse.inferStmt MojoGrimoire.Parse.inferBlock (fingerprint := "9908368116585406001")
*Definition: statements.* `var x = e` declares $`x` with the type of $`e`,
and `ref x = e` binds $`x` with the type of $`e`. An initial value is
expected to have the declared type of its variable, an assigned value the
type of the place it is assigned to, and a returned value the function's
result. A block is
inferred in order, each statement seeing the variables declared before it;
the variables of an inner block do not leave it.
:::

:::readable MojoGrimoire.Parse.inferFun MojoGrimoire.Parse.inferStruct MojoGrimoire.Parse.inferProgram MojoGrimoire.Parse.parse (fingerprint := "9524892158114152691")
*Definition: parsing a program.* Inference starts each function from its
parameters, and each destructor from `self`. Parsing a program lexes and
parses its text, and then infers inside every declaration.
:::
