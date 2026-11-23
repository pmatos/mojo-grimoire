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

:::moduleDocs (fingerprint := "16610191441976609754")
:::

:::readable MojoGrimoire.Check.CheckError.typed MojoGrimoire.Check.CheckError.owned (fingerprint := "1609402254190167827")
*Definition: errors of typing and of ownership.* A type mismatch, a
method that a type lacks, and an unknown variable, function or attribute
are found as the program is typed. An implicit copy and the use of an
uninitialized value are errors of ownership.
:::

:::readable MojoGrimoire.Check.bridged (fingerprint := "3089502766589725676")
*Rule: the bridge to `main`'s order.* A check of a statement or a
condition that has a twin, the one that `main`'s inference gave, is
bridged. When the check fails, a probe runs it again from the same state,
letting pass the error of each comparison with a literal that holds no
place whose value is not implicitly copyable, and counting them. When the
probe ends with no other error and exactly one such comparison, the
first error stands: it is that comparison's own. Otherwise the twin is
checked as `main` did, from the same state, and its error is reported;
when it has none, the first error stands. The first error stands too
when it is found as the program is typed and the twin's is one of
ownership, which the compiler reports later (#96), or is found as the
program is typed too. A check with no twin is not bridged. The twin is
inferred only once a check fails, so an accepted statement costs nothing
more.
:::

:::readable MojoGrimoire.Check.twinIf MojoGrimoire.Check.twinWhile MojoGrimoire.Check.checkCond (fingerprint := "7555081701817251173")
*Definition: twins of conditions and blocks.* The twin of an `if` gives
the twin of its condition and of its two blocks, and that of a loop the
twin of its condition and of its body; a twin of another form, or none,
gives no condition and empty blocks. A condition is checked bridged to
its twin, then needs a $`\mathsf{Bool}`.
:::

:::readable MojoGrimoire.Check.checkStmt MojoGrimoire.Check.checkScope MojoGrimoire.Check.checkBlock (fingerprint := "2871325450208287675")
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
