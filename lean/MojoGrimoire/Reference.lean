/-!
Mojo has no written specification, so the open-source Mojo compiler at a
pinned version is the reference that the model is tested against
(ADR-2026-11-15-1907). This module records which version that is, so that the
model and the conformance suite name the same one.
-/

namespace MojoGrimoire

/-- A Mojo version: a release `major.minor.patch`, or the nightly build of
that release stamped `dev`, as the wheel `1.3.0.dev2026111905` is. -/
structure MojoVersion where
  major : Nat
  minor : Nat
  patch : Nat
  dev : Option Nat
  deriving DecidableEq, Repr

/-- The Mojo version that the model is tested against: the nightly
`1.3.0.dev2026111905`, by the human's ruling of 2026-11-19. Its wheels and
their sha256 are pinned in `scripts/install-mojo.sh`. A move to another
version edits this definition, the script, the conformance suite's recorded
results, the decision log and `docs/decisions/semantics.md` in one PR
(ADR-2026-11-15-1907). -/
def referenceMojo : MojoVersion := ⟨1, 3, 0, some 2026111905⟩

end MojoGrimoire
