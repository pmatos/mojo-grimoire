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

:::moduleDocs (fingerprint := "10174287965529684323")
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

:::readable MojoGrimoire.Parse.nonOperandKeywords MojoGrimoire.Parse.startsOperand (fingerprint := "5206625054672960058")
*Definition: tokens that start an operand.* A token can start an
expression when it is an integer or string literal, one of the symbols
`+`, `-`, `*`, `(`, `[` and `==`, or a name that is not one of the
compiler's keywords `and`, `as`, `assert`, `break`, `case`, `class`,
`continue`, `del`, `elif`, `else`, `except`, `finally`, `for`, `from`,
`global`, `if`, `import`, `in`, `is`, `match`, `nonlocal`, `or`, `pass`,
`raise`, `return`, `struct`, `trait`, `try`, `while`, `with`, `yield`,
`__extension`, `__mlir_region`, `__match` and `__enum`. This is the
compiler's `isPrimaryExprStart` without `.`, restricted to the tokens the
lexer reads. The end of a logical line and a change of indentation start
no expression.
:::

:::readable MojoGrimoire.Parse.expr MojoGrimoire.Parse.orRest MojoGrimoire.Parse.andExpr MojoGrimoire.Parse.andRest MojoGrimoire.Parse.notExpr MojoGrimoire.Parse.sum MojoGrimoire.Parse.sumRest MojoGrimoire.Parse.product MojoGrimoire.Parse.productRest MojoGrimoire.Parse.unaryExpr MojoGrimoire.Parse.chain MojoGrimoire.Parse.trailers MojoGrimoire.Parse.primary MojoGrimoire.Parse.exprList (fingerprint := "7573940696555006066")
*Definition: expressions.*

$$`\begin{array}{lcl}
e & ::= & e~\mathsf{or}~e \mid e~\mathsf{and}~e \mid \mathsf{not}~e \\
 & \mid & e \mathbin{\mathit{cmp}} e \mid e + e \mid e - e \\
 & \mid & e * e \mid e~/\!/~e \mid e \mathbin{\%} e \mid -e \\
 & \mid & p \mid p\,\hat{} \mid p.\mathsf{copy}() \mid p.m(e^*) \mid f(e^*) \\
 & \mid & n \mid \mathit{string} \mid \mathsf{True} \mid \mathsf{False} \mid (e) \\
 & \mid & [e^*] \mid \mathsf{List}[\mathit{type}](e^*) \\
p & ::= & x \mid p.f \mid p[e] \mid p\,\hat{}.f
\end{array}`

The rows run from the loosest operators to the tightest. `or`, `and`, the
additive and the multiplicative operators associate to the left; a
comparison is not chained, and `not` takes a comparison or another `not`.
A negated integer literal is a negative literal. A postfix chain starts
from a primary expression: fields and indices of a place stay a place,
and `^`, `.copy()`, a method call or a call make an expression. A call
names a function or a struct. `^` is a transfer only when the token after
it does not start an operand; otherwise the compiler reads binary XOR,
which is outside the subset, and the parser fails (#54). So $`p\,\hat{}`
ends a chain, what follows it being an operator or the end of the
expression, unless `.` follows it: then it is the place $`p\,\hat{}`,
whose fields and methods the chain goes on to read, as the compiler does
for `p^.f` and `p^.m(…)` (#66).
A literal $`[e^*]` is left for inference to type, and $`\mathsf{List}[\mathit{type}]()` is an empty list literal.
With arguments, $`\mathsf{List}[\mathit{type}](e^+)` is its own expression, which the checker accepts only for one
argument, a list or an array that it copies (#103), or a call of the standard library's `range` (#121), and rejects
otherwise (#46). The compiler also accepts other iterables, which are outside the subset. Each function takes fuel and spends it on
each call, so parsing ends.
:::
