import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of `List[T](range(…))` with one, two or three `Int` arguments (#121).
The nightly 1.3.0.dev2026111905 builds the list of the plain definition, and
a range is not a value of its own in the model: `range` anywhere else is an
unknown function. A range whose start and end lie exactly 2^63 apart aborts
on the compiler, a compiler bug (D-0008); the model builds the list.
-/

namespace MojoGrimoireTest.Parse.ListRange

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- The body of `main` once the program whose lines are `ls` is parsed. -/
private def mainBody (ls : List String) : Option (List Stmt) :=
  match parse ("\n".intercalate ls) with
  | .ok prog => (prog.funs.find? (·.name == "main")).map (·.body)
  | .error _ => none

/-- A function that prints its argument, one that changes its argument,
and a struct. -/
private def lib : List String := [
  "def f(x: Int) -> Int:", "    print(\"f\", x)", "    return x",
  "def bump(mut x: Int) -> Int:", "    x += 10", "    return 3",
  "@fieldwise_init", "struct P(Copyable):", "    var x: Int",
  ""]

/-- The program of `lib` whose `main` runs `body`. -/
private def inMain (body : List String) : List String :=
  lib ++ "def main():" :: body.map ("    " ++ ·)

/-- Whether `main`, running `body`, prints the lines `out`. -/
private def prints (body : List String) (out : List String) : Bool :=
  runLines (inMain body) == some (.finished out)

/-- Whether `main`, running `body`, is rejected with the error `e`. -/
private def rejects (body : List String) (e : CheckError) : Bool :=
  runLines (inMain body) == some (.rejected ⟨"main", e⟩)

/-- `Int.MAX` and `Int.MIN`, written out. -/
private def maxS : String := "9223372036854775807"
private def minS : String := "-9223372036854775808"

-- The parser reads `range(…)` as a call, which `List[T](…)` takes.
#guard mainBody (inMain ["var xs = List[Int](range(3))"]) ==
  some [.decl "xs" (.list .int) (some (.listInit .int [.call "range" [.int 3]]))]

-- One, two or three arguments: the end; the start and the end; and a step.
#guard prints ["print(List[Int](range(3)))"] ["[0, 1, 2]"]
#guard prints ["print(List[Int](range(2, 5)))"] ["[2, 3, 4]"]
#guard prints ["print(List[Int](range(10, 0, -3)))"] ["[10, 7, 4, 1]"]
#guard prints ["print(List[Int](range(0, 10, 3)), List[Int](range(0, 9, 3)))"]
  ["[0, 3, 6, 9] [0, 3, 6]"]
#guard prints ["print(List[Int](range(0, 10, 100)), List[Int](range(0, -10, -100)))"]
  ["[0] [0]"]

-- An empty range, from an end before the start or a step of 0, is `[]`.
#guard prints ["print(len(List[Int](range(-2))), List[Int](range(0)), List[Int](range(3, 3)))"]
  ["0 [] []"]
#guard prints ["print(List[Int](range(5, 2)), List[Int](range(5, 2, 1)))"] ["[] []"]
#guard prints ["print(List[Int](range(2, 5, -1)), List[Int](range(0, 5, 0)))"] ["[] []"]

-- The extreme values of `Int`: no element wraps around.
#guard prints [s!"print(List[Int](range({maxS} - 1, {maxS})))"] ["[9223372036854775806]"]
#guard prints [s!"print(List[Int](range({minS}, {maxS}, {maxS})))"]
  ["[-9223372036854775808, -1, 9223372036854775806]"]
#guard prints [s!"print(List[Int](range({maxS}, {minS}, -{maxS})))"]
  ["[9223372036854775807, 0, -9223372036854775807]"]
#guard prints [s!"print(List[Int](range(5, 0, {minS})))"] ["[5]"]
#guard prints [s!"print(List[Int](range(-1, {maxS}, -1)), List[Int](range(0, {minS}, 1)))"]
  ["[] []"]

-- A non-empty range whose start and end lie 2^63 apart: the compiler aborts
-- (D-0008), and the model builds the list. The suite holds none of these,
-- since its recording of an abort is not reproducible.
#guard prints ["print(\"before\")", s!"print(List[Int](range(-1, {maxS}, {maxS})))"]
  ["before", "[-1, 9223372036854775806]"]
#guard prints [s!"print(List[Int](range(-1, {maxS}, 4611686018427387904)))"]
  ["[-1, 4611686018427387903]"]
#guard prints [s!"print(List[Int](range(-2, {maxS} - 1, {maxS})))"]
  ["[-2, 9223372036854775805]"]
#guard prints [s!"print(List[Int](range(0, {minS}, -{maxS})))"]
  ["[0, -9223372036854775807]"]
#guard prints ["var a = -9223372036854775807 - 1",
  "print(List[Int](range(a, 0, 4611686018427387904)))"]
  ["[-9223372036854775808, -4611686018427387904]"]
#guard prints [s!"print(List[Int](range(0, {minS}, {minS})))"] ["[0]"]
#guard prints [s!"print(List[Int](range({maxS}, -1, {minS})))"] ["[9223372036854775807]"]
#guard prints [s!"print(List[Int](range({minS}, 0, 4611686018427387904)))"]
  ["[-9223372036854775808, -4611686018427387904]"]

-- The arguments are evaluated from left to right, and a place among them is
-- read once every argument is: `bump` changes `x` first.
#guard prints ["print(List[Int](range(f(1), f(10), f(3))))"] ["f 1", "f 10", "f 3", "[1, 4, 7]"]
#guard prints ["var x = 1", "print(List[Int](range(x, bump(x))))"] ["[]"]
#guard prints ["var y = 1", "print(List[Int](range(bump(y), y)))"]
  ["[3, 4, 5, 6, 7, 8, 9, 10]"]
#guard prints ["var n = 4", "var xs = List[Int](range(n))", "xs.append(9)", "print(xs)"]
  ["[0, 1, 2, 3, 9]"]

-- An `Int` is expected of each argument, so a literal `[e]` is `e`.
#guard prints ["print(List[Int](range([3])), List[Int](range([3], 5)))"] ["[0, 1, 2] [3, 4]"]

-- A range too long for the fuel runs out of it, after what was printed.
#guard runLines (inMain ["print(\"before\")", s!"print(List[Int](range({maxS})))"]) ==
  some (.failed .outOfFuel ["before"])
#guard runLines (inMain [s!"print(len(List[Int](range({minS}, {maxS}))))"]) ==
  some (.failed .outOfFuel [])
#guard runLines (inMain [s!"print(len(List[Int](range(-1, {maxS}))))"]) ==
  some (.failed .outOfFuel [])

-- Every misfit is `noMatchingInit`: an element type other than `Int`, an
-- argument that is not an `Int`, and a wrong number of arguments.
#guard rejects ["var xs = List[Bool](range(3))"] (.noMatchingInit (.list .bool))
#guard rejects ["var xs = List[Int](range(True))"] (.noMatchingInit (.list .int))
#guard rejects ["var b = True", "var xs = List[Int](range(1, b))"] (.noMatchingInit (.list .int))
#guard rejects ["var xs = List[Int](range(\"a\"))"] (.noMatchingInit (.list .int))
#guard rejects ["var ys: List[Int] = [1]", "var xs = List[Int](range(ys))"]
  (.noMatchingInit (.list .int))
#guard rejects ["var xs = List[Int](range(P(1)))"] (.noMatchingInit (.list .int))
#guard rejects ["var xs = List[Int](range())"] (.noMatchingInit (.list .int))
#guard rejects ["var xs = List[Int](range(1, 2, 3, 4))"] (.noMatchingInit (.list .int))
#guard rejects ["var xs = List[Int](range(range(3)))"] (.noMatchingInit (.list .int))
#guard rejects ["var xs = List[Int](range([1, 2]))"] (.noMatchingInit (.list .int))

-- A string inside a call keeps the model's class for a string outside
-- `print`, where the compiler reports the call's own misfit.
#guard rejects ["var xs = List[Int](range(f(\"a\")))"] .stringOutsidePrint
#guard rejects ["var xs = List[Int](range(f(\"a\"), \"b\"))"] .stringOutsidePrint
-- `len(range(3))` is outside the subset by the ruling of 2026-11-19, so the
-- model gives it its class for `range` used elsewhere, `unknownFunction`,
-- also as an argument of `range`. The compiler, which takes it, reports
-- these two programs as `noMatchingInit`: this pins the model's choice.
#guard rejects ["var xs = List[Int](range(len(range(3))))"] (.unknownFunction "range")
#guard rejects ["var xs = List[Int](range(len(range(3)), range(2)))"] (.unknownFunction "range")

-- A variable or a parameter named `range` hides the standard library's:
-- the compiler reports that an `Int` cannot be called, which the suite
-- does not classify, and the model rejects the call as `unknownFunction`.
#guard rejects ["var range = 5", "print(List[Int](range(3)))"] (.unknownFunction "range")
#guard runLines (["def g(range: Int) -> List[Int]:", "    return List[Int](range(range))",
  "def main():", "    print(g(3))"]) == some (.rejected ⟨"g", .unknownFunction "range"⟩)
-- A variable declared after the call does not.
#guard prints ["print(List[Int](range(3)))", "var range = 5", "print(range)"]
  ["[0, 1, 2]", "5"]

-- Anywhere else, `range` is an unknown function: a range is not a value.
#guard rejects ["var r = range(3)"] (.unknownFunction "range")
#guard rejects ["print(len(range(3)))"] (.unknownFunction "range")
#guard rejects ["var xs = List[Int](range(3), 4)"] (.unknownFunction "range")

-- A function of the program named `range` is called instead.
#guard runLines (["def range(n: Int) -> List[Int]:", "    return [n, n]", "def main():",
  "    print(List[Int](range(3)))"]) == some (.finished ["[3, 3]"])

-- The length of `range(start, stop, step)`.
#guard rangeLength 0 10 3 == 4 && rangeLength 10 0 (-3) == 4 && rangeLength 0 5 0 == 0
#guard rangeLength 5 2 1 == 0 && rangeLength 2 5 (-1) == 0 && rangeLength 3 3 1 == 0
#guard rangeLength (-1) (2 ^ 63 - 1) (2 ^ 63 - 1) == 2
-- Spans up to 2^64 - 1 count without wrapping around.
#guard rangeLength (-2 ^ 63) (2 ^ 63 - 1) (2 ^ 62) == 4
#guard rangeLength (-2 ^ 63) (2 ^ 63 - 1) 1 == 2 ^ 64 - 1
#guard rangeLength (2 ^ 63 - 1) (-2 ^ 63) (-2 ^ 63) == 2

end MojoGrimoireTest.Parse.ListRange
