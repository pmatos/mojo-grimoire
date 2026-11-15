import VersoManual
import MojoGrimoire.Elab.Strip
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Elab.Strip`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Elaboration only inserts drops: readable blocks" =>

:::moduleDocs (fingerprint := "2137699260014510000")
:::

:::readable MojoGrimoire.Elab.stripStmt MojoGrimoire.Elab.stripBlock (fingerprint := "17318067068892795592")
*Definition: erasing drops.* A statement or block with every `drop` in it
removed, inside branches and loop bodies too.
:::

:::readable MojoGrimoire.Elab.stripFun MojoGrimoire.Elab.stripStruct MojoGrimoire.Elab.stripProgram (fingerprint := "12505016125399784277")
*Definition: erasing the drops of a program.* Every body of the program,
with its drops erased.
:::

:::readable MojoGrimoire.Elab.stripBlock_append MojoGrimoire.Elab.stripBlock_drops (fingerprint := "7754265541661857393")
*Lemma.* Erasing drops distributes over concatenation, and erases the drops
that elaboration adds to nothing.
:::

:::readable MojoGrimoire.Elab.stripBlock_elabStmt MojoGrimoire.Elab.stripBlock_elabBlock MojoGrimoire.Elab.stripBlock_elabBody (fingerprint := "17262067809458915494")
*Lemma: statements, blocks and bodies.* Erasing the drops of an elaborated
statement, block or body gives what was elaborated, with its drops erased.
The proof is by mutual induction on statements and blocks.
:::

:::readable MojoGrimoire.Elab.stripProgram_elabProgram (fingerprint := "18027251158332834446")
*Theorem: elaboration only inserts drops.* A program and its elaboration
are the same once their drops are erased. Elaboration changes when values
are destroyed, and nothing else.
:::
