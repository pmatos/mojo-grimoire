import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of a call that returns a reference, passed to `len` or to a `read`,
`mut` or `ref` parameter. The pinned compiler passes it as a location: it
is not copied, it counts for argument exclusivity through its origins, it
must be mutable for `mut`, and the values it points into live until the
call it is passed to is done. A `var` parameter still copies it. Each
verdict and output is the pinned compiler's for the program.
-/

namespace MojoGrimoireTest.Parse.ReturnedRefArgs

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- `Res` prints its id when it is destroyed; `first` returns its list, and
`look` returns its list through a `read` parameter. -/
private def lib : List String := [
  "@fieldwise_init",
  "struct Res(Movable):",
  "    var id: Int",
  "    def __deinit__(deinit self):",
  "        print(\"drop\", self.id)",
  "",
  "def first(ref xs: List[Int]) -> ref [xs] List[Int]:",
  "    return xs",
  "",
  "def look(xs: List[Int]) -> ref [xs] List[Int]:",
  "    return xs",
  "",
  "def firsts(ref xs: List[Res]) -> ref [xs] List[Res]:",
  "    return xs",
  "",
  "def count(xs: List[Int]) -> Int:",
  "    return len(xs)",
  "",
  "def push(mut xs: List[Int]) -> Int:",
  "    xs.append(9)",
  "    return len(xs)",
  ""]

/-- The program of `lib`, the declarations `decls`, and a `main` with the
body `body`. -/
private def prog (decls body : List String) : List String :=
  lib ++ decls ++ ["def main():"] ++ body.map ("    " ++ ·)

private def prints (decls body out : List String) : Bool :=
  runLines (prog decls body) == some (.finished out)

private def rejects (decls body : List String) (decl : Name) (err : CheckError) : Bool :=
  runLines (prog decls body) == some (.rejected ⟨decl, err⟩)

private def xs : String := "var xs: List[Int] = [1, 2]"
private def x : Place := .var "xs"

-- `len` reads a returned reference, directly or through another call.
#guard prints [] [xs, "print(len(first(xs)))", "print(len(first(first(xs))))"] ["2", "2"]
#guard prints [] [xs, "ref r = first(first(xs))", "print(len(r))"] ["2"]
#guard prints ["def at(ref a: Array[List[Int], 2]) -> ref [a] List[Int]:", "    return a[0]"]
  ["var a: Array[List[Int], 2] = [[1], [2, 3]]", "print(len(at(a)))"] ["1"]

-- A `read`, a `ref` and a `mut` parameter take it as a location.
#guard prints [] [xs, "print(count(first(xs)))"] ["2"]
#guard prints ["def n(ref ys: List[Int]) -> Int:", "    return len(ys)"]
  [xs, "print(n(first(xs)))"] ["2"]
#guard prints [] [xs, "print(push(first(xs)))", "print(len(xs))"] ["3", "3"]
-- A later argument that changes the list shows through it.
#guard prints ["def two(a: List[Int], b: Int) -> Int:", "    return len(a) + b"]
  [xs, "print(two(first(xs), push(xs)))"] ["6"]
-- An `Int` passed `read` is copied.
#guard prints ["def at(ref a: Array[Int, 2]) -> ref [a] Int:", "    return a[0]",
    "def keep(a: Int, mut b: Array[Int, 2]) -> Int:", "    b[0] = 100", "    return a"]
  ["var a: Array[Int, 2] = [1, 2]", "print(keep(at(a), a))"] ["1"]

-- The list lives until the call it is passed to is done.
#guard prints [] ["var rs: List[Res] = [Res(1), Res(2)]", "print(len(firsts(rs)))",
  "print(\"a\")"] ["drop 1", "drop 2", "2", "a"]
#guard prints [] ["var rs: List[Res] = [Res(3)]", "print(len(firsts(firsts(rs))))",
  "print(\"a\")"] ["drop 3", "1", "a"]

-- A `var` parameter copies it.
#guard rejects ["def n(var ys: List[Int]) -> Int:", "    return len(ys)"]
  [xs, "print(n(first(xs)))"] "main" (.implicitCopy (.list .int))
-- It aliases a `mut` argument, in either order.
#guard rejects ["def n(a: List[Int], mut b: List[Int]) -> Int:", "    return len(a)"]
  [xs, "print(n(first(xs), xs))"] "main" (.argumentExclusivity x)
#guard rejects ["def n(mut a: List[Int], b: List[Int]) -> Int:", "    return len(b)"]
  [xs, "print(n(xs, first(xs)))"] "main" (.argumentExclusivity x)
-- For `mut`, its origin must be mutable.
#guard rejects [] [xs, "print(push(look(xs)))"] "main" (.immutablePlace x)
#guard rejects ["def g(xs: List[Int]) -> Int:", "    return push(first(xs))"]
  [xs, "print(g(xs))"] "g" (.immutablePlace x)
-- A later argument may not move its origin away, nor invalidate it.
#guard rejects ["def take(var ys: List[Int]) -> Int:", "    return len(ys)",
    "def two(a: List[Int], b: Int) -> Int:", "    return len(a) + b"]
  [xs, "print(two(first(xs), take(xs^)))"] "main" (.uninitializedUse x)
#guard rejects ["def grow(mut ys: List[List[Int]]) -> Int:", "    ys.append([7])",
    "    return 0", "def two(a: List[Int], b: Int) -> Int:", "    return len(a) + b"]
  ["var ls: List[List[Int]] = [[1, 2]]", "print(two(first(ls[0]), grow(ls)))"] "main"
  (.invalidatedReference (.index (.var "ls") (.int 0)))
-- A result built into an element of the list it is passed `mut`.
#guard rejects ["def build(mut ys: List[Res]) -> Res:", "    return Res(len(ys))"]
  ["var rs: List[Res] = [Res(1), Res(2)]", "rs[0] = build(firsts(rs))"] "main"
  (.argumentExclusivity (.var "rs"))

end MojoGrimoireTest.Parse.ReturnedRefArgs
