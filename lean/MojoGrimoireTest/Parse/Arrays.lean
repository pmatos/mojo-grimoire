import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of arrays and of the type of a literal `[e₁, …, eₙ]`: an
`Array[T, n]` where nothing else is expected, and a `List[T]` where a list
is expected.
-/

namespace MojoGrimoireTest.Parse.Arrays

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- The class of error that rejects the program `ls`, in `main`. -/
private def rejects (ls : List String) (e : CheckError) : Bool :=
  runLines ls == some (.rejected ⟨"main", e⟩)

private def inMain (body : List String) : List String := "def main():" :: body.map ("    " ++ ·)

private def xs : Place := .var "xs"

-- An unannotated literal is an array: indexing, assignment, `len`, `.copy()`.
#guard runLines (inMain [
  "var xs = [1, 2, 3]",
  "xs[1] = 20",
  "var i = 2",
  "var ys = xs.copy()",
  "ys[0] = 9",
  "print(len(xs), xs[0], xs[1], xs[i], ys[0])"]) == some (.finished ["3 1 20 3 9"])

#guard match parse ("\n".intercalate (inMain ["var xs = [1, 2, 3]"])) with
  | .ok prog => prog.funs.any fun fd => fd.body.any fun
    | .decl "xs" (.array .int 3) _ => true
    | _ => false
  | .error _ => false

-- Arrays cross function boundaries and live in fields.
#guard runLines [
  "@fieldwise_init",
  "struct Holder:",
  "    var xs: Array[Int, 2]",
  "",
  "def make() -> Array[Int, 2]:",
  "    return [7, 8]",
  "",
  "def bump(mut xs: Array[Int, 2]):",
  "    xs[0] += 1",
  "",
  "def main():",
  "    var xs = make()",
  "    bump(xs)",
  "    var h = Holder(xs^)",
  "    h.xs[1] = 5",
  "    print(h.xs[0], h.xs[1])"] == some (.finished ["8 5"])

-- Where a list is expected, a literal is a list.
#guard runLines [
  "@fieldwise_init",
  "struct Box:",
  "    var xs: List[Int]",
  "",
  "    def put(mut self, ys: List[Int]):",
  "        self.xs = ys.copy()",
  "",
  "def make() -> List[Int]:",
  "    return [1, 2]",
  "",
  "def size(xs: List[Int]) -> Int:",
  "    return len(xs)",
  "",
  "def main():",
  "    var xs = make()",
  "    xs = [3, 4, 5]",
  "    var b = Box([1])",
  "    b.xs = [9, 9]",
  "    b.put([7])",
  "    var xss: List[List[Int]] = [[1], [2, 3]]",
  "    xss.append([4])",
  "    print(len(xs), len(b.xs), size([1, 2, 3, 4]), len(xss), len(xss[1]))"] ==
  some (.finished ["3 1 4 3 2"])

-- An array has no `append`, and is copied only explicitly.
#guard rejects (inMain ["var xs = [1, 2]", "xs.append(3)"]) (.unknownAttribute "Array" "append")
#guard rejects (inMain ["var xs = [1, 2]", "var ys = xs", "print(ys[0])"])
  (.implicitCopy (.array .int 2))

-- A constant index past the end is rejected; one known only at run time fails then.
#guard rejects (inMain ["var xs = [1, 2, 3]", "print(xs[3])"])
  (.constantIndexOutOfBounds (.index xs (.int 3)))
#guard rejects (inMain ["var xs = [1, 2, 3]", "xs[1 + 2] = 0"])
  (.constantIndexOutOfBounds (.index xs (.binary .add (.int 1) (.int 2))))
#guard rejects (inMain ["var xs = [1, 2, 3]", "print(xs[7 // 2])"])
  (.constantIndexOutOfBounds (.index xs (.binary .floorDiv (.int 7) (.int 2))))
#guard rejects (inMain ["var xs = [1, 2, 3]", "print(xs[7 % 4])"])
  (.constantIndexOutOfBounds (.index xs (.binary .mod (.int 7) (.int 4))))
#guard runLines (inMain ["var xs = [1, 2, 3]", "print(xs[-7 % 3], xs[7 // 4], xs[1 // 0])"]) ==
  some (.finished ["3 2 1"])
#guard rejects (inMain ["var xs = [1, 2, 3]", "print(xs[-1])"]) (.negativeIndex (.index xs (.int (-1))))
#guard rejects (inMain ["var xs: List[Int] = [1, 2, 3]", "print(xs[-7 // 2])"])
  (.negativeIndex (.index xs (.binary .floorDiv (.int (-7)) (.int 2))))
#guard runLines (inMain ["var xs = [1, 2, 3]", "var i = 3", "print(xs[i])"]) ==
  some (.failed .indexOutOfBounds [])
#guard runLines (inMain ["var xs: List[Int] = [1, 2, 3]", "print(xs[3])"]) ==
  some (.failed .indexOutOfBounds [])

-- The size of an array is part of its type. A literal of another size fits
-- no initializer of the array it initializes (#46).
#guard rejects (inMain ["var xs: Array[Int, 2] = [1, 2, 3]"]) (.noMatchingInit (.array .int 2))
#guard rejects (inMain ["var xs = [[1], [2, 3]]"]) (.typeMismatch (.array .int 1) (.array .int 2))

-- An empty literal needs an expected type.
#guard rejects (inMain ["var xs = []"]) (.invalidType .unknown)

end MojoGrimoireTest.Parse.Arrays
