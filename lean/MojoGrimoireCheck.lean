import MojoGrimoireTest

/-!
The check that every declaration of `lean/` is trusted (ADR-2026-11-15-1906).
`MojoGrimoireTest` imports every module of `lean/`, so this module sees them
all, the executable's root `MojoGrimoireCli` included. Its library needs
the list of the package's `.lean` files, so a file that nothing imports
reruns the check, even when every other module comes from a warm build. Nothing may follow the check, since it would not see it.
-/

#check_axioms MojoGrimoire MojoGrimoireTest MojoGrimoireCli
