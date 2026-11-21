import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the order of two `Bool`s and of `==` and `!=` on two lists (#185).
`<`, `<=`, `>` and `>=` order two `Bool`s, `False` first. Two lists of the
same type, whose elements are `Int`s, `Bool`s, lists or arrays of them,
are equal when their elements are, both read by reference, and a literal
on the right is converted to the list's type. Another type is a type
mismatch, found before an operand is read, and a list has no order
(`missingMethod`). A list of structs, and a literal on the left of a list,
keep the result they had before (#194, part 2 of #166), and so do the
gaps of a call's literal argument (#96, #165). Each verdict is
the pinned compiler's for the program, probed on the nightly
1.3.0.dev2026111905, but for those last ones.
-/

namespace MojoGrimoireTest.Parse.ListCompare

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- The declarations before `main`. -/
private def pre : List String :=
  ["@fieldwise_init", "struct P(Copyable, Movable):", "    var x: Int",
   "def pick(ref xs: List[Int]) -> ref [xs] List[Int]:", "    return xs",
   "def bump(mut xs: List[Int]) -> List[Int]:", "    xs.append(9)", "    return [1, 9]",
   "def mk(n: Int) -> List[Int]:", "    print(\"mk\", n)", "    return [n]",
   "def eq(xs: List[Int], ys: List[Int]) -> Bool:", "    return xs == ys",
   "@fieldwise_init", "struct H(Movable):", "    var n: Int", "    var xs: List[Int]",
   "    def __deinit__(deinit self):", "        print(\"del\", self.n)"]

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

-- The order of two `Bool`s, `False` first.
#guard prints ["print(True < False, False < True, True <= True, False <= True, True <= False)"]
  ["False True True True False"]
#guard prints ["print(True > False, False > True, True >= True, False >= True, True >= False)"]
  ["True False True False True"]
#guard prints ["var a = False", "if a < True:", "    print(1)", "print(not (a > a), a >= a)"]
  ["1", "True True"]
#guard prints ["var bs: List[Bool] = [False, True]", "print(bs[0] < bs[1], bs[1] <= bs[0])"]
  ["True False"]
-- Another type on either side is a type mismatch; an integer literal's
-- operators have several overloads.
#guard rejects ["print(True < 1)"] (.typeMismatch .bool .int)
#guard rejects ["var n = 0", "print(n < True)"] (.typeMismatch .int .bool)
#guard rejects ["print(1 < True)"] (.noMatchingMethod "__lt__")
#guard rejects ["var b: Bool", "print(b < True)"] (.uninitializedUse (.var "b"))

-- `==` and `!=` of lists of `Int`s, `Bool`s, lists and arrays.
#guard prints ["var xs: List[Int] = [1, 2]", "var ys: List[Int] = [1, 2]",
  "var zs: List[Int] = [1]", "print(xs == ys, xs != ys, xs == zs, zs != xs)"]
  ["True False False True"]
#guard prints ["var bs: List[Bool] = [True]", "var cs: List[Bool] = [False]",
  "print(bs == cs, bs != cs, List[Bool]() == List[Bool]())"] ["False True True"]
#guard prints ["var xs: List[List[Int]] = [[1], [2, 3]]", "var ys: List[List[Int]] = [[1], [2]]",
  "print(xs == ys, xs[0] == ys[0], xs[1] != ys[1])"] ["False True True"]
#guard prints ["var xs: List[Array[Int, 2]] = [[1, 2]]", "var ys: List[Array[Int, 2]] = [[1, 3]]",
  "print(xs == ys, xs != ys)"] ["False True"]
#guard prints ["print([List[Int]()] == [List[Int]()], [List[Int]()] != [List[Int]()])"]
  ["True False"]

-- Both operands are read by reference: a named list is not copied, and a
-- place is read once both operands are evaluated.
#guard prints ["var xs: List[Int] = [1]", "var ys: List[Int] = [1]", "ref r = xs",
  "print(pick(xs) == ys, ys == pick(ys), r == ys, eq(xs, ys))", "print(xs == bump(xs))"]
  ["True True True True", "True"]
#guard prints ["var xs: List[Int] = [1]", "print(mk(1) == xs, xs != mk(2))"]
  ["mk 1", "mk 2", "True True"]
-- A value whose last use is the comparison is destroyed once it is done.
#guard prints ["var h = H(1, [1])", "var g = H(2, [2])", "print(h.xs == g.xs)", "print(\"end\")"]
  ["del 2", "del 1", "False", "end"]

-- A literal on the right is converted to the list's type, also one that
-- holds literals or reads places late.
#guard prints ["var xs: List[Int] = [1, 2]", "print(xs == [1, 2], xs != [1], xs == [])"]
  ["True True False"]
#guard prints ["var xss: List[List[Int]] = [[1], []]", "print(xss == [[1], []], xss != [[1]])"]
  ["True True"]
#guard prints ["var xs: List[Int] = [1]", "print(xs == [[1]])"] ["True"]
#guard prints ["var n = 1", "var xs: List[Int] = [9, 9]", "print(bump(xs) == [1, n + 8])"]
  ["True"]

-- Another type, also as a literal's element, is a type mismatch, before
-- an operand is read.
#guard rejects ["var xs: List[Int] = [1]", "var a = [1]", "print(xs == a)"]
  (.typeMismatch (.list .int) (.array .int 1))
#guard rejects ["var xs: List[Int]", "var a = [1]", "print(xs == a)"]
  (.typeMismatch (.list .int) (.array .int 1))
#guard rejects ["var xs: List[Int] = [1]", "var ys: List[Bool]", "print(xs != ys)"]
  (.typeMismatch (.list .int) (.list .bool))
#guard rejects ["var xs: List[Int] = [1]", "print(xs == 1)"] (.typeMismatch (.list .int) .int)
#guard rejects ["var xs: List[Int] = [1]", "var b = True", "print(b == xs)"]
  (.typeMismatch .bool (.list .int))
#guard rejects ["var xs: List[Int] = [1]", "var b = True", "print(b < xs)"]
  (.typeMismatch .bool (.list .int))
#guard rejects ["var xs: List[Int] = [1]", "print(xs == [True])"] (.typeMismatch .int .bool)
#guard rejects ["var xs: List[Int] = [1]", "print(1 == xs)"] (.noMatchingMethod "__eq__")
#guard rejects ["var xs: List[Int]", "print(xs == [1])"] (.uninitializedUse (.var "xs"))
-- An inner literal where an `Int` is expected fits no initializer of `Int`
-- unless it has one element, as in a call.
#guard rejects ["var xs: List[Int] = [1]", "print(xs == [[1, 2]])"] (.noMatchingInit .int)
-- A list has no order.
#guard rejects ["var xs: List[Int] = [1]", "print(xs <= xs)"] (.missingMethod (.list .int) "__le__")

-- Not yet: a list of structs (#194), and a literal on the left of a list
-- (part 2 of #166), which keep their result.
#guard rejects ["var xs: List[P] = [P(1)]", "print(xs == xs)"] (.implicitCopy (.list (.struct "P")))
#guard rejects ["var xs: List[Int] = [1]", "print([1] == xs)"] (.implicitCopy (.list .int))
-- Nor the gaps of a call's literal argument: an element that does not fit
-- beside an uninitialized list comes after its use (#96), and an inner
-- literal that initializes a `Bool` is no type mismatch for the compiler
-- but `noMatchingInit` (#165).
#guard rejects ["var xs: List[Int]", "print(xs == [True])"] (.uninitializedUse (.var "xs"))
#guard runMain ["var bs: List[Bool] = [True]", "print(bs == [[True]])"] matches
  some (.rejected ⟨"main", .typeMismatch ..⟩)

end MojoGrimoireTest.Parse.ListCompare
