import VersoManual
import MojoGrimoire.Parse.Parser
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Parse.Parser`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "The parser's monad: readable blocks" =>

:::moduleDocs (fingerprint := "4941958006797234098")
:::

:::readable MojoGrimoire.Parse.P MojoGrimoire.Parse.peek MojoGrimoire.Parse.peek2 MojoGrimoire.Parse.curLine MojoGrimoire.Parse.fail MojoGrimoire.Parse.next (fingerprint := "11980558741493263240")
*Definition: the parser's monad.* A parser holds the tokens left to read
and may fail with a syntax error. It can look at the next token and the one
after it, and read the next token. A failure is reported at the line of
the next token, the one the parser stopped at.
:::

:::readable MojoGrimoire.Parse.atSym MojoGrimoire.Parse.atKw MojoGrimoire.Parse.acceptSym MojoGrimoire.Parse.acceptKw MojoGrimoire.Parse.expectSym MojoGrimoire.Parse.expectKw MojoGrimoire.Parse.expectNewline MojoGrimoire.Parse.skipNewlines (fingerprint := "13472585542897313469")
*Definition: reading expected tokens.* `at` tests the next token, `accept`
reads it when it is the one given and says whether it was, and `expect`
reads it or fails. Empty logical lines may be skipped.
:::

:::readable MojoGrimoire.Parse.keywords MojoGrimoire.Parse.name (fingerprint := "17069183746200021793")
*Definition: names.* A name is an identifier token that is not a keyword:
`def`, `fn`, `struct`, `var`, `ref`, the control-flow words, the boolean
operators and literals, the argument conventions and `raises`.
:::

:::readable MojoGrimoire.Parse.ty (fingerprint := "4739185668823864341")
*Definition: types.*

$$`\begin{array}{lcl}
\mathit{type} & ::= & \mathsf{Int} \mid \mathsf{Bool} \mid \mathsf{None} \\
 & \mid & \mathsf{List}[\mathit{type}] \\
 & \mid & \mathit{name}
\end{array}`

Any other name is the name of a struct, which the checker looks up. In the
parser's output, $`\mathsf{None}` also stands for a type that the program
leaves to inference.
:::
