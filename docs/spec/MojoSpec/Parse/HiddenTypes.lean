import VersoManual
import MojoGrimoire.Parse.HiddenTypes
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Parse.HiddenTypes`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Types that a variable hides: readable blocks" =>

:::moduleDocs (fingerprint := "15169841655853635901")
:::

:::readable MojoGrimoire.Parse.Ty.markHidden (fingerprint := "17310990593456863048")
*Definition: marking a type.* Where the variables $`vs` are in scope, a
type $`\mathsf{Int}`, $`\mathsf{Bool}` or a struct $`S` other than
`Self`, also inside a list or an array type, is marked as hidden
(`hiddenTy`) when one of $`vs` has its name. `List`, `Array` and `None`
are never marked.
:::

:::readable MojoGrimoire.Parse.Place.markHidden MojoGrimoire.Parse.Expr.markHidden MojoGrimoire.Parse.Expr.listMarkHidden (fingerprint := "6603496113252030798")
*Definition: marking an expression.* The types of
$`\mathsf{List}[u]()` and $`\mathsf{List}[u](\ldots)` are marked wherever
they stand in an expression, also inside an index of a place. A literal's
type, which inference finds, is left as it is.
:::

:::readable MojoGrimoire.Parse.Stmt.markHidden MojoGrimoire.Parse.Stmt.blockMarkHidden (fingerprint := "7911965465432367716")
*Definition: marking a block.* A statement's types and expressions are
marked where the variables before it are in scope. $`\mathsf{var}~x : t`
marks $`t` and its initializer without $`x`, then brings $`x` into scope,
as $`\mathsf{ref}~x = e` does; the blocks of `if` and `while` mark their
statements in a scope that ends with them.
:::

:::readable MojoGrimoire.Parse.Param.listMarkHidden MojoGrimoire.Parse.FunDecl.markHidden MojoGrimoire.Parse.markHidden (fingerprint := "7076216158293291452")
*Definition: marking a program.* Each parameter's type is marked where
the parameters before it are in scope, and the result and the body where
every parameter is. A program's functions, and its structs' methods,
initializers and destructors, are marked; a field's type is not, since no
variable is in scope there.
:::
