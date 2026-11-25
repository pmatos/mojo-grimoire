import MojoGrimoire.Parse.Infer
import MojoGrimoire.Interp.Run

/-!
Tests of the references into an element of a list inside an array, once
the array is subscripted (#282). The compiler passes an array that may
change to `__getitem__` as a mutable `self`, which invalidates them: a
`ref` binding, or an operand located before a later operand subscripts
the array. Subscripting a list, reading the array whole, or subscripting
a `read` parameter does not. A literal is built from its elements once
every operand of its operation is evaluated, so its elements are read
then. Each verdict and output is the pinned compiler's for the program,
probed on the nightly 1.3.0.dev2026111905, but where a comment says
otherwise.
-/

namespace MojoGrimoireTest.Parse.ArraySubscripts

open MojoGrimoire.Core MojoGrimoire.Check MojoGrimoire.Parse MojoGrimoire.Interp

/-- The declarations the programs share: `T` holds an array of lists, with
a method that takes `self` `read`, and the functions take such an array
`read`, two values, or such an array `read` or `mut`, which they return
by reference. -/
private def lib : List String := [
  "@fieldwise_init",
  "struct T(Movable):",
  "    var a: Array[List[Int], 1]",
  "    def rs(self):",
  "        print(self.a[0][0], self.a[0])",
  "",
  "def rd(v: Array[List[Int], 1]):",
  "    print(v[0][0], v[0])",
  "",
  "def rdAlias(v: Array[List[Int], 1]):",
  "    ref e = v",
  "    print(e[0][0], e[0])",
  "",
  "def two(x: Int, y: List[Int]):",
  "    print(x, y)",
  "",
  "def pair(a: List[Int], b: List[Int]):",
  "    print(a, b)",
  "",
  "def firstRead(a: Array[List[Int], 1]) -> ref [a] Array[List[Int], 1]:",
  "    return a",
  "",
  "def firstMut(mut a: Array[List[Int], 1]) -> ref [a] Array[List[Int], 1]:",
  "    return a",
  "",
  "def pairOwned(a: List[Int], var b: List[Int]):",
  "    print(a, b)",
  "",
  "def takeList(var b: List[Int]) -> Int:",
  "    return len(b)",
  ""]

/-- The program of `lib`, the declarations `extra` and a `main` that starts
with the variables every test uses, then runs `body`. -/
private def progWith (extra body : List String) : List String :=
  lib ++ extra ++ "def main():" :: ([
    "var v: Array[List[Int], 1] = [[1]]",
    "var u: Array[List[List[Int]], 1] = [[[1]]]",
    "var z: List[Array[List[Int], 1]] = [[[1]]]",
    "var aa: Array[Array[Int, 1], 1] = [[1]]",
    "var w: List[Int] = [1, 2]",
    "var t = T([[1]])",
    "var x = 1"] ++ body).map ("    " ++ ·)

/-- Parses and runs the program of `extra` and `body`; a syntax error gives
`none`. -/
private def runWith (extra body : List String) : Option Outcome :=
  match parse ("\n".intercalate (progWith extra body)) with
  | .ok p => some (run p 100000)
  | .error _ => none

/-- The program of `body` alone. -/
private def runBody := runWith []

/-- Whether the program of `extra` and `body` is rejected in `where_` as
the use of an invalidated reference. -/
private def staleIn (where_ : String) (extra body : List String) : Bool :=
  match runWith extra body with
  | some (.rejected ⟨w, .invalidatedReference _⟩) => w == where_
  | _ => false

private def stale := staleIn "main" []

private def prints (body : List String) (out : List String) : Bool :=
  runBody body == some (.finished out)

-- An operand located before a later operand subscripts the array.
#guard stale ["print(v[0][0], v[0])"]
#guard stale ["print(v[0][0], len(v[0]))"]
#guard stale ["print(v[0][0] == len(v[0]))"]
#guard stale ["print(v[0][0] < v[0][0])"]
#guard stale ["var y = v[0][0] + v[0][0]"]
#guard stale ["print(v[0][0], v[0][0] + 1)"]
#guard stale ["print(v[0][0], v[0].copy())"]
#guard stale ["print(v[0][0], v[0] == v[0])"]
#guard stale ["two(v[0][0], v[0])"]
#guard stale ["print(t.a[0][0], t.a[0])"]
#guard stale ["print(u[0][0][0], u[0])", "print(1)"]
#guard stale ["print(u[0][0][0], u[0][0])"]
#guard stale ["print(z[0][0][0], z[0][0])"]
-- The receiver and the base of a subscript are located first too.
#guard stale ["u[0][0].append(u[0][0][0])"]
#guard stale ["print(u[0][0][u[0][0][0] - 1])"]
-- Through a reference to the array, or to its element.
#guard stale ["ref e = v", "print(e[0][0], e[0])"]
#guard stale ["ref e = v[0]", "print(e[0], v[0])"]
-- Through a place reached through `p^`, when the later subscript is not.
#guard stale ["print(t^.a[0][0], t.a[0])"]
-- A `ref` binding, used after a later statement subscripts the array.
#guard stale ["ref r = v[0][0]", "print(len(v[0]))", "print(r)"]
#guard stale ["ref r = v[0][0]", "var y = v[0][0]", "print(r, y)"]
#guard stale ["ref r = v[0][0]", "v[0][0] = 5", "print(r)"]
#guard stale ["ref r = v[0][0]", "r = v[0][0] + 1", "print(r)"]
#guard stale ["ref r = v[0][0]", "if v[0][0] == 1:", "    print(r)"]
#guard stale ["ref r = v[0][0]", "if True:", "    print(v[0])", "print(r)"]
-- A store through a reference invalidated by an earlier statement.
#guard stale ["ref r = v[0][0]", "print(v[0])", "r = 5", "print(v[0])"]
-- The elements of a literal are read once its operation's operands are.
#guard stale ["print([v[0][0]], v[0])"]
#guard stale ["pair([v[0][0]], v[0])"]
#guard stale ["var q = [v[0][0], v[0][0]]"]
#guard stale ["print([v[0][0]] == [v[0][0]])"]
-- ... also a list's, which a later operand changes.
#guard stale ["print([w[0]], w.pop())"]
#guard stale ["print([x, w[0]], w.pop())"]
#guard stale ["print([w[0]] == [w.pop()])"]
-- A later operand that transfers a place gives it up only once the literal
-- is built; a call that takes it runs before.
#guard prints ["var b: List[Int] = [1]", "print([b[0]], b^)"] ["[1] [1]"]
#guard prints ["var b: List[Int] = [1]", "pairOwned([b[0]], b^)"] ["[1] [1]"]
#guard match runBody ["var b: List[Int] = [1]", "print([b[0]], takeList(b^))"] with
  | some (.rejected ⟨"main", .uninitializedUse _⟩) => true
  | _ => false
-- A literal inside a literal operand is built in its turn, before its later
-- siblings: `b^` moves `b` after `[b[0]]` reads it.
#guard prints ["var b = [1]", "var r: Array[Array[Int, 1], 2] = [[1], [0]]", "print(r > [[b[0]], b^])"]
  ["False"]
-- Not yet (#308): the compiler rejects this, as `v[0]` invalidates the
-- place that the nested literal reads late; the model runs it, as `main` did.
#guard prints ["print([[v[0][0]]], v[0])"] ["[[1]] [1]"]
/-- A function `f` that takes such an array by the convention `conv`, and
prints an element of a list in it beside the list. -/
private def fn (f conv : String) : List String :=
  [s!"def {f}({conv}v: Array[List[Int], 1]):", "    print(v[0][0], v[0])", ""]

/-- A struct `S` with a method `m` that takes `self` by the convention
`conv`, and prints such an element beside its list. -/
private def method (conv : String) : List String :=
  ["@fieldwise_init", "struct S(Movable):", "    var a: Array[List[Int], 1]",
   s!"    def m({conv}self):", "        print(self.a[0][0], self.a[0])", ""]

-- An array held `mut`, `ref` or `var`, as a parameter or as `self`.
#guard staleIn "mt" (fn "mt" "mut ") ["mt(v)"]
#guard staleIn "rf" (fn "rf" "ref ") ["rf(v)"]
#guard staleIn "own" (fn "own" "var ") ["own(v^)"]
#guard staleIn "rfAlias" ["def rfAlias(ref v: Array[List[Int], 1]):", "    ref e = v",
  "    print(e[0][0], e[0])", ""] ["rfAlias(v)"]
#guard staleIn "T2.__init__" ["struct T2(Movable):", "    var a: Array[List[Int], 1]",
  "    def __init__(out self):", "        self.a = [[1]]", "        print(self.a[0][0], self.a[0])", ""]
  ["var t2 = T2()", "print(t2.a[0])"]
-- A reference that a call returns through a `mut` parameter may change;
-- one through a `read` parameter may not, and its subscript changes nothing.
#guard stale ["ref e = firstMut(v)", "print(e[0][0], e[0])"]
#guard prints ["ref e = firstRead(v)", "print(e[0][0], e[0])"] ["1 [1]"]
-- A `ref` binding to a place reached through `p^` may change it.
#guard stale ["ref e = t^.a", "print(e[0][0], e[0])"]
-- On a later iteration of a loop, and only while the reference is in scope.
#guard stale ["ref r = v[0][0]", "var i = 0", "while i < 2:", "    print(r)", "    print(v[0])",
  "    i += 1"]
#guard prints ["if True:", "    ref r = v[0][0]", "    print(v[0])", "ref r = v[0][0]", "print(r)"]
  ["[1]", "1"]
#guard staleIn "S.m" (method "mut ") ["var s = S([[1]])", "s.m()"]
#guard staleIn "S.m" (method "ref ") ["var s = S([[1]])", "s.m()"]
-- A `read` parameter or `self` is subscripted as one that may not change.
#guard runBody ["rd(v)", "rdAlias(v)", "t.rs()"] == some (.finished ["1 [1]", "1 [1]", "1 [1]"])

-- None of these subscripts invalidates a reference that is still to be read.
#guard prints ["print(v[0][0], v)"] ["1 [[1]]"]
#guard prints ["print(v[0][0], len(v))"] ["1 1"]
#guard prints ["print(z[0][0][0], z[0])"] ["1 [[1]]"]
#guard prints ["print(v[0], v[0][0])"] ["[1] 1"]
#guard prints ["print(len(v[0]), v[0][0])"] ["1 1"]
#guard prints ["print(v[0][0] + x, v[0])"] ["2 [1]"]
#guard prints ["print(v[0][v[0][0] - 1])"] ["1"]
#guard prints ["v[0][0] = v[0][0] + 1", "print(v[0])"] ["[2]"]
#guard prints ["ref e = v[0]", "print(e[0], e)"] ["1 [1]"]
#guard prints ["ref r = v[0]", "print(v[0])", "print(r)"] ["[1]", "[1]"]
#guard prints ["ref r = v[0][0]", "print(v)", "print(r)"] ["[[1]]", "1"]
#guard prints ["print(t^.a[0][0], t^.a[0])"] ["1 [1]"]
#guard prints ["print(t.a[0][0], t^.a[0])"] ["1 [1]"]
#guard prints ["print([aa[0][0]] == aa[0])"] ["True"]
#guard prints ["print(v[0] == [v[0][0]])"] ["True"]
#guard prints ["print([v[0][0] + 0], v[0])"] ["[1] [1]"]
#guard prints ["print(len([v[0][0]]), v[0])"] ["1 [1]"]
#guard prints ["print([v[0][0]] == [1], v[0])"] ["True [1]"]
#guard prints ["var q = [v[0][0]]", "print(q, v[0])"] ["[1] [1]"]
-- A store through a reference that its own value invalidates: the
-- compiler locates the reference before the value, and the store is not
-- rejected; a later read of the reference is.
#guard prints ["ref r = v[0][0]", "r = v[0][0] + 1", "print(v[0])"] ["[2]"]

-- A comparison with a literal that part 2 of #166 converts is rejected
-- too: the subscript on the right invalidates the element that the
-- literal reads late, as the pin says.
#guard match runBody ["print([v[0][0]] == v[0])"] with
  | some (.rejected ⟨"main", .invalidatedReference _⟩) => true
  | _ => false
#guard match runBody ["print([v[0][0]] == v[0].copy())"] with
  | some (.rejected ⟨"main", .invalidatedReference _⟩) => true
  | _ => false

end MojoGrimoireTest.Parse.ArraySubscripts
