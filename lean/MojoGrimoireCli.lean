import MojoGrimoire.Driver.Main

/-!
The root of the executable `mojo-grimoire`: the top-level `main`, which calls
the driver, `MojoGrimoire.Driver.main`. It is a library of its own, outside
`MojoGrimoire`, because the spec document imports `MojoGrimoire` and is an
executable with a `main` of its own, which this one would clash with.
`MojoGrimoireTest` imports it, so the axiom check covers it.
-/

/-- The executable's entry point: the driver, `MojoGrimoire.Driver.main`. -/
def main (args : List String) : IO UInt32 := MojoGrimoire.Driver.main args
