import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the order inside a place (#142, #227, #96 part 10): the compiler
types a place from its variable outward, the variable, then each field and
each subscript, a type that cannot be indexed before its index, and an
assignment's target before its value. Each program is one of
`tests/conformance/order/place_*`, whose result the compiler gave.
-/

namespace MojoGrimoireTest.Parse.PlaceOrder

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- Whether `body`, the rest of `main` after a struct `P` of one `Int`
and a list of them, is rejected in `main` with an error that `q`
accepts. -/
private def rejects (body : List String) (q : CheckError → Bool) : Bool :=
  match runLines (["@fieldwise_init", "struct P(Movable):", "    var x: Int", "def main():",
      "    var p = P(1)", "    var l: List[P] = [P(0)]"] ++ body.map ("    " ++ ·)) with
  | some (.rejected ⟨"main", e⟩) => q e
  | _ => false

-- The variable and each field come before an index's error.
#guard rejects ["var u = zz[True]"] (· matches .unknownVariable _)
#guard rejects ["print(l[0].nope[zz])"] (· matches .unknownAttribute ..)
#guard rejects ["print(p.nope[zz])"] (· matches .unknownAttribute ..)
-- A type that cannot be indexed comes before its index.
#guard rejects ["print(p[True])"] (· matches .notAList _)
#guard rejects ["print(p[zz])"] (· matches .notAList _)
#guard rejects ["var b = True", "print(b[zz])"] (· matches .notAList _)
-- An assignment's target comes before its value.
#guard rejects ["p.nope = zz"] (· matches .unknownAttribute ..)
#guard rejects ["p[0] = zz"] (· matches .notAList _)
#guard rejects ["p[True] = zz"] (· matches .notAList _)
#guard rejects ["l[0].nope = zz"] (· matches .unknownAttribute ..)
-- The index of a list is typed with its subscript, before the value.
#guard rejects ["l[zz].x = nope"] (· matches .unknownVariable "zz")

end MojoGrimoireTest.Parse.PlaceOrder
