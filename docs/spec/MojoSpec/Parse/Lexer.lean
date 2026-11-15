import VersoManual
import MojoGrimoire.Parse.Lexer
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Parse.Lexer`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "The lexer: readable blocks" =>

:::moduleDocs (fingerprint := "15672268694869089244")
:::

:::readable MojoGrimoire.Parse.Tok MojoGrimoire.Parse.Token MojoGrimoire.Parse.SyntaxError (fingerprint := "12871311785592106213")
*Definition: tokens and syntax errors.*

$$`\begin{array}{lcl}
\mathit{tok} & ::= & \mathit{name} \\
 & \mid & n \\
 & \mid & \mathit{string} \\
 & \mid & \mathit{symbol} \\
 & \mid & \mathsf{newline} \\
 & \mid & \mathsf{indent} \\
 & \mid & \mathsf{dedent}
\end{array}`

A token is a name or keyword, a natural-number literal, a string literal,
a symbol, the end of a logical line, or a change of indentation. Each token
carries the line it starts on, counted from 1. A syntax error, from the
lexer or the parser, gives a line and a message.
:::

:::readable MojoGrimoire.Parse.symbols MojoGrimoire.Parse.isNameStart MojoGrimoire.Parse.isNameChar (fingerprint := "961679266447367512")
*Definition: symbols and names.* The symbols are listed longest first, so
that the longest symbol at a position is read: `//` before `/`, `->` before
`-`. A name starts with a letter or `_` and continues with letters, digits
and `_`.
:::

:::readable MojoGrimoire.Parse.lexChars MojoGrimoire.Parse.lexChars.close MojoGrimoire.Parse.lexLine (fingerprint := "18221403455036770234")
*Definition: the tokens of a line.* The characters of a line are read left
to right. Blanks are skipped and `#` ends the line. Digits make an integer
literal, and a name start makes a name. `"""…"""` is a docstring, which
must close on its line, and `"…"` a string literal. Anything else is the
longest symbol that matches, or an error. The lexer counts open
parentheses and square brackets, the bracket depth, across lines. Each step
reads at least one character, so the length of the line is enough fuel.
:::

:::readable MojoGrimoire.Parse.indentation MojoGrimoire.Parse.isBlank (fingerprint := "13018137188185731497")
*Definition: indentation and blank lines.* A line's indentation is its
number of leading spaces. A line that is empty, or holds only blanks and a
comment, is blank, and the lexer skips it.
:::

:::readable MojoGrimoire.Parse.lexLines MojoGrimoire.Parse.lex (fingerprint := "3269693425791201034")
*Definition: layout.* The lexer keeps a stack of the indentations of the
enclosing blocks, starting with $`[0]`. A line deeper than the top of the
stack pushes it and starts with $`\mathsf{indent}`; a shallower line pops
every deeper indentation, with one $`\mathsf{dedent}` each, and must land on
one that is on the stack. A logical line ends with $`\mathsf{newline}`,
unless a bracket is still open: then the next line continues it, whatever
its indentation. At the end of the file every open block is closed.
:::
