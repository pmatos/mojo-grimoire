import VersoManual
import MojoGrimoire.Interp.Run
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Interp.Run`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "Running a program: readable blocks" =>

:::moduleDocs (fingerprint := "2888190355538251931")
:::

:::readable MojoGrimoire.Interp.Outcome (fingerprint := "3429656939002660297")
*Definition: outcomes.* Running a program ends in one of three ways: it is
rejected by the checker, with the first error found; it finishes, with
the lines it printed; or it fails with a run-time error, after printing
some lines.
:::

:::readable MojoGrimoire.Interp.runMain MojoGrimoire.Interp.run (fingerprint := "16431783587329518701")
*Definition: running.* A program is checked; if it is accepted, it is
elaborated, and `main` is called on an empty machine with the fuel given.
:::
