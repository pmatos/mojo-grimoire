import VersoManual
import MojoGrimoire.Core.Equality
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Core.Equality`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Equality of terms: readable blocks" =>

:::moduleDocs (fingerprint := "13486367665186715618")
:::

:::readable MojoGrimoire.Core.Place.beq MojoGrimoire.Core.instBEqPlace MojoGrimoire.Core.Expr.beq MojoGrimoire.Core.Place.beqList MojoGrimoire.Core.Expr.beqList MojoGrimoire.Core.Expr.beqOption MojoGrimoire.Core.instBEqExpr (fingerprint := "14332551025486297835")
*Definition: equality of places and expressions.* Two places, or two
expressions, are equal when they are the same tree: the same constructor, with equal parts. Lists of
places and of expressions are equal element by element, and optional expressions when both
are absent or both present and equal. This equality is a test, written `==`;
the Lean writes it out by structural recursion, since equality derived by
Lean would be partial on a type that nests lists of itself.
:::

:::readable MojoGrimoire.Core.Stmt.beq MojoGrimoire.Core.Stmt.beqList MojoGrimoire.Core.instBEqStmt (fingerprint := "16711564836129394078")
*Definition: equality of statements.* Two statements are equal, written
`==`, when they are the same tree, comparing their expressions with the
equality above and their blocks statement by statement.
:::
