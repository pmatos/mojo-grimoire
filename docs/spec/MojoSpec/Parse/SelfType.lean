import VersoManual
import MojoGrimoire.Parse.SelfType
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Parse.SelfType`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Self in methods: readable blocks" =>

:::moduleDocs (fingerprint := "8884690138802357217")
:::

:::readable MojoGrimoire.Parse.Ty.withSelf MojoGrimoire.Parse.Place.withSelf MojoGrimoire.Parse.Expr.withSelf MojoGrimoire.Parse.Expr.listWithSelf MojoGrimoire.Parse.Stmt.withSelf MojoGrimoire.Parse.Stmt.blockWithSelf (fingerprint := "1496505879312861720")
*Definition: replacing Self.* `Self` is replaced by the struct $`S` in a
type, also inside a list or an array type, and in every type that a
place, an expression or a statement holds: the type of a declared
variable, of a list literal and of $`\mathsf{List}[u](\ldots)`.
:::

:::readable MojoGrimoire.Parse.FunDecl.withSelf MojoGrimoire.Parse.resolveSelf (fingerprint := "17484178061955353782")
*Definition: Self in a program.* In each struct's methods, initializer and
destructor, `Self` is the struct: in the types of their parameters and
results, and inside their bodies. The fields of a struct, and the
functions of the program, keep `Self` as written.
:::
