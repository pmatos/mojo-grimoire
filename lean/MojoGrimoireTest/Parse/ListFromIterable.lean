import MojoGrimoire.Parse.Subset
import MojoGrimoire.Interp.Run

/-!
Tests of `List[T](e)` with one argument that is a list or an array of `T`
(#103): Mojo 1.2.0 builds a new list from it through the initializer of
`List` from any iterable, which takes `e` by `ref` and copies each element.
-/

namespace MojoGrimoireTest.Parse.ListFromIterable

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`, as the driver does; a
syntax error, or a construct outside the subset, gives `none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parseSubset ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- The construct outside the subset of the program whose lines are `ls`,
which the driver reports with exit 3. -/
private def outsideOf (ls : List String) : Option Outside :=
  match parseSubset ("\n".intercalate ls) with
  | .error (.outside o) => some o
  | _ => none

/-- The body of `main` once the program whose lines are `ls` is parsed. -/
private def mainBody (ls : List String) : Option (List Stmt) :=
  match parse ("\n".intercalate ls) with
  | .ok prog => (prog.funs.find? (·.name == "main")).map (·.body)
  | .error _ => none

/-- A copyable struct that prints when it is destroyed, a struct that
cannot be copied, and functions that return a list of each. -/
private def lib : List String := [
  "@fieldwise_init", "struct C(Copyable):", "    var x: Int",
  "    def __deinit__(deinit self):", "        print(\"gone\", self.x)",
  "@fieldwise_init", "struct P(Movable):", "    var x: Int",
  "def mk() -> List[Int]:", "    return [1, 2, 3]",
  "def mkp() -> List[P]:", "    return [P(1)]",
  "def same(x: Int) -> Int:", "    return x",
  "def pick(ref a: List[List[Int]], ref b: List[Int]) -> ref [a, b] List[Int]:",
  "    return b",
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

/-- Whether the line `i` of `main`'s body `body`, from 1, is outside the
subset as the construct `m`. -/
private def outside (body : List String) (i : Nat) (m : String) : Bool :=
  outsideOf (inMain body) == some ⟨lib.length + 1 + i, m⟩

-- `List[T](e^)` borrows `e`: the argument is the place `e^`.
#guard mainBody (inMain ["var ys: List[Int] = [1]", "var xs = List[Int](ys^)"]) ==
  some [.decl "ys" (.list .int) (some (.list (.list .int) [.int 1])),
    .decl "xs" (.list .int) (some (.listInit .int [.place (.transferred (.var "ys"))]))]

-- A list, an array, a literal, a call's result or an element is copied into
-- a new list, which changes on its own.
#guard prints ["var ys: List[Int] = [1, 2]", "var xs = List[Int](ys)", "xs.append(3)",
  "print(xs, ys)"] ["[1, 2, 3] [1, 2]"]
#guard prints ["var a: Array[Int, 2] = [1, 2]", "var xs = List[Int](a)", "xs.append(3)",
  "print(xs, a)"] ["[1, 2, 3] [1, 2]"]
#guard prints ["var xs = List[Int]([4, 5])", "print(xs)"] ["[4, 5]"]
#guard prints ["print(len(List[Int](mk())))"] ["3"]
#guard prints ["var yss: List[List[Int]] = [[1, 2], [3]]", "var xs = List[Int](yss[0])",
  "xs.append(9)", "print(xs, yss)"] ["[1, 2, 9] [[1, 2], [3]]"]
#guard prints ["var yss: List[List[Int]] = [[1], [2]]", "var xss = List[List[Int]](yss)",
  "xss[0].append(9)", "print(xss, yss)"] ["[[1, 9], [2]] [[1], [2]]"]
#guard prints ["var xs = List[Int](List[Int]())", "print(xs)"] ["[]"]
#guard prints ["var xs: List[Int] = [1, 2]", "xs = List[Int](xs)", "print(xs)"] ["[1, 2]"]
#guard prints ["var ys: List[Int] = [1]", "print(List[Int](ys))"] ["[1]"]
-- The argument is borrowed, so `^` on it has no effect, also on a `mut`
-- parameter.
#guard prints ["var ys: List[Int] = [1]", "var xs = List[Int](ys^)", "print(xs, ys)"]
  ["[1] [1]"]
#guard runLines (lib ++ ["def f(mut ys: List[Int]):", "    var xs = List[Int](ys^)",
    "    print(xs)", "def main():", "    var ys: List[Int] = [1]", "    f(ys)",
    "    print(ys)"]) == some (.finished ["[1]", "[1]"])

-- A temporary source is destroyed once its elements are copied, and a
-- variable whose last use is the construction dies then.
#guard prints ["var xs = List[C]([C(1), C(2)])", "print(\"built\", len(xs))"]
  ["gone 1", "gone 2", "gone 1", "gone 2", "built 2"]
#guard prints ["var ys: List[C] = [C(3)]", "var zs = List[C](ys)", "print(\"copied\")",
  "print(len(zs))"] ["gone 3", "copied", "gone 3", "1"]

-- The elements must be of the list's element type, and copyable.
#guard rejects ["var ys: List[Bool] = [True]", "var xs = List[Int](ys)"]
  (.noMatchingInit (.list .int))
#guard rejects ["var xs = List[Int]([True])"] (.noMatchingInit (.list .int))
#guard rejects ["var xs = List[Int]([[1], [2]])"] (.noMatchingInit (.list .int))
#guard rejects ["var ys: List[P] = [P(1)]", "var xs = List[P](ys)"]
  (.noMatchingInit (.list (.struct "P")))
#guard rejects ["var xs = List[P]([P(1)])"] (.noMatchingInit (.list (.struct "P")))
#guard rejects ["var xs = List[P](mkp())"] (.noMatchingInit (.list (.struct "P")))
#guard rejects ["var ys: List[List[P]] = [[P(1)]]", "var xs = List[List[P]](ys)"]
  (.noMatchingInit (.list (.list (.struct "P"))))
-- A literal argument has no type expected, so the compiler infers its type
-- while it looks for an initializer: elements that differ in type, also in
-- a nested literal, fit none. An element's own error keeps its class.
#guard rejects ["var xs = List[Int]([1, True])"] (.noMatchingInit (.list .int))
#guard rejects ["var xs = List[List[Int]]([[1], [2, True]])"]
  (.noMatchingInit (.list (.list .int)))
#guard rejects ["var xs = List[Int]([same(True)])"] (.typeMismatch .int .bool)
#guard rejects ["var c = C(1)", "var xs = List[C]([c])"] (.implicitCopy (.struct "C"))
#guard prints ["var x = 2", "var xs = List[Int]([x, 3])", "print(xs)"] ["[2, 3]"]
-- A value that is neither a list nor an array fits no initializer.
#guard rejects ["var xs = List[Int]([])"] (.noMatchingInit (.list .int))
#guard outside ["var xs = List[Int](\"ab\")"] 1 outsideString
#guard rejects ["var n = 3", "var xs = List[Int](n)"] (.noMatchingInit (.list .int))
#guard rejects ["var ys: List[C] = [C(1)]", "var xs = List[C](ys[0])"]
  (.noMatchingInit (.list (.struct "C")))
-- The result is a list, not an array.
#guard rejects ["var a: Array[Int, 2] = [1, 2]", "var xs: Array[Int, 2] = List[Int](a)"]
  (.typeMismatch (.array .int 2) (.list .int))

-- The source must be initialized, and `e^` must be a value that could be
-- transferred.
#guard rejects ["var ys: List[Int]", "var xs = List[Int](ys)"] (.uninitializedUse (.var "ys"))
#guard rejects ["var ys: List[Int] = [1]", "var zs = ys^", "var xs = List[Int](ys)"]
  (.uninitializedUse (.var "ys"))
#guard runLines (lib ++ ["def f(ys: List[Int]):", "    var xs = List[Int](ys^)",
    "def main():", "    var ys: List[Int] = [1]", "    f(ys)"]) ==
  some (.rejected ⟨"f", .transferFromBorrowed (.var "ys")⟩)
#guard rejects ["var yss: List[List[Int]] = [[1]]", "var xs = List[Int](yss[0]^)"]
  (.transferFromElement (.index (.var "yss") (.int 0)))

-- A mutable source is passed `ref` as a mutable reference, which may change
-- it: a reference into one of its elements is invalidated. Through `e^`, or
-- from a `read` parameter, it is not.
#guard rejects ["var ys: List[Int] = [1, 2]", "ref e = ys[0]", "var xs = List[Int](ys)",
  "print(e, xs)"] (.invalidatedReference (.var "e"))
#guard prints ["var ys: List[Int] = [1, 2]", "ref e = ys[0]", "var xs = List[Int](ys^)",
  "print(e, xs)"] ["1 [1, 2]"]
#guard runLines (lib ++ ["def f(ys: List[Int]):", "    ref e = ys[0]",
    "    var xs = List[Int](ys)", "    print(e, xs)", "def main():",
    "    var ys: List[Int] = [1, 2]", "    f(ys)"]) == some (.finished ["1 [1, 2]"])

-- The new list is built in the place it is assigned to, which a mutable
-- reference passed as its argument may not alias.
#guard rejects ["var xss: List[List[Int]] = [[1], [2]]", "var ys: List[Int] = [5]",
  "xss[0] = List[Int](pick(xss, ys))"] (.argumentExclusivity (.var "xss"))
#guard prints ["var xss: List[List[Int]] = [[1], [2]]", "xss[0] = List[Int](xss[1])",
  "print(xss)"] ["[[2], [2]]"]

-- With more than one argument, no initializer fits.
#guard rejects ["var ys: List[Int] = [1]", "var xs = List[Int](ys, ys)"]
  (.noMatchingInit (.list .int))

end MojoGrimoireTest.Parse.ListFromIterable
