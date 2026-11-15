import VersoManual
import MojoGrimoire.Driver.Main
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section that renders `MojoGrimoire.Driver.Main`
(ADR-2026-11-15-2030). Each block explains declarations of that module and
pins their fingerprint; the build fails when the Lean changes under it.
-/

#doc (Manual) "The command-line driver: readable blocks" =>

:::moduleDocs (fingerprint := "14265898729153446237")
:::

:::readable MojoGrimoire.Driver.CheckError.className MojoGrimoire.Driver.RunError.name (fingerprint := "1484308185474954775")
*Definition: names of errors.* The driver names a class of static error,
and a run-time error, by its constructor, so that the conformance suite can
compare it with the class of the compiler's diagnostic.
:::

:::readable MojoGrimoire.Driver.defaultFuel MojoGrimoire.Driver.parseArgs MojoGrimoire.Driver.main (fingerprint := "868820494520024601")
*Definition: the driver.* `mojo-grimoire FILE [--fuel N]` reads the file,
parses it and runs it with $`N` units of fuel, $`10^8` by default. The
printed lines go to standard output, and the exit code says how the run
ended: 0 finished, 1 rejected, 2 a run-time error, 3 a syntax error, and 4
a command line or file that could not be used.
:::
