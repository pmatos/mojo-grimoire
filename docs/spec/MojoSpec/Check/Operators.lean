import VersoManual
import MojoGrimoire.Check.Operators
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Check.Operators`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Operators: readable blocks" =>

:::moduleDocs (fingerprint := "2859850607926075172")
:::

:::readable MojoGrimoire.Check.binaryResult (fingerprint := "7037857992261783058")
*Definition: the result of an operator.* An arithmetic operator gives an
$`\mathsf{Int}`, and every other binary operator a $`\mathsf{Bool}`,
whatever its operands: inference types an expression by it, and so does
the checker an element whose own check fails later (`lateElemTy`).
:::

:::readable MojoGrimoire.Check.binaryTy MojoGrimoire.Check.unaryTy (fingerprint := "7769671662555249431")
*Rule: operators.* Arithmetic takes two $`\mathsf{Int}` and gives an
$`\mathsf{Int}`; $`<`, $`\le`, $`>`, $`\ge`, $`==` and $`!=`
take two values of the same type, $`\mathsf{Int}` or $`\mathsf{Bool}`,
and give a $`\mathsf{Bool}` (#185); $`\mathsf{and}` and $`\mathsf{or}` take
and give $`\mathsf{Bool}`. Negation takes an $`\mathsf{Int}`, and
$`\mathsf{not}` a $`\mathsf{Bool}`.
:::

:::readable MojoGrimoire.Check.constInt (fingerprint := "18142347407676829893")
*Definition: constant indices.* An index made only of integer literals,
negation, $`+`, $`-`, $`\times`, `//` and `%` has a value that Mojo
computes when it compiles the program, with the same integer arithmetic
as a run.
:::
