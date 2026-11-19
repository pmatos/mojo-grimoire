import VersoManual
import MojoGrimoire.Reference
import MojoSpecSite.ReadableElab

open Verso.Genre Manual
open MojoSpecSite

/-!
The readable blocks of the section on the reference version, which renders
`MojoGrimoire.Reference` (ADR-2026-11-15-2030). Each block explains
declarations of that module and pins their fingerprint; the build fails
when the Lean changes under it.
-/

#doc (Manual) "The reference version: readable blocks" =>

:::moduleDocs (fingerprint := "13133016968976901803")
:::

:::readable MojoGrimoire.MojoVersion (fingerprint := "6034071841426746647")
*Definition: a Mojo version.* A version $`v` is a tuple of natural numbers
$`(\mathit{major}, \mathit{minor}, \mathit{patch})`, written
$`\mathit{major}.\mathit{minor}.\mathit{patch}`, with an optional nightly
stamp $`d`, written $`\mathit{major}.\mathit{minor}.\mathit{patch}.\mathrm{dev}d`.
With a stamp, it names the nightly build of that release made on the date
the stamp begins with, such as 1.3.0.dev2026111905, which comes before the
release 1.3.0 itself.
:::

:::readable MojoGrimoire.referenceMojo (pin := MojoGrimoire.MojoVersion) (fingerprint := "4522850919270270003")
*Definition: the reference version.* The reference version is
$$`v_{\mathrm{ref}} = 1.3.0.\mathrm{dev}2026111905`

The model's behaviour is checked against the open-source Mojo compiler of
this nightly, by the human's ruling of 2026-11-19 (ADR-2026-11-15-1907). The
conformance suite runs it as installed by `scripts/install-mojo.sh`, which
pins its wheels by sha256; `docs/decisions/semantics.md` records the
nearest public commit of its source. Moving to another version changes this
definition, that pin, the suite's recorded results and the decision log
together.
:::
