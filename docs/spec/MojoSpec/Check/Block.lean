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

#doc (Manual) "Blocks and the bridge to main's order: readable blocks" =>

:::moduleDocs (fingerprint := "316376257180527850")
:::

:::readable MojoGrimoire.Check.bridged (fingerprint := "15637765802588083994")
*Rule: the bridge to `main`'s order.* A check of a statement or a
condition that has a twin, the one that `main`'s inference gave, is
bridged. When the check fails, the twin is checked as `main` did, from
the same state. When the twin fails too, its error, `main`'s, is
reported; when it passes, the first error stands. A check with no twin
is not bridged. The twin is inferred only once a check fails, so an
accepted statement costs nothing more. The bridge is temporary: #96
part 4 orders the model's errors as the compiler does.
:::

:::readable MojoGrimoire.Check.twinIf MojoGrimoire.Check.twinWhile MojoGrimoire.Check.checkCond (fingerprint := "7555081701817251173")
*Definition: twins of conditions and blocks.* The twin of an `if` gives
the twin of its condition and of its two blocks, and that of a loop the
twin of its condition and of its body; a twin of another form, or none,
gives no condition and empty blocks. A condition is checked bridged to
its twin, then needs a $`\mathsf{Bool}`.
:::

:::readable MojoGrimoire.Check.checkStmt MojoGrimoire.Check.checkScope MojoGrimoire.Check.checkBlock (fingerprint := "2214868477864486889")
*Rule: blocks.* A statement that holds no block is checked by the rule
of statements, bridged to its twin.

* `if` needs a $`\mathsf{Bool}` condition and joins its branches, each a
  scope of its own; `while` needs a $`\mathsf{Bool}` condition and a
  body that keeps what was initialized. When the body can reach its end,
  the next iteration starts from the state before the loop with $`M`,
  $`H`, $`T`, $`P` and the invalidated references joined with those the
  body leaves; when that adds anything, the condition and the body are
  checked once more from it. After the loop, which may have run any number
  of times, the state is that one, with $`M`, $`H`, $`T` and $`P` of the
  second check joined in too. Each condition is bridged to its twin, and
  each block is checked beside its twin.

A block checks its statements in order, each beside the statement at the
same position in its twin, and the changes recorded for operands start
afresh with each statement.
:::
