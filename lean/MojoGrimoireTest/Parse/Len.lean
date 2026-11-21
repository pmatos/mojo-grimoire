import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the built-in `len` (#190). `len` of an `Int`, a SIMD vector of
width 1, is 1. Every other misfit, of the argument's type or of the number
of arguments, is the compiler's "no matching function in call to 'len'",
`noMatchingInit`, found from the arguments' types before they are read.
-/

namespace MojoGrimoireTest.Parse.Len

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

private def inMain (body : List String) : List String := "def main():" :: body.map ("    " ++ ·)

/-- Whether the body `body` of `main`, after `pre`, is rejected with `e` in
`main`. -/
private def rejects (pre body : List String) (e : CheckError) : Bool :=
  runLines (pre ++ inMain body) == some (.rejected ⟨"main", e⟩)

/-- Whether the body `body` of `main`, after `pre`, prints `out`. -/
private def prints (pre body : List String) (out : List String) : Bool :=
  runLines (pre ++ inMain body) == some (.finished out)

private def decls : List String := [
  "@fieldwise_init", "struct P(Copyable, Movable):", "    var a: Int",
  "struct T(Movable):", "    var a: Int",
  "    def __init__(out self):", "        self.a = 2",
  "    def __len__(self) -> Int:", "        return self.a",
  "def g() -> Int:", "    print(\"g\")", "    return 5",
  "def nothing():", "    pass",
  "def bump(mut x: Int) -> Int:", "    x += 1", "    return x",
  "def f(a: Int) -> Int:", "    return len(a)", ""]

-- `len` of an `Int` is 1, of a place, a literal, an expression, a field,
-- an element, a parameter and a call, which is evaluated.
#guard prints [] ["var x = -7", "print(len(x), x)"] ["1 -7"]
#guard prints [] ["print(len(5), len(3 + 4))"] ["1 1"]
#guard prints decls ["var p = P(4)", "var xs: List[Int] = [5, 6]", "print(len(p.a), len(xs[1]))"]
  ["1 1"]
#guard prints decls ["print(f(9), len(g()))"] ["g", "1 1"]
#guard prints [] ["var xs: List[Int] = [1, 2]", "print(len(len(xs)))"] ["1"]
#guard prints decls ["var x = 1", "print(len(x), bump(x), len(x), x)"] ["1 2 1 2"]
#guard prints [] ["var x = 3", "var xs = List[Int](range(len(x)))", "print(len(xs), xs[0])"]
  ["1 0"]
-- An `Int` moved with `^` is copied, so `len` still reads it.
#guard prints [] ["var x = 1", "var y = x^", "print(len(x), y)"] ["1 1"]
-- An uninitialized `Int` fits `len`, and is then read.
#guard rejects [] ["var x: Int", "print(len(x))"] (.uninitializedUse (.var "x"))

-- A `Bool`, `None` and a struct fit no overload, even a struct that declares
-- `__len__` without `Sized`.
#guard rejects [] ["print(len(True))"] (.noMatchingInit .bool)
#guard rejects decls ["var n = nothing()", "print(len(n))"] (.noMatchingInit .noneType)
#guard rejects decls ["print(len(nothing()))"] (.noMatchingInit .noneType)
#guard rejects decls ["var p = P(4)", "print(len(p))"] (.noMatchingInit (.struct "P"))
#guard rejects decls ["var t = T()", "print(len(t))"] (.noMatchingInit (.struct "T"))
-- Nor does a wrong number of arguments.
#guard rejects [] ["print(len())"] (.noMatchingInit .unknown)
#guard rejects [] ["var xs: List[Int] = [1]", "print(len(xs, xs))"] (.noMatchingInit .unknown)
#guard rejects [] ["var xs: List[Int] = [1]", "print(len(xs) + len())"] (.noMatchingInit .unknown)

-- The misfit is found from the types, before the arguments are read.
#guard rejects [] ["var b: Bool", "print(len(b))"] (.noMatchingInit .bool)
#guard rejects decls ["var p = P(4)", "var q = p^", "print(len(p), q.a)"]
  (.noMatchingInit (.struct "P"))
#guard rejects [] ["var xs: List[Int] = [1]", "var y: Int", "print(len(xs, y))"]
  (.noMatchingInit .unknown)
#guard rejects [] ["var xs: List[Int] = [1]", "print(len(xs[-1], xs))"] (.noMatchingInit .unknown)
-- An error of typing inside an argument comes first.
#guard rejects [] ["print(len(True, nope))"] (.unknownVariable "nope")
-- A misfit inside an argument, or a literal's element, is a misfit too: it
-- is not the literal's failed SIMD constraint.
#guard rejects [] ["print(len(len(True)))"] (.noMatchingInit .bool)
#guard rejects [] ["var x: Int = [len(True), nope]", "print(x)"] (.noMatchingInit .bool)
#guard rejects [] ["var xs = List[Int](range(len(True)))", "print(len(xs))"]
  (.noMatchingInit .bool)
-- A string keeps its class, outside `print`.
#guard rejects [] ["print(len(\"abc\"))"] .stringOutsidePrint

end MojoGrimoireTest.Parse.Len
