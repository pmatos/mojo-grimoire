import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of initializations whose arguments fit no initializer, which the
compiler reports as "no matching function in initialization" and the model
as `noMatchingInit` (#46): `List[T](e₁, …, eₙ)`, a literal that does not
fit the list or array it initializes, and a construction `S(…)` with wrong
arguments. Ordinary calls, and literals passed to them, keep their own
classes.
-/

namespace MojoGrimoireTest.Parse.Initializers

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- Whether the program `ls` is rejected with the error `e` in `main`. -/
private def rejects (ls : List String) (e : CheckError) : Bool :=
  runLines ls == some (.rejected ⟨"main", e⟩)

private def inMain (body : List String) : List String := "def main():" :: body.map ("    " ++ ·)

/-- The body of `main` once the program whose lines are `ls` is parsed. -/
private def mainBody (ls : List String) : Option (List Stmt) :=
  match parse ("\n".intercalate ls) with
  | .ok prog => (prog.funs.find? (·.name == "main")).map (·.body)
  | .error _ => none

/-- A `@fieldwise_init` struct of one `Int`, a struct whose `__init__` takes
an `Int`, one whose `__init__` takes it `mut`, and a struct holding an
array. -/
private def structs : List String := [
  "@fieldwise_init", "struct P(Movable):", "    var x: Int",
  "struct Q(Movable):", "    var x: Int",
  "    def __init__(out self, x: Int):", "        self.x = x",
  "struct M(Movable):", "    var x: Int",
  "    def __init__(out self, mut y: Int):", "        self.x = y",
  "@fieldwise_init", "struct H(Movable):", "    var xs: Array[Int, 2]",
  "def f(x: Int) -> Int:", "    return x",
  "def g(xs: Array[Int, 2]) -> Int:", "    return len(xs)",
  "def h(xs: List[Int]) -> Int:", "    return len(xs)",
  "def k(xs: List[Array[Int, 2]]) -> Int:", "    return len(xs)",
  "def ps(xs: List[P]) -> Int:", "    return len(xs)",
  ""]

private def withStructs (body : List String) : List String := structs ++ inMain body

-- `List[T](…)` with arguments is read as such, and `List[T]()` as an empty
-- list.
#guard mainBody (inMain ["var xs = List[Int](1, 2)"]) ==
  some [.decl "xs" (.list .int) (some (.listInit .int [.int 1, .int 2]))]
#guard mainBody (inMain ["var xs = List[Int]()"]) ==
  some [.decl "xs" (.list .int) (some (.list (.list .int) []))]

-- No initializer of `List` takes its elements as arguments.
#guard rejects (inMain ["var xs = List[Int](1, 2)", "print(len(xs))"])
  (.noMatchingInit (.list .int))
#guard rejects (inMain ["var xs = List[Int](1)"]) (.noMatchingInit (.list .int))
#guard rejects (inMain ["var xs = List[Int](True)"]) (.noMatchingInit (.list .int))
#guard rejects (inMain ["var xs = List[List[Int]]([1], [2, 3])"])
  (.noMatchingInit (.list (.list .int)))
#guard rejects (inMain ["var xs: List[List[Int]] = [List[Int](1)]"])
  (.noMatchingInit (.list .int))
#guard runLines (inMain ["var xs = List[Int]()", "print(len(xs))"]) == some (.finished ["0"])
-- An argument's own error comes first.
#guard rejects (inMain ["var xs = List[Int](nope)"]) (.unknownVariable "nope")

-- An array literal of another size fits no initializer of the array it
-- initializes: declared, assigned, returned, inside a literal of an expected
-- type, or as the argument of a construction.
#guard rejects (inMain ["var xs: Array[Int, 3] = [1, 2]"]) (.noMatchingInit (.array .int 3))
#guard rejects (inMain ["var xs: Array[Int, 2] = [1, 2]", "xs = [1, 2, 3]"])
  (.noMatchingInit (.array .int 2))
#guard runLines ["def arr() -> Array[Int, 2]:", "    return [1, 2, 3]", "def main():",
    "    print(len(arr()))"] ==
  some (.rejected ⟨"arr", .noMatchingInit (.array .int 2)⟩)
#guard rejects (inMain ["var ys: List[Array[Int, 2]] = [[1, 2, 3]]"])
  (.noMatchingInit (.array .int 2))
#guard rejects (withStructs ["var h = H([1, 2, 3])"]) (.noMatchingInit (.array .int 2))
-- Passed to a function or a method, it is converted, and does not fit as a
-- type mismatch, also inside a literal.
#guard rejects (withStructs ["print(g([1, 2, 3]))"])
  (.typeMismatch (.array .int 2) (.array .int 3))
#guard rejects (inMain ["var ys: List[Array[Int, 2]] = []", "ys.append([1, 2, 3])"])
  (.typeMismatch (.array .int 2) (.array .int 3))
#guard rejects (withStructs ["print(k([[1, 2, 3]]))"])
  (.typeMismatch (.array .int 2) (.array .int 3))

-- An element that does not fit the list or array that a literal initializes.
#guard rejects (inMain ["var xs: List[Int] = [True, False]"]) (.noMatchingInit (.list .int))
#guard rejects (inMain ["var xs: Array[Int, 2] = [1, True]"]) (.noMatchingInit (.array .int 2))
#guard rejects (inMain ["var xs: List[List[Int]] = [[True]]"]) (.noMatchingInit (.list .int))
-- Converted for a function, or with no expected type, it is a type mismatch.
#guard rejects (withStructs ["print(h([True]))"]) (.typeMismatch .int .bool)
#guard rejects (inMain ["var xs = [1, True]"]) (.typeMismatch .int .bool)

-- A literal that initializes a struct or a `Bool` calls its initializer with
-- the elements, which none takes; passed to a function, it is converted.
#guard rejects (withStructs ["var p: P = [1]"]) (.noMatchingInit (.struct "P"))
#guard rejects (withStructs ["var p: P = [1, True]"]) (.noMatchingInit (.struct "P"))
#guard rejects (withStructs ["var p: P = []"]) (.noMatchingInit (.struct "P"))
#guard rejects (withStructs ["var p = P(1)", "p = [2]"]) (.noMatchingInit (.struct "P"))
#guard rejects (inMain ["var b: Bool = [True]"]) (.noMatchingInit .bool)
#guard runLines (structs ++ ["def mk() -> P:", "    return [1]", "def main():",
    "    var p = mk()"]) == some (.rejected ⟨"mk", .noMatchingInit (.struct "P")⟩)
#guard rejects (withStructs ["var p: P = [nope]"]) (.unknownVariable "nope")
#guard rejects (structs ++ ["def gp(p: P) -> Int:", "    return p.x", "def main():",
    "    print(gp([1]))"]) (.typeMismatch (.struct "P") (.array .int 1))

-- A construction with a wrong argument or a wrong number of them, whether
-- the struct is `@fieldwise_init` or has an `__init__`.
#guard rejects (withStructs ["var p = P(True)"]) (.noMatchingInit (.struct "P"))
#guard rejects (withStructs ["var p = P(1, 2)"]) (.noMatchingInit (.struct "P"))
#guard rejects (withStructs ["var p = P()"]) (.noMatchingInit (.struct "P"))
#guard rejects (withStructs ["var b = True", "var p = P(b)"]) (.noMatchingInit (.struct "P"))
#guard rejects (withStructs ["var q = Q(True)"]) (.noMatchingInit (.struct "Q"))
#guard rejects (withStructs ["var q = Q(1, 2)"]) (.noMatchingInit (.struct "Q"))
#guard rejects (withStructs ["var q = Q()"]) (.noMatchingInit (.struct "Q"))
-- A value that is not a place, or a place that may not change, passed `mut`.
#guard rejects (withStructs ["var m = M(1)"]) (.noMatchingInit (.struct "M"))
#guard runLines (structs ++ ["def take(y: Int) -> Int:", "    var m = M(y)", "    return m.x",
    "def main():", "    print(take(1))"]) ==
  some (.rejected ⟨"take", .noMatchingInit (.struct "M")⟩)
#guard runLines (withStructs ["var y = 1", "var m = M(y)", "print(m.x)"]) ==
  some (.finished ["1"])
-- A construction inside a literal passed to a function.
#guard rejects (withStructs ["print(ps([P(True)]))"]) (.noMatchingInit (.struct "P"))

-- An argument's own error, and one found once an initializer fits, keep
-- their classes.
#guard rejects (withStructs ["var p = P(1 + True)"]) (.typeMismatch .int .bool)
#guard rejects (withStructs ["var p = P(nope)"]) (.unknownVariable "nope")
#guard rejects (withStructs ["var y: Int", "var p = P(y)"]) (.uninitializedUse (.var "y"))
#guard rejects (withStructs ["var p = P(1)", "var h = H([1, 2])", "var r = H(h.xs)"])
  (.implicitCopy (.array .int 2))

-- An ordinary call keeps the type and arity mismatches.
#guard rejects (withStructs ["print(f(True))"]) (.typeMismatch .int .bool)
#guard rejects (withStructs ["print(f(1, 2))"]) (.arityMismatch "f" 1 2)

end MojoGrimoireTest.Parse.Initializers
