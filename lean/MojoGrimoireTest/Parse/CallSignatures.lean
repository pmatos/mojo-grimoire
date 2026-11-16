import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the signatures of calls and method calls, which inference, the
checker and elaboration all read from one table: the parameters that
inference expects arguments to fit, the errors that the checker reports for
what has no signature, and the order of those errors.
-/

namespace MojoGrimoireTest.Parse.CallSignatures

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- The error that rejects the function `f` of the program whose lines are
`ls`. -/
private def rejects (ls : List String) (e : CheckError) (f : Name := "main") : Bool :=
  runLines ls == some (.rejected ⟨f, e⟩)

/-- The body of `main` once the program whose lines are `ls` is parsed. -/
private def mainBody (ls : List String) : Option (List Stmt) :=
  match parse ("\n".intercalate ls) with
  | .ok prog => (prog.funs.find? (·.name == "main")).map (·.body)
  | .error _ => none

/-- A struct that declares fields but neither `__init__` nor
`@fieldwise_init`. -/
private def bare : List String := ["struct Bare:", "    var xs: List[Int]", ""]

-- A struct with no initializer cannot be built, and the declaration of a
-- variable that it would initialize is still given the struct's type.
#guard rejects (bare ++ ["def main():", "    var b = Bare([1, 2])"]) (.noInitializer "Bare")

-- With no initializer, the construction has no parameters, so a literal
-- among its arguments is expected to fit nothing and is an array.
#guard mainBody (bare ++ ["def main():", "    var b = Bare([1, 2])"]) ==
  some [.decl "b" (.struct "Bare")
    (some (.call "Bare" [.list (.array .int 2) [.int 1, .int 2]]))]

-- A method that a list or an array does not have is reported before the
-- receiver is read: here it is not yet initialized.
#guard rejects ["def main():", "    var xs: List[Int]", "    xs.insert(0)"]
  (.unknownMethod "List" "insert")
#guard rejects ["def main():", "    var a = [1, 2]", "    var b = a^", "    a.pop()"]
  (.unknownMethod "Array" "pop")

-- A receiver that is neither a struct, a list nor an array has no methods.
#guard rejects ["def main():", "    var n = 1", "    n.pop()"] (.typeMismatch (.struct "") .int)

-- A struct's unknown method is reported with the struct's name.
#guard rejects (bare ++ ["def f(b: Bare):", "    b.pop()", "", "def main():", "    pass"])
  (.unknownMethod "Bare" "pop") "f"

end MojoGrimoireTest.Parse.CallSignatures
