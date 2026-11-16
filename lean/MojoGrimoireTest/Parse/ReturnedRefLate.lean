import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of a call that returns a reference, used as an operand that is read
by value: printed, an operand of a binary operator, an argument passed by
value, or an element of a list or an array literal. The pinned compiler
reads the reference only once every operand of the operation has been
evaluated, so a later operand's change shows through it, and its origins
must then still be initialized and not invalidated. The operand of a unary
operator, of `and` and of `or` is read at once. Each verdict and output is
the pinned compiler's for the program.
-/

namespace MojoGrimoireTest.Parse.ReturnedRefLate

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- Parses and runs the program whose lines are `ls`; a syntax error gives
`none`. -/
private def runLines (ls : List String) : Option Outcome :=
  match parse ("\n".intercalate ls) with
  | .ok prog => some (run prog 100000)
  | .error _ => none

/-- `pick` returns one of two `Int`s, `pickb` one of two `Bool`s, `pickl`
one of two lists and `pickp` one of two `P`s, which print their value when
they are destroyed; `same` returns its `P`. `bump`, `flip`, `grow` and
`bumpp` change their argument, and `takep` takes its `P`. -/
private def lib : List String := [
  "@fieldwise_init",
  "struct P(ImplicitlyCopyable):",
  "    var v: Int",
  "    def __deinit__(deinit self):",
  "        print(\"drop\", self.v)",
  "",
  "def pick(ref a: Int, ref b: Int, first: Bool) -> ref [a, b] Int:",
  "    if first:",
  "        return a",
  "    return b",
  "",
  "def pickb(ref a: Bool, ref b: Bool, first: Bool) -> ref [a, b] Bool:",
  "    if first:",
  "        return a",
  "    return b",
  "",
  "def pickl(ref a: List[Int], ref b: List[Int], first: Bool) -> ref [a, b] List[Int]:",
  "    if first:",
  "        return a",
  "    return b",
  "",
  "def pickp(ref a: P, ref b: P, first: Bool) -> ref [a, b] P:",
  "    if first:",
  "        return a",
  "    return b",
  "",
  "def bump(mut x: Int) -> Int:",
  "    x += 10",
  "    return 0",
  "",
  "def flip(mut x: Bool) -> Bool:",
  "    x = not x",
  "    return True",
  "",
  "def grow(mut xs: List[Int]) -> Int:",
  "    xs.append(3)",
  "    return 0",
  "",
  "def bumpp(mut p: P) -> Int:",
  "    p.v += 10",
  "    return 0",
  "",
  "def same(ref p: P) -> ref [p] P:",
  "    return p",
  "",
  "def takep(var x: P) -> Int:",
  "    return x.v",
  ""]

/-- The program of `lib`, the declarations `decls`, and a `main` with the
body `body`. -/
private def prog (decls body : List String) : List String :=
  lib ++ decls ++ ["def main():"] ++ body.map ("    " ++ ·)

private def prints (decls body out : List String) : Bool :=
  runLines (prog decls body) == some (.finished out)

private def rejects (decls body : List String) (err : CheckError) : Bool :=
  runLines (prog decls body) == some (.rejected ⟨"main", err⟩)

private def ab : List String := ["var a = 1", "var b = 2"]
private def xs : List String := ["var xs: List[Int] = [1, 2]", "var b = 5"]
private def elem : Place := .index (.var "xs") (.int 0)

-- `print` and a binary operator read it late.
#guard prints [] (ab ++ ["print(pick(a, b, True), bump(a))"]) ["11 0"]
#guard prints [] (ab ++ ["print(pick(a, b, True) + bump(a))"]) ["11"]
#guard prints [] (ab ++ ["print(pick(a, b, True) == bump(a) + 11)"]) ["True"]
#guard prints [] (ab ++ ["a = pick(a, b, True) * 2 + bump(a)", "print(a)"]) ["2"]
-- A unary operator, `and` and `or` read it at once.
#guard prints [] (ab ++ ["print(-pick(a, b, True), bump(a))"]) ["-1 0"]
#guard prints [] ["var p = True", "var q = False", "print(pickb(p, q, True) and flip(p))",
  "print(pickb(p, q, True) or flip(p))"] ["True", "True"]

-- An argument passed by value, to a function, an initializer or a method.
#guard prints ["def two(x: Int, y: Int) -> Int:", "    return x + y"]
  (ab ++ ["print(two(pick(a, b, True), bump(a)))"]) ["11"]
#guard prints ["def own(var x: Int, y: Int) -> Int:", "    return x + y"]
  (ab ++ ["print(own(pick(a, b, True), bump(a)))"]) ["11"]
#guard prints ["@fieldwise_init", "struct C(Movable):", "    var v: Int", "    var w: Int",
    "    def add(self, x: Int, y: Int) -> Int:", "        return x + y"]
  (ab ++ ["var c = C(pick(a, b, True), bump(a))", "print(c.v, c.w)",
    "print(c.add(pick(a, b, True), bump(a)))"]) ["11 0", "21"]

-- An element of a list or an array literal, and a printed list.
#guard prints [] (ab ++ ["var l: List[Int] = [pick(a, b, True), bump(a)]", "print(l)"])
  ["[11, 0]"]
#guard prints [] (ab ++ ["var l: Array[Int, 2] = [pick(a, b, True), bump(a)]", "print(l)"])
  ["[11, 0]"]
#guard prints [] ["var a: List[Int] = [1, 2]", "var b: List[Int] = [3]",
  "print(pickl(a, b, True), a.pop())"] ["[1] 2"]

-- Its origins live until it is read, then those that die are destroyed,
-- the last declared first, in the order the operands are read.
#guard prints ["def own(var x: P, y: Int) -> Int:", "    print(x.v, y)", "    return 0"]
  ["var a = P(1)", "var b = P(2)", "print(own(pickp(a, b, True), bumpp(a)))"]
  ["drop 2", "drop 11", "11 0", "drop 11", "0"]
#guard prints ["def own(var x: P, var y: P, z: Int) -> Int:", "    print(x.v, y.v, z)",
    "    return 0"]
  ["var c = P(3)", "var a = P(1)", "var b = P(2)", "print(own(c, pickp(a, b, True), bumpp(a)))"]
  ["drop 3", "drop 2", "drop 11", "3 11 0", "drop 11", "drop 3", "0"]

-- A copy is made before its origins are destroyed (#94), and a `return`
-- reads it before they are destroyed: the parameters first, then the
-- locals, each the last declared first.
#guard prints [] ["var p = P(7)", "print(takep(same(p)) + 1)"] ["drop 7", "drop 7", "8"]
#guard prints [] ["var p = P(7)", "print(takep(same(p)))"] ["drop 7", "drop 7", "7"]
#guard prints [] ["var p = P(7)", "var ps: List[P] = [same(p)]", "print(len(ps))"]
  ["drop 7", "drop 7", "1"]
#guard prints ["def get() -> P:", "    var a = P(1)", "    var b = P(2)",
    "    return pickp(a, b, True)"] ["var p = get()", "print(p.v)"]
  ["drop 2", "drop 1", "1", "drop 1"]
#guard prints ["def get(var a: P, var b: P) -> P:", "    return pickp(a, b, True)"]
  ["var p = get(P(1), P(2))", "print(p.v)"] ["drop 2", "drop 1", "1", "drop 1"]
#guard prints ["def get(var a: P) -> P:", "    var b = P(2)", "    return pickp(a, b, True)"]
  ["var p = get(P(1))", "print(p.v)"] ["drop 1", "drop 2", "1", "drop 1"]
-- An element of an array.
#guard prints ["def at(ref a: Array[Int, 2]) -> ref [a] Int:", "    return a[0]",
    "def setf(mut b: Array[Int, 2]) -> Int:", "    b[0] = 100", "    return 0",
    "def two(x: Int, y: Int) -> Int:", "    return x + y"]
  ["var a: Array[Int, 2] = [1, 2]", "print(two(at(a), setf(a)))"] ["100"]

-- A later operand may not invalidate its origin, in any position.
#guard rejects [] (xs ++ ["print(pick(xs[0], b, True), xs.pop())"])
  (.invalidatedReference elem)
#guard rejects [] (xs ++ ["print(pick(xs[0], b, True), grow(xs))"])
  (.invalidatedReference elem)
#guard rejects [] (xs ++ ["print(pick(xs[0], b, True) + xs.pop())"])
  (.invalidatedReference elem)
#guard rejects ["def two(x: Int, y: Int) -> Int:", "    return x + y"]
  (xs ++ ["print(two(pick(xs[0], b, True), grow(xs)))"]) (.invalidatedReference elem)
#guard rejects [] (xs ++ ["var l: List[Int] = [pick(xs[0], b, True), grow(xs)]", "print(l)"])
  (.invalidatedReference elem)
#guard rejects ["def first(ref xs: List[Int]) -> ref [xs] List[Int]:", "    return xs",
    "def shrink(mut ys: List[List[Int]]) -> Int:", "    var t = ys.pop()", "    return 0"]
  ["var ls: List[List[Int]] = [[1, 2]]", "print(first(ls[0]), shrink(ls))"]
  (.invalidatedReference (.index (.var "ls") (.int 0)))
-- An origin argument that is a temporary leaves the others to check.
#guard rejects ["def eat(var r: List[Int]) -> Int:", "    return len(r)"]
  ["var b: List[Int] = [3]", "print(pickl([1], b, False), eat(b^))"]
  (.uninitializedUse (.var "b"))
-- Reading the list does not invalidate it.
#guard prints [] (xs ++ ["print(pick(xs[0], b, True) + len(xs))"]) ["3"]
-- Nor may it move its origin away.
#guard rejects ["def eat(var r: List[Int]) -> Int:", "    return len(r)"]
  ["var a: List[Int] = [1, 2]", "var b: List[Int] = [3]", "print(pickl(a, b, True), eat(a^))"]
  (.uninitializedUse (.var "a"))

end MojoGrimoireTest.Parse.ReturnedRefLate
