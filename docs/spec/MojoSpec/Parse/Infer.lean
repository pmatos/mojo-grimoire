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

:::moduleDocs (fingerprint := "4901654192864183592")
:::

:::readable MojoGrimoire.Parse.TyEnv MojoGrimoire.Parse.binaryResult (fingerprint := "17188177613617268651")
*Definition: the types in scope.* Inference keeps the types of the
variables in scope, innermost first. An arithmetic operator gives an
$`\mathsf{Int}`, and every other binary operator a $`\mathsf{Bool}`.
:::

:::readable MojoGrimoire.Parse.inferPlace MojoGrimoire.Parse.inferExpr MojoGrimoire.Parse.inferList (fingerprint := "4134415264142089499")
*Definition: the types of places and expressions.* A variable has its
declared type, a field the type its struct declares, and an element its
list's element type. A literal has its own type. A call of a struct has
the struct's type, a call of a function its result, and `len` gives an
$`\mathsf{Int}`. A method of a list gives $`\mathsf{None}`, and a method
of a struct its result. A literal left open takes the type expected where
it stands: a list type as it is, and an array type with the literal's own
length, which the checker compares. With no list or array expected, it is
an array of its elements, of the type of the first: Mojo's
$`\mathsf{Array}[t, n]`. The elements of a literal are expected to have its
element type, and the arguments of a call the types of its parameters; the
argument of `append` is expected to be an element of the list. The drops
that elaboration inserts have the type of their operation. Inference fills
in the literals inside an expression as it goes; where it finds no type,
it gives none.
:::

:::readable MojoGrimoire.Parse.openLiteralTy MojoGrimoire.Parse.elemExpected MojoGrimoire.Parse.callParamTys MojoGrimoire.Parse.methodParamTys (fingerprint := "5802502470161267199")
*Definition: expected types.* A literal of $`n` elements expected to have
the type $`\mathsf{List}[t]` has that type, and one expected to have the
type $`\mathsf{Array}[t, m]` has the type $`\mathsf{Array}[t, n]`;
otherwise its elements decide. Its elements are expected to have its
element type. The arguments of a call are expected to have the types of
the parameters of the function, of the struct's initializer, or of the
struct's fields when it has none; those of a method, the types of its
parameters after `self`.
:::

:::readable MojoGrimoire.Parse.inferStmt MojoGrimoire.Parse.inferBlock (fingerprint := "507949887862353920")
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
