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

:::moduleDocs (fingerprint := "18421714691409238919")
:::

:::readable MojoGrimoire.Check.placeDrops MojoGrimoire.Check.exprDrops MojoGrimoire.Check.exprsDrops MojoGrimoire.Check.stmtDrops MojoGrimoire.Check.withDropStmt MojoGrimoire.Check.withDropStmts MojoGrimoire.Check.alignStmt MojoGrimoire.Check.alignTwin MojoGrimoire.Check.dropsProgram MojoGrimoire.Check.synthesizedDestructors (fingerprint := "3038197563290071209")
*Definition: where values are destroyed.* The instantiation phase checks
each body as written, with the `drop` statements that elaboration places
after the last use of each value kept among its statements, and every
other change of elaboration erased. A value that an expression destroys
is destroyed by a `drop` statement after the statement, or, in a
condition, at the start of each block it leads to and after a loop. The
twin of each body, the body that `main`'s inference gave it, gets the
same `drop` statements at the same places, so that each statement is
still checked beside its own twin. A struct that declares no
`__deinit__` has the destructor that the compiler synthesizes, which
destroys its fields, the last first.
:::

:::readable MojoGrimoire.Check.instantiate MojoGrimoire.Check.checkInst MojoGrimoire.Check.checkProgram (fingerprint := "925330081724011157")
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
