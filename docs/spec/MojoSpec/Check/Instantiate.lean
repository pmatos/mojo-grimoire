import VersoManual
import MojoGrimoire.Check.Instantiate
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders
`MojoGrimoire.Check.Instantiate` (ADR-2026-11-15-2030). Each block explains
declarations of that module and pins their fingerprint; the build fails
when the Lean changes under it.
-/

#doc (Manual) "Instantiation: readable blocks" =>

:::moduleDocs (fingerprint := "17173356907780003474")
:::

:::readable MojoGrimoire.Check.withDropStmt MojoGrimoire.Check.withDropStmts MojoGrimoire.Check.dropsProgram (fingerprint := "731557528821529265")
*Definition: where values are destroyed.* The instantiation phase checks
each body as written, with the `drop` statements that elaboration places
after the last use of each value kept among its statements, and every
other change of elaboration erased. A value destroyed inside an
expression, a temporary, is not followed yet.
:::

:::readable MojoGrimoire.Check.instantiate MojoGrimoire.Check.checkInst MojoGrimoire.Check.checkProgram (fingerprint := "7869356785938974748")
*Rule: instantiation.* A body is instantiated once. Its own errors come
first, in the order of the body: a literal of $`\mathsf{Int}`s of the
wrong length, and a constant index out of an array's or an
$`\mathsf{Int}`'s range. Then its calls, the last first, each instantiated
depth first; a negative constant index of a list fails as a call does.
The instantiation starts from `main`, and then takes the bodies that
`main` does not reach, in the order of the declarations (#264). A
program is checked in the type phase, then the flow phase, then the
instantiation phase, and rejected with the first error found (#96 part
7).
:::
