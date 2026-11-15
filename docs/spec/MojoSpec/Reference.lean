import VersoManual
import MojoGrimoire.Reference
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section on the reference release, which renders
`MojoGrimoire.Reference` (ADR-2026-11-15-2030). Each block explains
declarations of that module and pins their fingerprint; the build fails
when the Lean changes under it.
-/

#doc (Manual) "The reference release: readable blocks" =>

:::moduleDocs (fingerprint := "3703418468824446801")
:::

:::readable MojoGrimoire.MojoVersion (fingerprint := "13084417616642602083")
*Definition: a Mojo release.* A release $`v` is a pair of natural numbers
$`(\mathit{major}, \mathit{minor})`, written $`\mathit{major}.\mathit{minor}`.
It names a release line, such as 1.2, and not one patch release or commit of
it.
:::

:::readable MojoGrimoire.referenceMojo (pin := MojoGrimoire.MojoVersion) (fingerprint := "8984371093788453841")
*Definition: the reference release.* The reference release is
$$`v_{\mathrm{ref}} = 1.2`

The model's behaviour is checked against the open-source Mojo compiler of
this release line (ADR-2026-11-15-1907). The exact commit of the compiler,
which the conformance suite runs, is pinned by `scripts/build-mojo.sh` and
recorded in `docs/decisions/semantics.md`. Moving to a newer release changes
this definition, that pin, the suite's recorded results and the decision log
together.
:::
