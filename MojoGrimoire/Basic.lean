/-!
# MojoGrimoire

Placeholder module so the build and the axiom audit have something to check.
The core calculus, primitive-op layer and abstract spec land in Phase 1 onwards
(see the roadmap linked from the README).
-/

namespace MojoGrimoire

/-- Version of the Mojo compiler this model is tested against. -/
def mojoReference : String := "1.2.x"

theorem mojoReference_nonempty : mojoReference ≠ "" := by decide

end MojoGrimoire
