import MojoGrimoire.Reference

/-! Tests of `MojoGrimoire.Reference`. -/

namespace MojoGrimoireTest

open MojoGrimoire

#guard referenceMojo == ⟨1, 3, 0, some 2026111905⟩

theorem referenceMojo_major : referenceMojo.major = 1 := rfl

end MojoGrimoireTest
