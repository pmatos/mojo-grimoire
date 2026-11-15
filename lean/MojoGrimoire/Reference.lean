/-!
Mojo has no written specification, so the open-source Mojo compiler at a
pinned release is the reference that the model is tested against
(ADR-2026-11-15-1907). This module records which release that is, so that the
model and the conformance suite name the same one.
-/

namespace MojoGrimoire

/-- A Mojo release, by its version numbers. -/
structure MojoVersion where
  major : Nat
  minor : Nat
  deriving DecidableEq, Repr

/-- The Mojo release line that the model is tested against. The exact commit
is pinned in `scripts/build-mojo.sh`. A move to a newer release edits this
definition, the script, the conformance suite's recorded results, the decision
log and `docs/decisions/semantics.md` in one PR (ADR-2026-11-15-1907). -/
def referenceMojo : MojoVersion := ⟨1, 2⟩

end MojoGrimoire
