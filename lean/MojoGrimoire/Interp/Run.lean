import MojoGrimoire.Interp.Eval
import MojoGrimoire.Check.Instantiate
import MojoGrimoire.Elab.Elaborate

/-!
Running a program as the compiler would: check it, elaborate it, and call
`main`. The outcome is what the conformance suite compares with the
compiler's: the class of error that rejects a program, or the lines a run
prints and how the run ends.
-/

namespace MojoGrimoire.Interp

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Elab

/-- How running a program ends: rejected by the checker, finished with the
lines it printed, or failed with a run-time error after printing some
lines. -/
inductive Outcome where
  | rejected (r : Rejection)
  | finished (output : List String)
  | failed (e : RunError) (output : List String)
  deriving BEq

/-- Runs `main` of an elaborated program with `fuel`. -/
def runMain (prog : Program) (fuel : Nat) : Outcome :=
  let m : Machine := ⟨#[], #[]⟩
  match findFun prog "main" with
  | none => .failed (.stuck "no main") []
  | some fd =>
    match (callFun prog fuel fd []).run m with
    | (.ok _, m') => .finished m'.output.toList
    | (.error (.error e), m') => .failed e m'.output.toList
    | (.error (.returned _), m') => .failed (.stuck "a return outside a call") m'.output.toList

/-- Checks a program, elaborates it and runs it with `fuel`. -/
def run (prog : Program) (fuel : Nat) : Outcome :=
  match checkProgram prog with
  | .error r => .rejected r
  | .ok () => runMain (elabProgram prog) fuel

end MojoGrimoire.Interp
