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

:::moduleDocs (fingerprint := "12603978488659590576")
:::

:::readable MojoGrimoire.Parse.PState MojoGrimoire.Parse.P MojoGrimoire.Parse.peek MojoGrimoire.Parse.peek2 MojoGrimoire.Parse.curLine MojoGrimoire.Parse.markStmt MojoGrimoire.Parse.fail MojoGrimoire.Parse.next (fingerprint := "2346832099094864449")
*Definition: the parser's monad.* A parser holds the tokens left to read
and may fail with a syntax error. It can look at the next token and the one
after it, and read the next token. A failure is reported at the line of
the next token, the one the parser stopped at, or at line 0 when no token
is left. It also records the line of the next token where a statement
starts (`markStmt`), and each function it has read with the lines of its
statements, from which the check of the constructs outside the subset
reports a line (#180).
:::

:::readable MojoGrimoire.Parse.atSym MojoGrimoire.Parse.atKw MojoGrimoire.Parse.acceptSym MojoGrimoire.Parse.acceptKw MojoGrimoire.Parse.expectSym MojoGrimoire.Parse.expectKw MojoGrimoire.Parse.expectNewline MojoGrimoire.Parse.skipNewlines (fingerprint := "8776066741729761534")
*Definition: reading expected tokens.* `at` tests the next token, `accept`
reads it when it is the one given and says whether it was, and `expect`
reads it or fails. Empty logical lines may be skipped.
:::

:::readable MojoGrimoire.Parse.loopExits MojoGrimoire.Parse.keywords MojoGrimoire.Parse.name MojoGrimoire.Parse.memberName (fingerprint := "3055080341729133795")
*Definition: names.* A name is an identifier token that is not a keyword:
`def`, `fn`, `struct`, `var`, `ref`, the control-flow words, the boolean
operators and literals, the argument conventions `mut`, `out` and
`deinit`, and `raises`. `imm`, `read` and `owned` are names, as in the
compiler; the parser reads `imm` and `read` specially where a parameter
starts. `break` and `continue` (`loopExits`) are keywords, so that a
variable, a parameter, a function or a field of either name is a syntax
error, as the compiler fails to parse it (#268). As in the compiler, a
method's name in a struct and the name after `.` may be either word
(`memberName`).
:::

:::readable MojoGrimoire.Parse.ty MojoGrimoire.Parse.typeArgument (fingerprint := "4722139437781860587")
*Definition: types.*

$$`\begin{array}{lcl}
\mathit{type} & ::= & \mathsf{Int} \mid \mathsf{Bool} \mid \mathsf{None} \\
 & \mid & \mathsf{List}[\mathit{type}] \mid \mathsf{Array}[\mathit{type}, n] \\
 & \mid & \mathit{name}
\end{array}`

The size $`n` of an array is an integer literal. Any other name is the
name of a struct, which the checker looks up. In the
parser's output, $`?` stands for a type that the program leaves to
inference (#131). $`\mathsf{None}` as the type argument of a list or an
array is a value where Mojo expects a type, which the compiler rejects:
`typeArgument` reads it as $`?`, which the checker rejects as `invalidType`
(#183).
:::
