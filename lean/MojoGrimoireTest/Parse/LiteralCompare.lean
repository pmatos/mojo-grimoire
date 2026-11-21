import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of a literal compared with an array or a list (part 2 of #166): the
compiler converts it to the type of the other operand, element by
element, as a call converts its argument. A literal on the right takes
the left operand's type, and one on the left the right operand's, unless
that is a literal too. One that does not fit is a type mismatch, found
before the operands are read. Each verdict is the pinned compiler's for
the program, probed on the nightly 1.3.0.dev2026111905.
-/

namespace MojoGrimoireTest.Parse.LiteralCompare

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- The declarations before `main`. -/
private def pre : List String :=
  ["def two() -> Int:", "    return 2"]

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

-- On the right: each inner literal `[e]` initializes an `Int`, or an array.
#guard prints ["print([1, 2] == [[1], [2]], [1] == [[1]])"] ["True True"]
#guard prints ["var a = [1, 2]", "var x = 1", "print(a == [[1], [2]], a == [[x], 2], a < [1, [3]])"]
  ["True True True"]
#guard prints ["var a = [1, 2]", "print(a == [[1], [two()]])"] ["True"]
#guard prints ["var a = [1]", "print(a == [[[1]]])"] ["True"]
#guard prints ["print([[1]] == [[[1]]], [[2]] >= [[[1]]])"] ["True True"]
#guard prints ["var a = [[1, 2], [3, 4]]", "print(a == [[[1], 2], [3, [4]]])"] ["True"]
#guard prints ["var xs: List[Array[Int, 2]] = [[1, 2]]", "print(xs == [[[1], [2]]])"] ["True"]
-- One that does not fit, before the operands are read.
#guard rejects ["var a = [[1]]", "print(a == [[]])"] (.typeMismatch (.array (.array .int 1) 1) .unknown)
#guard rejects ["var a = [[1, 2]]", "print(a == [[1]])"]
  (.typeMismatch (.array (.array .int 2) 1) (.array (.array .int 1) 1))
#guard rejects ["print([[1]] == [[]])"] (.typeMismatch (.array (.array .int 1) 1) .unknown)
#guard rejects ["print([[1]] == [1])"] (.typeMismatch (.array (.array .int 1) 1) (.array .int 1))
#guard rejects ["print([[1], [2]] == [1, 2])"]
  (.typeMismatch (.array (.array .int 1) 2) (.array .int 2))
#guard rejects ["var a: Array[Int, 1]", "print(a == [[1, 2], 3])"]
  (.typeMismatch (.array .int 1) .unknown)
#guard rejects ["var a: Array[Int, 2]", "print(a == [[1], [2]])"] (.uninitializedUse (.var "a"))
-- An inner literal of another length, where an `Int` is expected, fails
-- SIMD's constraint, after the reads.
#guard rejects ["var a = [1]", "print(a == [[1, 2]])"] (.noMatchingInit .int)

-- On the left: the right operand's type, when the literal fits it.
#guard prints ["var a = [1]", "print([[1]] == a)"] ["True"]
#guard prints ["var a = [1, 2]", "print([[1], [2]] != a, [[1], 2] == a, [1, [2]] == a)"]
  ["False True True"]
#guard prints ["var a = [1, 2]", "print([[1], [2]] < a, [[0], 9] <= a)"] ["False True"]
#guard prints ["var xs: List[Int] = [1, 2]", "print([1, 2] == xs, [1] != xs)"] ["True True"]
#guard prints ["var xss: List[List[Int]] = [[1], []]", "print([[1], []] == xss)"] ["True"]
#guard prints ["var xs: List[Int] = []", "print([] == xs)"] ["True"]
#guard prints ["var xs: List[Int] = [1]", "var x = 1", "print([x] == xs, [[1]] == xs)"]
  ["True True"]
-- Its own type, when it does not fit: it is built first, so an implicit
-- copy in it comes first, and the right operand is converted to it.
#guard rejects ["var a = [1]", "print([1, 2] == a)"] (.typeMismatch (.array .int 2) (.array .int 1))
#guard rejects ["var a = [1]", "print([[True]] == a)"]
  (.typeMismatch (.array (.array .bool 1) 1) (.array .int 1))
#guard rejects ["var xs: List[Int] = [1]", "print([True] == xs)"]
  (.typeMismatch (.array .bool 1) (.list .int))
#guard rejects ["var ys: List[Int] = [1]", "var xs: List[Int] = [1]", "print([ys] == xs)"]
  (.implicitCopy (.list .int))
#guard rejects ["var ys: List[Int] = [1]", "var xs: List[Int] = [1]", "print([ys^] == xs)"]
  (.typeMismatch (.array (.list .int) 1) (.list .int))
-- A list has no order, so `<` converts no literal to it, nor to an array
-- of lists on the right, though a literal on the right converts to it.
#guard rejects ["var xs: List[Int] = [1]", "print([1] < xs)"]
  (.typeMismatch (.array .int 1) (.list .int))
#guard rejects ["var v: Array[List[Int], 1] = [[1]]", "print([[1]] < v)"]
  (.typeMismatch (.array (.array .int 1) 1) (.array (.list .int) 1))
#guard rejects ["var v: Array[List[Int], 1] = [[1]]", "print(v < [[1]])"]
  (.violatedConstraint (.array (.list .int) 1) "__lt__")
-- Not yet: a literal on the left that holds an inner literal of another
-- length where an `Int` is expected is not converted, since the order of
-- SIMD's failure and the reads waits for #96. It keeps the checks it had
-- before #166: the right operand is copied, and the compiler's
-- `noMatchingInit` is `implicitCopy`, or the read of an uninitialized
-- operand, as the compiler says, `uninitializedUse`.
#guard rejects ["var a = [1]", "print([[1, 2]] == a)"] (.implicitCopy (.array .int 1))
#guard rejects ["var a: Array[Int, 1]", "print([[1, 2]] == a)"] (.uninitializedUse (.var "a"))
#guard rejects ["var x: Int", "var a = [1, 2]", "print([[2, 3], [x]] == a)"]
  (.uninitializedUse (.var "x"))
-- A literal with a type, `List[u]()`, fits only that type.
#guard rejects ["var a = [1, 2]", "print([List[Int](), 2] == a)"]
  (.typeMismatch (.list .int) .int)
-- A constructor's error in a converted literal comes before the reads.
#guard runMain ["var xss: List[List[Int]]", "print([List[Int](1)] == xss)"] matches
  some (.rejected ⟨"main", .noMatchingInit ..⟩)
-- A literal on the left that the comparison does not convert is built
-- first, so its implicit copy comes before its misfit.
#guard rejects ["var ys: List[Int] = [1]", "var xss: List[List[Int]] = [[1]]", "print([ys] < xss)"]
  (.implicitCopy (.list .int))

end MojoGrimoireTest.Parse.LiteralCompare
