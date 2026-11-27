import VersoManual
import MojoGrimoire.Parse.Subset
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Parse.Subset`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Constructs outside the subset: readable blocks" =>

:::moduleDocs (fingerprint := "6713392529538466924")
:::

:::readable MojoGrimoire.Parse.Outside MojoGrimoire.Parse.ReadError MojoGrimoire.Parse.outsideString MojoGrimoire.Parse.outsideRange MojoGrimoire.Parse.outsideLoopExit MojoGrimoire.Parse.loopExit (pin := MojoGrimoire.Parse.loopExits) (fingerprint := "12198467578375226299")
*Definition: constructs outside the subset.* A construct outside the
subset is reported with the line where the statement that holds it starts
and what it is: a string literal outside `print`, a call of `range`
outside $`\mathsf{List}[T](\ldots)`, or a $`\mathsf{break}` or
$`\mathsf{continue}` statement (#268), which the parser reads as a call
with no arguments of a callee of that name (`loopExit`). The text of a
file is no program of the subset when it has a syntax error or such a
construct.
:::

:::readable MojoGrimoire.Parse.stdRange (fingerprint := "12363406301872528563")
*Definition: the standard library's `range`.* A call of `range` calls
the standard library's when no variable or parameter in scope, and no
struct or function of the program, is named `range` (#176); the second
half is the checker's own test, `builtinRange`.
:::

:::readable MojoGrimoire.Parse.Place.outside MojoGrimoire.Parse.Expr.outside MojoGrimoire.Parse.Expr.listOutside (fingerprint := "5740984364388510973")
*Definition: constructs in an expression.* The first construct outside
the subset in an expression, in the order of its text, is a string
literal, or a call of the standard library's `range`, at any depth, also
in the index of a place. The one argument of
$`\mathsf{List}[T](\mathsf{range}(\ldots))` is the call of `range` that
the subset takes, whose own arguments are checked.
:::

:::readable MojoGrimoire.Parse.foundIn MojoGrimoire.Parse.Stmt.outside MojoGrimoire.Parse.Stmt.blockOutside (fingerprint := "7350593405211082892")
*Definition: constructs in a block.* The statements are walked in the
order of the file, each before the statements it holds, and numbered so;
the walk stops at the first statement that holds a construct. A
$`\mathsf{var}~x` or $`\mathsf{ref}~x` brings $`x` into scope after its
initializer, for the rest of its block. The arguments of the `print`
statement may be string literals, unless a variable named `print` makes
the statement a call of it. A $`\mathsf{break}` or $`\mathsf{continue}`
statement is outside the subset wherever it stands.
:::

:::readable MojoGrimoire.Parse.FunDecl.outside MojoGrimoire.Parse.outsideSubset MojoGrimoire.Parse.parseSubset (fingerprint := "7885277836923273557")
*Definition: constructs in a program.* The functions, methods,
initializers and destructors are walked in the order of the file, each
with its parameters in scope, and the first construct is reported at the
line that the parser recorded for its statement. `parseSubset` parses a
file, fails with its syntax error or its first construct outside the
subset, and otherwise gives the program that `parse` gives. The driver
reports the construct as `outside the subset: line N: MESSAGE`, with
exit 3 (#180).
:::
