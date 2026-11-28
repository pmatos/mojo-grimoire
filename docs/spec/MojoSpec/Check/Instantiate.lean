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

:::moduleDocs (fingerprint := "11927810718368734126")
:::

:::readable MojoGrimoire.Check.placeDrops MojoGrimoire.Check.exprDrops MojoGrimoire.Check.exprsDrops MojoGrimoire.Check.stmtDrops MojoGrimoire.Check.keptDrops MojoGrimoire.Check.withDropStmt MojoGrimoire.Check.withDropStmts MojoGrimoire.Check.dropsProgram MojoGrimoire.Check.synthesizedDestructors (fingerprint := "4085899041235453346")
*Definition: where values are destroyed.* The instantiation phase checks
each body as written, with the `drop` statements that elaboration places
after the last use of each value kept among its statements, and every
other change of elaboration erased. A value that an expression destroys
is destroyed by a `drop` statement after the statement, or, in a
condition, at the start of each block it leads to and after a loop. The
hidden variables of temporaries are erased with their declarations and
their drops (`keptDrops`), as a temporary is everywhere else in the
checker. A struct that declares no
`__deinit__` has the destructor that the compiler synthesizes, which
destroys its fields, the last first.
:::

:::readable MojoGrimoire.Check.instantiate MojoGrimoire.Check.checkInst MojoGrimoire.Check.checkProgramAs MojoGrimoire.Check.indexCallIn MojoGrimoire.Check.indexCallsIn MojoGrimoire.Check.indexCallAt MojoGrimoire.Check.indexCallStmt MojoGrimoire.Check.indexCallBlock MojoGrimoire.Check.indexedCalls MojoGrimoire.Check.checkProgram (fingerprint := "11014849162680387735")
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

It is checked twice (`checkProgramAs`). The first pass leaves a temporary
origin argument in a place's index out of the origins, as anywhere else
(#80), so that a rejected program gets the compiler's first error. A
program that the first pass accepts is checked again, in a strict pass that
rejects every such argument, as before #80. Elaboration does not name the
temporary in an index, so the model would read it after it is destroyed
(#377). The compiler accepts these programs. The second pass runs only
when an index of some body holds a call of a function or a method
(`indexedCalls`): elsewhere the two passes cannot differ, and a program
pays for one.
:::
