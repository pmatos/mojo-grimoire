import VersoManual
import MojoGrimoire.Parse.Expr
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Parse.Expr`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Expressions: readable blocks" =>

:::moduleDocs (fingerprint := "14970591485620210808")
:::

:::readable MojoGrimoire.Parse.Term MojoGrimoire.Parse.Term.toExpr (fingerprint := "13183905014692490612")
*Definition: terms.* A postfix chain is a place while it reads only fields
and indices of a name, and an expression once it reads anything else. A
place used where an expression is expected is read as a value.
:::

:::readable MojoGrimoire.Parse.compOps MojoGrimoire.Parse.addOps MojoGrimoire.Parse.mulOps MojoGrimoire.Parse.acceptOp (fingerprint := "6467674933063426272")
*Definition: operators.* The binary operators fall in three levels:
comparisons `<`, `<=`, `>`, `>=`, `==`, `!=`; additive `+`, `-`; and
multiplicative `*`, `//`, `%`. The parser reads an operator of a level
when it is next.
:::

:::readable MojoGrimoire.Parse.expr MojoGrimoire.Parse.orRest MojoGrimoire.Parse.andExpr MojoGrimoire.Parse.andRest MojoGrimoire.Parse.notExpr MojoGrimoire.Parse.sum MojoGrimoire.Parse.sumRest MojoGrimoire.Parse.product MojoGrimoire.Parse.productRest MojoGrimoire.Parse.unaryExpr MojoGrimoire.Parse.chain MojoGrimoire.Parse.trailers MojoGrimoire.Parse.primary MojoGrimoire.Parse.exprList (fingerprint := "6198610230411943232")
*Definition: expressions.*

$$`\begin{array}{lcl}
e & ::= & e~\mathsf{or}~e \mid e~\mathsf{and}~e \mid \mathsf{not}~e \\
 & \mid & e \mathbin{\mathit{cmp}} e \mid e + e \mid e - e \\
 & \mid & e * e \mid e~/\!/~e \mid e \mathbin{\%} e \mid -e \\
 & \mid & p \mid p\,\hat{} \mid p.\mathsf{copy}() \mid p.m(e^*) \mid f(e^*) \\
 & \mid & n \mid \mathit{string} \mid \mathsf{True} \mid \mathsf{False} \mid (e) \\
 & \mid & [e^*] \mid \mathsf{List}[\mathit{type}](e^*) \\
p & ::= & x \mid p.f \mid p[e]
\end{array}`

The rows run from the loosest operators to the tightest. `or`, `and`, the
additive and the multiplicative operators associate to the left; a
comparison is not chained, and `not` takes a comparison or another `not`.
A negated integer literal is a negative literal. A postfix chain starts
from a primary expression: fields and indices of a place stay a place,
and `^`, `.copy()`, a method call or a call make an expression. A call
names a function or a struct. A literal $`[e^*]` is left for inference to
type, and $`\mathsf{List}[\mathit{type}](e^*)` is a list literal; Mojo
1.2.0 accepts it only with no elements (#46). Each function takes fuel and spends it on
each call, so parsing ends.
:::
