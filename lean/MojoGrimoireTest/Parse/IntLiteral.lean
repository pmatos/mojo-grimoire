import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of a literal `[e]` of one `Int` element where an `Int` is expected
(#103). Mojo 1.2.0's `Int` is `SIMD[DType.int, 1]`, whose `__list_literal__`
initializer takes the elements, so such a literal is the value of `e`.
Literals of other lengths wait on a ruling (#122) and keep their errors.
-/

namespace MojoGrimoireTest.Parse.IntLiteral

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

/-- Functions that take and give an `Int` by each convention, a struct
built field by field and one with an `__init__` and a method. -/
private def lib : List String := [
  "def rd(x: Int) -> Int:", "    return x",
  "def own(var x: Int) -> Int:", "    return x",
  "def rf(ref x: Int) -> Int:", "    return x",
  "def bump(mut x: Int):", "    x += 1",
  "def seven() -> Int:", "    return [7]",
  "def loud(n: Int) -> Int:", "    print(\"loud\", n)", "    return n",
  "def inc(mut x: Int) -> Int:", "    x += 10", "    return 0",
  "def two(a: Int, b: Int) -> Int:", "    return a * 100 + b",
  "@fieldwise_init", "struct D(Movable):", "    var n: Int",
  "    def __deinit__(deinit self):", "        print(\"del\", self.n)",
  "def eat(var d: D) -> Int:", "    return 5",
  "def pick(ref a: Int) -> ref [a] Int:", "    return a",
  "@fieldwise_init", "struct S(Movable):", "    var a: Int", "    var b: Bool",
  "struct Q(Movable):", "    var a: Int",
  "    def __init__(out self, a: Int):", "        self.a = a",
  "    def get(self, k: Int) -> Int:", "        return self.a + k",
  ""]

/-- The program of `lib` whose `main` declares `x`, `xs` and `arr`, then
runs `body`. -/
private def inMain (body : List String) : List String :=
  lib ++ "def main():" :: (["var x = 1", "var xs: List[Int] = [5, 6]",
    "var arr: Array[Int, 2] = [5, 6]"] ++ body).map ("    " ++ ·)

/-- Whether `main`, running `body`, prints the lines `out`. -/
private def prints (body : List String) (out : List String) : Bool :=
  runLines (inMain body) == some (.finished out)

/-- Whether `main`, running `body`, is rejected with the error `e`. -/
private def rejects (body : List String) (e : CheckError) : Bool :=
  runLines (inMain body) == some (.rejected ⟨"main", e⟩)

-- Inference types the literal `Int`.
#guard mainBody ["def main():", "    var y: Int = [1]"] ==
  some [.decl "y" .int (some (.list .int [.int 1]))]
#guard mainBody ["def main():", "    var y: Int = [[1]]"] ==
  some [.decl "y" .int (some (.list .int [.list .int [.int 1]]))]

-- A literal that reads a place or calls is replaced by its element, which
-- Mojo reads as that operand.
#guard mainBody ["def main():", "    var x = 1", "    var y: Int = [[x]]"] ==
  some [.decl "x" .int (some (.int 1)), .decl "y" .int (some (.place (.var "x")))]

-- Declared, assigned, returned, nested, and of any `Int` expression.
#guard prints ["var y: Int = [1]", "print(y)"] ["1"]
#guard prints ["var y: Int = [[[2]]]", "print(y)"] ["2"]
#guard prints ["var y: Int = [x + 2]", "y = [y * 2]", "print(y)"] ["6"]
#guard prints ["print(seven())"] ["7"]
#guard prints ["var y: Int = [loud(3)]", "print(y)"] ["loud 3", "3"]
#guard prints ["var y: Int = [x^]", "print(x, y)"] ["1 1"]
-- Passed to a parameter of any convention but `mut`, and to an initializer
-- or a method.
#guard prints ["print(rd([4]), own([5]), rf([6]))"] ["4 5 6"]
#guard prints ["var s = S([4], True)", "s.a = [9]", "print(s.a)"] ["9"]
#guard prints ["var q = Q([3])", "print(q.get([4]))"] ["7"]
#guard prints ["xs.append([7])", "xs[0] = [8]", "print(xs.pop([0]))", "print(xs)"]
  ["8", "[6, 7]"]
-- An element of a literal of `Int`s, a list or an array.
#guard prints ["var ys: List[Int] = [[1], [2]]", "print(ys)"] ["[1, 2]"]
#guard prints ["var ys: Array[Int, 2] = [[1], 2]", "print(ys)"] ["[1, 2]"]
#guard prints ["var ys: List[List[Int]] = [[[1]]]", "print(ys)"] ["[[1]]"]
-- An index.
#guard prints ["print(xs[[1]], arr[[0]])"] ["6 5"]
-- The right operand of an operator on an `Int`, and the left operand of an
-- arithmetic one.
#guard prints ["print(x + [2], x - [1], x * [3], x // [2], x % [2])"] ["3 0 3 0 1"]
#guard prints ["print(x == [1], x != [1], x < [2], x <= [0], x > [0], x >= [2])"]
  ["True False True False True False"]
#guard prints ["print([2] + x, [2] - x, [3] * x, [7] // x, [7] % x)"] ["3 1 3 7 0"]
#guard prints ["x += [3]", "print(x)"] ["4"]
#guard prints ["print(1 + [2], [5] - 2, len(xs) + [1])"] ["3 3 3"]

-- A place in the literal is read, re-checked and destroyed once every operand
-- of the operation is evaluated, as the place alone would be.
#guard prints ["print([x] + inc(x))"] ["11"]
#guard prints ["print(two([x], inc(x)))"] ["1100"]
#guard prints ["var ys: List[Int] = [[x], inc(x)]", "print(ys)"] ["[11, 0]"]
#guard prints ["print(xs[[x] + inc(x) - 10])"] ["6"]
#guard rejects ["var d = D(1)", "print(two([d.n], eat(d^)))"] (.uninitializedUse (.field (.var "d") "n"))
#guard rejects ["print([xs[0]] + xs.pop())"]
  (.invalidatedReference (.index (.var "xs") (.int 0)))
#guard prints ["var d = D(1)", "print([d.n] + loud(2))"] ["loud 2", "del 1", "3"]
-- Passed `mut` or `ref`, it is a temporary, not the place, so it is read at
-- once, and it is not a place that `mut` may change.
#guard rejects ["bump([x])"] (.notAPlace "bump")
#guard prints ["print(pick([x]) + inc(x))"] ["1"]
#guard prints ["print(pick([xs[0]]) + xs.pop())"] ["11"]

-- The compiler does not compute an index that holds such a literal when it
-- compiles the program, so it fails only at run time.
#guard runLines (inMain ["print(xs[[-1]])"]) == some (.failed .indexOutOfBounds [])
#guard runLines (inMain ["print(arr[[2]])"]) == some (.failed .indexOutOfBounds [])
#guard runLines (inMain ["print(xs[[1] - 2])"]) == some (.failed .indexOutOfBounds [])

-- An element that is not an `Int` fits no initializer of `Int`, and other
-- lengths keep their errors until #122 is ruled.
#guard rejects ["var y: Int = [True]"] (.noMatchingInit .int)
#guard rejects ["var y: Int = [1, 2]"] (.noMatchingInit .int)
#guard rejects ["var y: Int = []"] (.noMatchingInit .int)
#guard rejects ["print(x + [True])"] (.typeMismatch .int (.array .bool 1))
-- A literal with no type expected is still an array: as the left operand of
-- a comparison, negated, as the argument of `List[Int](…)`, or bound to a
-- variable.
#guard rejects ["print([2] < x)"] (.typeMismatch .int (.array .int 1))
#guard rejects ["print([1] == x)"] (.typeMismatch .int (.array .int 1))
#guard rejects ["print(-[1])"] (.typeMismatch .int (.array .int 1))
#guard rejects ["var ys = List[Int]([[1]])"] (.noMatchingInit (.list .int))
#guard rejects ["var a = [1]", "var y: Int = a.copy()"] (.typeMismatch .int (.array .int 1))
-- A value is not a place, so it cannot be passed `mut`.
#guard rejects ["bump([1])"] (.notAPlace "bump")

end MojoGrimoireTest.Parse.IntLiteral
