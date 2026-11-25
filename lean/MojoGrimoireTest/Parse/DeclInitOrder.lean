import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the order inside declarations, assignments and literals (#133,
#134, #96 part 11): the compiler types a declaration's initializer before
it finds the name declared already, a literal's elements before the
literal's element type, and a value's type before its implicit copy. Each program is one of `tests/conformance/order/decl_*`,
whose result the compiler gave.
-/

namespace MojoGrimoireTest.Parse.DeclInitOrder

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- Whether `body`, the rest of `main` after a struct `S` of one `Int`
and a variable `s` of it, is rejected in `main` with an error that `q`
accepts. -/
private def rejects (body : List String) (q : CheckError → Bool) : Bool :=
  match runLines (["@fieldwise_init", "struct S(Movable):", "    var k: Int",
      "def f(x: Int):", "    pass", "def main():", "    var s = S(7)"] ++ body.map ("    " ++ ·)) with
  | some (.rejected ⟨"main", e⟩) => q e
  | _ => false

-- A redeclared variable's initializer comes before the duplicate name.
#guard rejects ["var s = s.nope"] (· matches .unknownAttribute ..)
#guard rejects ["var s: Int = s.nope"] (· matches .unknownAttribute ..)
#guard rejects ["var s = zz"] (· matches .unknownVariable "zz")
#guard rejects ["var s = 1 + True"] (· matches .noMatchingMethod ..)
#guard rejects ["var s = [1, True]"] (· matches .typeMismatch ..)
#guard rejects ["ref s = s.nope"] (· matches .unknownAttribute ..)
-- Its conversion to the declared type comes after.
#guard rejects ["var s: Int = True"] (· matches .duplicate "s")
#guard rejects ["var s = S(8)"] (· matches .duplicate "s")
-- A literal's elements come before its element type.
#guard rejects ["var u = [[], s.nope]"] (· matches .unknownAttribute ..)
#guard rejects ["var u = [[], zz]"] (· matches .unknownVariable "zz")
#guard rejects ["var u = [1, True, zz]"] (· matches .unknownVariable "zz")
#guard rejects ["var u: List[Int] = [True, zz]"] (· matches .unknownVariable "zz")
#guard rejects ["var u: List[List[Int]] = [[True], [zz]]"] (· matches .unknownVariable "zz")
-- A value's type comes before its implicit copy.
#guard rejects ["var xs: List[Int] = [1]", "var b: Int = xs"] (· matches .typeMismatch ..)
#guard rejects ["var xs: List[Int] = [1]", "var a: List[Int] = [xs]"] (· matches .noMatchingInit _)
#guard rejects ["var xs: List[Int] = [1]", "var b = 0", "b = xs"] (· matches .typeMismatch ..)
#guard rejects ["var b: Int = s"] (· matches .typeMismatch ..)
#guard rejects ["var xs: List[Int] = [1]", "var a = [xs, 1]"] (· matches .typeMismatch ..)
#guard rejects ["var xs: List[Int] = [1]", "var a = [[xs, True]]"] (· matches .typeMismatch ..)
-- A copy alone is still reported, and so is one that builds an inner
-- literal on its own, before the outer literal's misfit.
#guard rejects ["var xs: List[Int] = [1]", "var a: List[Int] = xs"] (· matches .implicitCopy _)
#guard rejects ["var t = s"] (· matches .implicitCopy _)
#guard rejects ["var xs: List[Int] = [1]", "var a = [[xs], [1]]"] (· matches .implicitCopy _)
#guard rejects ["var xs: List[Int] = [1]", "var a = [[xs], True]"] (· matches .implicitCopy _)
-- So does a `return`.
#guard runLines ["def g(xs: List[Int]) -> Int:", "    return xs", "def main():",
    "    var xs: List[Int] = [1]", "    print(g(xs))"] matches
  some (.rejected ⟨"g", .typeMismatch ..⟩)

end MojoGrimoireTest.Parse.DeclInitOrder
