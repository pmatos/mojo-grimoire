import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of `List.pop(i)`, which removes the element at the index `i` of a
list and gives it back: its result, the run-time bounds check on `i`, the
order in which its operands are evaluated, and the checks that it shares
with `pop()`. Each verdict and output is the pinned compiler's for the
program.
-/

namespace MojoGrimoireTest.Parse.ListPopIndex

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

private def inMain (body : List String) : List String := "def main():" :: body.map ("    " ++ ·)

private def prints (body : List String) (out : List String) : Bool :=
  runLines (inMain body) == some (.finished out)

/-- The class of error that rejects `main`, whose body is `body`. -/
private def rejects (body : List String) (e : CheckError) : Bool :=
  runLines (inMain body) == some (.rejected ⟨"main", e⟩)

private def x (n : Name) : Place := .var n
private def at_ (p : Place) (i : Int) : Place := .index p (.int i)

-- `pop(i)` gives the element at `i` and closes the gap it leaves.
#guard prints [
  "var xs: List[Int] = [1, 2, 3, 4]",
  "print(xs.pop(1), len(xs))",
  "print(xs[0], xs[1], xs[2])",
  "print(xs.pop(0), xs.pop(len(xs) - 1), len(xs))",
  "print(xs.pop(xs[0] - 3))",
  "print(len(xs))"] ["2 3", "1 3 4", "1 4 1", "3", "0"]

-- The index is checked when the call runs. A negative index is out of
-- bounds, even a constant one, which indexing would reject at compile time.
#guard runLines (inMain [
  "var xs: List[Int] = [1, 2]",
  "print(\"before\")",
  "print(xs.pop(-1))"]) == some (.failed .indexOutOfBounds ["before"])
#guard runLines (inMain ["var xs: List[Int] = [1, 2]", "print(xs.pop(2))"]) ==
  some (.failed .indexOutOfBounds [])

-- The index is evaluated before the list is read: an index that pops the
-- same list sees it shorter.
#guard prints ["var xs: List[Int] = [5, 0, 1]", "print(xs.pop(xs.pop()))", "print(len(xs), xs[0])"]
  ["0", "1 5"]

-- An element of the list itself may be the index.
#guard prints ["var xs: List[Int] = [1, 0, 2]", "print(xs.pop(xs[0]))", "print(len(xs), xs[0], xs[1])"]
  ["0", "2 1 2"]
#guard prints [
  "var xss: List[List[Int]] = [[1], [0, 7]]",
  "print(xss[1].pop(xss[1][0]))",
  "print(len(xss[1]))"] ["0", "1"]

-- A popped struct is destroyed after its last use, a discarded one at once.
#guard runLines ([
  "@fieldwise_init",
  "struct Res(Movable):",
  "    var id: Int",
  "    def __deinit__(deinit self):",
  "        print(\"drop\", self.id)",
  ""] ++ inMain [
  "var rs: List[Res] = [Res(1), Res(2), Res(3)]",
  "var r = rs.pop(0)",
  "print(\"popped\", r.id, len(rs))",
  "rs.pop(1)",
  "print(\"after discard\", len(rs))",
  "print(\"end\", r.id)"]) == some (.finished
    ["popped 1 2", "drop 3", "drop 2", "after discard 1", "end 1", "drop 1"])

-- A `mut` parameter's list may be popped at an index, and the caller sees
-- the change.
#guard runLines [
  "def take(mut xs: List[Int], i: Int) -> Int:",
  "    return xs.pop(i)",
  "",
  "def main():",
  "    var xs: List[Int] = [7, 8, 9]",
  "    print(take(xs, 1), len(xs), xs[1])"] == some (.finished ["8 2 9"])

-- `pop(i)` changes its list as `pop()` does: it invalidates references into
-- the list's elements, and its result may not be built in an element of it.
#guard rejects ["var xs: List[Int] = [1, 2]", "ref e = xs[0]", "print(xs.pop(0))", "print(e)"]
  (.invalidatedReference (x "e"))
#guard rejects ["var xss: List[List[Int]] = [[1], [0, 7]]", "print(xss[1].pop(len(xss.pop()) - 1))"]
  (.invalidatedReference (at_ (x "xss") 1))
#guard rejects ["var xs: List[Int] = [3, 4]", "xs[0] = xs.pop(1)", "print(xs[0])"]
  (.argumentExclusivity (x "xs"))

-- The index is an `Int`, and `pop` takes at most one argument.
#guard rejects ["var xs: List[Int] = [1, 2]", "print(xs.pop(True))"] (.typeMismatch .int .bool)
#guard rejects ["var xs: List[Int] = [1, 2]", "print(xs.pop(0, 1))"] (.arityMismatch "pop" 1 2)

end MojoGrimoireTest.Parse.ListPopIndex
