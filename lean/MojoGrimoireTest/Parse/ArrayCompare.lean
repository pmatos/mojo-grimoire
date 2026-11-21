import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the comparison of two arrays (#166): `<`, `<=`, `>`, `>=`, `==`
and `!=` of two arrays of the same type, whose elements are `Int`s,
`Bool`s or such arrays, in lexicographic order, with both operands read
by reference. Arrays of another length or element type are a type
mismatch, and arrays whose element type does not conform to the trait
the operator needs, `None` or, to order them, a list, `violatedConstraint`.
An element type that holds a struct, and the equality of arrays of lists,
keep the result they had before. Each verdict is the pinned compiler's
for the program, probed on the nightly 1.3.0.dev2026111905, but for the
last ones, which part 2 of #166 and #185 cover.
-/

namespace MojoGrimoireTest.Parse.ArrayCompare

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- The declarations before `main`. -/
private def pre : List String :=
  ["@fieldwise_init", "struct P(ImplicitlyCopyable):", "    var x: Int",
   "def f():", "    pass",
   "def pick(ref a: Array[Int, 2]) -> ref [a] Array[Int, 2]:", "    return a",
   "def bump(mut a: Array[Int, 1]) -> Array[Int, 1]:", "    a[0] = 5", "    return [5]",
   "def lt(a: Array[Int, 2], b: Array[Int, 2]) -> Bool:", "    return a < b"]

/-- Parses and runs the program of `pre` and a `main` whose body is `body`;
a syntax error gives `none`. -/
private def runMain (body : List String) : Option Outcome :=
  match parse ("\n".intercalate (pre ++ "def main():" :: body.map ("    " ++ ·))) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

private def prints (body : List String) (out : List String) : Bool :=
  runMain body == some (.finished out)

private def rejects (body : List String) (e : CheckError) : Bool :=
  runMain body == some (.rejected ⟨"main", e⟩)

-- The six operators, in lexicographic order, of `Int`s, `Bool`s and arrays.
#guard prints ["print([2] < [3], [2] <= [3], [2] > [3], [2] >= [3], [2] == [3], [2] != [3])"]
  ["True True False False False True"]
#guard prints
  ["print([2, 0] < [1, 5], [1, 9] < [2, 0], [1, 2] < [1, 2], [1, 2] <= [1, 2], [1, 2] > [1, 1])"]
  ["False True False True True"]
#guard prints ["print([True] == [True], [True] < [False], [False] < [True], [False] >= [False])"]
  ["True False True True"]
#guard prints ["print([[1]] == [[1]], [[1]] < [[2]], [[1, 2], [3, 4]] < [[1, 2], [3, 5]])"]
  ["True True True"]
#guard prints ["print([-1] < [0], [1 + 1] == [2])"] ["True True"]

-- Both operands are read by reference: a named array is not copied.
#guard prints ["var a = [1, 2]", "var b = [1, 3]", "print(a < b, a == b, a != b, a >= b)",
  "print(a[0], b[1])"] ["True False True False", "1 3"]
#guard prints ["var a = [1]", "print(a == [1], [1] == a, a < [2], [0] < a)"]
  ["True True True True"]
#guard prints ["var a = [[1, 2], [3, 4]]", "var b = [[1, 2], [3, 4]]", "print(a == b, a < b)"]
  ["True False"]
#guard prints ["var a = [1, 2]", "print(a == a, a < a, lt(a, [1, 3]))"] ["True False True"]
#guard prints ["var a = [1, 2]", "var b = [1, 3]", "print(pick(a) < pick(b), pick(a) == b)"]
  ["True False"]
#guard prints ["var xs: List[Array[Int, 1]] = [[1], [2]]", "print(xs[0] < xs[1])"] ["True"]
-- A place is read once every operand is evaluated.
#guard prints ["var a = [1]", "print(a == bump(a))"] ["True"]
#guard prints ["var a = [1]", "print(bump(a) == a)"] ["True"]
-- In `and`, `or`, `not` and conditions.
#guard prints ["var a = [1]", "var b = [2]", "print(a < b and b > a, a == b or not (a != b))"]
  ["True False"]
#guard prints ["var a = [1, 2]", "if a < [1, 3]:", "    print(1)", "while a == [0, 0]:",
  "    print(2)"] ["1"]

-- Another length or element type, an `Int`, or an empty literal: a type
-- mismatch, before an operand is read.
#guard rejects ["print([1] < [1, 2])"] (.typeMismatch (.array .int 1) (.array .int 2))
#guard rejects ["print([1] == [True])"] (.typeMismatch (.array .int 1) (.array .bool 1))
#guard rejects ["print([1] == [])"] (.typeMismatch (.array .int 1) .unknown)
#guard rejects ["var a = [1]", "var x = 1", "print(a < x)"] (.typeMismatch (.array .int 1) .int)
#guard rejects ["var a = [1]", "var x = 1", "print(x == a)"] (.typeMismatch .int (.array .int 1))
#guard rejects ["var a: Array[Int, 1]", "print(a == [1, 2])"]
  (.typeMismatch (.array .int 1) (.array .int 2))
#guard rejects ["var a: Array[Int, 1]", "print(a == [1])"] (.uninitializedUse (.var "a"))
-- An integer literal's operator has several overloads.
#guard rejects ["var a = [1]", "print(1 == a)"] (.noMatchingMethod "__eq__")

-- An element type that does not conform, before an operand is read.
#guard rejects ["print([f()] == [f()])"] (.violatedConstraint (.array .noneType 1) "__eq__")
#guard rejects ["print([[f()]] < [[f()]])"]
  (.violatedConstraint (.array (.array .noneType 1) 1) "__lt__")
#guard rejects ["var a = [f()]", "print(a != a)"] (.violatedConstraint (.array .noneType 1) "__ne__")
#guard rejects ["print([List[Int]()] < [List[Int]()])"]
  (.violatedConstraint (.array (.list .int) 1) "__lt__")
#guard rejects ["print([f()] == [1])"] (.typeMismatch (.array .noneType 1) (.array .int 1))

-- Not yet: a struct element (part 2 of #166, after #194), the equality of
-- lists (#185) and the order of `Bool`s, which keep their result.
#guard rejects ["print([P(1)] == [P(1)])"] (.typeMismatch .int (.array (.struct "P") 1))
#guard rejects ["var a = [P(1)]", "print(a < a)"] (.implicitCopy (.array (.struct "P") 1))
#guard rejects ["print([List[Int]()] == [List[Int]()])"]
  (.typeMismatch .int (.array (.list .int) 1))
#guard rejects ["print(True < False)"] (.typeMismatch .int .bool)

end MojoGrimoireTest.Parse.ArrayCompare
