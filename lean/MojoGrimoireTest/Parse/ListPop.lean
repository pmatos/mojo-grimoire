import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of `List.pop()`, which removes the last element of a list and gives
it back: its type, the checks on its list, when the popped value is
destroyed, and the run-time error on an empty list. Each expected output
is what the pinned compiler prints for the program.
-/

namespace MojoGrimoireTest.Parse.ListPop

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- The class of error that rejects the program `ls`, in `decl`. -/
private def rejects (ls : List String) (e : CheckError) (decl : Name := "main") : Bool :=
  runLines ls == some (.rejected ⟨decl, e⟩)

private def inMain (body : List String) : List String := "def main():" :: body.map ("    " ++ ·)

private def res : List String := [
  "@fieldwise_init",
  "struct Res(Movable):",
  "    var id: Int",
  "    def __deinit__(deinit self):",
  "        print(\"drop\", self.id)"]

-- `pop` gives the last element, of the list's element type; a result that
-- is not used is destroyed.
#guard runLines (inMain [
  "var xs: List[Int] = [1, 2, 3]",
  "var x = xs.pop()",
  "print(x, len(xs))",
  "print(xs.pop())",
  "xs.pop()",
  "print(len(xs))"]) == some (.finished ["3 2", "2", "0"])

-- Operands are evaluated left to right.
#guard runLines (inMain [
  "var xs: List[Int] = [4, 5, 6]",
  "print(xs.pop() - xs.pop(), len(xs))"]) == some (.finished ["1 1"])

-- A list of lists pops a whole list.
#guard runLines (inMain [
  "var xss: List[List[Int]] = [[1], [2, 3]]",
  "var ys = xss.pop()",
  "print(len(ys), len(xss))"]) == some (.finished ["2 1"])

-- A popped struct is destroyed after its last use, a discarded one at once.
#guard runLines (res ++ inMain [
  "var rs = List[Res]()",
  "rs.append(Res(1))",
  "rs.append(Res(2))",
  "rs.append(Res(3))",
  "var r = rs.pop()",
  "print(\"popped\", r.id)",
  "rs.pop()",
  "print(\"after discard\")",
  "print(\"len\", len(rs))",
  "print(\"end\", r.id)"]) == some (.finished
    ["popped 3", "drop 2", "after discard", "drop 1", "len 1", "end 3", "drop 3"])

-- When `pop` is the last use of its list, the list dies after the call.
#guard runLines (res ++ inMain [
  "var s = List[Res]()",
  "s.append(Res(4))",
  "s.append(Res(5))",
  "s.pop()",
  "print(\"end\")"]) == some (.finished ["drop 5", "drop 4", "end"])

-- Popping an empty list fails at run time, after what was printed before.
#guard runLines (inMain [
  "var xs = List[Int]()",
  "print(\"before\")",
  "print(xs.pop())"]) == some (.failed .indexOutOfBounds ["before"])

-- `pop` changes its list, which must be one the function may change.
#guard rejects [
  "def f(xs: List[Int]):",
  "    print(xs.pop())",
  "",
  "def main():",
  "    var xs: List[Int] = [1]",
  "    f(xs)"] (.immutablePlace (.var "xs")) "f"

-- An array has no `pop`.
#guard rejects (inMain ["var xs = [1, 2]", "print(xs.pop())"]) (.unknownAttribute "Array" "pop")

-- A `mut` parameter's list may be popped, and the caller sees the change.
#guard runLines [
  "def take(mut xs: List[Int]) -> Int:",
  "    return xs.pop()",
  "",
  "def main():",
  "    var xs: List[Int] = [7, 8]",
  "    print(take(xs), len(xs))"] == some (.finished ["8 1"])

end MojoGrimoireTest.Parse.ListPop
