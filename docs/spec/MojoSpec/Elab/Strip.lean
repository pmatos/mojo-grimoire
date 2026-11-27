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

:::moduleDocs (fingerprint := "5884568760521945247")
:::

:::readable MojoGrimoire.Elab.stripPlace MojoGrimoire.Elab.stripExpr MojoGrimoire.Elab.stripExprs (fingerprint := "11164421411142739363")
*Definition: erasing drops from expressions.* A place or an expression with
every $`\mathsf{drops}(e; p^*; q^*)` and every $`\mathsf{temp}~x := e` in
it replaced by $`e`, at every depth.
:::

:::readable MojoGrimoire.Elab.stripStmt MojoGrimoire.Elab.stripBlock (fingerprint := "16697511624580475593")
*Definition: erasing drops.* A statement or block with every `drop` in it
removed, and every declaration of a hidden variable (`isTempName`), inside
branches and loop bodies too, and the drops and temporaries erased from
its expressions.
:::

:::readable MojoGrimoire.Elab.stripFun MojoGrimoire.Elab.stripStruct MojoGrimoire.Elab.stripProgram (fingerprint := "17319533999491605863")
*Definition: erasing the drops of a program.* Every body of the program,
with its drops erased.
:::

:::readable MojoGrimoire.Elab.stripBlock_append MojoGrimoire.Elab.stripBlock_drops (fingerprint := "7754265541661857393")
*Lemma.* Erasing drops distributes over concatenation, and erases the drops
that elaboration adds to nothing.
:::

:::readable MojoGrimoire.Elab.stripExpr_withDropsOf MojoGrimoire.Elab.stripExpr_elabExpr MojoGrimoire.Elab.stripExprs_elabOps MojoGrimoire.Elab.stripExpr_elabLate (fingerprint := "8640328033391100900")
*Lemma: expressions.* Erasing the drops of an operation that elaboration
wraps gives the operation, and erasing the drops of an elaborated
expression, or list of operands, gives what was elaborated, with its drops
erased. The proof is by mutual induction on expressions and lists of them.
:::

:::readable MojoGrimoire.Elab.stripExprs_elabPrintOps (fingerprint := "4068548137934973793")
*Lemma: the operands of print.* Erasing the drops of the elaborated
operands of `print` gives the operands, with their drops erased, by
induction on the list of operands.
:::

:::readable MojoGrimoire.Elab.stripExpr_elabReturn MojoGrimoire.Elab.stripBlock_elabStmt MojoGrimoire.Elab.stripBlock_elabBlock MojoGrimoire.Elab.stripBlock_elabBody (fingerprint := "4047838485057190857")
*Lemma: statements, blocks and bodies.* Erasing the drops of the
elaborated value of a `return` gives the value, and erasing the drops of
an elaborated statement, block or body gives what was elaborated, with its
drops erased. The proof is by mutual induction on statements and blocks,
using the lemmas on expressions.
:::

:::readable MojoGrimoire.Elab.isTempName_tempName MojoGrimoire.Elab.stripBlock_tempDecls MojoGrimoire.Elab.stripExpr_wrapTemp MojoGrimoire.Elab.stripExpr_tempExpr MojoGrimoire.Elab.stripExprs_tempArgs MojoGrimoire.Elab.stripBlock_withTemps MojoGrimoire.Elab.stripBlock_tempStmt MojoGrimoire.Elab.stripBlock_tempBlock (fingerprint := "14623661532255733941")
*Lemma: temporaries.* The declarations of hidden variables erase to
nothing, and so does a temporary in an argument. So naming the
temporaries of an expression, a list of arguments, a statement or a block,
and declaring their hidden variables, gives what it named once erased. The
proof is by mutual induction on expressions and lists of them, then on
statements and blocks.
:::

:::readable MojoGrimoire.Elab.stripProgram_elabProgram (fingerprint := "18027251158332834446")
*Theorem: elaboration only inserts drops.* A program and its elaboration
are the same once their drops, temporaries and hidden variables are
erased. Elaboration changes when values are destroyed, and nothing else.
:::
