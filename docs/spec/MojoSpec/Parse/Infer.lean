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

:::moduleDocs (fingerprint := "6242404514614913019")
:::

:::readable MojoGrimoire.Parse.TyEnv MojoGrimoire.Parse.binaryResult (fingerprint := "17188177613617268651")
*Definition: the types in scope.* Inference keeps the types of the
variables in scope, innermost first. An arithmetic operator gives an
$`\mathsf{Int}`, and every other binary operator a $`\mathsf{Bool}`.
:::

:::readable MojoGrimoire.Parse.inferPlace MojoGrimoire.Parse.inferExpr MojoGrimoire.Parse.inferList (fingerprint := "79296385413240963")
*Definition: the types of places and expressions.* A variable has its
declared type, a field the type its struct declares, and an element its
list's element type. A literal has its own type. A call of a struct has
the struct's type, a call of a function its result, and `len` gives an
$`\mathsf{Int}`. A method of a list gives $`\mathsf{None}`, and a method
of a struct its result. A list literal left open takes the type of its
first element, and the drops that elaboration inserts the type of their
operation. Inference fills in the literals inside an expression as it
goes; where it finds no type, it gives none.
:::

:::readable MojoGrimoire.Parse.expecting (fingerprint := "16990100330322309864")
*Definition: expected types.* An empty list literal `[]` takes the element
type of the list type it is expected to have.
:::

:::readable MojoGrimoire.Parse.inferStmt MojoGrimoire.Parse.inferBlock (fingerprint := "507949887862353920")
*Definition: statements.* `var x = e` declares $`x` with the type of $`e`,
and `ref x = e` binds $`x` with the type of $`e`. An empty list is expected
to have the declared type of its variable, the type of the place it is
assigned to, or the function's result when it is returned. A block is
inferred in order, each statement seeing the variables declared before it;
the variables of an inner block do not leave it.
:::

:::readable MojoGrimoire.Parse.inferFun MojoGrimoire.Parse.inferStruct MojoGrimoire.Parse.inferProgram MojoGrimoire.Parse.parse (fingerprint := "9524892158114152691")
*Definition: parsing a program.* Inference starts each function from its
parameters, and each destructor from `self`. Parsing a program lexes and
parses its text, and then infers inside every declaration.
:::
