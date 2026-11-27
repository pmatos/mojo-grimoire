import VersoManual
import MojoGrimoire.Check.Block
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Block`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Blocks: readable blocks" =>

:::moduleDocs (fingerprint := "304662169746679265")
:::

:::readable MojoGrimoire.Check.checkCond MojoGrimoire.Check.checkStmt MojoGrimoire.Check.checkScope MojoGrimoire.Check.checkBlock (fingerprint := "6013654905548759369")
*Rule: blocks.* A statement that holds no block is checked by the rule
of statements, and a condition needs a $`\mathsf{Bool}`.

* `if` needs a $`\mathsf{Bool}` condition and joins its branches, each a
  scope of its own; `while` needs a $`\mathsf{Bool}` condition and a
  body that keeps what was initialized. When the body can reach its end,
  the next iteration starts from the state before the loop with $`M`,
  $`H`, $`T`, $`P` and the invalidated references joined with those the
  body leaves; when that adds anything, the condition and the body are
  checked once more from it. After the loop, which may have run any number
  of times, the state is that one, with $`M`, $`H`, $`T` and $`P` of the
  second check joined in too.

A block checks its statements in order, and the changes recorded for
operands start afresh with each statement. What the instantiation phase records in a
branch or a loop's body is kept after it, in the order of the text.
:::
