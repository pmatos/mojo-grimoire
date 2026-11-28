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

:::moduleDocs (fingerprint := "11643330475195301674")
:::

:::readable MojoGrimoire.Check.compares (fingerprint := "4667244952484152006")
*Definition: comparisons.* $`<`, $`\le`, $`>`, $`\ge`, $`==` and $`!=`
compare.
:::

:::readable MojoGrimoire.Check.boolLiteralMisfit (fingerprint := "7580903694873803838")
*Rule: a $`\mathsf{Bool}` compared with an empty literal.* When the left
operand of $`<`, $`\le`, $`>`, $`\ge`, $`==` or $`!=` is a
$`\mathsf{Bool}` and the right one is an empty literal with no type,
the literal is the argument `rhs` of the $`\mathsf{Bool}`'s method,
which the compiler cannot convert to a $`\mathsf{Bool}`: a type
mismatch, found from the operands' forms before they are read (#286).
A literal with typed elements tries the initializers of
$`\mathsf{Bool}` instead (#165), one made only of empty literals waits
for #300, and an empty literal on the left has no type at all.
:::

:::readable MojoGrimoire.Check.binaryResult (fingerprint := "7037857992261783058")
*Definition: the result of an operator.* An arithmetic operator gives an
$`\mathsf{Int}`, and every other binary operator a $`\mathsf{Bool}`,
whatever its operands: inference types an expression by it.
:::

:::readable MojoGrimoire.Check.binaryTy MojoGrimoire.Check.unaryTy (fingerprint := "7769671662555249431")
*Rule: operators.* Arithmetic takes two $`\mathsf{Int}` and gives an
$`\mathsf{Int}`; $`<`, $`\le`, $`>`, $`\ge`, $`==` and $`!=`
take two values of the same type, $`\mathsf{Int}` or $`\mathsf{Bool}`,
and give a $`\mathsf{Bool}` (#185); $`\mathsf{and}` and $`\mathsf{or}` take
and give $`\mathsf{Bool}`. Negation takes an $`\mathsf{Int}`, and
$`\mathsf{not}` a $`\mathsf{Bool}`.
:::

:::readable MojoGrimoire.Check.constInt (fingerprint := "5788987419930283119")
*Definition: constant indices.* An index made only of integer literals,
negation, $`+`, $`-`, $`\times`, `//` and `%` has a value that Mojo
computes when it compiles the program, with the same integer arithmetic
as a run.
:::
