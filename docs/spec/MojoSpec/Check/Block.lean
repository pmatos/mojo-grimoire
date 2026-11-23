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

:::moduleDocs (fingerprint := "5392723304193030340")
:::

:::readable MojoGrimoire.Check.probeErrors (fingerprint := "17388420857594909131")
*Definition: a probe.* A probe checks a statement or a condition again
from the current state, letting pass the error of each comparison with a
literal operand that holds no place whose value is not implicitly
copyable, and numbering the comparisons in order. When it ends with no
other error, it gives the errors it let pass, each with its number; a
probe that meets another error gives nothing. The state is left as it
was.
:::

:::readable MojoGrimoire.Check.bridged (fingerprint := "17849206641235804087")
*Rule: the bridge to `main`'s order.* A check of a statement or a
condition that has a twin, the one that `main`'s inference gave, is
bridged. When the check fails, it is probed. The first error stands when
the probe lets exactly one comparison's error pass, numbered $`n`, and
the probe of the twin, checked as `main` did, gives errors that hold none
of the same class at $`n`, or whose first is of that class at $`n`.
Otherwise the twin is checked as `main` did, from the same state, and its
error is reported; when it has none, the first error stands. No class of
error stands over the twin's by its kind. A check with no twin is not
bridged. The twin is inferred only once a check fails, so an accepted
statement costs nothing more.
:::

:::readable MojoGrimoire.Check.twinIf MojoGrimoire.Check.twinWhile MojoGrimoire.Check.checkCond (fingerprint := "12024879113537353927")
*Definition: twins of conditions and blocks.* The twin of an `if` gives
the twin of its condition and of its two blocks, and that of a loop the
twin of its condition and of its body; a twin of another form, or none,
gives no condition and empty blocks. A condition is checked bridged to
its twin, then needs a $`\mathsf{Bool}`.
:::

:::readable MojoGrimoire.Check.checkStmt MojoGrimoire.Check.checkScope MojoGrimoire.Check.checkBlock (fingerprint := "598045508457035348")
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
